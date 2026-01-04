#!/usr/bin/env bash
#==============================================================================
# Example WAES Plugin
# Demonstrates plugin hook system
#==============================================================================

HOOK="$1"
shift
ARGS=("$@")

case "$HOOK" in
    post_discovery)
        echo "[Plugin] Running post-discovery analysis..."
        # Custom logic here
        ;;
        
    pre_reporting)
        echo "[Plugin] Enhancing report..."
        # Custom logic here
        ;;
        
    *)
        echo "[Plugin] Unknown hook: $HOOK"
        ;;
esac
