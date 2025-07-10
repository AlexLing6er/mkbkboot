#!/usr/bin/env bash
# mkbkboot v2 — 幂等 + 自检 + 日志
# curl -sSL https://raw.githubusercontent.com/AlexLing6er/mkbkboot/main/mkbkboot_v2.sh | sudo bash
set -Eeuo pipefail
trap 'echo -e "\n❌ 脚本中断或出错！请查看 /var/log/mkbkboot.log"; exit 1' ERR

# ------------- 日志重定向 -------------
exec > >(tee -a /var/log/mkbkboot.log) 2>&1
echo -e "\n================ $(date) ================"

# ------------- 工具函数 -------------
prompt() { local t="$1" d="$2" v; while true; do read -r -p "$t [$d]: " v </dev/tty; v="${v:-$d}"; [[ -n "$v" ]] && { printf '%s' "$v"; return; }; done; }
is_domain() { [[ "$1" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$ ]]; }
is_email()  { [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; }
is_int()    { [[ "$1" =~ ^[1-9][0-9]*$ ]]; }

# ------------- 交互输入 -------------
while true; do DOMAIN="$(prompt '要签发证书的域名 (必填)' vpn.example.com)"; is_domain "$DOMAIN" && break; echo "❌ 域名格式错误"; done
while true; do EMAIL="$(prompt '通知邮箱 (回车默认)' "root@$DOMAIN")"; is_email "$EMAIL" && break; echo "❌ 邮箱格式错误"; done
while true; do SWAP_GB="$(prompt 'Swap 大小 GB' 2)"; is_int "$SWAP_GB" && break; echo "❌ 请输入正整数"; done
echo -e "➡️  域名:$DOMAIN  邮箱:$EMAIL  Swap:${SWAP_GB}G\n"

# ------------- 步骤 1：Swap -------------
SWAPFILE=/swapfile
if swapon --noheadings | grep -q "$SWAPFILE"; then
  echo "✔️  Swap 已挂载"
else
  if [[ -f $SWAPFILE ]]; then
    SIZE_ON_DISK=$(stat -c%s "$SWAPFILE")
    EXPECT=$((SWAP_GB*1024*1024*1024))
    if [[ $SIZE_ON_DISK -ne $EXPECT ]]; then
      echo "⚠️  检测到 /swapfile 大小不符 (${SIZE_ON_DISK} vs ${EXPECT})，请手动删除后重跑"; exit 1
    fi
    echo "🔄  检测到 /swapfile 未启用，正在 swapon..."
    chmod 600 "$SWAPFILE"; mkswap "$SWAPFILE"; swapon "$SWAPFILE"
  else
    echo "⬜  创建 ${SWAP_GB}G Swap..."
    dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SWAP_GB*1024)) status=progress conv=fsync
    chmod 600 "$SWAPFILE"; mkswap "$SWAPFILE"; swapon "$SWAPFILE"
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
    sysctl -w vm.swappiness=10
  fi
fi
swapon --show

# ------------- 步骤 2：Certbot 安装 -------------
if ! command -v certbot >/dev/null 2>&1; then
  echo "⬜  安装 snapd & certbot..."
  apt update && apt install -y snapd
  snap install core && snap refresh core
  snap install --classic certbot
  ln -sf /snap/bin/certbot /usr/bin/certbot
else
  echo "✔️  Certbot 已安装"
fi

# ------------- 步骤 3：DNS & 端口检查 -------------
echo "🔍  检查 DNS 解析..."
DNS_IP=$(dig +short "$DOMAIN" @8.8.8.8 | tail -n1)
SERVER_IP=$(curl -s4 ifconfig.me)
[[ "$DNS_IP" == "$SERVER_IP" ]] || { echo "❌ DNS 解析 ($DNS_IP) 与本机 IP ($SERVER_IP) 不符"; exit 1; }

echo "🔍  检查 80/443 端口占用..."
ss -ltn sport = :80 -o state listening | grep -q LISTEN && { echo "❌ 端口 80 被占用"; exit 1; }
ss -ltn sport = :443 -o state listening | grep -q LISTEN && { echo "❌ 端口 443 被占用"; exit 1; }

# ------------- 步骤 4：签发 / 续期 -------------
if certbot certificates | grep -q "Domains: $DOMAIN"; then
  echo "✔️  证书已存在，路径如下："
  certbot certificates | grep -A2 "Domains: $DOMAIN"
else
  echo "⬜  申请证书..."
  certbot certonly --standalone -d "$DOMAIN" -m "$EMAIL" --agree-tos --non-interactive --preferred-challenges http
fi

echo -e "\n✅ 全部完成！日志保存在 /var/log/mkbkboot.log"
