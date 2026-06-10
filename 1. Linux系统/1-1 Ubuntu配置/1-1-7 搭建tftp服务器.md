## 1. 安装tftpd-hpa
```bash
sudo apt update -y
sudo apt install -y tftpd-hpa
```
## 2. 创建tftp目录
```bash
sudo mkdir -p /srv/tftp; sudo chmod 777 /srv/tftp
```
## 3. 配置tftp【可选】
打开配置文件
```bash
sudo cat >> /etc/default/tftpd-hpa << EOF
# /etc/default/tftpd-hpa

TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure -l -c"
EOF
```
## 4. 重启TFTP服务以应用更改
```bash
sudo systemctl restart tftpd-hpa
```
