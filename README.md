# SillyTavern-WebDAV

SillyTavern-WebDAV 是一个基于 [SillyTavern](https://github.com/SillyTavern/SillyTavern) 的 Docker 项目，通过 `rclone` 定期同步数据到远程 WebDAV（如 Teracloud）实现持久化，存储路径为 `/home/node/SillyTavern/data`，并使用 HTTP 基本认证（`basicAuthMode`）保护访问。项目适合本地和云部署（如 Render、Hugging Face Spaces、Fly.io、Koyeb）。

## 功能

- **数据同步**：使用 `rclone` 定期（默认每 5 分钟）将 `/home/node/SillyTavern/data` 同步到 WebDAV，取代 FUSE 挂载。
- **基本认证**：通过 `basicAuthMode` 保护 SillyTavern 访问，支持用户名/密码登录。
- **动态配置**：通过 `.env` 文件生成 `config.yaml`，支持灵活的云部署。
- **调试支持**：详细日志帮助排查同步、认证和启动问题。
- **云兼容**：支持 Render、Hugging Face Spaces、Fly.io、Koyeb 等，环境变量管理敏感信息。

## 要求

- **Docker**：最新版本（Windows、Linux 或 macOS）。
- **WebDAV 服务**：如 Teracloud、Nextcloud 或 S3（需支持 WebDAV 协议）。
- **Git**：用于克隆仓库（可选）。
- **硬件**：
  - 内存：1–2 GB。
  - CPU：1 核即可。
  - 存储：本地磁盘或 WebDAV 空间根据数据需求（建议 ≥1 GB）。

## 安装

1. **克隆仓库**（可选）：
   ```bash
   git clone https://github.com/your-username/sillytavern-webdav.git
   cd sillytavern-webdav
   ```

2. **创建 `.env` 文件**：
   在项目根目录创建 `.env`，内容如下：
   ```
   WEBDAV_SERVER=https://mori.teracloud.jp/dav/
   WEBDAV_USERNAME=your_webdav_username
   WEBDAV_PASSWORD=your_webdav_password
   DATA_DIR=/home/node/SillyTavern/data
   SYNC_INTERVAL=300
   WHITELIST_MODE=false
   PORT=8000
   LISTEN=true
   BASIC_AUTH_MODE=true
   BASIC_AUTH_USER=admin:your_basic_auth_password
   SKIP_CONTENT_CHECK=true
   ```
   - 替换 `your_webdav_username` 和 `your_webdav_password` 为你的 WebDAV 凭据。
   - 替换 `your_basic_auth_password` 为强密码（建议 ≥12 位，包含字母、数字、符号）。
   - `SYNC_INTERVAL` 为同步间隔（秒），默认 300 秒（5 分钟）。

3. **构建 Docker 镜像**：
   ```bash
   docker build -t sillytavern-webdav:latest .
   ```

4. **运行容器**：
   ```bash
   docker run -d --name sillytavern \
     --env-file .env \
     -p 8001:8000 \
     sillytavern-webdav:latest
   ```

## 云部署

### Render
1. **创建 Web 服务**：
   - 在 Render 仪表板创建 Web Service，连接到你的 GitHub 仓库。
   - 设置构建命令：`npm install`。
   - 启动命令：留空（使用 `Dockerfile` 的 `/app/start.sh`）。
2. **添加磁盘**（可选）：
   - 名称：`sillytavern-data`
   - 挂载路径：`/home/node/SillyTavern/data`
   - 大小：建议 1 GB 或根据需求。
3. **设置环境变量**：
   - 上传 `.env` 或在仪表板添加上述 `.env` 内容。
   - 使用 Render Secrets 存储 `WEBDAV_PASSWORD` 和 `BASIC_AUTH_USER` 的密码。
4. **注意事项**：
   - Render 不支持 FUSE，项目使用 `rclone` 同步数据。
   - 确保 `PORT=8000` 与服务端口匹配。

### Hugging Face Spaces
1. **创建 Space**：
   - 在 Hugging Face Spaces 创建 Docker-based Space，上传 `Dockerfile` 和项目文件。
   - 设置环境变量（同 `.env`）。
2. **注意事项**：
   - Spaces 可能不支持 FUSE，`rclone` 确保兼容。
   - 使用 2 GB RAM 配置，适合 SillyTavern。

### Fly.io
1. **部署**：
   ```bash
   flyctl deploy --image sillytavern-webdav:latest \
     --env-file .env \
     --vm-size shared-cpu-1x \
     --volume size=3
   ```
2. **注意事项**：
   - Fly.io 可能不支持 FUSE，`rclone` 确保兼容。
   - 免费层 256 MB 内存可能不足，考虑付费计划。

### Koyeb
1. **部署**：
   - 在 Koyeb 仪表板创建服务，上传 Docker 镜像。
   - 设置环境变量（同 `.env`）。
2. **注意事项**：
   - Koyeb 不支持 FUSE，`rclone` 确保兼容。
   - 512 MB 内存可能不足。

## 使用

1. **访问 SillyTavern**：
   - 本地：访问 `http://127.0.0.1:8001` 或 `http://localhost:8001`。
   - 云：访问分配的 URL（如 Render 的 `https://your-app.onrender.com`）。
   - 输入用户名 `admin` 和 `.env` 中设置的 `your_basic_auth_password`。
   - 若无认证提示，参考“调试”部分。

2. **数据存储**：
   - 数据存储在 `/home/node/SillyTavern/data`，定期同步到 WebDAV。
   - 默认包含 `default-user` 目录、`cookie-secret.txt` 等。

3. **停止和清理**：
   ```bash
   docker stop sillytavern
   docker rm sillytavern
   ```

## 调试

若遇到问题（如无法访问、认证失败、同步失败）：

1. **检查日志**：
   ```bash
   docker logs sillytavern
   ```
   预期输出：
   ```
   DEBUG: WEBDAV_SERVER=https://mori.teracloud.jp/dav/
   DEBUG: BASIC_AUTH_MODE=true
   DEBUG: Initial sync from WebDAV to /home/node/SillyTavern/data...
   ...
   Starting SillyTavern...
   SillyTavern is listening on IPv4: 0.0.0.0:8000
   ```

2. **验证配置**：
   ```bash
   docker exec -it sillytavern /bin/bash
   cat /home/node/SillyTavern/config.yaml
   cat /home/node/.config/rclone/rclone.conf
   ```
   确认 `config.yaml` 包含：
   ```yaml
   basicAuthMode: true
   basicAuthUser:
     username: "admin"
     password: "your_basic_auth_password"
   ```

3. **检查同步**：
   ```bash
   ls -l /home/node/SillyTavern/data
   rclone ls webdav:/
   ```

4. **检查端口**：
   ```bash
   netstat -tuln
   ```
   确认 `0.0.0.0:8000` 监听。

5. **手动运行**：
   ```bash
   docker exec -it sillytavern /bin/bash
   cd /home/node/SillyTavern
   su -s /bin/bash node -c "WHITELIST_MODE=false BASIC_AUTH_MODE=true node server.js"
   ```

6. **检查网络**（Windows）：
   ```powershell
   netsh advfirewall firewall add rule name="SillyTavern 8001" dir=in action=allow protocol=TCP localport=8001
   ```

## 内存开销

- **SillyTavern**：300–1000 MB。
- **rclone**：10–30 MB。
- **Node.js 依赖**：50–200 MB。
- **总计**：1–2 GB。

## 注意事项

- **密码安全**：确保 `your_basic_auth_password` 强且安全。
- **权限**：`777`/`666` 仅用于测试，生产环境建议更严格权限（如 `755`/`644`）。
- **同步频率**：调整 `SYNC_INTERVAL` 平衡性能和数据一致性（过短可能增加 WebDAV 负载）。
- **日志**：若遇到问题，请分享 `docker logs sillytavern` 输出。

## 贡献

欢迎提交问题或 PR！请遵循 [SillyTavern 贡献指南](https://github.com/SillyTavern/SillyTavern/blob/main/CONTRIBUTING.md)。

## 许可证

采用 [MIT 许可证](LICENSE)，与 SillyTavern 一致。