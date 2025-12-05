# HƯỚNG DẪN CÀI ĐẶT STORAGE MONITORING

## 1. Trên Linux Server

### Bước 1: Copy scripts lên server
```bash
# Tạo thư mục
sudo mkdir -p /usr/local/bin
sudo mkdir -p /var/lib/node_exporter/textfile_collector

# Copy scripts
sudo cp scripts/collect_user_storage.sh /usr/local/bin/
sudo cp scripts/collect_user_subfolders.sh /usr/local/bin/

# Phân quyền
sudo chmod +x /usr/local/bin/collect_user_storage.sh
sudo chmod +x /usr/local/bin/collect_user_subfolders.sh
```

### Bước 2: Cấu hình Node Exporter với textfile collector
```bash
# Sửa Node Exporter service để thêm textfile collector
sudo nano /etc/systemd/system/node_exporter.service

# Thêm flag: --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
ExecStart=/usr/local/bin/node_exporter \
  --collector.textfile.directory=/var/lib/node_exporter/textfile_collector

# Restart Node Exporter
sudo systemctl daemon-reload
sudo systemctl restart node_exporter
```

### Bước 3A: Dùng Systemd Timer (Khuyên dùng)
```bash
# Copy systemd files
sudo cp systemd/user-storage-collector.service /etc/systemd/system/
sudo cp systemd/user-storage-collector.timer /etc/systemd/system/

# Enable và start timer
sudo systemctl daemon-reload
sudo systemctl enable user-storage-collector.timer
sudo systemctl start user-storage-collector.timer

# Kiểm tra status
sudo systemctl status user-storage-collector.timer
sudo systemctl list-timers user-storage-collector.timer
```

### Bước 3B: Hoặc dùng Cron
```bash
# Thêm vào crontab
sudo crontab -e

# Copy nội dung từ crontab/user-storage-cron.txt
*/5 * * * * /usr/local/bin/collect_user_storage.sh >> /var/log/user_storage_collector.log 2>&1
*/5 * * * * /usr/local/bin/collect_user_subfolders.sh >> /var/log/user_storage_collector.log 2>&1
```

### Bước 4: Test scripts
```bash
# Chạy thử scripts
sudo /usr/local/bin/collect_user_storage.sh
sudo /usr/local/bin/collect_user_subfolders.sh

# Kiểm tra output
cat /var/lib/node_exporter/textfile_collector/user_storage.prom
cat /var/lib/node_exporter/textfile_collector/user_subfolders.prom
```

## 2. Cấu hình Prometheus

### Bước 1: Thêm storage alert rules
```bash
# Thêm vào prometheus.yml
rule_files:
  - "/etc/prometheus/alert.rules.yml"
  - "/etc/prometheus/storage_alert.rules.yml"  # <-- Thêm dòng này
```

### Bước 2: Restart Prometheus
```bash
docker compose -f docker-compose.monitoring.yml restart prometheus
```

### Bước 3: Kiểm tra metrics
Truy cập: http://localhost:9090/graph

Query:
- `user_workspace_bytes` - Xem dung lượng user workspace
- `user_subfolder_bytes` - Xem dung lượng subfolders
- `user_workspace_bytes / 1024 / 1024 / 1024` - Xem GB

## 3. Metrics Format

### User Workspace Metrics
```prometheus
user_workspace_bytes{user="user1",path="/home/user1"} 53687091200
user_workspace_bytes{user="user2",path="/home/user2"} 21474836480
```

### Subfolder Metrics
```prometheus
user_subfolder_bytes{user="user1",folder="A",path="/home/user1/A"} 10737418240
user_subfolder_bytes{user="user1",folder="B",path="/home/user1/B"} 5368709120
```

## 4. Alerts

### Warning Alerts
- **UserWorkspaceHighUsage**: User workspace > 50GB
- **UserSubfolderHighUsage**: Subfolder > 10GB

### Critical Alerts
- **UserWorkspaceCriticalUsage**: User workspace > 100GB
- **UserSubfolderCriticalUsage**: Subfolder > 20GB

## 5. Grafana Queries

### Panel 1: User Workspace Usage (Table)
```promql
user_workspace_bytes / 1024 / 1024 / 1024
```
Format: Table, Columns: user, path, Value (GB)

### Panel 2: Top 10 Subfolders by Size
```promql
topk(10, user_subfolder_bytes / 1024 / 1024 / 1024)
```

### Panel 3: Total Storage by User (Bar Chart)
```promql
sum by (user) (user_workspace_bytes) / 1024 / 1024 / 1024
```

### Panel 4: Storage Growth Over Time
```promql
user_workspace_bytes[1h] / 1024 / 1024 / 1024
```

## 6. Troubleshooting

### Kiểm tra Node Exporter có nhận metrics không
```bash
curl http://localhost:9101/metrics | grep user_workspace
curl http://localhost:9101/metrics | grep user_subfolder
```

### Kiểm tra Prometheus có scrape được không
```bash
# Vào Prometheus UI: http://localhost:9090/targets
# Tìm node-exporter target, kiểm tra status UP
```

### Xem logs
```bash
# Systemd timer logs
sudo journalctl -u user-storage-collector.service -f

# Cron logs
sudo tail -f /var/log/user_storage_collector.log
```

## 7. Tùy chỉnh

### Thay đổi thư mục monitor
Sửa trong scripts:
```bash
# Thay vì /home/*, monitor /data/users/*
for user_dir in /data/users/*; do
```

### Thay đổi interval
- Systemd: Sửa `OnUnitActiveSec=5min` trong `.timer` file
- Cron: Sửa `*/5 * * * *` (mỗi 5 phút)

### Thay đổi threshold alerts
Sửa trong `storage_alert.rules.yml`:
```yaml
expr: user_workspace_bytes / 1024 / 1024 / 1024 > 50  # Đổi 50 thành giá trị khác
```
