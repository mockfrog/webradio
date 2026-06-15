#!/usr/bin/env python3
import os
import re
import sys
import subprocess
from datetime import datetime, timezone
import email.utils
import xml.etree.ElementTree as ET
from xml.dom import minidom

def get_duration(file_path):
    """Get duration of audio file in seconds using ffprobe."""
    try:
        cmd = [
            'ffprobe', 
            '-v', 'error', 
            '-show_entries', 'format=duration', 
            '-of', 'default=noprint_wrappers=1:nokey=1', 
            file_path
        ]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        duration_sec = float(result.stdout.strip())
        return int(duration_sec)
    except Exception as e:
        print(f"Warning: Could not get duration for {file_path}: {e}", file=sys.stderr)
        return None

def format_duration(seconds):
    """Format seconds into HH:MM:SS or MM:SS."""
    if seconds is None:
        return ""
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60
    if hours > 0:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"

def parse_date_from_filename(filename):
    """
    Attempt to extract YYYYMMDD from filename.
    Returns a datetime object (UTC) or None.
    """
    match = re.search(r'(\d{8})', filename)
    if match:
        date_str = match.group(1)
        try:
            # Assume recording happened at 18:00:00 local/UTC time to have a reasonable pubDate
            dt = datetime.strptime(date_str, "%Y%m%d")
            return dt.replace(hour=18, minute=0, second=0, tzinfo=timezone.utc)
        except ValueError:
            pass
    return None

def generate_feed():
    # Load environment variables with defaults
    base_url = os.environ.get('BASE_URL', 'http://localhost:8080').rstrip('/')
    podcast_dir = os.environ.get('PODCAST_DIR', '/app/podcasts')
    title = os.environ.get('PODCAST_TITLE', 'Webradio Podcast')
    description = os.environ.get('PODCAST_DESCRIPTION', 'Recorded webradio streams')
    language = os.environ.get('PODCAST_LANG', 'de')

    if not os.path.exists(podcast_dir):
        print(f"Error: Podcast directory '{podcast_dir}' does not exist.", file=sys.stderr)
        sys.exit(1)

    # Find all mp3 files
    mp3_files = [f for f in os.listdir(podcast_dir) if f.endswith('.mp3')]
    
    items = []
    for filename in mp3_files:
        file_path = os.path.join(podcast_dir, filename)
        
        # File size
        try:
            file_size = os.path.getsize(file_path)
        except OSError:
            continue
            
        # File date (try parsing filename first, fallback to mtime)
        dt = parse_date_from_filename(filename)
        if not dt:
            mtime = os.path.getmtime(file_path)
            dt = datetime.fromtimestamp(mtime, tz=timezone.utc)
            
        # Duration
        duration_sec = get_duration(file_path)
        
        items.append({
            'filename': filename,
            'file_size': file_size,
            'date': dt,
            'duration': duration_sec
        })

    # Sort items by date descending (newest first)
    items.sort(key=lambda x: x['date'], reverse=True)

    # Build RSS XML
    rss = ET.Element('rss', {
        'version': '2.0',
        'xmlns:itunes': 'http://www.itunes.com/dtds/podcast-1.0.dtd',
        'xmlns:content': 'http://purl.org/rss/1.0/modules/content/'
    })
    
    channel = ET.SubElement(rss, 'channel')
    
    ET.SubElement(channel, 'title').text = title
    ET.SubElement(channel, 'description').text = description
    ET.SubElement(channel, 'link').text = base_url
    ET.SubElement(channel, 'language').text = language
    ET.SubElement(channel, 'generator').text = 'Python Podcast Feed Generator'
    
    now_rfc = email.utils.format_datetime(datetime.now(timezone.utc))
    ET.SubElement(channel, 'lastBuildDate').text = now_rfc

    for item_data in items:
        fn = item_data['filename']
        # Extract title from filename. e.g. fsr_20260615 -> FSR - 15.06.2026
        dt_str = item_data['date'].strftime('%d.%m.%Y')
        # Simple clean title formatting
        clean_title = fn.replace('.mp3', '').replace('_', ' ').upper()
        if re.search(r'\d{8}', fn):
            # If it has a date, format it nicely
            prefix = fn.split('_')[0].upper() if '_' in fn else 'FSR'
            item_title = f"{prefix} - {dt_str}"
        else:
            item_title = clean_title

        item = ET.SubElement(channel, 'item')
        ET.SubElement(item, 'title').text = item_title
        ET.SubElement(item, 'description').text = f"Recorded episode: {fn}"
        
        pub_date_rfc = email.utils.format_datetime(item_data['date'])
        ET.SubElement(item, 'pubDate').text = pub_date_rfc
        
        file_url = f"{base_url}/{fn}"
        ET.SubElement(item, 'enclosure', {
            'url': file_url,
            'length': str(item_data['file_size']),
            'type': 'audio/mpeg'
        })
        
        # GUID
        guid = ET.SubElement(item, 'guid', {'isPermaLink': 'false'})
        guid.text = fn
        
        # Duration
        dur_str = format_duration(item_data['duration'])
        if dur_str:
            ET.SubElement(item, 'itunes:duration').text = dur_str

    # Format XML nicely
    xml_str = ET.tostring(rss, encoding='utf-8')
    parsed_xml = minidom.parseString(xml_str)
    pretty_xml = parsed_xml.toprettyxml(indent="  ", encoding="utf-8")
    
    feed_path = os.path.join(podcast_dir, 'podcast.xml')
    with open(feed_path, 'wb') as f:
        f.write(pretty_xml)
        
    print(f"Successfully updated feed with {len(items)} items at {feed_path}")

if __name__ == "__main__":
    generate_feed()
