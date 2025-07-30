# mkbkboot

交互式一键脚本：  
1. 创建自定义大小的 Swap  
2. 安装 Certbot（snap）并签发 Let’s Encrypt 证书  

---

## 使用方法

公开免费命令，直接执行（脚本会逐步提示输入）：

```bash
curl -sSL https://raw.githubusercontent.com/AlexLing6er/mkbkboot/main/mkbkboot.sh | sudo bash
```

## 逗号自用命令，切勿使用！数据被改后果自负!
### v2bx
```bash
wget -N https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh && bash install.sh
```
### 3xui
```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```
### bbr
centos预先准备
```bash
yum install ca-certificates wget -y && update-ca-trust force-enable
```
debian/ubuntu预先准备
```bash
apt-get install ca-certificates wget -y && update-ca-certificates
```

不卸载内核版本
```bash
wget -O tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh" && chmod +x tcpx.sh && ./tcpx.sh
```

卸载内核版本(小白勿用)
```bash
wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
```
