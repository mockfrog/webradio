#!/bin/bash

# Default values if not provided
export STREAM_URL="${STREAM_URL:-http://example.com/stream.mp3}"
export RECORD_DURATION_MINS="${RECORD_DURATION_MINS:-60}"
export PODCAST_DIR="${PODCAST_DIR:-/app/podcasts}"
export BASE_URL="${BASE_URL:-http://localhost:8080}"
export PODCAST_TITLE="${PODCAST_TITLE:-Webradio Podcast}"
export PODCAST_DESCRIPTION="${PODCAST_DESCRIPTION:-Aufgenommene Webradio-Sendungen}"
export PODCAST_LANG="${PODCAST_LANG:-de}"

# Ensure directories exist
mkdir -p "$PODCAST_DIR"

# Save environment variables to env.sh for the cron environment
declare -p STREAM_URL RECORD_DURATION_MINS PODCAST_DIR BASE_URL PODCAST_TITLE PODCAST_DESCRIPTION PODCAST_LANG > /app/env.sh
chmod +x /app/env.sh

# Run the feed generator once on startup to ensure the XML file exists
echo "Initialer Feed-Aufbau..."
python3 /app/update_feed.py

# Create crontab file
SCHEDULE="${CRON_SCHEDULE:-0 18 * * 1-5}"
echo "Cron-Zeitplan eingerichtet: $SCHEDULE"

# Write the cron job. It loads env.sh and runs record_stream.sh.
echo "$SCHEDULE . /app/env.sh && /app/record_stream.sh \"\$STREAM_URL\" \"\$RECORD_DURATION_MINS\" \"\$PODCAST_DIR\" >> /var/log/cron.log 2>&1" > /app/crontab.txt

# Install the crontab
crontab /app/crontab.txt

# Start Nginx in the background
echo "Starte Nginx..."
nginx

# Setup log file and pipe to stdout
touch /var/log/cron.log
tail -f /var/log/cron.log &

# Start Cron daemon in the foreground
echo "Starte Cron Daemon..."
exec cron -f
