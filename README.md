## Neovim 一键安装脚本
- 仅适用于 Linux
- 仅下载支持最新版

## 依赖项
- curl
- wget
- tar

### 说明
是否安装 neovim，设置为 no 只下载配置文件，内部下载自带镜像  
nvim_insta=no (不填默认为yes)


### 安装命令


**Root 用户**
```shell
curl -fsSL https://raw.bgithub.xyz/jianghuaangte/Neovim/refs/heads/main/install-glibc.sh | bash
# or
wget -O - https://raw.bgithub.xyz/jianghuaangte/Neovim/refs/heads/main/install-glibc.sh | bash
```

**非 Root 用户**
```shell
curl -fsSL https://raw.bgithub.xyz/jianghuaangte/Neovim/refs/heads/main/install-glibc.sh | sudo bash
# or
wget -O - https://raw.bgithub.xyz/jianghuaangte/Neovim/refs/heads/main/install-glibc.sh | sudo bash
```

**Musl**

```shell
wget -O - https://raw.bgithub.xyz/jianghuaangte/Neovim/refs/heads/main/install-musl.sh | sh
# or
wget -O - https://raw.bgithub.xyz/jianghuaangte/Neovim/refs/heads/main/install-musl.sh | sudo sh
```



## 卸载

**Root 用户**
```shell
curl -fsSL https://raw.bgithub.xyz/jianghuaangte/Neovim/refs/heads/main/uninstall-glibc.sh | bash
# or
wget -O - https://raw.bgithub.xyz/jianghuaangte/Neovim/refs/heads/main/uninstall-glibc.sh | bash
```

**非 Root 用户**
```shell
curl -fsSL https://raw.bgithub.xyz/jianghuaangte/Neovim/refs/heads/main/uninstall-glibc.sh | sudo bash
# or
wget -O - https://raw.bgithub.xyz/jianghuaangte/Neovim/refs/heads/main/uninstall-glibc.sh | sudo bash
```

## 支持

 - x86_64/arm64 (仅linxu)
 - osc 复制 (终端须支持)
