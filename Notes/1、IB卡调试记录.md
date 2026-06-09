
### 1. 配置apt代理  【服务器没有连接外网，用笔记本做转发】
```shell
	vim /etc/apt/apt.conf.d/99clash.conf
```

```text
	Acquire::http::Proxy "http://192.168.100.100:7897";
	Acquire::https::Proxy "http://192.168.100.100:7897";
```

### 2. 配置http代理
```shell
	export http_proxy="http://192.168.100.100:7897"
	export https_proxy="http://192.168.100.100:7897"
```

### 3. 测试代理是否生效，同时更新apt库
```shell
	apt update
```

### 4. 下载并解压Nvidia驱动安装器
```shell
tar -xzvf MLNX_OFED_LINUX-24.10-4.1.4.0-ubuntu22.04-x86_64.tgz
```

### 5. 运行安装工具
```shell
cd MLNX_OFED_LINUX-24.10-4.1.4.0-ubuntu22.04-x86_64/

./mlnxofedinstall --force	# --force参数强制卸载之前安装的旧版本驱动
```

### 6. 加载新驱动
```shell
/etc/init.d/openibd restart
```

### 7. 查看节点是否生成
```shell
ibnodes
ibv_devices
```

### 8. 启动opensmd服务
```shell
systemctl enable opensmd
systemctl restart opensmd
systemctl status opensmd
```
	
### 9. 查看InfiniBand接口是否识别成功 
```shell
ip link show | grep ib
```


### 10. 查看IB接口是否ACTIVE
```shell
ibstatus
```


### 11. 配置网络 【以ibs5接口为例】
```shell
vim /etc/netplan/00-installer-config.yaml
```

在后边追加如下内容：

```text
ibs5:
      addresses:
        - 192.168.200.80/24
      dhcp4: false
```
	
	
### 12. 测试网络是否连通
```shell
ping 192.168.200.81
```
