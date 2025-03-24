#!/bin/bash

# Update and install basic packages
apt update && apt install -y git docker.io docker-compose

# Clone your repository (replace with your repo)
mkdir -p /opt/status-page
cd /opt/status-page
git clone https://github.com/meitavEini/Status_page_FORKED_REPO.git .
git checkout main

# Run the app
docker compose -f docker-compose.yml up -d --build
