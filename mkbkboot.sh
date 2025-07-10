#!/usr/bin/env bash
# Description : 为新 VPS 创建 2 GB Swap 并申请 Let's Encrypt 证书
# Usage       : sudo ./bootstrap_vpn.sh [DOMAIN] [EMAIL]
#               - 若不传参数，将进入交互式问答。
#               - DOMAIN 必填；EMAIL 可省略，默认为 root@DOMAIN。
set -euo pipefail

###########################
# 1. 处理参数 / 交互输入  #
###########################
# 小工具：提示 + 默认值 + 必填校验
prompt() {
  local tip="$1" default="$2" var
  while true; do
    read -rp "$tip [$default]: " var
    var="${var:-$default}"      # 如果直接回车 → 用默认
    [[ -n "$var" ]] && { printf '%s' "$var"; return; }
  done
}

# 优先用位置参数；缺失时进入交互
DOMAIN="${1:-}"
EMAIL="${2:-}"

if [[ -z "$DOMAIN" ]]; then
  DOMAIN="$(prompt '请输入要签发证书的域名 (必填)' vpn.example.com)"
fi

if [[ -z "$EMAIL" ]]; then
  EMAIL="$(prompt '请输入通知邮箱 (可回车默认)' "root@$DOMAIN")"
fi

echo -e "\n➡️  域名: $DOMAIN\n📧 邮箱: $EMAIL\n"

###########################
# 2. 创建 Swap            #
###########################
SWAP_GB=2
SWAPFILE="/swapfile"

echo "=== [1/3] 创建 ${SWAP_GB}GB Swap ==="
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

🎉  证书签发成功！
  公钥 (fullchain) : $LIVE_DIR/fullchain.pem
  私钥 (privkey)   : $LIVE_DIR/privkey.pem

请将以上路径写入 VPN 配置，并重载服务。
EOF
