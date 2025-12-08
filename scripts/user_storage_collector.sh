#!/bin/bash

# Configuration
OUTPUT_FILE="/var/lib/node_exporter/textfile_collector/user_storage.prom"
TEMP_FILE="${OUTPUT_FILE}.$$"
HOME_BASE="/home"

# Start building metrics file
cat << 'EOF' > "$TEMP_FILE"
# HELP user_home_storage_bytes Total storage used by user home directory in bytes
# TYPE user_home_storage_bytes gauge
# HELP user_home_storage_gigabytes Total storage used by user home directory in gigabytes
# TYPE user_home_storage_gigabytes gauge
# HELP user_subdirectory_storage_bytes Storage used by first-level subdirectories in user home
# TYPE user_subdirectory_storage_bytes gauge
# HELP user_subdirectory_storage_gigabytes Storage used by first-level subdirectories in gigabytes
# TYPE user_subdirectory_storage_gigabytes gauge
# HELP user_storage_collection_timestamp Unix timestamp of when this collection was performed
# TYPE user_storage_collection_timestamp gauge
# HELP user_storage_collection_duration_seconds Time taken to collect storage metrics
# TYPE user_storage_collection_duration_seconds gauge
EOF

# Record start time
START_TIME=$(date +%s)

# Collect metrics for each user in /home
if [ -d "$HOME_BASE" ]; then
    for user_home in "$HOME_BASE"/*; do
        if [ -d "$user_home" ]; then
            username=$(basename "$user_home")
            
            # Skip lost+found and other system directories
            if [[ "$username" == "lost+found" ]]; then
                continue
            fi
            
            echo "# Processing user: $username" >> "$TEMP_FILE"
            
            # Use du once with --max-depth=1 to get all sizes (much faster!)
            # Output is in KB by default, convert to bytes
            du --max-depth=1 "$user_home" 2>/dev/null | while read -r size_kb path; do
                size_bytes=$((size_kb * 1024))
                
                if [ "$path" = "$user_home" ]; then
                    # This is the total for user home
                    if [ -n "$size_bytes" ] && [ "$size_bytes" -gt 0 ]; then
                        total_gb=$(echo "scale=2; $size_bytes / 1073741824" | bc)
                        echo "user_home_storage_bytes{username=\"$username\",path=\"$user_home\"} $size_bytes" >> "$TEMP_FILE"
                        echo "user_home_storage_gigabytes{username=\"$username\",path=\"$user_home\"} $total_gb" >> "$TEMP_FILE"
                    fi
                else
                    # This is a subdirectory
                    if [ -d "$path" ]; then
                        dirname=$(basename "$path")
                        
                        if [ -n "$size_bytes" ] && [ "$size_bytes" -gt 0 ]; then
                            size_gb=$(echo "scale=2; $size_bytes / 1073741824" | bc)
                            
                            # Escape special characters in directory names for Prometheus labels
                            safe_dirname=$(echo "$dirname" | sed 's/["\\]/\\&/g')
                            
                            echo "user_subdirectory_storage_bytes{username=\"$username\",directory=\"$safe_dirname\",path=\"$path\"} $size_bytes" >> "$TEMP_FILE"
                            echo "user_subdirectory_storage_gigabytes{username=\"$username\",directory=\"$safe_dirname\",path=\"$path\"} $size_gb" >> "$TEMP_FILE"
                        fi
                    fi
                fi
            done
        fi
    done
fi

# Record end time and duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "user_storage_collection_timestamp $(date +%s)" >> "$TEMP_FILE"
echo "user_storage_collection_duration_seconds $DURATION" >> "$TEMP_FILE"

# Atomic move to prevent partial reads
mv "$TEMP_FILE" "$OUTPUT_FILE"

# Set appropriate permissions
chmod 644 "$OUTPUT_FILE"

echo "User storage metrics collected successfully at $(date)"
