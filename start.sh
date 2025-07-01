#!/bin/bash

# 环境变量
WEBDAV_SERVER="${WEBDAV_SERVER:-https://your-webdav-server.com}"
WEBDAV_USERNAME="${WEBDAV_USERNAME:-your_username}"
WEBDAV_PASSWORD="${WEBDAV_PASSWORD:-your_password}"
DATA_DIR="/home/node/SillyTavern/data"
SYNC_INTERVAL="${SYNC_INTERVAL:-300}" # 同步间隔（秒），默认 5 分钟
WHITELIST_MODE="${WHITELIST_MODE:-false}"
PORT="${PORT:-8000}"
LISTEN="${LISTEN:-true}"
BASIC_AUTH_MODE="${BASIC_AUTH_MODE:-false}"
BASIC_AUTH_USER="${BASIC_AUTH_USER:-}"
SKIP_CONTENT_CHECK="${SKIP_CONTENT_CHECK:-true}"
RCLONE_CONFIG="/home/node/.config/rclone/rclone.conf"

# 验证环境变量
if [ -z "$WEBDAV_SERVER" ] || [ "$WEBDAV_SERVER" = "https://your-webdav-server.com" ]; then
  echo "ERROR: WEBDAV_SERVER is not set or invalid"
  sleep infinity
fi
if [ -z "$WEBDAV_USERNAME" ] || [ "$WEBDAV_USERNAME" = "your_username" ]; then
  echo "ERROR: WEBDAV_USERNAME is not set or invalid"
  sleep infinity
fi
if [ -z "$WEBDAV_PASSWORD" ] || [ "$WEBDAV_PASSWORD" = "your_password" ]; then
  echo "ERROR: WEBDAV_PASSWORD is not set or invalid"
  sleep infinity
fi
if [ "$BASIC_AUTH_MODE" = "true" ] && [ -z "$BASIC_AUTH_USER" ]; then
  echo "ERROR: BASIC_AUTH_USER is not set when BASIC_AUTH_MODE is true"
  sleep infinity
fi

# 调试：打印环境变量
echo "DEBUG: WEBDAV_SERVER=$WEBDAV_SERVER"
echo "DEBUG: WEBDAV_USERNAME=$WEBDAV_USERNAME"
echo "DEBUG: DATA_DIR=$DATA_DIR"
echo "DEBUG: WEBDAV_PASSWORD is set (length: ${#WEBDAV_PASSWORD})"
echo "DEBUG: SYNC_INTERVAL=$SYNC_INTERVAL"
echo "DEBUG: WHITELIST_MODE=$WHITELIST_MODE"
echo "DEBUG: PORT=$PORT"
echo "DEBUG: LISTEN=$LISTEN"
echo "DEBUG: BASIC_AUTH_MODE=$BASIC_AUTH_MODE"
echo "DEBUG: BASIC_AUTH_USER=$BASIC_AUTH_USER"
echo "DEBUG: SKIP_CONTENT_CHECK=$SKIP_CONTENT_CHECK"
echo "DEBUG: RCLONE_CONFIG=$RCLONE_CONFIG"

# 调试：检查 rclone
echo "DEBUG: rclone version:"
rclone --version || echo "ERROR: rclone not found"

# 配置 rclone
echo "DEBUG: Configuring rclone..."
mkdir -p /home/node/.config/rclone
cat > "$RCLONE_CONFIG" << EOF
[webdav]
type = webdav
url = $WEBDAV_SERVER
vendor = other
user = $WEBDAV_USERNAME
pass = $(rclone obscure "$WEBDAV_PASSWORD")
EOF
chown node:node "$RCLONE_CONFIG"
chmod 600 "$RCLONE_CONFIG"
echo "DEBUG: rclone.conf content:"
cat "$RCLONE_CONFIG"

# 以 node 用户进行初始同步
echo "DEBUG: Initial sync from WebDAV to $DATA_DIR..."
su -s /bin/bash node -c "rclone sync webdav:/ '$DATA_DIR' --config '$RCLONE_CONFIG' --progress" || {
  echo "WARNING: Initial WebDAV sync failed, proceeding with empty data directory"
  mkdir -p "$DATA_DIR"
}

