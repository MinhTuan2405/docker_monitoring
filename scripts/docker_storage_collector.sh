#!/bin/bash


# Configuration
OUTPUT_FILE="/var/lib/node_exporter/textfile_collector/docker_storage.prom"
TEMP_FILE="${OUTPUT_FILE}.$$"
DOCKER_BASE="/var/lib/docker/containers"

# Start building metrics file
cat << 'EOF' > "$TEMP_FILE"
# HELP docker_container_log_size Docker container log file size with human readable label
# TYPE docker_container_log_size gauge
EOF

# Collect Docker container log sizes using du -h on log files specifically
for container_dir in "$DOCKER_BASE"/*; do
    if [ -d "$container_dir" ]; then
        container_id=$(basename "$container_dir")
        short_id=$(echo "$container_id" | cut -c1-12)
        
        # Get container name
        container_name=$(docker ps -a --filter "id=$short_id" --format "{{.Names}}" 2>/dev/null)
        if [ -z "$container_name" ]; then
            container_name="$short_id"
        fi
        
        # Get log file size using du -h on the specific log file
        log_file="$container_dir/${container_id}-json.log"
        if [ -f "$log_file" ]; then
            log_size_human=$(du -h "$log_file" 2>/dev/null | cut -f1)
            if [ -n "$log_size_human" ]; then
                echo "docker_container_log_size{container_id=\"$short_id\",container_name=\"$container_name\",size=\"$log_size_human\"} 1" >> "$TEMP_FILE"
            fi
        fi
    fi
done



# Atomic move to prevent partial reads
mv "$TEMP_FILE" "$OUTPUT_FILE"

# Set appropriate permissions
chmod 644 "$OUTPUT_FILE"

echo "Docker storage metrics collected successfully at $(date)"