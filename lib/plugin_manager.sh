#!/usr/bin/env bash
#==============================================================================
# WAES Plugin Manager
# Load and execute third-party scanner plugins
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true

PLUGINS_DIR="${SCRIPT_DIR}/plugins"
ENABLED_PLUGINS=()

#==============================================================================
# PLUGIN DISCOVERY
#==============================================================================

discover_plugins() {
    local plugins=()
    
    for plugin_dir in "${PLUGINS_DIR}"/*; do
        [[ -d "$plugin_dir" ]] || continue
        [[ -f "${plugin_dir}/manifest.yml" ]] || continue
        
        local plugin_name=$(basename "$plugin_dir")
        plugins+=("$plugin_name")
    done
    
    echo "${plugins[@]}"
}

#==============================================================================
# PLUGIN VALIDATION
#==============================================================================

validate_plugin() {
    local plugin_name="$1"
    local plugin_dir="${PLUGINS_DIR}/${plugin_name}"
    
    # Check manifest exists
    if [[ ! -f "${plugin_dir}/manifest.yml" ]]; then
        print_error "Plugin $plugin_name missing manifest.yml"
        return 1
    fi
    
    # Check main script exists
    if [[ ! -f "${plugin_dir}/main.sh" ]]; then
        print_error "Plugin $plugin_name missing main.sh"
        return 1
    fi
    
    # Check dependencies (basic check)
    local deps
    deps=$(grep "dependencies:" "${plugin_dir}/manifest.yml" -A 10 | grep "  -" | sed 's/.*- //')
    
    for dep in $deps; do
        if ! command -v "$dep" &>/dev/null; then
            print_warn "Plugin $plugin_name requires $dep (not installed)"
        fi
    done
    
    return 0
}

#==============================================================================
# HOOK SYSTEM
#==============================================================================

trigger_hook() {
    local hook_name="$1"
    shift
    local args=("$@")
    
    print_info "Triggering hook: $hook_name"
    
    for plugin_name in "${ENABLED_PLUGINS[@]}"; do
        local plugin_dir="${PLUGINS_DIR}/${plugin_name}"
        
        # Check if plugin listens to this hook
        if grep -q "  - $hook_name" "${plugin_dir}/manifest.yml"; then
            print_running "  Executing plugin: $plugin_name"
            
            # Execute plugin
            if [[ -x "${plugin_dir}/main.sh" ]]; then
                "${plugin_dir}/main.sh" "$hook_name" "${args[@]}" || true
            fi
        fi
    done
}

#==============================================================================
# PLUGIN MANAGEMENT
#==============================================================================

load_plugin() {
    local plugin_name="$1"
    
    if validate_plugin "$plugin_name"; then
        ENABLED_PLUGINS+=("$plugin_name")
        print_success "Loaded plugin: $plugin_name"
        return 0
    else
        return 1
    fi
}

load_all_plugins() {
    local plugins
    plugins=($(discover_plugins))
    
    print_info "Discovering plugins..."
    
    for plugin in "${plugins[@]}"; do
        load_plugin "$plugin"
    done
    
    if [[ ${#ENABLED_PLUGINS[@]} -gt 0 ]]; then
        print_success "Loaded ${#ENABLED_PLUGINS[@]} plugin(s)"
    else
        print_warn "No plugins loaded"
    fi
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-list}" in
        list)
            discover_plugins
            ;;
        load)
            load_plugin "$2"
            ;;
        validate)
            validate_plugin "$2"
            ;;
        *)
            echo "Usage: $0 {list|load <name>|validate <name>}"
            exit 1
            ;;
    esac
fi
