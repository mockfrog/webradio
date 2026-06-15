# Webradio Recorder & Podcast Server

This project automatically records webradio streams using a cron job inside a Docker container, generates a subscribable RSS podcast feed, and serves it along with the audio files using an integrated Nginx web server.

## Features
- **Automatic Recording**: Records streams using `ffmpeg` (copying the stream directly without re-encoding to minimize CPU load).
- **Integrated Scheduler**: An internal cron daemon starts the recordings fully automatically.
- **Automatic RSS Generation**: Updates the `podcast.xml` file immediately after each recording.
- **Podcast Web Server**: Nginx serves the RSS XML feed and MP3 episodes. Supports HTTP Byte-Ranges (essential for seeking/skipping in podcatchers) and CORS.
- **Fully Configurable**: All key parameters are managed via environment variables in the `docker-compose.yml` file.

---

## Project Structure

- `record_stream.sh`: The shell script that runs ffmpeg and executes the feed generator upon completion.
- `update_feed.py`: The Python script that scans the MP3 files, determines their duration using `ffprobe`, and builds the RSS XML feed.
- `nginx.conf`: Custom Nginx configuration for the web server.
- `entrypoint.sh`: Sets up environment variables, registers the cron job, starts Nginx, and runs the cron daemon in the foreground.
- `docker-compose.yml`: Defines the Docker container service, volumes, and environment variables.

---

## Setup & Startup

1. **Adjust Configuration**
   Open [docker-compose.yml](file:///home/mockfrog/dev/scripting/webradio/docker-compose.yml) and modify the environment variables to your needs:
   - `STREAM_URL`: The streaming URL of the radio station.
   - `RECORD_DURATION_MINS`: Recording duration in minutes.
   - `CRON_SCHEDULE`: When to trigger the recording (e.g., `0 18 * * 1-5` for Monday–Friday at 18:00).
   - `BASE_URL`: The external URL where your server is reachable (important for generating valid episode links in the feed).
   - `TZ`: The system timezone (e.g., `Europe/Berlin`) so that cron triggers at the correct local time.

2. **Build and Start the Container**
   Run the following command in the project directory:
   ```bash
   docker compose up --build -d
   ```

3. **Subscribe to the Podcast**
   Add the following URL to your preferred podcatcher (e.g., AntennaPod, Apple Podcasts):
   ```text
   http://<your-server-ip>:8080/podcast.xml
   ```

---

## Useful Commands

### View Logs
To view the output of the container (including the ffmpeg recording logs):
```bash
docker compose logs -f
```

### Trigger a Manual Recording
If you want to test the recording process outside of the scheduled time:
```bash
docker compose exec webradio-recorder /app/record_stream.sh "STREAM_URL" DURATION_MINS /app/podcasts
```
*The RSS feed will be updated immediately after a successful run.*

---

## Development & Local Testing

If you want to test the feed generation locally, make sure `ffprobe` is installed on your system. Then, set the environment variables and run the Python script:

```bash
export PODCAST_DIR="./podcasts"
export BASE_URL="http://localhost:8080"
mkdir -p ./podcasts
python3 update_feed.py
```
