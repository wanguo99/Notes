## 1. 设置root密码并切换至root 【可选】
```bash
sudo passwd root && su
```

## 2. 更新软件
```bash
sudo apt update -y && sudo apt upgrade -y 
```

## 3. 配置时区
```bash
sudo timedatectl set-timezone Asia/Shanghai
```

## 4. 配置ssh
### 4.1 安装openssh
```bash
sudo apt install -y libssl-dev openssh-server openssh-client
```
### 4.2 ssh配置文件修改
```bash
sudo cat >> /etc/ssh/sshd_config.d/wanguo.conf << EOF
# 设置密码登录
PasswordAuthentication yes

# 允许root登录
PermitRootLogin yes
EOF
```
### 4.3 重启sshd服务
```bash
sudo systemctl restart sshd
```

## 8. 搭建nfs服务器
### 8.1 安装nfs-server
```bash
sudo apt install -y nfs-kernel-server
```
### 8.2 创建nfs目录
```bash
sudo mkdir -p /srv/nfs  # 与tftp同一级根目录
```
### 8.3 配置nfs目录
```bash
echo "/srv/nfs *(rw,sync,no_root_squash,no_subtree_check)" | sudo tee -a /etc/exports
```
### 8.4 重启nfs服务
```bash
sudo systemctl restart nfs-kernel-server
```
### 8.5 查看nfs目录是否导出成功
```bash
showmount -e
```
### 8.6 查看nfs目录是否可以正常挂载
挂载nfs目录并创建文件，若能挂载成功，且在nfs目录下看到测试文件生成，则说明功能正常
```bash
# 创建临时目录并将其挂载到nfs目录
mkdir ${HOME}/nfs_test && sudo mount -t nfs 127.0.0.1:/srv/nfs ${HOME}/nfs_test
```
```bash
# 在挂载目录内创建测试文件
sudo touch ${HOME}/nfs_test/test_file
```
```bash
# 查看nfs目录下是否生成了测试文件
ls -l /srv/nfs/test_file
```
```bash
# 卸载nfs目录
sudo umount ${HOME}/nfs_test
```

## 9. 搭建tftp服务器
### 9.1 安装tftpd-hpa
```bash
sudo apt update -y
sudo apt install -y tftpd-hpa
```
### 9.2 创建tftp目录
```bash
sudo mkdir -p /srv/tftp; sudo chmod 777 /srv/tftp
```
### 9.3 配置tftp【可选】
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
### 9.4 重启TFTP服务以应用更改
```bash
sudo systemctl restart tftpd-hpa
```
