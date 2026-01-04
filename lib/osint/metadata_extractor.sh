#!/usr/bin/env bash
#==============================================================================
# WAES Metadata Extraction Module
# Document metadata extraction for intelligence gathering
#==============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
    print_running() { echo "[>] $*"; }
}

#==============================================================================
# DOCUMENT DISCOVERY
#==============================================================================

discover_documents() {
    local url="$1"
    local output_file="$2"
    
    print_running "Discovering documents on target..."
    
    # Document extensions to search for
    local extensions=("pdf" "doc" "docx" "xls" "xlsx" "ppt" "pptx" "jpg" "png")
    
    local found_docs=()
    
    # Try to crawl site for documents
    for ext in "${extensions[@]}"; do
        print_info "  Searching for .$ext files..."
        
        # Google dork simulation (limited to site crawl)
        local docs
        docs=$(curl -sk "$url" 2>/dev/null | \
            grep -oE "href=['\"]([^'\"]*\.$ext)" | \
            sed "s/href=['\"]//g" | sed "s/['\"]//g")
        
        if [[ -n "$docs" ]]; then
            while IFS= read -r doc; do
                # Make absolute URL if relative
                if [[ ! "$doc" =~ ^http ]]; then
                    doc="${url}/${doc#/}"
                fi
                found_docs+=("$doc")
            done <<< "$docs"
        fi
    done
    
    # Save discovered documents
    printf '%s\n' "${found_docs[@]}" | sort -u > "$output_file"
    
    local count=${#found_docs[@]}
    if [[ $count -gt 0 ]]; then
        print_success "Found $count documents"
    else
        print_warn "No documents discovered"
    fi
    
    echo "$count"
}

#==============================================================================
# METADATA EXTRACTION
#==============================================================================

extract_metadata() {
    local doc_url="$1"
    local output_dir="$2"
    
    if ! command -v exiftool &>/dev/null; then
        return 1
    fi
    
    # Download document
    local filename
    filename=$(basename "$doc_url")
    local temp_file="${output_dir}/.${filename}"
    
    if ! curl -sk -o "$temp_file" "$doc_url" 2>/dev/null; then
        return 1
    fi
    
    # Extract metadata
    local metadata
    metadata=$(exiftool "$temp_file" 2>/dev/null)
    
    if [[ -n "$metadata" ]]; then
        echo "=== $filename ===" >> "${output_dir}/metadata.txt"
        echo "$metadata" >> "${output_dir}/metadata.txt"
        echo "" >> "${output_dir}/metadata.txt"
        
        # Extract specific fields of interest
        local author creator producer
        author=$(echo "$metadata" | grep -i "Author" | cut -d':' -f2- | sed 's/^ *//')
        creator=$(echo "$metadata" | grep -i "Creator" | cut -d':' -f2- | sed 's/^ *//')
        producer=$(echo "$metadata" | grep -i "Producer" | cut -d':' -f2- | sed 's/^ *//')
        
        [[ -n "$author" ]] && echo "$author" >> "${output_dir}/authors.txt"
        [[ -n "$creator" ]] && echo "$creator" >> "${output_dir}/creators.txt"
        [[ -n "$producer" ]] && echo "$producer" >> "${output_dir}/software.txt"
    fi
    
    # Cleanup
    rm -f "$temp_file"
    
    return 0
}

#==============================================================================
# USERNAME EXTRACTION
#==============================================================================

extract_usernames() {
    local metadata_file="$1"
    local output_file="$2"
    
    print_running "Extracting potential usernames..."
    
    # Extract email-like patterns
    grep -oE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" "$metadata_file" 2>/dev/null | \
        sort -u >> "$output_file"
    
    # Extract Windows-style usernames (C:\Users\username)
    grep -oE "C:\\\\Users\\\\[a-zA-Z0-9._-]+" "$metadata_file" 2>/dev/null | \
        sed 's|C:\\Users\\||' | \
        sort -u >> "${output_file}.windows"
    
    # Extract names from Author/Creator fields
    grep -iE "(Author|Creator).*:" "$metadata_file" 2>/dev/null | \
        cut -d':' -f2- | \
        sed 's/^ *//; s/ *$//' | \
        sort -u >> "${output_file}.names"
    
    # Combine and deduplicate
    cat "$output_file" "${output_file}.windows" "${output_file}.names" 2>/dev/null | \
        sort -u > "${output_file}.tmp"
    mv "${output_file}.tmp" "$output_file"
    rm -f "${output_file}.windows" "${output_file}.names"
    
    local count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
    print_success "Extracted $count potential usernames/identities"
}

#==============================================================================
# MAIN METADATA EXTRACTION FUNCTION
#==============================================================================

run_metadata_extraction() {
    local target="$1"
    local report_dir="${2:-.}"
    
    # Ensure target has protocol
    if [[ ! "$target" =~ ^https?:// ]]; then
        target="http://$target"
    fi
    
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    
    print_info "Starting metadata extraction for: $target"
    echo ""
    
    local output_dir="${report_dir}/metadata"
    mkdir -p "$output_dir"
    
    # Check for exiftool
    if ! command -v exiftool &>/dev/null; then
        print_error "exiftool not found. Install with: apt install libimage-exiftool-perl"
        return 1
    fi
    
    # 1. Discover documents
    local doc_list="${output_dir}/documents.txt"
    local doc_count
    doc_count=$(discover_documents "$target" "$doc_list")
    
    if [[ $doc_count -eq 0 ]]; then
        print_warn "No documents found for metadata extraction"
        return 1
    fi
    
    # 2. Extract metadata from each document
    print_running "Extracting metadata from $doc_count documents..."
    
    local extracted=0
    while IFS= read -r doc_url; do
        print_info "  Processing: $(basename "$doc_url")"
        if extract_metadata "$doc_url" "$output_dir"; then
            ((extracted++))
        fi
    done < "$doc_list"
    
    print_success "Extracted metadata from $extracted documents"
    
    # 3. Extract usernames and identities
    if [[ -f "${output_dir}/metadata.txt" ]]; then
        local username_file="${output_dir}/usernames.txt"
        extract_usernames "${output_dir}/metadata.txt" "$username_file"
    fi
    
    # Generate summary report
    local summary_file="${report_dir}/${domain}_metadata.md"
    {
        echo "# Metadata Extraction Report"
        echo ""
        echo "**Target:** $target"
        echo "**Scan Date:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        echo "## Summary"
        echo "- **Documents Found:** $doc_count"
        echo "- **Metadata Extracted:** $extracted"
        
        local username_count=$(wc -l < "${output_dir}/usernames.txt" 2>/dev/null || echo 0)
        echo "- **Usernames/Identities:** $username_count"
        echo ""
        
        if [[ $username_count -gt 0 ]]; then
            echo "## Discovered Usernames/Identities"
            echo '```'
            cat "${output_dir}/usernames.txt"
            echo '```'
            echo ""
        fi
        
        if [[ -f "${output_dir}/software.txt" ]]; then
            echo "## Software Versions"
            echo '```'
            sort -u "${output_dir}/software.txt"
            echo '```'
            echo ""
        fi
        
        echo "## Full Metadata"
        echo "See: ${output_dir}/metadata.txt"
        
    } > "$summary_file"
    
    print_success "Metadata extraction complete: $summary_file"
    
    return 0
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat <<EOF
Usage: $0 <target_url> [report_dir]

Metadata Extraction Module
Discovers and extracts metadata from documents (PDF, DOC, images, etc.)

Requirements:
  - exiftool (apt install libimage-exiftool-perl)

Intelligence Gathered:
  - Employee names (from document authors)
  - Email addresses
  - Internal file paths
  - Software versions
  - Creation dates and timestamps

Examples:
    $0 http://example.com
    $0 https://example.com ./reports
EOF
        exit 1
    fi
    
    run_metadata_extraction "$@"
fi
