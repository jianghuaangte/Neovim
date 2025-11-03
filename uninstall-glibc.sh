#!/usr/bin/env bash
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 颜色重置

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}错误：请使用 sudo 或 root 用户运行本脚本${NC}"
  exit 1
fi

# 获取实际用户配置路径
TARGET_USER_HOME="$HOME"
if [ -n "$SUDO_USER" ]; then
  TARGET_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
fi

# 定义清理目标
declare -A CLEAN_PATHS=(
  ["主程序"]="/usr/local/nvim"
  ["符号链接"]="/usr/local/bin/nvim"
  ["环境配置"]="/etc/profile.d/nvim.sh"
  ["下载缓存"]="/tmp/isneovim"
  ["默认配置"]="$TARGET_USER_HOME/.config/nvim/init.lua"
)

# 终止运行中的进程
echo -e "${YELLOW}[1/5] 正在停止 Neovim 进程...${NC}"
pkill -9 nvim 2>/dev/null || true

# 主清理流程
echo -e "${YELLOW}[2/5] 开始系统级清理${NC}"
for item in "${!CLEAN_PATHS[@]}"; do
  path="${CLEAN_PATHS[$item]}"
  if [ -e "$path" ]; then
    echo -e "  ${RED}移除${NC} $item: ${YELLOW}$path${NC}"
    rm -rf "$path"
  fi
done

# 环境更新
echo -e "${YELLOW}[3/5] 更新系统环境${NC}"
source /etc/profile >/dev/null 2>&1

# 用户配置处理
echo -e "${YELLOW}[4/5] 用户配置处理${NC}"
NVIM_RELATED_PATHS=(
  "$TARGET_USER_HOME/.local/share/nvim"
  "$TARGET_USER_HOME/.cache/nvim"
  "$TARGET_USER_HOME/.config/nvim"
)

if [ -t 0 ]; then # 交互模式
  for path in "${NVIM_RELATED_PATHS[@]}"; do
    if [ -e "$path" ]; then
      read -p "是否删除用户数据 ${YELLOW}$path${NC}？(y/N): " confirm
      [[ $confirm =~ [Yy] ]] && rm -rfv "$path"
    fi
  done
else # 非交互模式
  echo -e "${YELLOW}非交互模式运行，保留以下用户数据：${NC}"
  for path in "${NVIM_RELATED_PATHS[@]}"; do
    [ -e "$path" ] && echo "  $path"
  done
  echo -e "如需清理请手动执行：${RED}rm -rf ~/.config/nvim ~/.cache/nvim ~/.local/share/nvim${NC}"
fi

# 最终检查
echo -e "${YELLOW}[5/5] 执行最终检查${NC}"
if ! command -v nvim &>/dev/null; then
  echo -e "${GREEN}✓ Neovim 已彻底卸载${NC}"
else
  echo -e "${RED}⚠ 检测到残留的 Neovim 可执行文件，请手动检查${NC}"
fi

echo -e "\n${GREEN}卸载完成！建议操作：${NC}"
echo "1. 关闭并重新打开所有终端窗口"
