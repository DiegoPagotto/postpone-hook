#!/bin/bash

CONFIG_FILE=".git/maxcommits"
COMMIT_COUNT_FILE=".git/commit_counts"
DEFAULT_MAX_COMMITS=2

DEFAULT_CONFIG_CONTENT=$(cat <<EOL
Monday=2
Tuesday=2
Wednesday=2
Thursday=2
Friday=2
Saturday=1
Sunday=0
EOL
)

# Create config file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Creating config file with default values."
  echo "$DEFAULT_CONFIG_CONTENT" > "$CONFIG_FILE"
fi

# Ensure commit count file exists
if [ ! -f "$COMMIT_COUNT_FILE" ]; then
  echo "Creating empty commit count file."
  touch "$COMMIT_COUNT_FILE"
fi

DAY_OF_WEEK=$(date +"%A")
TODAY=$(date +"%Y-%m-%d")

# Load max commits for today
if [ -f "$CONFIG_FILE" ]; then
  MAX_COMMITS=$(grep "^$DAY_OF_WEEK=" "$CONFIG_FILE" | cut -d '=' -f 2)
fi

MAX_COMMITS=${MAX_COMMITS:-$DEFAULT_MAX_COMMITS}

# Read today's commit count
COMMITS_TODAY=$(grep "^$TODAY=" "$COMMIT_COUNT_FILE" | cut -d '=' -f 2)
COMMITS_TODAY=${COMMITS_TODAY:-0}

echo "Debug: Current commit count for today ($TODAY): $COMMITS_TODAY"

# Check if commit limit is reached
if [ "$COMMITS_TODAY" -ge "$MAX_COMMITS" ]; then
  echo "Daily commit limit of $MAX_COMMITS reached for $DAY_OF_WEEK ($TODAY)."

  NEXT_DATE="$TODAY"
  while true; do
    # Increment date by 1 day based on OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      NEXT_DATE=$(date -I -d "$NEXT_DATE + 1 day")
      NEXT_DAY=$(date -d "$NEXT_DATE" +"%A")
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      NEXT_DATE=$(date -j -v+1d -f "%Y-%m-%d" "$NEXT_DATE" +"%Y-%m-%d")
      NEXT_DAY=$(date -j -f "%Y-%m-%d" "$NEXT_DATE" +"%A")
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
      NEXT_DATE=$(powershell -Command "(Get-Date -Date '$NEXT_DATE').AddDays(1).ToString('yyyy-MM-dd')")
      NEXT_DAY=$(powershell -Command "(Get-Date -Date '$NEXT_DATE').AddDays(1).DayOfWeek")
    else
      echo "Unsupported OS: $OSTYPE"
      exit 1
    fi

    echo "Checking commits for $NEXT_DAY ($NEXT_DATE)"

    # Get max commits for the next day
    COMMITS_NEXT=$(grep "^$NEXT_DAY=" "$CONFIG_FILE" | cut -d '=' -f 2)
    MAX_COMMITS_NEXT=${COMMITS_NEXT:-$DEFAULT_MAX_COMMITS}

    # Read commit count for the next date
    NEXT_DAY_COMMITS=$(grep "^$NEXT_DATE=" "$COMMIT_COUNT_FILE" | cut -d '=' -f 2)
    NEXT_DAY_COMMITS=${NEXT_DAY_COMMITS:-0}
    echo "Commits on $NEXT_DATE: $NEXT_DAY_COMMITS"

    if [ "$NEXT_DAY_COMMITS" -lt "$MAX_COMMITS_NEXT" ]; then
      echo "Next available date: $NEXT_DATE ($NEXT_DAY)"
      break
    fi
  done

  echo "Postponing commit to: $NEXT_DATE ($NEXT_DAY)"

  # Get previous commit timestamp
  PREV_COMMIT_DATE=$(git log -1 --format=%cd --date=iso)

  # Set commit date to previous commit's date
  COMMIT_DATE="$NEXT_DATE $(echo $PREV_COMMIT_DATE | awk '{print $2}')"

  # Update commit with new timestamp
  mv .git/hooks/post-commit .git/post-commit
  GIT_COMMITTER_DATE="$COMMIT_DATE" git commit --amend --date "$COMMIT_DATE" --no-edit --no-verify
  mv .git/post-commit .git/hooks/post-commit

  echo "Commit postponed to $NEXT_DATE ($NEXT_DAY)."
  echo "Updating commit count for $NEXT_DATE ($NEXT_DAY)."

  if grep -q "^$NEXT_DATE=" "$COMMIT_COUNT_FILE"; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^$NEXT_DATE=.*/$NEXT_DATE=$((NEXT_DAY_COMMITS + 1))/" "$COMMIT_COUNT_FILE"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      sed -i "s/^$NEXT_DATE=.*/$NEXT_DATE=$((NEXT_DAY_COMMITS + 1))/" "$COMMIT_COUNT_FILE"
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
      powershell -Command "(Get-Content '$COMMIT_COUNT_FILE') -replace '^$NEXT_DATE=.*', '$NEXT_DATE=$((NEXT_DAY_COMMITS + 1))' | Set-Content '$COMMIT_COUNT_FILE'"
    else
      echo "Unsupported OS: $OSTYPE"
      exit 1
    fi
  else
    echo "$NEXT_DATE=1" >> "$COMMIT_COUNT_FILE"
  fi

  exit 0
else
  echo "Daily commit limit of $MAX_COMMITS not reached for $DAY_OF_WEEK ($TODAY)."

  # Increment today's commit count
  if grep -q "^$TODAY=" "$COMMIT_COUNT_FILE"; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^$TODAY=.*/$TODAY=$((COMMITS_TODAY + 1))/" "$COMMIT_COUNT_FILE"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      sed -i "s/^$TODAY=.*/$TODAY=$((COMMITS_TODAY + 1))/" "$COMMIT_COUNT_FILE"
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
      powershell -Command "(Get-Content '$COMMIT_COUNT_FILE') -replace '^$TODAY=.*', '$TODAY=$((COMMITS_TODAY + 1))' | Set-Content '$COMMIT_COUNT_FILE'"
    else
      echo "Unsupported OS: $OSTYPE"
      exit 1
    fi
  else
    echo "$TODAY=$((COMMITS_TODAY + 1))" >> "$COMMIT_COUNT_FILE"
  fi
fi