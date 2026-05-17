#!/bin/bash
# Milhouse - Long-running Codex agent loop
# Usage: ./milhouse.sh [max_iterations]

set -e

MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      echo "Usage: ./milhouse.sh [max_iterations]"
      echo ""
      echo "Runs Codex repeatedly until all prd.json stories pass or max_iterations is reached."
      exit 0
      ;;
    [0-9]*)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
        if [ "$MAX_ITERATIONS" -lt 1 ]; then
          echo "Error: max_iterations must be greater than zero."
          exit 1
        fi
      else
        echo "Error: Invalid max_iterations '$1'. Must be a positive integer."
        exit 1
      fi
      shift
      ;;
    *)
      echo "Error: Unknown argument '$1'."
      echo "Usage: ./milhouse.sh [max_iterations]"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
PROMPT_FILE="$SCRIPT_DIR/CODEX.md"

if ! command -v codex >/dev/null 2>&1; then
  echo "Error: codex CLI not found. Install and authenticate Codex before running Milhouse."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not found. Install jq before running Milhouse."
  exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: Missing Codex prompt file: $PROMPT_FILE"
  exit 1
fi

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^milhouse/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    echo "# Milhouse Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Milhouse Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Milhouse with Codex - Max iterations: $MAX_ITERATIONS"
echo "Workspace: $WORKSPACE_DIR"
echo "Milhouse state: $SCRIPT_DIR"

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo ""
  echo "==============================================================="
  echo "  Milhouse Iteration $i of $MAX_ITERATIONS (codex)"
  echo "==============================================================="

  LAST_MESSAGE_FILE="$(mktemp)"

  OUTPUT=$(
    {
      cat "$PROMPT_FILE"
      printf '\n\n## Runtime Paths\n\n'
      printf -- '- Milhouse state directory: `%s`\n' "$SCRIPT_DIR"
      printf -- '- Target workspace directory: `%s`\n' "$WORKSPACE_DIR"
      printf -- '- PRD file: `%s`\n' "$PRD_FILE"
      printf -- '- Progress file: `%s`\n' "$PROGRESS_FILE"
    } | codex exec \
      --cd "$WORKSPACE_DIR" \
      --sandbox danger-full-access \
      --ask-for-approval never \
      --output-last-message "$LAST_MESSAGE_FILE" \
      - 2>&1 | tee /dev/stderr
  ) || true

  if grep -q "<promise>COMPLETE</promise>" "$LAST_MESSAGE_FILE" 2>/dev/null || echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Milhouse completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    rm -f "$LAST_MESSAGE_FILE"
    exit 0
  fi

  rm -f "$LAST_MESSAGE_FILE"
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Milhouse reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
