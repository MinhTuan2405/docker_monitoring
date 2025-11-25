# Docker Monitoring System with Prometheus and Grafana

## Introduction

This is a complete monitoring system for Docker containers and host systems using modern monitoring stack. The system includes:

### Main Components

- **Prometheus** - Time-series database for collecting and storing metrics
- **Grafana** - Data visualization platform and dashboard creation
- **Alertmanager** - Alert management and email notifications
- **cAdvisor** - Collects container metrics (CPU, memory, network, disk I/O)
- **Node Exporter** - Collects host system metrics (CPU, memory, disk, network)

### Features

✅ Real-time monitoring of Docker containers  
✅ Host system resource monitoring (CPU, RAM, Disk, Network)  
✅ Visual dashboards with Grafana  
✅ Automatic email alerts when:
  - Instance/service is down
  - CPU usage > 90% for 5 minutes
  - Disk space < 10% for 10 minutes
✅ Flexible and easily extensible configuration  
✅ Persistent data with Docker volumes

---

## Installation Guide

### System Requirements

- **Docker** version 20.10 or higher
- **Docker Compose** version 2.0 or higher
- **Minimum RAM**: 4GB (recommended 8GB)
- **Disk space**: 10GB free
- **OS**: Windows, Linux, or macOS

### Installation Steps

#### 1. Clone or download the project

```bash
cd d:\WorkSpace\projects\docker_monitoring
```

#### 2. Configure Alertmanager (Optional)

If you want to receive email alerts, edit the file `monitoring_config/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: 'smtp.office365.com:587'
  smtp_from: 'your-email@yourcompany.com'
  smtp_auth_username: 'your-email@yourcompany.com'
  smtp_auth_password: 'YOUR_APP_PASSWORD'
  smtp_require_tls: true

receivers:
  - name: 'email-alerts'
    email_configs:
      - to: 'recipient1@yourcompany.com,recipient2@yourcompany.com'
```

**Note**: 
- For Outlook/Microsoft 365, you need to create an App Password instead of using your regular password
- Access: https://account.microsoft.com/security → App passwords

#### 3. Fix typo in docker-compose.yml

The `docker-compose.yml` file has a typo in the postgres image:

```yaml
# Wrong: postgres:lastest
# Correct: postgres:latest
```

Change to:

```yaml
services:
  postgres:
    image: postgres:latest  
```

#### 4. Start the monitoring system

```bash
# Start all services
docker-compose -f docker-compose.monitoring.yml up -d

# Check status
docker-compose -f docker-compose.monitoring.yml ps
```

#### 5. Start PostgreSQL service (if needed)

```bash
docker-compose -f docker-compose.yml up -d
```

#### 6. Verify services are running

```bash
docker ps
```

You should see the following containers running:
- prometheus
- grafana
- alertmanager
- cadvisor
- node-exporter
- postgres (if started)

---

## Usage Guide

### Access Web Interfaces

| Service | URL | Username | Password | Description |
|---------|-----|----------|----------|-------------|
| **Grafana** | http://localhost:3001 | admin | admin | Dashboard and visualization |
| **Prometheus** | http://localhost:9090 | - | - | Query metrics and alerts |
| **Alertmanager** | http://localhost:9093 | - | - | Alert management |
| **cAdvisor** | http://localhost:8080 | - | - | Container metrics |
| **Node Exporter** | http://localhost:9101/metrics | - | - | Host metrics (raw) |

### Using Grafana

#### 1. First login

- Access http://localhost:3001
- Username: `admin`
- Password: `admin`
- System will ask to change password (can skip)

#### 2. Create Dashboard

**Option 1: Import pre-built dashboard from Grafana.com**

1. Click **+** → **Import**
2. Enter dashboard ID:
   - **893** - Docker Monitoring
   - **1860** - Node Exporter Full
   - **193** - Docker Dashboard
3. Select Prometheus datasource → **Import**

**Option 2: Create new dashboard**

1. Click **+** → **Create Dashboard**
2. **Add visualization**
3. Select Prometheus datasource
4. Enter query (examples):

```promql
# CPU usage by container
rate(container_cpu_usage_seconds_total[5m]) * 100

# Memory usage by container
container_memory_usage_bytes / 1024 / 1024

# Network received
rate(container_network_receive_bytes_total[5m])

# Disk usage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100
```

### Using Prometheus

#### 1. Query Metrics

Access http://localhost:9090 → **Graph**

Some useful queries:

```promql
# Check which service is down
up == 0

# Host CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100

# Container memory usage
sum(container_memory_usage_bytes) by (name)
```

