#!/usr/bin/env python3
import sys
import json
import urllib.request
import urllib.parse
import datetime

def format_duration(seconds):
    """Formats seconds into MM:SS or H:MM:SS."""
    try:
        seconds = int(seconds)
    except (ValueError, TypeError):
        return "Unknown"
    
    if seconds < 3600:
        # MM:SS
        m, s = divmod(seconds, 60)
        return f"{m}:{s:02d}"
    else:
        # H:MM:SS
        h, remainder = divmod(seconds, 3600)
        m, s = divmod(remainder, 60)
        return f"{h}:{m:02d}:{s:02d}"

def search_youtube(query):
    """Searches YouTube via Invidious API and prints formatted results."""
    base_url = "https://yt.tarka.dev/api/v1/search"
    params = {
        "q": query,
        "type": "video"
    }
    url = f"{base_url}?{urllib.parse.urlencode(params)}"
    
    try:
        with urllib.request.urlopen(url) as response:
            data = json.loads(response.read().decode())
            
        if not data:
            print("No results found.")
            return

        # Limit to top 5 results
        results = data[:5]
        
        for video in results:
            title = video.get("title", "Untitled")
            video_id = video.get("videoId", "")
            author = video.get("author", "Unknown Author")
            view_count = video.get("viewCountText", "N/A views")
            published = video.get("publishedText", "Unknown date")
            length_seconds = video.get("lengthSeconds", 0)
            
            duration = format_duration(length_seconds)
            link = f"https://yt.tarka.dev/watch?v={video_id}"
            
            # Markdown format
            print(f"- [**{title}**]({link}) by {author} - {view_count} - {published} - Duration: {duration}")
            
    except Exception as e:
        print(f"Error searching YouTube: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 search.py <query>")
        sys.exit(1)
    
    query = " ".join(sys.argv[1:])
    search_youtube(query)
