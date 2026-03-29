#!/bin/bash

# ==============================================================================
# clockify_switch.sh
# 
# A DevOps-friendly script to automate Clockify context switching.
# It automatically stops the current active timer and starts a new one based on 
# a fuzzy search of your project names.
#
# Usage:
#   ./clockify_switch.sh "infra" "Debugging database latency"
#   ./clockify_switch.sh "client a" "Daily standup"
#   ./clockify_switch.sh ""  (Just stops the current timer)
# ==============================================================================

# Inputs
PROJECT_SEARCH=$1
DESCRIPTION=${2:-"Working on $PROJECT_SEARCH"}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.clockify_config"

# Load config if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Ensure API Key is provided
if [ -z "$CLOCKIFY_API_KEY" ]; then
    echo "❌ Error: CLOCKIFY_API_KEY is not set."
    echo "Please configure it by running:"
    echo "  echo \"export CLOCKIFY_API_KEY='your_api_key_here'\" > $CONFIG_FILE"
    exit 1
fi

# Ensure jq is installed (used for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo "❌ Error: 'jq' is not installed. Please install it (e.g., sudo apt install jq)."
    exit 1
fi

API_BASE="https://api.clockify.me/api/v1"

# ------------------------------------------------------------------------------
# 1. Fetch User and Workspace info (and cache it for future runs)
# ------------------------------------------------------------------------------
if [ -z "$CLOCKIFY_USER_ID" ] || [ -z "$CLOCKIFY_WORKSPACE_ID" ]; then
    echo "🔍 First run setup: Fetching User and Workspace info..."
    USER_INFO=$(curl -s -H "X-Api-Key: $CLOCKIFY_API_KEY" "$API_BASE/user")
    
    CLOCKIFY_USER_ID=$(echo "$USER_INFO" | jq -r '.id')
    CLOCKIFY_WORKSPACE_ID=$(echo "$USER_INFO" | jq -r '.activeWorkspace')
    
    if [ "$CLOCKIFY_USER_ID" == "null" ] || [ -z "$CLOCKIFY_USER_ID" ]; then
         echo "❌ Error: Failed to fetch user info. Check if your API key is valid."
         exit 1
    fi
    
    # Cache for next time to speed up the script
    echo "export CLOCKIFY_USER_ID='$CLOCKIFY_USER_ID'" >> "$CONFIG_FILE"
    echo "export CLOCKIFY_WORKSPACE_ID='$CLOCKIFY_WORKSPACE_ID'" >> "$CONFIG_FILE"
fi

# ------------------------------------------------------------------------------
# 2. Stop the currently running timer
# ------------------------------------------------------------------------------
# Clockify API requires time in UTC ISO 8601 format
CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "⏸️  Stopping any currently running timer..."
STOP_RESP=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$API_BASE/workspaces/$CLOCKIFY_WORKSPACE_ID/user/$CLOCKIFY_USER_ID/time-entries" \
     -H "X-Api-Key: $CLOCKIFY_API_KEY" \
     -H "Content-Type: application/json" \
     -d "{\"end\": \"$CURRENT_TIME\"}")

if [ "$STOP_RESP" == "200" ]; then
    echo "✅ Successfully stopped the active timer."
else
    echo "ℹ️  No active timer found (or HTTP $STOP_RESP)."
fi

# If no project is provided, our job is done. Exit.
if [ -z "$PROJECT_SEARCH" ]; then
    echo "👋 No project specified. Exiting."
    exit 0
fi

# ------------------------------------------------------------------------------
# 3. Find the Project ID using a case-insensitive substring match
# ------------------------------------------------------------------------------
echo "🔎 Searching for a project matching '$PROJECT_SEARCH'..."

# Fetch up to 200 projects from the workspace
PROJECTS=$(curl -s -H "X-Api-Key: $CLOCKIFY_API_KEY" "$API_BASE/workspaces/$CLOCKIFY_WORKSPACE_ID/projects?page-size=200")

# Use jq to perform a case-insensitive search and grab the first match
PROJECT_ID=$(echo "$PROJECTS" | jq -r --arg query "$PROJECT_SEARCH" '.[] | select(.name | ascii_downcase | contains($query | ascii_downcase)) | .id' | head -n 1)
PROJECT_NAME=$(echo "$PROJECTS" | jq -r --arg query "$PROJECT_SEARCH" '.[] | select(.name | ascii_downcase | contains($query | ascii_downcase)) | .name' | head -n 1)

if [ "$PROJECT_ID" == "null" ] || [ -z "$PROJECT_ID" ]; then
    echo "❌ Error: Could not find any project matching '$PROJECT_SEARCH'."
    exit 1
fi

# ------------------------------------------------------------------------------
# 4. Start the new timer
# ------------------------------------------------------------------------------
echo "▶️  Starting a new timer for '$PROJECT_NAME'..."

START_RESP=$(curl -s -X POST "$API_BASE/workspaces/$CLOCKIFY_WORKSPACE_ID/time-entries" \
     -H "X-Api-Key: $CLOCKIFY_API_KEY" \
     -H "Content-Type: application/json" \
     -d "{
           \"start\": \"$CURRENT_TIME\",
           \"projectId\": \"$PROJECT_ID\",
           \"description\": \"$DESCRIPTION\"
         }")

ENTRY_ID=$(echo "$START_RESP" | jq -r '.id')

if [ "$ENTRY_ID" != "null" ] && [ -n "$ENTRY_ID" ]; then
    echo "✅ Success! Timer is now running."
    echo "   - Project: $PROJECT_NAME"
    echo "   - Description: $DESCRIPTION"
else
    echo "❌ Failed to start timer. Response details:"
    echo "$START_RESP" | jq .
    exit 1
fi
