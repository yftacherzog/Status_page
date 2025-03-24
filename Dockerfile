# 1️⃣ Use Ubuntu as base image
FROM ubuntu:22.04

# 2️⃣ Set working directory inside the container
WORKDIR /app

# 3️⃣ Install system dependencies
RUN apt update && apt install -y \
    python3-pip python3-venv python3-dev build-essential \
    libpq-dev libssl-dev libffi-dev python3-setuptools && \
    rm -rf /var/lib/apt/lists/*

# 4️⃣ Copy application files
COPY . /app

# 5️⃣ Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# 6️⃣ Copy entrypoint script and give execution permission
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 7️⃣ Expose port 8000 for the app
EXPOSE 8000

# 8️⃣ Use entrypoint script to handle setup and run Gunicorn
ENTRYPOINT ["/entrypoint.sh"]
