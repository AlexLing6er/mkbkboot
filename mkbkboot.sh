#!/usr/bin/env bash
# Description : 为新 VPS 创建 2 GB Swap 并申请 Let's Encrypt 证书
# Usage       : sudo ./mkbkboot.sh [DOMAIN] [EMAIL]
#               - 不传参且是交互式 TTY → 脚本会逐步询问
#               - 非交互环境下若缺参 → 直接给出用法并退出
set -euo pipefail

###########################
# 0. 判断是否交互式       #
###########################
is_interactive() { [[ -t 0 && -t 1 ]]; }

###########################
# 1. 格式校验            #
###########################
valid_domain() { [[ "$1" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; }
valid_email()  { [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; }

prompt() {
  local tip="$1" default="$2" var
  while true; do
    read -rp "$tip [$default]: " var || { echo; exit 1; }
    var="${var:-$default}"
    [[ -n "$var" ]] && { printf '%s' "$var"; return; }
  done
}

DOMAIN="${1:-}"
EMAIL="${2:-}"

# ▲ 非交互 + 缺少必填参数 → 打印帮助并退出
if ! is_interactive && [[ -z "$DOMAIN" ]]; then
  cat >&2 <<USAGE
用法: curl ... | bash -s -- <DOMAIN> [EMAIL]
  <DOMAIN>  必填，要申请证书的域名
  [EMAIL]   选填，默认 root@<DOMAIN>
USAGE
  exit 1
fi

# ▼ 交互模式或已传参，继续处理
while [[ -z "$DOMAIN" || ! $(valid_domain "$DOMAIN") ]]; do
  DOMAIN="$(prompt '请输入要签发证书的域名 (必填)' vpn.example.com)"
  valid_domain "$DOMAIN" || { echo "❌ 域名格式不正确，请重新输入！"; DOMAIN=""; }
done

while [[ -z "$EMAIL" || ! $(valid_email "$EMAIL") ]]; do
  EMAIL="$(prompt '请输入通知邮箱 (可回车默认)' "root@$DOMAIN")"
  valid_email "$EMAIL" || { echo "❌ 邮箱格式不正确，请重新输入！"; EMAIL=""; }
done

echo -e "\n➡️  域名: $DOMAIN\n📧 邮箱: $EMAIL\n"

###########################
# 2. 创建 Swap            #
###########################
SWAP_GB=2
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

🎉  证书签发成功！
  公钥 (fullchain) : $LIVE_DIR/fullchain.pem
  私钥 (privkey)   : $LIVE_DIR/privkey.pem

请将以上路径写入 VPN 配置，并重载/重启服务。
EOF
