#!/bin/bash

# Set the download page URL
url="https://papermc.io/downloads/paper"

# Use curl to fetch the HTML and grep to extract the download link for the latest paper.jar
download_link=$(curl -s $url | grep -oP '(?<=href=")[^"]*(?=">Download the latest Paper)')

# Combine the base URL with the extracted download path (if necessary)
full_url="https://papermc.io$download_link"

# Download the latest paper.jar to the specified directory
curl -L $full_url -o /root/paper.jar

echo "The latest version of paper.jar has been downloaded and stored in /root/"
