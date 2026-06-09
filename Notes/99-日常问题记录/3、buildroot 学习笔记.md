1. 如何使用本地源码作为linux/u-boot源码编译，而不是指定git仓库路径？
	- 在buildroot根目录创建 **local.mk** 文件
	- 文件内设置本地源码路径，如：
```shell
	LINUX_OVERRIDE_SRCDIR=/path/to/your/local/linux-source
	UBOOT_OVERRIDE_SRCDIR=/path/to/your/local/u-boot-source
```

下载目录：$(BR2_DL_DIR)
根目录：$(TOPDIR)
输出目录：$(BASE_DIR)

make BR2_EXTERNAL=../buildroot-external-TI ti_release_am62x_sk_defconfig

make TI_K3_BOOT_FIRMWARE_VERSION=12.00.00.06

sudo dd if=output/images/sdcard.img of=/dev/sdX
