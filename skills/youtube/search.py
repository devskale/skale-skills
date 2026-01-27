#!/usr/bin/env python3
import sys
import json
import urllib.request
import urllib.parse
import datetime
import argparse

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

def search_youtube(query, num=5, sort_by='relevance'):
    """Searches YouTube via Invidious API and prints formatted results."""
    base_url = "https://yt.tarka.dev/api/v1/search"
    
    # Map friendly sort names to API parameter values
    # API supports: relevance, rating, upload_date, view_count
    sort_map = {
        'relevance': 'relevance',
        'date': 'upload_date',
        'views': 'view_count',
        'rating': 'rating',
        'ranking': 'rating'
    }
    
    api_sort = sort_map.get(sort_by, 'relevance')
    
    params = {
        "q": query,
        "type": "video",
        "sort_by": api_sort
    }
    url = f"{base_url}?{urllib.parse.urlencode(params)}"
    
    try:
        with urllib.request.urlopen(url) as response:
            data = json.loads(response.read().decode())
            
        if not data:
            print("No results found.")
            return

        # Limit results
        results = data[:num]
        
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
    parser = argparse.ArgumentParser(description='Search YouTube videos via Invidious API')
    parser.add_argument('query', help='Search query')
    parser.add_argument('--num', type=int, default=3, help='Number of results to return (default: 3)')
    parser.add_argument('--rank', choices=['relevance', 'date', 'views', 'rating', 'ranking'], default='relevance',
                        help='Sort order: relevance, date, views, rating, ranking (default: relevance)')
    
    args = parser.parse_args()
    
    search_youtube(args.query, num=args.num, sort_by=args.rank)
