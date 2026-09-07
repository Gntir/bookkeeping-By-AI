#!/usr/bin/env bash
# 一键初始化（在服务器上只跑一次）：装依赖 + 生成配置
set -e
cd "$(dirname "$0")"

# 1. 检查 Python3
if ! command -v python3 >/dev/null; then
    echo "错误：服务器没有 python3，先安装："
    echo "  Ubuntu/Debian: apt update && apt install -y python3 python3-pip python3-venv"
    echo "  CentOS:        yum install -y python3 python3-pip"
    exit 1
fi

# 2. 虚拟环境 + 依赖（清华镜像加速）
python3 -m venv .venv 2>/dev/null || {
    echo "创建虚拟环境失败，先装 venv 组件："
    echo "  Ubuntu/Debian: apt install -y python3-venv"
    exit 1
}
.venv/bin/pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple -q
.venv/bin/pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple -q
echo "依赖安装完成"

# 3. 生成 .env（部署包自带已配置的 .env 则直接用）
if [ ! -f .env ]; then
    SECRET=$(head -c 64 /dev/urandom | md5sum | cut -d' ' -f1)
    sed -e "s|^SECRET_KEY=.*|SECRET_KEY=$SECRET|" \
        -e "s|^PORT=.*|PORT=7012|" \
        .env.example > .env
    echo ".env 已生成（随机密钥 + 端口 7012）"
fi

# 4. 检查 aihubmix key 是否已填
KEY=$(grep -E '^AIHUBMIX_API_KEY=' .env | cut -d= -f2 | tr -d ' \r')
if [ -z "$KEY" ]; then
    echo ""
    echo "===== 还差一步 ====="
    echo "编辑配置文件填入你的 aihubmix key："
    echo "  nano .env"
    echo "  （把 AIHUBMIX_API_KEY= 后面填上 key，保存：Ctrl+O 回车，退出：Ctrl+X）"
    echo "然后启动："
    echo "  bash start.sh"
else
    echo ""
    echo "===== 配置齐全，直接启动 ====="
    echo "  bash start.sh"
    echo "  （不填 key 也能跑：手动记账/统计可用，AI 对话不可用）"
fi
