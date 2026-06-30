#!/bin/bash

# Überprüfung der Parameter
if [ "$#" -lt 3 ]; then
    echo "Benutzung: $0 <URL> <DAUER_IN_MINUTEN> <ZIELORDNER>"
    exit 1
fi

STREAM_URL="$1"
DURATION_MIN="$2"
TARGET_DIR="$3"

# Minuten in Sekunden umrechnen für ffmpeg
DURATION_SEC=$((DURATION_MIN * 60))

# Zielverzeichnis erstellen, falls es nicht existiert
mkdir -p "$TARGET_DIR"

# Zeitstempel für den Dateinamen generieren (Format: JJJJMMTT_HHMMSS)
TIMESTAMP=$(date +"%Y%m%d")
# Wir hängen .mp3 an, ffmpeg erkennt das Format meist automatisch am Stream, 
# aber .mp3 ist ein sicherer Standard für Audio-Streams.
OUTPUT_FILE="$TARGET_DIR/fsr_${TIMESTAMP}.mp3"

# ffmpeg Befehl:
# -i: Input Stream
# -t: Dauer in Sekunden
# -c copy: Daten direkt kopieren (vermeidet Neucodierung/CPU-Last)
# -metadata artist: Setzt den Interpreten auf "FSR"
# -metadata title: Setzt den Titel auf "FSR - YYYYMMDD"
# -y: Vorhandene Dateien überschreiben
# -loglevel warning: Nur wichtige Meldungen ausgeben
ffmpeg -i "$STREAM_URL" -t "$DURATION_SEC" -c copy -metadata artist="FSR" -metadata title="FSR-$TIMESTAMP" "$OUTPUT_FILE" -y -loglevel warning

# Exit-Code von ffmpeg sichern
FFMPEG_STATUS=$?

if [ $FFMPEG_STATUS -ne 0 ]; then
    echo "Warnung: ffmpeg wurde mit Fehler beendet (Status: $FFMPEG_STATUS)."
fi

# Podcast-Feed aktualisieren, wenn die Datei existiert und nicht leer ist
if [ -s "$OUTPUT_FILE" ]; then
    echo "Aufnahmedatei vorhanden. Aktualisiere Podcast-Feed..."
    # Setze PODCAST_DIR auf das tatsächliche Zielverzeichnis für update_feed.py
    export PODCAST_DIR="$TARGET_DIR"

    # Prüfe ob update_feed.py im App-Ordner oder aktuellen Ordner liegt
    if [ -f "/app/update_feed.py" ]; then
        python3 /app/update_feed.py
    elif [ -f "$(dirname "$0")/update_feed.py" ]; then
        python3 "$(dirname "$0")/update_feed.py"
    else
        echo "update_feed.py nicht gefunden. Feed wurde nicht aktualisiert."
    fi
else
    echo "Fehler: Aufnahmedatei wurde nicht erstellt oder ist leer. Feed wird nicht aktualisiert."
    exit 1
fi