#### 2. View Alerts

- Access http://localhost:9090/alerts
- View configured alert rules
- Status: Inactive, Pending, or Firing

### Managing Alerts

#### 1. View Alerts in Alertmanager

Access http://localhost:9093

#### 2. Customize Alert Rules

Edit file `monitoring_config/alert.rules.yml`:

```yaml
groups:
  - name: custom-alerts
    rules:
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% for 5 minutes."
```

After editing, reload Prometheus:

```bash
curl -X POST http://localhost:9090/-/reload
```

Or restart container:

```bash
docker-compose -f docker-compose.monitoring.yml restart prometheus
```

### Monitoring PostgreSQL

PostgreSQL container (`docker-compose.yml`) is configured with:
- Memory limit: 7GB
- Memory reservation: 4GB
- CPU limit: 4 cores
- Data persistence: `./postgres_data`

To view PostgreSQL metrics in cAdvisor:
1. Access http://localhost:8080
2. Find container **postgres**
3. View CPU, Memory, Network, and Disk I/O

### Stop and Remove System

```bash
# Stop all services
docker-compose -f docker-compose.monitoring.yml down
docker-compose -f docker-compose.yml down

# Stop and remove volumes (warning: data loss!)
docker-compose -f docker-compose.monitoring.yml down -v
docker-compose -f docker-compose.yml down -v
```

---

## Directory Structure

```
docker_monitoring/
├── docker-compose.yml              # PostgreSQL service
├── docker-compose.monitoring.yml   # Monitoring stack
├── monitoring_config/
│   ├── prometheus.yml             # Prometheus configuration
│   ├── alert.rules.yml            # Alert rules
│   ├── alertmanager.yml           # Alertmanager config (email)
│   ├── grafana-datasources.yml    # Grafana datasource config
│   └── grafana-dashboards.yml     # Grafana dashboard provisioning
├── postgres_data/                 # PostgreSQL data (auto-created)
└── README.md                      # This documentation
```

---

## Troubleshooting

### Prometheus not collecting metrics

```bash
# Check targets
# Access: http://localhost:9090/targets
# All targets must be in UP status
```

### cAdvisor not running on Windows

cAdvisor may have issues with Docker Desktop on Windows. Solutions:

1. Use Windows Subsystem for Linux (WSL2)
2. Or comment out cAdvisor section and use only Node Exporter

### Alerts not sending emails

1. Check SMTP configuration in `alertmanager.yml`
2. Check logs:

```bash
docker logs alertmanager
```

3. Test SMTP connection:

```bash
# From inside container
docker exec -it alertmanager sh
# Try sending test alert
```

### Grafana cannot connect to Prometheus

1. Check datasource configuration
2. Verify Prometheus is running:

```bash
curl http://localhost:9090/api/v1/status/config
```

### Port already in use

If you encounter port conflict error, edit ports in `docker-compose.monitoring.yml`:

```yaml
# Example: change Grafana port from 3001 to 3002
ports:
  - "3002:3000"
```

---

## Performance Tuning

### Reduce Storage Space

Edit retention in `prometheus.yml`:

```yaml
command:
  - '--storage.tsdb.retention.time=7d'  # Keep data for 7 days
  - '--storage.tsdb.retention.size=10GB' # Maximum 10GB
```

### Reduce Scrape Interval

In `monitoring_config/prometheus.yml`:

```yaml
global:
  scrape_interval: 30s      # Increase from 15s to 30s
  evaluation_interval: 30s   # Increase from 15s to 30s
```

---

## Security Best Practices

1. **Change Grafana default password**
2. **Don't expose ports to internet** (use localhost only or VPN)
3. **Protect email credentials** in alertmanager.yml
4. **Regular backups**:

```bash
# Backup Grafana dashboards
docker exec grafana grafana-cli admin export-dashboards /backup

# Backup Prometheus data
docker cp prometheus:/prometheus ./prometheus_backup
```

5. **Use environment variables** for sensitive data:

```yaml
environment:
  - SMTP_PASSWORD=${SMTP_PASSWORD}
```

---

## Extensions

### Add Other Exporters

- **PostgreSQL Exporter**: Monitor PostgreSQL databases
- **MySQL Exporter**: Monitor MySQL databases
- **Redis Exporter**: Monitor Redis
- **Nginx Exporter**: Monitor Nginx
- **Blackbox Exporter**: Monitor endpoints (HTTP, TCP, ICMP)

Example adding PostgreSQL Exporter:

