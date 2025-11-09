#!/bin/bash
# === BIGG BOSS TAMIL 9 – STREAM EXTRACTOR v1.0b (BASH) ===
# GitHub-ready | Auto-runs daily | Outputs streams.json
# v1.0 core logic translated to Bash (curl + grep + sed)

# ------------------- CONFIG -------------------
TAG_URL="https://www.1tamilcrow.net/tag/bigg-boss-tamil-season-9/"
USER_AGENT="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"
# ---------------------------------------------

# Generate dates: today, yesterday, 2 days ago
TODAY=$(date '+%d-%m-%Y')
YESTERDAY=$(date -d "yesterday" '+%d-%m-%Y')
DAY_BEFORE=$(date -d "2 days ago" '+%d-%m-%Y')
DATES=("$TODAY" "$YESTERDAY" "$DAY_BEFORE")

# Step 1: Fetch tag page and find first valid episode link
EPISODE_URL=""
EPISODE_TITLE="Latest Episode"

TAG_HTML=$(curl -s -A "$USER_AGENT" "$TAG_URL")

# Look for link with bigg-boss-9-tamil-DD-MM-YYYY/
for DATE in "${DATES[@]}"; do
    MATCH=$(echo "$TAG_HTML" | grep -oE "https?://[^\"']*bigg-boss-9-tamil-[^\"']*${DATE}/" | head -1)
    if [ -n "$MATCH" ]; then
        EPISODE_URL="$MATCH"
        # Extract title from nearby text
        TITLE_LINE=$(echo "$TAG_HTML" | grep -C1 "$EPISODE_URL" | head -2 | tail -1)
        EPISODE_TITLE=$(echo "$TITLE_LINE" | sed 's/.*<[^>]*>\([^<]*\).*/\1/' | xargs)
        [ -z "$EPISODE_TITLE" ] && EPISODE_TITLE="Latest Episode"
        break
    fi
done

# Step 2: Fallback – try direct URLs
if [ -z "$EPISODE_URL" ]; then
    for DATE in "${DATES[@]}"; do
        TEST_URL="https://www.1tamilcrow.net/bigg-boss-9-tamil-${DATE}/"
        if curl -s -o /dev/null -w "%{http_code}" -A "$USER_AGENT" "$TEST_URL" | grep -q "200"; then
            EPISODE_URL="$TEST_URL"
            EPISODE_TITLE="Bigg Boss 9 Tamil | $DATE"
            break
        fi
    done
fi

# Exit if no episode
[ -z "$EPISODE_URL" ] && echo '{"error": "No episode found"}' > streams.json && exit 1

# Step 3: Fetch episode and extract title
EPISODE_HTML=$(curl -s -A "$USER_AGENT" "$EPISODE_URL")
TITLE=$(echo "$EPISODE_HTML" | grep -i '<h1' | head -1 | sed 's/.*<h1[^>]*>\(.*\)<\/h1>.*/\1/' | xargs)
[ -n "$TITLE" ] && EPISODE_TITLE="$TITLE"

# Step 4: EXTRACT STREAMS (v1.0 LOGIC IN BASH)
STREAMS=()

# 1. iframes & embeds
IFRAMES=$(echo "$EPISODE_HTML" | grep -i 'iframe\|embed' | grep -o 'src="[^"]*"' | sed 's/src="//;s/"$//' | head -3)
for SRC in $IFRAMES; do
    [ -n "$SRC" ] && STREAMS+=("$SRC")
done

# 2. Fallback: direct links in content
if [ ${#STREAMS[@]} -lt 3 ]; then
    LINKS=$(echo "$EPISODE_HTML" | grep -o 'https://[^"]*\(dailymotion\|ok\.ru\|player\|embed\)[^"]*' | head -10)
    for LINK in $LINKS; do
        [[ ! " ${STREAMS[@]} " =~ " $LINK " ]] && STREAMS+=("$LINK")
        [ ${#STREAMS[@]} -eq 3 ] && break
    done
fi

# 3. Fallback: URLs in scripts
if [ ${#STREAMS[@]} -lt 3 ]; then
    SCRIPTS=$(echo "$EPISODE_HTML" | grep -o '<script[^>]*>[^<]*</script>' | grep -o 'https://[^'\'']*')
    for URL in $SCRIPTS; do
        if echo "$URL" | grep -qE "(dailymotion|ok\.ru|player|embed)"; then
            [[ ! " ${STREAMS[@]} " =~ " $URL " ]] && STREAMS+=("$URL")
            [ ${#STREAMS[@]} -eq 3 ] && break
        fi
    done
fi

# Trim to 3
STREAMS=("${STREAMS[@]:0:3}")

# Step 5: Build JSON
JSON_STREAMS=$(printf '"%s",' "${STREAMS[@]}" | sed 's/,*$//')
[ -z "$JSON_STREAMS" ] && JSON_STREAMS=""

cat > streams.json << EOF
{
  "episode": "$EPISODE_TITLE",
  "date": "$TODAY",
  "link": "$EPISODE_URL",
  "streams": [$JSON_STREAMS]
}
EOF

echo "v1.0b: Streams updated in streams.json"
