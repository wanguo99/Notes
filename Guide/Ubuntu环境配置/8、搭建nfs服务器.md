## 1. 安装nfs-server
```bash
sudo apt install -y nfs-kernel-server
```
## 2. 创建nfs目录
```bash
sudo mkdir -p /srv/nfs  # 与tftp同一级根目录
```
## 3. 配置nfs目录
```bash
echo "/srv/nfs *(rw,sync,no_root_squash,no_subtree_check)" | sudo tee -a /etc/exports
```
## 4. 重启nfs服务
```bash
sudo systemctl restart nfs-kernel-server
```
## 5. 查看nfs目录是否导出成功
```bash
showmount -e
```
## 6. 查看nfs目录是否可以正常挂载
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
