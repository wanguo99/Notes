## 1. 安装zsh
```bash
sudo apt install -y zsh
```

## 2. 下载并安装oh-my-zsh
```bash
sh -c "$(curl -fsSL https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh)"
```

## 3. 安装插件
### 3.1 命令高亮
```bash
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```
### 3.2 命令提示
```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```
### 3.3 命令补全
```bash
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions
```

## 4. 配置zshrc
[[97-4 zshrc|>>点击跳转，复制文件内容并替换到 ~/.zshrc <<]]
```bash
vim ~/.zshrc
```
