#!/usr/bin/env bash
set -e
# set -x

if [[ $EUID -ne 0 ]]; then
  echo -e "非 root 用户，请用 sudo -i 切换并输入密码再运行"
  exit 1
fi

nvim_install="${nvim_install:-yes}"


# 架构检查
# Get platform
is_platform() {
  if command -v uname >/dev/null 2>&1; then
    platform=$(uname -m)
  else
    platform=$(arch)
  fi

  ARCH="UNKNOWN"

  case "$platform" in
  x86_64)
    PACKAGE_NAME="nvim-linux-x86_64"
    ;;
  aarch64 | arm64)
    PACKAGE_NAME="nvim-linux-arm64"
    ;;
  *)
    echo -e "\r\n出错了，不支持的架构\r\n"
    exit 1
    ;;
  esac
}

download_neovim() {
  is_tmp_dir="/tmp/isneovim/"
  if [ -d "$is_tmp_dir" ]; then
    rm -rf "$is_tmp_dir"
  fi

  if [ -d "/usr/local/nvim" ]; then
    rm -rf "/usr/local/nvim"
  fi
  mkdir -p "$is_tmp_dir"
  # 从南京大学镜像站下载
  wget -P ${is_tmp_dir} https://mirror.nju.edu.cn/github-release/neovim/neovim/LatestRelease/${PACKAGE_NAME}.tar.gz
}

is_install() {
  NVIM_FILE="/tmp/isneovim/${PACKAGE_NAME}.tar.gz"
  INSTALL_DIR="/usr/local/nvim"
  tar -xzvf "$NVIM_FILE" -C /tmp/isneovim >/dev/null 2>&1
  mkdir -p "$INSTALL_DIR"
  mv /tmp/isneovim/${PACKAGE_NAME}/* "$INSTALL_DIR" >/dev/null 2>&1
  chmod +x "$INSTALL_DIR/bin/nvim"
  [ -L /usr/local/bin/nvim ] && rm /usr/local/bin/nvim
  ln -s "$INSTALL_DIR/bin/nvim" /usr/local/bin/nvim
}

ADD_PATH() {
  nvim_path="/etc/profile.d/nvim.sh"
  if [ -f "$nvim_path" ]; then
    rm -rf "$nvim_path"
  fi
  cat <<'EOF' >"$nvim_path"
export PATH=\$PATH:/usr/local/nvim/bin
EOF

  chmod +x "$nvim_path"
  source "/etc/profile"
  echo "Neovim 安装成功!,如未生效请运行 source /etc/profile"
}

ADD_MINI_CONFIG() {
  # 获取实际用户的家目录（兼容 sudo 和直接 root 执行）
  TARGET_USER_HOME="$HOME"
  if [ -n "$SUDO_USER" ]; then
    TARGET_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  fi

  NVIM_CONFIG_DIR="$TARGET_USER_HOME/.config/nvim"
  NVIM_CONFIG_FILE="$NVIM_CONFIG_DIR/init.lua"

  # 创建目录（确保权限正确）
  mkdir -p "$NVIM_CONFIG_DIR"
  chown -R "$SUDO_USER:$SUDO_USER" "$NVIM_CONFIG_DIR" 2>/dev/null || true

  # 写入配置文件
  cat <<EOF >"$NVIM_CONFIG_FILE"
-- 设置行号
vim.opt.number = true             -- 显示绝对行号
vim.opt.relativenumber = true     -- 显示相对行号
vim.opt.termguicolors = true      -- 启用真彩色

-- 设置 Tab 缩进
vim.opt.tabstop = 4              -- 一个 tab 键宽度为 4 个空格
vim.opt.shiftwidth = 4           -- 每次缩进使用 4 个空格
vim.opt.expandtab = true         -- 使用空格代替 Tab 键

-- 设置 gj gk
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true, silent = true })
-- 可视模式同理
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

  # 修正文件所有权（如果通过 sudo 执行）
  if [ -n "$SUDO_USER" ]; then
    chown "$SUDO_USER:$SUDO_USER" "$NVIM_CONFIG_FILE"
  fi
}

start_init() {
  is_platform
  download_neovim
  is_install
  ADD_PATH
  ADD_MINI_CONFIG
}

start_init_config() {
  is_platform
  ADD_MINI_CONFIG
}

# 是否安装neovim还是仅安装 配置
case "${nvim_install}" in
  yes|YES|y|Y)
    start_init
    ;;
  no|NO|n|N)
    start_init_config
    ;;
  *)
    echo "未检测到有效的 nvim_install 值，请设置 nvim_install=yes 或 nvim_install=no"
    ;;
esac
