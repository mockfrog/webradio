FROM python:3.11-slim

# Install system dependencies: ffmpeg (for recording), nginx (web server), cron (scheduler), and tzdata (timezone)
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg nginx cron tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Copy configuration and scripts
COPY nginx.conf /etc/nginx/nginx.conf
COPY record_stream.sh /app/record_stream.sh
COPY update_feed.py /app/update_feed.py
COPY entrypoint.sh /app/entrypoint.sh

# Make scripts executable
RUN chmod +x /app/record_stream.sh /app/update_feed.py /app/entrypoint.sh

# Create folder for podcasts (this will also be mounted as a volume)
RUN mkdir -p /app/podcasts

# Expose Nginx port
EXPOSE 80

# Environment variable to ensure Python outputs logs immediately
ENV PYTHONUNBUFFERED=1

# Run entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]
