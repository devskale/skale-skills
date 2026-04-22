# User Profiling

Build a `profile.md` that describes a peep user's interests, political stances, and core values based on their X activity.

## Data Collection

Use **small batches** (max 20 at a time) to avoid timeouts and rate limits. Collect from multiple signals:

```bash
# Identity
peep whoami

# Their own voice (most revealing)
peep user-tweets @HANDLE -n 20
peep user-tweets @HANDLE -n 20 --cursor <cursor>

# What they amplify (likes = strongest preference signal)
peep likes -n 20
peep likes -n 20 --cursor <cursor>

# What they save for later
peep bookmarks -n 20

# Who they follow (curated graph)
peep following -n 40

# What they search for
# (not available via peep — use their bookmarks/likes as proxy)

# Conversations they engage in
peep mentions -n 20
peep replies <tweet-id> -n 20
```

### Batch Strategy

Collect 3-5 batches of 20 across different signals. Don't fetch everything at once. Start with likes and own tweets — those are the strongest signals.

```bash
# Session 1: Own voice + likes
peep user-tweets @HANDLE -n 20
peep likes -n 20

# Session 2: More likes + bookmarks
peep likes -n 20 --cursor <cursor>
peep bookmarks -n 20

# Session 3: Following graph + more own tweets
peep following -n 40
peep user-tweets @HANDLE -n 20 --cursor <cursor>
```

**Use `--json` output** and pipe through a script for analysis. The plain text output is for human reading, not programmatic analysis.

## Analysis Framework

### 1. Interests (what topics they engage with)

Look at:
- **Liked tweet topics** — categorize each batch (tech, politics, science, sports, etc.)
- **Own tweet topics** — what do they talk about
- **Bookmarked content** — what they want to remember
- **Following graph** — which domains (journalists, politicians, tech people, meme accounts)

### 2. Political Stances (how they position themselves)

Look at:
- **Liked political content** — which side of debates they amplify
- **Own political tweets/replies** — direct statements of position
- **Who they follow** — politicians, commentators, think tanks
- **What they DON'T like** — follow-reply chains to see what they argue against
- **Nuance signals** — do they criticize their own side? Do they engage across the aisle?

Key questions:
- Are they consistent or contrarian within their cluster?
- Do they focus on specific policies or broad ideology?
- Are they anti-establishment, partisan, or independent?
- Do they engage with geopolitical events (Israel/Gaza, Ukraine, NATO, China)?

### 3. Core Values (what principles drive them)

Infer from patterns across all signals:
- **Free speech / anti-censorship** — likes of speech-related content, following of anti-censorship accounts
- **Privacy / anti-surveillance** — follows/likes of privacy advocates, self-hosting enthusiasts
- **Open source / anti-corporate** — preference for OSS alternatives, criticism of big tech
- **Nationalism vs globalism** — stance on NATO, EU, sovereignty, immigration
- **Individual liberty** — anti-regulation, anti-lockdown, pro-crypto signals
- **Truth-seeking / anti-establishment** — conspiracy-adjacent content, skepticism of official narratives
- **Humor / irreverence** — meme likes, shitposting, absurdity appreciation

### 4. Identity Markers

- **Language** — primary language(s), do they code-switch?
- **Location signals** — local politics, regional topics, timezone activity
- **Professional identity** — tech, media, academic, blue-collar signals
- **Community membership** — specific subcultures (AI/ML, crypto, gaming, prepping, etc.)
- **Religion / philosophy** — implicit or explicit signals

## Writing the Profile

### Template

```markdown
# @handle — Profile

**Generated:** <date>
**Data sources:** likes (N tweets), own tweets (N), bookmarks (N), following (N accounts), mentions (N)

## Identity
- **Handle:** @handle
- **Display name:** Name
- **Bio:** (from whoami or user-tweets)
- **Languages:** English, German, ...
- **Location:** inferred from content / bio
- **Professional:** developer, journalist, ...

## Interests

### Primary Interests
- Topic A — description of engagement pattern
- Topic B — ...
- Topic C — ...

### Secondary Interests
- Topic X — occasional engagement
- Topic Y — ...

## Political Profile

### Overall Stance
One paragraph summarizing political orientation.

### Key Positions
| Issue | Stance | Evidence |
|-------|--------|----------|
| Foreign policy | anti-interventionist | liked X, replied Y |
| Domestic policy | ... | ... |

### Nuance & Contradictions
- They believe X but also like content arguing Y
- They criticize their own side on Z

### Political Accounts
Most-engaged political voices (liked + followed):
- @account1 — role/context
- @account2 — role/context

## Core Values

Ranked by signal strength:
1. **Value 1** — evidence
2. **Value 2** — evidence
3. **Value 3** — evidence

## Information Diet

### Trusted Sources
Accounts they follow/like repeatedly for news and analysis.

### Sceptical Of
Accounts/topics they criticize or avoid.

### Filter Bubble Assessment
How diverse is their information diet? Do they only see one perspective?

## Personality Signals

- **Tone:** serious, humorous, aggressive, thoughtful, ironic
- **Engagement style:** lurker, debater, shitposter, educator, curmudgeon
- **Conviction level:** strong ideologue vs curious explorer vs contrarian troll
- **Self-awareness:** do they acknowledge their own biases?

## Caveats
- Based on N likes, M own tweets, K follows — incomplete picture
- Likes don't always mean endorsement (can be "bookmarking to track")
- Sarcasm and irony are hard to detect programmatically
- Activity may not reflect private beliefs
```

## Tips

- **Likes > own tweets > follows** as signal strength for true preferences
- **Replies** are the most honest signal — they show what someone chooses to argue about
- **Bookmarks** show what someone wants to reference later — often more considered than likes
- **Following graph** is noisy — people follow for many reasons (news, hate-reading, networking)
- **Don't over-interpret single data points** — look for patterns across batches
- **Flag uncertainty** — use hedging language when signal is weak
- **Update periodically** — profiles drift over time
