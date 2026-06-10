## 1. 安装samba
```bash
sudo apt install -y samba
```
## 2. 修改samba配置
```bash
sudo cat >> /etc/samba/smb.conf << EOF

[${USER}]
comment = samba share path
browseable = yes
path = /home/${USER}
create mask = 0700
directory mask = 0700
valid users = ${USER}
force user = ${USER}
force group = ${USER}
public = yes
available = yes
writable = yes

EOF
```
## 3. 添加samba用户
执行如下命令，并根据提示设置密码
```bash
sudo smbpasswd -a ${USER}
```
## 4. 重启smbd服务
```bash
sudo systemctl restart smbd
```
