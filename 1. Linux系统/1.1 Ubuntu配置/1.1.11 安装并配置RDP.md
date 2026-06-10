Windows 带有一个非常方便的功能，称为远程桌面连接，它使用 RDP 协议远程连接 PC。虽然在建立从 Windows 到 Windows 系统的远程桌面连接时使用起来非常容易，但对于 Linux 系统来说就不一样了。这是因为Linux默认没有安装RDP协议。在这种情况下，我们必须在 Linux 系统上手动执行一些配置来启用 RDP，在本指南中我们知道如何做到这一点。

什么是XRDP？

`XRDP 是一个免费的开源程序，是 Microsoft RDP（远程桌面协议）的实现，可通过 GUI 轻松远程访问 Linux 系统。使用 XRDP，可以登录到远程 Linux 计算机并创建一个真实的桌面会话，就像您登录到本地计算机一样。`

## 1.执行系统更新

在本教程中，我们将使用系统的默认存储库和 APT 包管理器。因此，要重建 APT 缓存，请运行一次系统更新命令。

```plaintext
sudo apt update
```

## 2. 在 Ubuntu 22.04 上安装 XRDP

我们知道 Ubuntu 没有像 Windows 操作系统那样安装 RDP，因此，我们需要在我们的 Linux 系统上安装 RDP 的开源实现 XRDP。好在我们不需要添加任何第三方存储库，因为它可以使用系统默认安装。

```mipsasm
sudo apt install xrdp
```

## 3. 启动并启用 XRDP 服务

要在系统启动时自动启动并启用 XRDP 服务，请使用给定的命令：

**要启动它：**

```plaintext
sudo systemctl start xrdp
```

**开机启用它：**

```plaintext
sudo systemctl enable xrdp
```

**检查状态：**

```plaintext
systemctl status xrdp
```

## 4.在防火墙中打开3389端口

要让网络中的其他系统通过 RDP 远程访问 Ubuntu 22.04 Jammy，请在系统防火墙上打开端口号 3389。

```yaml
sudo ufw allow from any to any port 3389 proto tcp
```