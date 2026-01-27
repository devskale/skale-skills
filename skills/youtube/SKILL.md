---
name: youtube
description: Search YouTube videos via Invidious API. Use when the user wants to find, search for, or look up videos, or asks for video recommendations on a topic.
---

# YouTube Video Search

Search YouTube videos using the Invidious API at `https://yt.tarka.dev`.

## How to Search

Run the included python script to search and get formatted results:

```bash
python3 search.py "<query>"
```

The script will output a markdown list of videos.

## Example

When user asks "find me a video about Clojure macros":

```bash
python3 search.py "Clojure macros"
```

Output:

- [**Clojure Tutorial**](https://yt.tarka.dev/watch?v=ciGyHkDuPAE) by Derek Banas - 175K views - 8 years ago - Duration: 1:11:23

## Notes

- If the script fails, check your internet connection.
- If no results are found, the script will output "No results found."
