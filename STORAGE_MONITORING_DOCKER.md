# STORAGE MONITORING VỚI NODE EXPORTER TRONG DOCKER

## Cách hoạt động

Node Exporter chạy trong Docker container nhưng đọc metrics từ host thông qua volume mount:
- Host Linux: Scripts ghi metrics vào `/var/lib/node_exporter/textfile_collector/*.prom`
- Docker mount: `/var/lib/node_exporter/textfile_collector:/textfile_collector:ro`
- Node Exporter đọc từ `/textfile_collector` trong container

## Setup trên Host Linux

### 1. Tạo thư mục textfile collector
```bash
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chmod 755 /var/lib/node_exporter/textfile_collector
```

### 2. Copy scripts lên server
```bash
# Tạo thư mục scripts
sudo mkdir -p /usr/local/bin

# Copy từ repo
sudo cp scripts/collect_user_storage.sh /usr/local/bin/
sudo cp scripts/collect_user_subfolders.sh /usr/local/bin/

# Phân quyền thực thi
sudo chmod +x /usr/local/bin/collect_user_storage.sh
sudo chmod +x /usr/local/bin/collect_user_subfolders.sh
```

### 3. Setup Systemd Timer (Khuyên dùng)
```bash
# Copy systemd files
sudo cp systemd/user-storage-collector.service /etc/systemd/system/
sudo cp systemd/user-storage-collector.timer /etc/systemd/system/

# Reload và enable
sudo systemctl daemon-reload
sudo systemctl enable user-storage-collector.timer
sudo systemctl start user-storage-collector.timer

# Kiểm tra
sudo systemctl status user-storage-collector.timer
sudo systemctl list-timers | grep user-storage
```

### 4. Hoặc dùng Cron
```bash
# Mở crontab
sudo crontab -e

# Thêm vào (chạy mỗi 5 phút)
*/5 * * * * /usr/local/bin/collect_user_storage.sh >> /var/log/user_storage_collector.log 2>&1
*/5 * * * * /usr/local/bin/collect_user_subfolders.sh >> /var/log/user_storage_collector.log 2>&1
```

### 5. Test scripts
```bash
# Chạy thử
sudo /usr/local/bin/collect_user_storage.sh
sudo /usr/local/bin/collect_user_subfolders.sh

# Kiểm tra output
ls -la /var/lib/node_exporter/textfile_collector/
cat /var/lib/node_exporter/textfile_collector/user_storage.prom
cat /var/lib/node_exporter/textfile_collector/user_subfolders.prom
```

## Setup Docker Stack

### 1. Docker Compose đã được cấu hình
File `docker-compose.monitoring.yml` đã được update với:
```yaml
node-exporter:
  command:
    - '--collector.textfile.directory=/textfile_collector'
  volumes:
    - /var/lib/node_exporter/textfile_collector:/textfile_collector:ro
```

### 2. Prometheus đã có storage alert rules
```yaml
prometheus:
  volumes:
    - ./monitoring_config/storage_alert.rules.yml:/etc/prometheus/storage_alert.rules.yml
```

### 3. Restart Docker stack
```bash
# Down containers
docker compose -f docker-compose.monitoring.yml down

# Up lại với config mới
docker compose -f docker-compose.monitoring.yml up -d

# Check logs
docker logs node-exporter
docker logs prometheus
```

## Kiểm tra

### 1. Test metrics trong Node Exporter
```bash
# Curl từ host
curl http://localhost:9101/metrics | grep user_workspace
curl http://localhost:9101/metrics | grep user_subfolder

# Hoặc từ container
docker exec node-exporter wget -qO- http://localhost:9100/metrics | grep user_
```

### 2. Test Prometheus scrape
- Mở: http://localhost:9090/targets
- Tìm `node-exporter` target, check status UP
- Vào Graph tab, query: `user_workspace_bytes`

### 3. Test alerts
- Mở: http://localhost:9090/alerts
- Tìm: `UserWorkspaceHighUsage`, `UserSubfolderHighUsage`
- Check state: Inactive/Pending/Firing

## Metrics Query Examples

### Xem dung lượng user workspace (GB)
```promql
user_workspace_bytes / 1024 / 1024 / 1024
```

### Top 5 users dùng nhiều storage nhất
```promql
topk(5, user_workspace_bytes)
```

### Xem dung lượng subfolder (GB)
```promql
user_subfolder_bytes / 1024 / 1024 / 1024
```

### Top 10 subfolders lớn nhất
```promql
topk(10, user_subfolder_bytes)
```

