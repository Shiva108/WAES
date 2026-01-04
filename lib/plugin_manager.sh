#!/usr/bin/env bash
#==============================================================================
# WAES Plugin Manager
# Discover, load, and execute plugins to extend WAES functionality
#==============================================================================

set -euo pipefail

# Source color library if available
if [[ -f "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh" ]]; then
    source "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh"
else
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
fi

#==============================================================================
# PLUGIN SYSTEM
#==============================================================================

declare -A LOADED_PLUGINS
declare -A PLUGIN_HOOKS

# Plugin hook points
HOOK_PRE_SCAN="pre_scan"
HOOK_POST_SCAN="post_scan"
HOOK_ON_FINDING="on_finding"
HOOK_PRE_STAGE="pre_stage"
HOOK_POST_STAGE="post_stage"

# Discover plugins in directory
discover_plugins() {
    local plugin_dir="${1:-./plugins}"
    
    if [[ ! -d "$plugin_dir" ]]; then
        print_warn "Plugin directory not found: $plugin_dir"
        return 1
    fi
    
    print_info "Discovering plugins in: $plugin_dir"
    
    for plugin_file in "$plugin_dir"/*.sh; do
        [[ -f "$plugin_file" ]] || continue
        
        local plugin_name
        plugin_name=$(basename "$plugin_file" .sh)
        
        echo "  - $plugin_name"
    done
}

# Load a plugin
load_plugin() {
    local plugin_name="$1"
    local plugin_dir="${2:-./plugins}"
    local plugin_file="${plugin_dir}/${plugin_name}.sh"
    
    if [[ ! -f "$plugin_file" ]]; then
        print_error "Plugin not found: $plugin_name"
        return 1
    fi
    
    # Check if already loaded
    if [[ -n "${LOADED_PLUGINS[$plugin_name]:-}" ]]; then
        print_warn "Plugin already loaded: $plugin_name"
        return 0
    fi
    
    print_info "Loading plugin: $plugin_name"
    
    # Source the plugin
    # shellcheck disable=SC1090
    if source "$plugin_file"; then
        LOADED_PLUGINS[$plugin_name]="$plugin_file"
        print_success "Plugin loaded: $plugin_name"
        
        # Call plugin init if exists
        if declare -f "plugin_${plugin_name}_init" &>/dev/null; then
            "plugin_${plugin_name}_init"
        fi
        
        return 0
    else
        print_error "Failed to load plugin: $plugin_name"
        return 1
    fi
}

# Register a plugin hook
register_hook() {
    local hook_point="$1"
    local plugin_name="$2"
    local function_name="$3"
    
    if [[ -z "${PLUGIN_HOOKS[$hook_point]:-}" ]]; then
        PLUGIN_HOOKS[$hook_point]="$plugin_name:$function_name"
    else
        PLUGIN_HOOKS[$hook_point]="${PLUGIN_HOOKS[$hook_point]},$plugin_name:$function_name"
    fi
    
    print_info "Registered hook: $hook_point -> $plugin_name::$function_name"
}

# Execute hooks at a specific point
execute_hooks() {
    local hook_point="$1"
    shift
    local hook_args=("$@")
    
    local hooks="${PLUGIN_HOOKS[$hook_point]:-}"
    
    if [[ -z "$hooks" ]]; then
        return 0
    fi
    
    print_info "Executing hooks for: $hook_point"
    
    IFS=',' read -ra HOOK_LIST <<< "$hooks"
    for hook in "${HOOK_LIST[@]}"; do
        local plugin_name="${hook%%:*}"
        local function_name="${hook##*:}"
        
        if declare -f "$function_name" &>/dev/null; then
            print_info "  → ${plugin_name}::${function_name}"
            "$function_name" "${hook_args[@]}" || true
        fi
    done
}

# List loaded plugins
list_loaded_plugins() {
    if [[ ${#LOADED_PLUGINS[@]} -eq 0 ]]; then
        print_info "No plugins loaded"
        return 0
    fi
    
    print_info "Loaded plugins:"
    for plugin_name in "${!LOADED_PLUGINS[@]}"; do
        echo "  - $plugin_name (${LOADED_PLUGINS[$plugin_name]})"
    done
}

# Unload a plugin
unload_plugin() {
    local plugin_name="$1"
    
    if [[ -z "${LOADED_PLUGINS[$plugin_name]:-}" ]]; then
        print_warn "Plugin not loaded: $plugin_name"
        return 1
    fi
    
    # Call plugin cleanup if exists
    if declare -f "plugin_${plugin_name}_cleanup" &>/dev/null; then
        "plugin_${plugin_name}_cleanup"
    fi
    
    unset "LOADED_PLUGINS[$plugin_name]"
    print_success "Plugin unloaded: $plugin_name"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        discover)
            discover_plugins "${2:-./plugins}"
            ;;
        load)
            if [[ -z "${2:-}" ]]; then
                print_error "Plugin name required"
                exit 1
            fi
            load_plugin "$2" "${3:-./plugins}"
            ;;
        list)
            list_loaded_plugins
            ;;
        *)
            cat << EOF
Usage: $0 <command> [arguments]

Commands:
    discover [plugin_dir]         Discover available plugins
    load <plugin> [plugin_dir]    Load a plugin
    list                          List loaded plugins

Examples:
    $0 discover
    $0 load slack_notify
    $0 list
EOF
            exit 1
            ;;
    esac
fi
