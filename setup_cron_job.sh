#!/bin/bash
#
# Setup script for User Storage Monitoring
# Run this script with root privileges
#

echo "=== Setting up User Storage Monitoring ==="

# 1. Create textfile collector directory
echo "Creating textfile collector directory..."
mkdir -p /var/lib/node_exporter/textfile_collector
chmod 755 /var/lib/node_exporter/textfile_collector

# 2. Set permissions for collector script
echo "Setting up collector script..."
SCRIPT_PATH="/home/ven_tom_tran/user_storage_collector.sh"
chmod 755 "$SCRIPT_PATH"

# 3. Test the script
echo "Testing collector script..."
"$SCRIPT_PATH"

# 4. Verify output file
if [ -f /var/lib/node_exporter/textfile_collector/user_storage.prom ]; then
    echo "✓ Metrics file created successfully"
    echo "First 20 lines of metrics:"
    head -20 /var/lib/node_exporter/textfile_collector/user_storage.prom
else
    echo "✗ Failed to create metrics file"
    exit 1
fi

# 5. Setup cron job
echo "Setting up cron job to run every 4 hours..."
SCRIPT_PATH="/home/ven_tom_tran/user_storage_collector.sh"
CRON_JOB="0 */4 * * * $SCRIPT_PATH >> /var/log/user_storage_collector.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "user_storage_collector.sh"; then
    echo "Cron job already exists"
else
    # Add cron job
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "✓ Cron job added"
fi

# 6. Check Node Exporter configuration
echo ""
echo "=== Node Exporter Configuration Check ==="
if systemctl is-active --quiet node_exporter; then
    echo "Node Exporter is running"
    
    # Check if textfile collector is enabled
    NODE_EXPORTER_ARGS=$(systemctl show node_exporter -p ExecStart --value | grep -o '\-\-collector\.textfile\.directory=[^ ]*')
    
    if [ -n "$NODE_EXPORTER_ARGS" ]; then
        echo "Textfile collector is configured: $NODE_EXPORTER_ARGS"
    else
        echo "⚠ WARNING: Node Exporter may not have textfile collector enabled"
        echo "You need to add --collector.textfile.directory=/var/lib/node_exporter/textfile_collector"
        echo ""
        echo "To configure Node Exporter:"
        echo "1. Edit: /etc/systemd/system/node_exporter.service"
        echo "2. Add to ExecStart: --collector.textfile.directory=/var/lib/node_exporter/textfile_collector"
        echo "3. Run: systemctl daemon-reload && systemctl restart node_exporter"
    fi
else
    echo "⚠ Node Exporter is not running or not installed"
fi

echo ""
echo "=== Setup Complete ==="
echo "Metrics will be available at: http://localhost:9100/metrics"
echo "Search for metrics starting with: user_home_storage_ or user_subdirectory_storage_"