### Tổng storage theo user
```promql
sum by (user) (user_workspace_bytes) / 1024 / 1024 / 1024
```

## Grafana Dashboard

### Panel 1: User Storage Table
**Query:**
```promql
user_workspace_bytes / 1024 / 1024 / 1024
```
**Visualization:** Table  
**Columns:** user, path, Value (rename to "Size (GB)")

### Panel 2: Subfolder Storage Table
**Query:**
```promql
user_subfolder_bytes / 1024 / 1024 / 1024
```
**Visualization:** Table  
**Columns:** user, folder, path, Value (rename to "Size (GB)")

### Panel 3: Top Users Bar Chart
**Query:**
```promql
topk(10, user_workspace_bytes / 1024 / 1024 / 1024)
```
**Visualization:** Bar Chart  
**Legend:** {{user}}

### Panel 4: Storage Trend
**Query:**
```promql
user_workspace_bytes{user="user1"} / 1024 / 1024 / 1024
```
**Visualization:** Time Series  
**Legend:** {{user}} - {{path}}

## Troubleshooting

### Metrics không xuất hiện

**1. Check file tồn tại trên host:**
```bash
ls -la /var/lib/node_exporter/textfile_collector/
```

**2. Check quyền file:**
```bash
# File phải readable
sudo chmod 644 /var/lib/node_exporter/textfile_collector/*.prom
```

**3. Check Node Exporter logs:**
```bash
docker logs node-exporter 2>&1 | grep textfile
docker logs node-exporter 2>&1 | grep error
```

**4. Check volume mount:**
```bash
docker inspect node-exporter | grep -A 10 Mounts
```

**5. Test metrics endpoint:**
```bash
curl http://localhost:9101/metrics | grep -E "(user_workspace|user_subfolder)"
```

### Scripts không chạy

**1. Check systemd timer:**
```bash
sudo systemctl status user-storage-collector.timer
sudo journalctl -u user-storage-collector.service -n 50
```

**2. Check cron:**
```bash
sudo tail -f /var/log/user_storage_collector.log
sudo grep CRON /var/log/syslog | grep user_storage
```

**3. Test manual run:**
```bash
sudo /usr/local/bin/collect_user_storage.sh
echo $?  # Should return 0 for success
```

### Alerts không fire

**1. Check Prometheus rules:**
```bash
# Vào UI: http://localhost:9090/rules
# Tìm: storage_alerts group
```

**2. Check alert expression:**
```bash
# Vào Graph, test query:
user_workspace_bytes / 1024 / 1024 / 1024 > 50
```

**3. Check Alertmanager:**
```bash
# http://localhost:9093/#/alerts
docker logs alertmanager
```

## Tùy chỉnh

### Thay đổi đường dẫn monitor
Sửa trong scripts:
```bash
# Từ /home/* sang /data/users/*
for user_dir in /data/users/*; do
```

### Thay đổi interval
**Systemd:**
```bash
sudo nano /etc/systemd/system/user-storage-collector.timer
# Sửa: OnUnitActiveSec=5min → OnUnitActiveSec=10min
sudo systemctl daemon-reload
sudo systemctl restart user-storage-collector.timer
```

**Cron:**
```bash
sudo crontab -e
# */5 * * * * → */10 * * * * (mỗi 10 phút)
```

### Thay đổi threshold alerts
Sửa `monitoring_config/storage_alert.rules.yml`:
```yaml
# User workspace > 50GB → 100GB
expr: user_workspace_bytes / 1024 / 1024 / 1024 > 100
```

Restart Prometheus:
```bash
docker compose -f docker-compose.monitoring.yml restart prometheus
```

## Best Practices

1. **Permissions**: Đảm bảo scripts có quyền đọc /home/*
2. **Disk I/O**: Interval không nên quá ngắn (khuyến nghị >= 5 phút)
3. **Monitoring**: Theo dõi logs của scripts để phát hiện lỗi sớm
4. **Backup**: Backup metrics files trước khi update scripts
5. **Testing**: Test trên 1-2 users trước khi áp dụng toàn bộ

## Quick Commands Reference

```bash
# Start monitoring
docker compose -f docker-compose.monitoring.yml up -d

# View metrics
curl http://localhost:9101/metrics | grep user_

# Restart timer
sudo systemctl restart user-storage-collector.timer

# Check logs
docker logs node-exporter
docker logs prometheus
sudo journalctl -u user-storage-collector.service -f

# Manual run
sudo /usr/local/bin/collect_user_storage.sh
sudo /usr/local/bin/collect_user_subfolders.sh
```
