#!/bin/bash

# Script thu thập disk usage cho subfolders trong user workspace
# Ví dụ: /home/user1/A, /home/user1/B

TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
OUTPUT_FILE="${TEXTFILE_DIR}/user_subfolders.prom"
TEMP_FILE="${OUTPUT_FILE}.$$"

# Tạo thư mục nếu chưa có
mkdir -p "$TEXTFILE_DIR"

# Bắt đầu file metrics
cat > "$TEMP_FILE" <<EOF
# HELP user_subfolder_bytes Disk usage in bytes for each user subfolder
# TYPE user_subfolder_bytes gauge
EOF

# Thu thập dung lượng của subfolders
for user_dir in /home/*; do
    if [ -d "$user_dir" ]; then
        username=$(basename "$user_dir")
        
        # Lặp qua tất cả subfolders level 1
        for subfolder in "$user_dir"/*; do
            if [ -d "$subfolder" ]; then
                folder_name=$(basename "$subfolder")
                # Lấy dung lượng bằng bytes
                size_bytes=$(du -sb "$subfolder" 2>/dev/null | awk '{print $1}')
                
                if [ -n "$size_bytes" ]; then
                    echo "user_subfolder_bytes{user=\"$username\",folder=\"$folder_name\",path=\"$subfolder\"} $size_bytes" >> "$TEMP_FILE"
                fi
            fi
        done
    fi
done

# Move temp file to final location atomically
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "User subfolder metrics collected at $(date)"
