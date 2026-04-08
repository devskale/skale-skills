# Media Uploads & Downloads

## Upload (posting)

peep can **upload** media when posting tweets:

```bash
peep tweet "Hello" --media /path/to/image.jpg
peep tweet "Hello" --media img1.jpg --media img2.jpg --media img3.jpg --media img4.jpg
peep tweet "Hello" --media photo.jpg --alt "Description of image"
peep tweet "Check this out" --media video.mp4
peep reply 1234567890 "Here's more" --media photo.jpg
```

### Supported Formats

| Type | Formats |
|------|---------|
| Images | jpg, jpeg, png, webp, gif |
| Video | mp4, mov |

### Limits
- Up to 4 images/GIFs
- OR 1 video (no mixing)

## Download Images from a Tweet

peep doesn't have a built-in download command, but you can extract and download images:

### One-liner
```bash
# Download all images from a tweet to current directory
peep read <tweet-id> --json | jq -r '.media[] | select(.type == "photo") | .url' | xargs -I {} curl -L -O {}
```

### With Custom Filename
```bash
# Download as tweetID_1.jpg, tweetID_2.jpg, etc.
ID="1234567890"
peep read $ID --json | jq -r --arg id "$ID" '(.media // []) | to_entries[] | "\($id)_\(.key+1)." + (.value.url / "." | last)' | paste - <(peep read $ID --json | jq -r '.media[] | .url') | while read name url; do curl -L -o "$name" "$url"; done
```

### Simple Script (add to ~/.bashrc or ~/.zshrc)

```bash
peep-media() {
  local tweet="$1"
  local dir="${2:-.}"
  mkdir -p "$dir"
  peep read "$tweet" --json | jq -r '.media[] | select(.type == "photo") | .url' | while read -r url; do
    curl -L -o "$dir/$(basename "$url")" "$url"
    echo "Saved: $dir/$(basename "$url")"
  done
}
```

Usage:
```bash
peep-media 1234567890          # Download to current dir
peep-media 1234567890 images   # Download to ./images/
```

### Download All Media from User

```bash
peep user-tweets <username> -n 100 --json | jq -r '.[] | select(.media) | .media[] | .url' | xargs -I {} curl -L -O {}
```
