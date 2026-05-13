#!/bin/bash

# Define the target and temporary download locations
TARGET="/usr/local/x-ui/bin/xray-linux-amd64"
TEMP_DOWNLOAD="/tmp/xray-linux-64.zip"

# Download the latest version
echo "Downloading the latest Xray version..."
wget -qO $TEMP_DOWNLOAD https://github.com/XTLS/Xray-core/releases/download/latest/Xray-linux-64.zip

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download the file. Exiting..."
    exit 1
fi

# Unzip the new version
echo "Unpacking the new version..."
unzip -o $TEMP_DOWNLOAD -d /tmp

# Replace the old executable with the new one
echo "Updating the executable..."
cp -f /tmp/xray-linux-64 $TARGET

# Ensure the new executable has the correct permissions
chmod +x $TARGET

# Restart the x-ui service
echo "Restarting the x-ui service..."
systemctl restart x-ui

# Cleanup
rm -f $TEMP_DOWNLOAD
echo "Update completed successfully!"

