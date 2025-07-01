FROM ghcr.io/sillytavern/sillytavern:latest

# 安装 rclone、tini、dos2unix 等必要工具
USER root
RUN apk update && apk add --no-cache tini dos2unix bash curl less procps findutils && \
    curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip && \
    unzip rclone-current-linux-amd64.zip && \
    mv rclone-*-linux-amd64/rclone /usr/bin/ && \
    rm -rf rclone-*-linux-amd64* && \
    rm -rf /var/cache/apk/*

# 创建目录
RUN mkdir -p /home/node/SillyTavern/data /home/node/.config/rclone && \
    cp -r /home/node/app/* /home/node/SillyTavern/ && \
    chown -R node:node /home/node/SillyTavern /home/node/.config && \
    chmod 777 /home/node/SillyTavern/data

# 复制启动脚本
COPY start.sh /app/start.sh

# 修复换行符和权限
RUN dos2unix /app/start.sh && chmod +x /app/start.sh && chown node:node /app/start.sh

# 调试：验证 start.sh
RUN ls -l /app/start.sh || echo "ERROR: start.sh not found"

# 使用 tini 作为入口
ENTRYPOINT ["tini", "--", "/bin/bash", "/app/start.sh"]