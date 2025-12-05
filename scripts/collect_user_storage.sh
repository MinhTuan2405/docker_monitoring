#!/bin/bash

# Script thu thập disk usage cho các user workspace
# Output metrics format cho Prometheus Node Exporter textfile collector

TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
OUTPUT_FILE="${TEXTFILE_DIR}/user_storage.prom"
TEMP_FILE="${OUTPUT_FILE}.$$"

# Tạo thư mục nếu chưa có
mkdir -p "$TEXTFILE_DIR"

# Bắt đầu file metrics
cat > "$TEMP_FILE" <<EOF
# HELP user_workspace_bytes Disk usage in bytes for each user workspace
# TYPE user_workspace_bytes gauge
EOF

# Thu thập dung lượng của /home/user1, /home/user2, etc.
for user_dir in /home/*; do
    if [ -d "$user_dir" ]; then
        username=$(basename "$user_dir")
        # Lấy dung lượng bằng bytes
        size_bytes=$(du -sb "$user_dir" 2>/dev/null | awk '{print $1}')
        
        if [ -n "$size_bytes" ]; then
            echo "user_workspace_bytes{user=\"$username\",path=\"$user_dir\"} $size_bytes" >> "$TEMP_FILE"
        fi
    fi
done

# Move temp file to final location atomically
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "User storage metrics collected at $(date)"
