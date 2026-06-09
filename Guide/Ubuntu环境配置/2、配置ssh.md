
## 1. 安装openssh
```bash
sudo apt install -y libssl-dev openssh-server openssh-client
```
## 2. ssh配置文件修改
```bash
sudo cat >> /etc/ssh/sshd_config.d/wanguo.conf << EOF
# 设置密码登录
PasswordAuthentication yes

# 允许root登录
PermitRootLogin yes
EOF
```
## 3. 重启sshd服务
```bash
sudo systemctl restart sshd
```
