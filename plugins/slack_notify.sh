#!/usr/bin/env bash
#==============================================================================
# Sample Plugin: Slack Notifications
# Sends notifications to Slack channel on scan events
#==============================================================================

# Plugin metadata
PLUGIN_NAME="slack_notify"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Send scan notifications to Slack"

# Configuration (set via environment or here)
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

#==============================================================================
# PLUGIN FUNCTIONS
#==============================================================================

# Plugin initialization
plugin_slack_notify_init() {
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        echo "[PLUGIN:slack_notify] Warning: SLACK_WEBHOOK_URL not set"
        return 1
    fi
    
    echo "[PLUGIN:slack_notify] Initialized"
    
    # Register hooks
    if declare -f register_hook &>/dev/null; then
        register_hook "pre_scan" "slack_notify" "slack_notify_scan_start"
        register_hook "post_scan" "slack_notify" "slack_notify_scan_complete"
        register_hook "on_finding" "slack_notify" "slack_notify_finding"
    fi
}

# Send message to Slack
slack_send_message() {
    local message="$1"
    local color="${2:-#36a64f}"
    
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        return 1
    fi
    
    local payload
    payload=$(cat <<EOF
{
    "attachments": [{
        "color": "$color",
        "text": "$message",
        "footer": "WAES Scanner",
        "ts": $(date +%s)
    }]
}
EOF
)
    
    curl -s -X POST -H 'Content-type: application/json' \
        --data "$payload" \
        "$SLACK_WEBHOOK_URL" >/dev/null
}

# Hook: Scan start notification
slack_notify_scan_start() {
    local target="$1"
    local scan_type="$2"
    
    slack_send_message "🚀 Scan started: $target (Type: $scan_type)" "#4A90E2"
}

# Hook: Scan complete notification
slack_notify_scan_complete() {
    local target="$1"
    local status="$2"
    
    local color="#36a64f"
    [[ "$status" != "success" ]] && color="#ff0000"
    
    slack_send_message "✅ Scan completed: $target (Status: $status)" "$color"
}

# Hook: Finding notification
slack_notify_finding() {
    local severity="$1"
    local finding="$2"
    
    local color="#ffa500"
    [[ "$severity" == "critical" ]] && color="#ff0000"
    [[ "$severity" == "high" ]] && color="#ff4500"
    
    slack_send_message "⚠️  Finding ($severity): $finding" "$color"
}

# Plugin cleanup
plugin_slack_notify_cleanup() {
    echo "[PLUGIN:slack_notify] Cleanup complete"
}

# Export functions for use
export -f slack_send_message
export -f slack_notify_scan_start
export -f slack_notify_scan_complete
export -f slack_notify_finding
