#!/usr/bin/env bash
# 用法：sudo ./bootstrap_vpn.sh example.com admin@example.com
set -euo pipefail

DOMAIN="$1"          # 必填：要签发证书的域名
EMAIL="${2:-root@$DOMAIN}"  # 可选：接收续期提醒的邮箱
SWAP_GB=2
SWAPFILE="/swapfile"

echo "=== [1/3] 创建 ${SWAP_GB}GB Swap ==="
if ! grep -q "$SWAPFILE" /etc/fstab; then
  dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SWAP_GB*1024)) status=progress
  chmod 600 "$SWAPFILE"
  mkswap "$SWAPFILE"
  swapon "$SWAPFILE"
  echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
  sysctl -w vm.swappiness=10   # 建议调低换页倾向
fi
swapon --show

echo "=== [2/3] 安装 Certbot（snap 方式） ==="
if ! command -v certbot >/dev/null 2>&1; then
  apt update && apt install -y snapd
  snap install core && snap refresh core
  snap install --classic certbot            # 官方推荐方式 :contentReference[oaicite:0]{index=0}
  ln -sf /snap/bin/certbot /usr/bin/certbot
fi

echo "=== [3/3] 申请证书 ==="
certbot certonly --standalone \
  -d "$DOMAIN" \
  -m "$EMAIL" \
  --agree-tos \
  --non-interactive \
  --preferred-challenges http

LIVE_DIR="/etc/letsencrypt/live/$DOMAIN"
echo
echo "证书已生成："
echo "  公钥 (fullchain) : $LIVE_DIR/fullchain.pem"
echo "  私钥 (privkey)   : $LIVE_DIR/privkey.pem"  # Certbot 默认存放路径 :contentReference[oaicite:1]{index=1}
echo
echo "下一步交给你：将上述文件路径写入 VPN 服务端配置中，然后重载/重启服务即可。"

echo "脚本执行完毕 ✅"