```yaml
postgres-exporter:
  image: prometheuscommunity/postgres-exporter
  environment:
    DATA_SOURCE_NAME: "postgresql://admin:admin123@postgres:5432/testing?sslmode=disable"
  ports:
    - "9187:9187"
  networks:
    - monitoring
```

### Integration with Other Services

Add to `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']
```

---

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [cAdvisor GitHub](https://github.com/google/cadvisor)
- [Node Exporter GitHub](https://github.com/prometheus/node_exporter)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)

---

## Author

**Project**: Docker Monitoring System  
**Version**: 1.0  
**Date**: November 2025  
**Contact**: [Add your contact information]  
**License**: [Add license if needed]

---

## Changelog

### Version 1.0 (November 2025)
- ✅ Initial release
- ✅ Prometheus + Grafana setup
- ✅ cAdvisor + Node Exporter integration
- ✅ Alertmanager with email notifications
- ✅ PostgreSQL monitoring support
- ✅ Pre-configured alert rules
- ✅ Complete documentation

---

## Contributing

If you want to contribute to this project:

1. Fork repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Create Pull Request

---

## Support

If you encounter issues or have questions:

1. Check **Troubleshooting** section above
2. View logs: `docker-compose logs [service-name]`
3. Create issue on GitHub (if repository exists)
4. Contact via email: [Add your email]

---

**Happy Monitoring! 🚀📊**

---
---

# Hệ Thống Giám Sát Docker với Prometheus và Grafana

## Giới Thiệu

Đây là một hệ thống giám sát hoàn chỉnh cho Docker containers và host system sử dụng stack monitoring hiện đại. Hệ thống bao gồm:

### Các Thành Phần Chính

- **Prometheus** - Cơ sở dữ liệu chuỗi thời gian (time-series database) để thu thập và lưu trữ metrics
- **Grafana** - Nền tảng trực quan hóa dữ liệu và tạo dashboard
- **Alertmanager** - Quản lý và gửi cảnh báo qua email
- **cAdvisor** - Thu thập metrics của containers (CPU, memory, network, disk I/O)
- **Node Exporter** - Thu thập metrics của host system (CPU, memory, disk, network)

### Tính Năng

✅ Giám sát real-time các Docker containers  
✅ Giám sát tài nguyên hệ thống host (CPU, RAM, Disk, Network)  
✅ Dashboard trực quan với Grafana  
✅ Cảnh báo tự động qua email khi:
  - Instance/service down
  - CPU usage > 90% trong 5 phút
  - Disk space < 10% trong 10 phút
✅ Cấu hình linh hoạt và dễ mở rộng  
✅ Persistent data với Docker volumes

---

## Hướng Dẫn Cài Đặt

### Yêu Cầu Hệ Thống

- **Docker** phiên bản 20.10 trở lên
- **Docker Compose** phiên bản 2.0 trở lên
- **RAM tối thiểu**: 4GB (khuyến nghị 8GB)
- **Disk space**: 10GB trống
- **OS**: Windows, Linux, hoặc macOS

### Các Bước Cài Đặt

#### 1. Clone hoặc tải về project

```bash
cd d:\WorkSpace\projects\docker_monitoring
```

#### 2. Cấu hình Alertmanager (Tùy chọn)

Nếu muốn nhận cảnh báo qua email, chỉnh sửa file `monitoring_config/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: 'smtp.office365.com:587'
  smtp_from: 'your-email@yourcompany.com'
  smtp_auth_username: 'your-email@yourcompany.com'
  smtp_auth_password: 'YOUR_APP_PASSWORD'
  smtp_require_tls: true

receivers:
  - name: 'email-alerts'
    email_configs:
      - to: 'recipient1@yourcompany.com,recipient2@yourcompany.com'
```

**Lưu ý**: 
- Đối với Outlook/Microsoft 365, bạn cần tạo App Password thay vì dùng mật khẩu thường
- Truy cập: https://account.microsoft.com/security → App passwords

#### 3. Sửa lỗi typo trong docker-compose.yml

File `docker-compose.yml` có lỗi chính tả trong image postgres:

```yaml
# Sai: postgres:lastest
# Đúng: postgres:latest
```

Sửa thành:

```yaml
services:
  postgres:
    image: postgres:latest  
```

#### 4. Khởi động hệ thống monitoring

```bash
# Khởi động tất cả services
docker-compose -f docker-compose.monitoring.yml up -d

# Kiểm tra trạng thái
docker-compose -f docker-compose.monitoring.yml ps
```

#### 5. Khởi động service PostgreSQL (nếu cần)

```bash
docker-compose -f docker-compose.yml up -d
```

#### 6. Xác nhận các services đã chạy

```bash
docker ps
```

Bạn sẽ thấy các containers sau đang chạy:
- prometheus
- grafana
- alertmanager
- cadvisor
- node-exporter
- postgres (nếu đã khởi động)

---

## Hướng Dẫn Sử Dụng

### Truy Cập Các Web Interfaces

| Service | URL | Username | Password | Mô tả |
|---------|-----|----------|----------|-------|
| **Grafana** | http://localhost:3001 | admin | admin | Dashboard và visualization |
| **Prometheus** | http://localhost:9090 | - | - | Query metrics và alerts |
| **Alertmanager** | http://localhost:9093 | - | - | Quản lý alerts |
| **cAdvisor** | http://localhost:8080 | - | - | Container metrics |
| **Node Exporter** | http://localhost:9101/metrics | - | - | Host metrics (raw) |

### Sử Dụng Grafana

#### 1. Đăng nhập lần đầu

- Truy cập http://localhost:3001
- Username: `admin`
- Password: `admin`
- Hệ thống sẽ yêu cầu đổi password (có thể skip)

#### 2. Tạo Dashboard

**Tùy chọn 1: Import dashboard có sẵn từ Grafana.com**

1. Click **+** → **Import**
2. Nhập ID dashboard:
   - **893** - Docker Monitoring
   - **1860** - Node Exporter Full
   - **193** - Docker Dashboard
3. Chọn Prometheus datasource → **Import**

**Tùy chọn 2: Tạo dashboard mới**

1. Click **+** → **Create Dashboard**
2. **Add visualization**
3. Chọn Prometheus datasource
4. Nhập query (ví dụ):

```promql
# CPU usage by container
rate(container_cpu_usage_seconds_total[5m]) * 100

# Memory usage by container
container_memory_usage_bytes / 1024 / 1024

# Network received
rate(container_network_receive_bytes_total[5m])

# Disk usage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100
```

### Sử Dụng Prometheus

#### 1. Truy vấn Metrics

Truy cập http://localhost:9090 → **Graph**

Một số query hữu ích:

```promql
# Kiểm tra service nào đang down
up == 0

# CPU usage của host
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100

# Container memory usage
sum(container_memory_usage_bytes) by (name)
```

#### 2. Xem Alerts

- Truy cập http://localhost:9090/alerts
- Xem các alert rules đã được cấu hình
- Trạng thái: Inactive, Pending, hoặc Firing

### Quản Lý Alerts

#### 1. Xem Alerts trong Alertmanager

Truy cập http://localhost:9093

#### 2. Tùy chỉnh Alert Rules

Chỉnh sửa file `monitoring_config/alert.rules.yml`:

```yaml
groups:
  - name: custom-alerts
    rules:
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% for 5 minutes."
```

Sau khi chỉnh sửa, reload Prometheus:

```bash
curl -X POST http://localhost:9090/-/reload
```

Hoặc restart container:

```bash
docker-compose -f docker-compose.monitoring.yml restart prometheus
```

### Giám Sát PostgreSQL

Container PostgreSQL (`docker-compose.yml`) đã được cấu hình với:
- Memory limit: 7GB
- Memory reservation: 4GB
- CPU limit: 4 cores
- Data persistence: `./postgres_data`

Để xem metrics của PostgreSQL trong cAdvisor:
1. Truy cập http://localhost:8080
2. Tìm container **postgres**
3. Xem CPU, Memory, Network, và Disk I/O

### Dừng và Xóa Hệ Thống

```bash
# Dừng tất cả services
docker-compose -f docker-compose.monitoring.yml down
docker-compose -f docker-compose.yml down

# Dừng và xóa volumes (cảnh báo: mất dữ liệu!)
docker-compose -f docker-compose.monitoring.yml down -v
docker-compose -f docker-compose.yml down -v
```

---

## Cấu Trúc Thư Mục

```
docker_monitoring/
├── docker-compose.yml              # PostgreSQL service
├── docker-compose.monitoring.yml   # Monitoring stack
├── monitoring_config/
│   ├── prometheus.yml             # Prometheus configuration
│   ├── alert.rules.yml            # Alert rules
│   ├── alertmanager.yml           # Alertmanager config (email)
│   ├── grafana-datasources.yml    # Grafana datasource config
│   └── grafana-dashboards.yml     # Grafana dashboard provisioning
├── postgres_data/                 # PostgreSQL data (auto-created)
└── README.md                      # Documentation này
```

---

## Troubleshooting

### Prometheus không thu thập được metrics

```bash
# Kiểm tra targets
# Truy cập: http://localhost:9090/targets
# Tất cả targets phải ở trạng thái UP
```

### cAdvisor không chạy trên Windows

cAdvisor có thể gặp vấn đề với Docker Desktop trên Windows. Giải pháp:

1. Sử dụng Windows Subsystem for Linux (WSL2)
2. Hoặc comment phần cAdvisor và chỉ dùng Node Exporter

### Alerts không được gửi email

1. Kiểm tra cấu hình SMTP trong `alertmanager.yml`
2. Kiểm tra logs:

```bash
docker logs alertmanager
```

3. Test SMTP connection:

```bash
# Từ trong container
docker exec -it alertmanager sh
# Thử gửi test alert
```

### Grafana không kết nối được Prometheus

1. Kiểm tra datasource configuration
2. Xác nhận Prometheus đang chạy:

```bash
curl http://localhost:9090/api/v1/status/config
```

### Port đã được sử dụng

Nếu gặp lỗi port conflict, chỉnh sửa ports trong `docker-compose.monitoring.yml`:

```yaml
# Ví dụ: đổi port Grafana từ 3001 sang 3002
ports:
  - "3002:3000"
```

---

## Performance Tuning

### Giảm Storage Space

Chỉnh sửa retention trong `prometheus.yml`:

```yaml
command:
  - '--storage.tsdb.retention.time=7d'  # Giữ data 7 ngày
  - '--storage.tsdb.retention.size=10GB' # Tối đa 10GB
```

### Giảm Scrape Interval

Trong `monitoring_config/prometheus.yml`:

```yaml
global:
  scrape_interval: 30s      # Tăng từ 15s lên 30s
  evaluation_interval: 30s   # Tăng từ 15s lên 30s
```

---

## Security Best Practices

1. **Đổi mật khẩu mặc định của Grafana**
2. **Không expose các ports ra internet** (chỉ dùng localhost hoặc VPN)
3. **Bảo vệ email credentials** trong alertmanager.yml
4. **Backup định kỳ**:

```bash
# Backup Grafana dashboards
docker exec grafana grafana-cli admin export-dashboards /backup

# Backup Prometheus data
docker cp prometheus:/prometheus ./prometheus_backup
```

5. **Sử dụng environment variables** cho sensitive data:

```yaml
environment:
  - SMTP_PASSWORD=${SMTP_PASSWORD}
```

---

## Mở Rộng

### Thêm Exporters Khác

- **PostgreSQL Exporter**: Monitor PostgreSQL databases
- **MySQL Exporter**: Monitor MySQL databases
- **Redis Exporter**: Monitor Redis
- **Nginx Exporter**: Monitor Nginx
- **Blackbox Exporter**: Monitor endpoints (HTTP, TCP, ICMP)

Ví dụ thêm PostgreSQL Exporter:

```yaml
postgres-exporter:
  image: prometheuscommunity/postgres-exporter
  environment:
    DATA_SOURCE_NAME: "postgresql://admin:admin123@postgres:5432/testing?sslmode=disable"
  ports:
    - "9187:9187"
  networks:
    - monitoring
```

### Tích Hợp với Services Khác

Thêm vào `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']
```

---

## Tài Liệu Tham Khảo

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [cAdvisor GitHub](https://github.com/google/cadvisor)
- [Node Exporter GitHub](https://github.com/prometheus/node_exporter)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)

---

## Tác Giả

**Project**: Docker Monitoring System  
**Version**: 1.0  
**Date**: November 2025  
**Contact**: [Thêm thông tin liên hệ của bạn]  
**License**: [Thêm license nếu cần]

---

## Changelog

### Version 1.0 (November 2025)
- ✅ Initial release
- ✅ Prometheus + Grafana setup
- ✅ cAdvisor + Node Exporter integration
- ✅ Alertmanager with email notifications
- ✅ PostgreSQL monitoring support
- ✅ Pre-configured alert rules
- ✅ Complete documentation

---

## Contributing

Nếu bạn muốn đóng góp vào project:

1. Fork repository
2. Tạo feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Tạo Pull Request

---

## Support

Nếu gặp vấn đề hoặc có câu hỏi:

1. Kiểm tra phần **Troubleshooting** ở trên
2. Xem logs: `docker-compose logs [service-name]`
3. Tạo issue trên GitHub (nếu có repository)
4. Liên hệ qua email: [Thêm email của bạn]

---

**Happy Monitoring! 🚀📊**
