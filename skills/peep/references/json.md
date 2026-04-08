# JSON Output

## Commands with JSON Support

Add `--json` to: read, replies, thread, search, mentions, bookmarks, likes, following, followers, about, lists, list-timeline, user-tweets, query-ids

Add `--json-full` for raw API response in `_raw` field.

## Tweet Object Schema

```json
{
  "id": "1234567890123456789",
  "text": "Tweet text content",
  "author": {
    "username": "username",
    "name": "Display Name"
  },
  "authorId": "12345678",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "replyCount": 10,
  "retweetCount": 5,
  "likeCount": 100,
  "conversationId": "1234567890123456789",
  "inReplyToStatusId": "9876543210987654321",
  "quotedTweet": { ... },
  "media": [
    { "type": "photo", "url": "https://..." }
  ],
  "article": {
    "title": "Article Title",
    "previewText": "Preview..."
  }
}
```

## User Object Schema

```json
{
  "id": "12345678",
  "username": "username",
  "name": "Display Name",
  "description": "Bio text",
  "followersCount,
  "following": 1000Count": 500,
  "isBlueVerified": true,
  "profileImageUrl": "https://...",
  "createdAt": "2020-01-01T00:00:00.000Z"
}
```

## Pagination

When using `--all`, `--cursor`, `--max-pages`, or `-n > 20` (for user-tweets):

```json
{
  "tweets": [...],
  "nextCursor": "DAABCgFDA..."
}
```

`nextCursor` is `null` when no more pages.

## Quote Depth

Control quoted tweet recursion with `--quote-depth`:
- `--quote-depth 0` - No quotes
- `--quote-depth 1` - One level (default)
- `--quote-depth 2` - Two levels
