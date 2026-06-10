## 1、配置全局工具链
### 1. 编译SDK
```bash
sudo mkdir -p /opt/buildroot/download
```
```bash
sudo mkdir -p /opt/buildroot/download
```
### 1.2 安装到服务器
```bash
sudo mkdir -p /opt/buildroot/download
```
## 2、配置全局dl目录
### 2.1 修改defconfig目录
```bash
sudo mkdir -p /opt/buildroot/download
```
### 2.1 创建目录
```bash
sudo mkdir -p /opt/buildroot/download
```
### 2.2 设置所有者为root
```bash
sudo chown -R root:root /opt/buildroot
```
### 2.3 设置download目录权限为全局可读写
```bash
sudo chmod -R 1777 /opt/buildroot/download
```
>权限说明:
>- 1777中的 1 是 sticky bit（粘滞位）
>- 777 = 所有人可读、可写、可执行
>- sticky bit作用：用户只能删除自己创建的文件，不能删除别人的文件（类似 /tmp 目录）
