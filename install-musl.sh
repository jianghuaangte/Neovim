#!/bin/sh
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "非 root 用户，请用 sudo -i 切换并输入密码再运行"
  exit 1
fi

nvim_install="${nvim_install:-yes}"

# 架构检查
is_platform() {
  if command -v uname >/dev/null 2>&1; then
    platform=$(uname -m)
  else
    platform=$(arch)
  fi

  case "$platform" in
  x86_64)
    PACKAGE_DIR="x86_64"
    ;;
  aarch64 | arm64)
    PACKAGE_DIR="aarch64"
    ;;
  *)
    echo "\n出错了，不支持的架构\n"
    exit 1
    ;;
  esac
}

download_neovim() {
  apk update
  # 获取包列表
  packages=$(apk fetch --recursive --simulate neovim 2>&1 | awk -F' ' '{print $2}')
  # 镜像源下载
  MAIN_REPO="https://mirrors.ustc.edu.cn/alpine/edge/main/${PACKAGE_DIR}"
  COMMUNITY_REPO="https://mirrors.ustc.edu.cn/alpine/edge/community/${PACKAGE_DIR}"

  is_tmp_dir="/tmp/isneovim"
  [ -d "$is_tmp_dir" ] && rm -rf "$is_tmp_dir"
  mkdir -p "$is_tmp_dir"

  # 遍历每个包
  for pkg in $packages; do
    # 去掉版本号
    pkg_name=$(echo "$pkg" | sed 's/-[0-9].*//')
    echo "正在查找包: $pkg_name"
    # 先在community仓库查找
    if curl -s "$COMMUNITY_REPO/APKINDEX.tar.gz" | zcat | grep -q "^P:${pkg_name}$"; then
      echo "  在community仓库找到，开始下载..."
      curl -s -L -o "$is_tmp_dir/$pkg.apk" "$COMMUNITY_REPO/$pkg.apk"
      # 然后在main仓库查找
    elif curl -s "$MAIN_REPO/APKINDEX.tar.gz" | zcat | grep -q "^P:${pkg_name}$"; then
      echo "  在main仓库找到，开始下载..."
      curl -s -L -o "$is_tmp_dir/$pkg.apk" "$MAIN_REPO/$pkg.apk"
    else
      echo "  错误: 在main和community仓库都找不到包 $pkg_name"
    fi
  done
  echo "下载完成，文件保存在 $is_tmp_dir/"
}

install_apks() {
  is_tmp_dir="/tmp/isneovim"
  echo "开始安装..."
  apk add --no-network --allow-untrusted /tmp/isneovim/*.apk 2>/dev/null
  rm -rf $is_tmp_dir
  echo "安装完成"
}

ADD_MINI_CONFIG() {
  TARGET_USER_HOME="$HOME"
  if [ -n "$SUDO_USER" ]; then
    TARGET_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  fi

  NVIM_CONFIG_DIR="$TARGET_USER_HOME/.config/nvim"
  NVIM_CONFIG_FILE="$NVIM_CONFIG_DIR/init.lua"

  mkdir -p "$NVIM_CONFIG_DIR"
  chown -R "$SUDO_USER:$SUDO_USER" "$NVIM_CONFIG_DIR" 2>/dev/null || true

  cat >"$NVIM_CONFIG_FILE" <<EOF
-- 设置行号
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true      -- 启用真彩色

-- 设置 Tab 缩进
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- 设置 gj gk
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', 'j', 'gj', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', 'k', 'gk', { noremap = true, silent = true })

-- 设置剪贴板
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
    ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
  },
}
-- 文本搜索
-- 定义 map 函数（如果还没有的话）
local function map(mode, lhs, rhs, opts)
  local options = { noremap = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.keymap.set(mode, lhs, rhs, options)
end

-- 搜索功能
map('n', ',s', function()
  local word = vim.fn.input("搜索文字 > ")
  if word == nil or #word == 0 then
    -- 如果输入为空，清除搜索高亮并退出
    vim.cmd('nohlsearch')
    return
  end

  -- 转义输入文字以进行字面搜索
  local escaped_word = string.gsub(word, "\\", "\\\\")
  local literal_pattern = "\\V" .. string.gsub(escaped_word, "\n", "\\n")

  -- 设置搜索寄存器
  vim.fn.setreg('/', literal_pattern)

  -- 启用搜索高亮
  vim.cmd('set hlsearch')

  -- 尝试执行搜索，捕获可能的错误
  local success, err = pcall(function()
    vim.cmd('normal! n')
  end)

  if not success then
    -- 如果搜索失败，通知用户并清除高亮
    print("未找到模式: " .. word)
    vim.cmd('nohlsearch')
  end
end, { noremap = true, silent = false })
EOF

  [ -n "$SUDO_USER" ] && chown "$SUDO_USER:$SUDO_USER" "$NVIM_CONFIG_FILE"
}

start_init() {
  is_platform
  download_neovim
  install_apks
  ADD_MINI_CONFIG
}


start_init_config() {
  is_platform
  ADD_MINI_CONFIG
}

# 执行
case "$nvim_install" in
  yes|y|YES|Y)
    start_init
    ;;
  no|n|NO|N)
    start_init_config
    ;;
  *)
    echo "无效的 nvim_install 值，请设置为 yes 或 no"
    exit 1
    ;;
esac