# 创建数据目录
echo "DEBUG: Creating data directory..."
mkdir -p "$DATA_DIR"
chown node:node "$DATA_DIR"
chmod 777 "$DATA_DIR"

# 启动定期同步（后台进程，以 node 用户运行）
echo "DEBUG: Starting periodic sync every $SYNC_INTERVAL seconds..."
su -s /bin/bash node -c "while true; do echo 'DEBUG: Syncing $DATA_DIR to WebDAV...'; rclone sync '$DATA_DIR' webdav:/ --config '$RCLONE_CONFIG' --progress || echo 'WARNING: Sync to WebDAV failed'; sleep $SYNC_INTERVAL; done" &

# 生成 config.yaml
echo "DEBUG: Generating config.yaml..."
CONFIG_YAML="/home/node/SillyTavern/config.yaml"
cat > "$CONFIG_YAML" << EOF
port: $PORT
listen: $LISTEN
whitelistMode: $WHITELIST_MODE
basicAuthMode: $BASIC_AUTH_MODE
dataRoot: $DATA_DIR
EOF

# 添加 basicAuthUser
if [ "$BASIC_AUTH_MODE" = "true" ] && [ -n "$BASIC_AUTH_USER" ]; then
  IFS=':' read -r ba_username ba_password <<< "$BASIC_AUTH_USER"
  cat >> "$CONFIG_YAML" << EOF
basicAuthUser:
  username: "$ba_username"
  password: "$ba_password"
EOF
fi

# 添加 skipContentCheck
cat >> "$CONFIG_YAML" << EOF
skipContentCheck: $SKIP_CONTENT_CHECK
EOF

# 设置 config.yaml 权限
chown node:node "$CONFIG_YAML"
chmod 666 "$CONFIG_YAML"
echo "DEBUG: config.yaml content:"
cat "$CONFIG_YAML" || echo "ERROR: Cannot read config.yaml"

# 复制 config.yaml 到数据目录
echo "DEBUG: Copying config.yaml to data directory..."
cp "$CONFIG_YAML" "$DATA_DIR/config.yaml" || {
  echo "ERROR: Failed to copy config.yaml to $DATA_DIR/config.yaml"
  ls -l "$DATA_DIR"
  sleep infinity
}

# 调试：验证复制的 config.yaml
echo "DEBUG: Checking copied config.yaml:"
ls -l "$DATA_DIR/config.yaml"

# 切换到 SillyTavern 目录
echo "DEBUG: Changing to working directory /home/node/SillyTavern..."
cd /home/node/SillyTavern || {
  echo "ERROR: Failed to change to /home/node/SillyTavern"
  sleep infinity
}

# 安装 Node.js 依赖
echo "DEBUG: Installing Node.js dependencies..."
if [ -f "/home/node/SillyTavern/package.json" ]; then
  su -s /bin/bash node -c "npm install --no-audit" || {
    echo "ERROR: Failed to install Node.js dependencies"
    sleep infinity
  }
else
  echo "ERROR: package.json not found at /home/node/SillyTavern/package.json"
  sleep infinity
fi

# 调试：检查 start.sh
echo "DEBUG: Checking for start.sh..."
if [ -f "/home/node/SillyTavern/start.sh" ]; then
  echo "DEBUG: start.sh found"
else
  echo "ERROR: start.sh not found at /home/node/SillyTavern/start.sh"
  sleep infinity
fi

# 调试：检查网络
echo "DEBUG: Checking network before starting..."
netstat -tuln || echo "ERROR: Failed to check network"

# 设置 SillyTavern 环境变量
export WHITELIST_MODE="$WHITELIST_MODE"
export BASIC_AUTH_MODE="$BASIC_AUTH_MODE"

# 调试：验证环境变量
echo "DEBUG: Environment variables for SillyTavern:"
echo "WHITELIST_MODE=$WHITELIST_MODE"
echo "BASIC_AUTH_MODE=$BASIC_AUTH_MODE"

# 启动 SillyTavern
echo "Starting SillyTavern..."
exec su -s /bin/bash node -c "cd /home/node/SillyTavern && /home/node/SillyTavern/start.sh"