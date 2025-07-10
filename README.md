# mkbkboot

为新 VPS **一键创建 2 GB Swap + 申请 Let's Encrypt 证书** 的脚本  
（bash | Ubuntu/Debian 20.04+ | snap 版 Certbot | 自动续期）

---

## 快速使用
### 全自动传参（CI / 自动化）
```bash
curl -sSL https://raw.githubusercontent.com/AlexLing6er/mkbkboot/main/mkbkboot.sh \
  | sudo bash -s -- <DOMAIN> [EMAIL]
```
| 参数       | 是否必填 | 说明           | 默认值           |
| -------- | ---- | ------------ | ------------- |
| <DOMAIN> | ✅    | 要申请证书的完整域名   | —             |
| \[EMAIL] | ❌    | 通知邮箱（证书续期提醒） | root@<DOMAIN> |


### 零参数交互式（最省心）

```bash
curl -sSL https://raw.githubusercontent.com/AlexLing6er/mkbkboot/main/mkbkboot.sh | sudo bash
```

