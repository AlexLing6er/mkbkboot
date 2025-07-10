#!/usr/bin/env bash
# Description : 创建 Swap 并申请 Let's Encrypt 证书（全部交互式）
# Usage       : sudo ./mkbkboot.sh          ← 直接运行后按提示输入
set -euo pipefail

###########################
# 0. 通用小工具           #
###########################
prompt() {                      # 强制从终端读取，确保 curl | bash 也能交互
  local tip="$1" default="$2" v
  while true; do
    read -r -p "$tip [$default]: " v </dev/tty
    v="${v:-$default}"
    [[ -n "$v" ]] && { printf '%s' "$v"; return; }
  done
}

valid_domain() { [[ "$1" =~ ^([a-zA-Z0-9-]+\.)+[A-Za-z]{2,}$ ]]; }
valid_email()  { [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; }
valid_int()    { [[ "$1" =~ ^[1-9][0-9]*$ ]]; }

###########################
# 1. 交互式收集参数       #
###########################
while true; do
  DOMAIN="$(prompt '请输入要签发证书的域名 (必填)' vpn.example.com)"
  valid_domain "$DOMAIN" && break
  echo "❌ 域名格式不正确，请重新输入！"
done

while true; do
  EMAIL="$(prompt '请输入通知邮箱 (可回车默认)' "root@$DOMAIN")"
  valid_email "$EMAIL" && break
  echo "❌ 邮箱格式不正确，请重新输入！"
done

while true; do
  SWAP_GB="$(prompt '请输入 Swap 大小 (GB)' 2)"
  valid_int "$SWAP_GB" && break
  echo "❌ 请输入正整数！"
done

echo -e "\n➡️ 域名: $DOMAIN\n📧 邮箱: $EMAIL\n💾 Swap: ${SWAP_GB}GB\n"

###########################
# 2. 创建 Swap            #
###########################
SWAPFILE="/swapfile"
echo "=== [1/3] 创建 ${SWAP_GB} GB Swap ==="
if ! grep -q "$SWAPFILE" /etc/fstab; then
  dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SWAP_GB*1024)) status=progress
  chmod 600 "$SWAPFILE"
  mkswap "$SWAPFILE"
  swapon "$SWAPFILE"
  echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
  sysctl -w vm.swappiness=10
else
  echo "Swap 已存在，跳过创建。"
fi
swapon --show

###########################
# 3. 安装 Certbot         #
###########################
echo "=== [2/3] 安装 Certbot（snap 方式） ==="
if ! command -v certbot >/dev/null 2>&1; then
  apt update && apt install -y snapd
  snap install core && snap refresh core
  snap install --classic certbot
  ln -sf /snap/bin/certbot /usr/bin/certbot
else
  echo "Certbot 已安装，跳过。"
fi

###########################
# 4. 申请证书             #
###########################
echo "=== [3/3] 申请证书 ==="
certbot certonly --standalone \
  -d "$DOMAIN" \
  -m "$EMAIL" \
  --agree-tos \
  --non-interactive \
  --preferred-challenges http

LIVE_DIR="/etc/letsencrypt/live/$DOMAIN"
cat <<EOF

🎉 证书签发成功！
  公钥 (fullchain) : $LIVE_DIR/fullchain.pem
  私钥 (privkey)   : $LIVE_DIR/privkey.pem

请将以上路径写入 VPN 配置，并重载/重启服务。
EOF
