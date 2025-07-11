#!/usr/bin/env bash
# mkbkboot v2.4 — 体检(含公钥/私钥路径) → 交互 → 幂等
# curl -sSL https://raw.githubusercontent.com/AlexLing6er/mkbkboot/main/mkbkboot.sh | sudo bash

set -Eeuo pipefail
trap 'echo -e "\n❌ 运行出错！查看 /var/log/mkbkboot.log"; exit 1' ERR
exec > >(tee -a /var/log/mkbkboot.log) 2>&1
echo -e "\n================ 系统体检 $(date) ================"

################ 0. 体检：Swap & 证书 ################
echo "🔎 当前 Swap 状态："
if swapon --noheadings | awk '{print $1,$3,$4}'; then :; else echo "  (无已挂载 Swap)"; fi
[[ -f /swapfile ]] && ls -lh /swapfile | sed 's/^/  - /'

echo -e "\n🔎 已安装证书（含路径）："
FOUND=0
for d in /etc/letsencrypt/live/*; do
  [[ -d "$d" ]] || continue
  dn=$(basename "$d")
  echo "  - $dn"
  echo "      fullchain : $d/fullchain.pem"
  echo "      privkey   : $d/privkey.pem"
  FOUND=1
done
[[ $FOUND -eq 0 ]] && echo "  (未找到证书)"

echo -e "\n================ 开始交互 ========================="

################ 1. 工具 & 交互 ################
prompt() { local t="$1" d="$2" v; while true; do read -r -p "$t [$d]: " v </dev/tty; v="${v:-$d}"; [[ -n "$v" ]] && { printf '%s' "$v"; return; }; done; }
is_dom()  { [[ "$1" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$ ]]; }
is_mail() { [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; }
is_num()  { [[ "$1" =~ ^[1-9][0-9]*$ ]]; }

while true; do DOMAIN="$(prompt '要签发的域名(必填)' vpn.example.com)"; is_dom "$DOMAIN" && break; echo "❌ 域名格式错误"; done
while true; do EMAIL="$(prompt '通知邮箱(回车默认)' "root@$DOMAIN")"; is_mail "$EMAIL" && break; echo "❌ 邮箱格式错误"; done
while true; do SWAP_GB="$(prompt 'Swap 大小GB' 2)"; is_num "$SWAP_GB" && break; echo "❌ 需正整数"; done
echo -e "➡️  域名:$DOMAIN  邮箱:$EMAIL  Swap:${SWAP_GB}G\n"

################ 2. Swap 幂等 ################
SWAPFILE=/swapfile
if swapon --noheadings | grep -q "$SWAPFILE"; then
  echo "✔️  Swap 已挂载"
else
  if [[ -f $SWAPFILE ]]; then
    SIZE=$(stat -c%s "$SWAPFILE"); EXP=$((SWAP_GB*1024*1024*1024))
    [[ $SIZE -ne $EXP ]] && { echo "⚠️  /swapfile 大小不符，请删除重跑"; exit 1; }
    chmod 600 "$SWAPFILE"; mkswap "$SWAPFILE"; swapon "$SWAPFILE"
  else
    echo "⬜  创建 ${SWAP_GB}G Swap..."
    dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SWAP_GB*1024)) status=progress conv=fsync
    chmod 600 "$SWAPFILE"; mkswap "$SWAPFILE"; swapon "$SWAPFILE"
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
    sysctl -w vm.swappiness=10
  fi
fi

################ 3. Certbot 安装 ################
if ! command -v certbot >/dev/null 2>&1; then
  echo "⬜  安装 snapd & certbot..."
  apt update && apt install -y snapd
  snap install core && snap refresh core
  snap install --classic certbot
  ln -sf /snap/bin/certbot /usr/bin/certbot
else
  echo "✔️  Certbot 已安装"
fi

################ 4. DNS / 端口检查 ################
# 确保有 dig
if ! command -v dig >/dev/null 2>&1; then
  echo "⬜  安装 dnsutils（提供 dig）..."
  apt-get update && apt-get install -y dnsutils
fi

echo "🔍  检查 DNS..."
DNS_IP=$(dig +short "$DOMAIN" @8.8.8.8 | tail -n1)
MY_IP=$(curl -s4 ifconfig.me)
[[ "$DNS_IP" == "$MY_IP" ]] || { echo "❌ DNS 解析 ($DNS_IP) ≠ 本机 IP ($MY_IP)"; exit 1; }

echo "🔍  检查端口..."
if ss -ltn | awk '{print $4}' | grep -qE ':(80|443)$'; then
  echo "❌ 检测到 80 或 443 已被占用，先停止相关服务"; exit 1
fi

################ 5. 申请/列证书 ################
LIVE_DIR="/etc/letsencrypt/live/$DOMAIN"
if certbot certificates 2>/dev/null | grep -q "Domains: $DOMAIN"; then
  echo "✔️  已存在证书，跳过申请"
else
  echo "⬜  申请证书..."
  certbot certonly --standalone -d "$DOMAIN" -m "$EMAIL" --agree-tos --non-interactive --preferred-challenges http
fi

################ 6. 统一输出 ################
if [[ -f "$LIVE_DIR/fullchain.pem" && -f "$LIVE_DIR/privkey.pem" ]]; then
  echo -e "\n🎉  证书准备就绪！请记录以下路径："
  echo "  公钥 (fullchain) : $LIVE_DIR/fullchain.pem"
  echo "  私钥 (privkey)   : $LIVE_DIR/privkey.pem"
else
  echo "❌ 未找到证书文件，请检查 /var/log/letsencrypt/letsencrypt.log"
  exit 1
fi

echo -e "\n✅ 全部完成！日志保存在 /var/log/mkbkboot.log"
