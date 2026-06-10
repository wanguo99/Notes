## 1. 编译命令：
### 1.1 使用编译参数指定external tree路径：
```bash
BR2_EXTERNAL=${HOME}/CSPD/buildroot-external make h200_100p_am625_defconfig
```
### 1.2 使用环境变量指定external tree路径：
```bash
export BR2_EXTERNAL=${HOME}/CSPD/buildroot-external
```
```bash
make h200_100p_am625_defconfig
```
### 1.3 设置环境变量长期生效：
```bash
cat >> ${HOME}/.zshrc << EOF
export BR2_EXTERNAL=${HOME}/CSPD/buildroot-external
EOF
```