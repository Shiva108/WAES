#!/usr/bin/env bash
#==============================================================================
# WAES Cloud Infrastructure Detection Module
# AWS, Azure, GCP, and cloud bucket enumeration
#==============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

source "${SCRIPT_DIR}/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
    print_running() { echo "[>] $*"; }
}

#==============================================================================
# S3 BUCKET ENUMERATION
#==============================================================================

enumerate_s3_buckets() {
    local domain="$1"
    local output_file="$2"
    
    print_running "Enumerating AWS S3 buckets..."
    
    # Common bucket name patterns
    local patterns=(
        "$domain"
        "${domain//./-}"
        "${domain//./}"
        "$domain-backup"
        "$domain-backups"
        "$domain-data"
        "$domain-assets"
        "$domain-static"
        "$domain-files"
        "$domain-uploads"
        "$domain-images"
        "$domain-media"
        "www-$domain"
        "cdn-$domain"
        "s3-$domain"
    )
    
    local found=0
    
    for bucket in "${patterns[@]}"; do
        # Test bucket existence and accessibility
        local url="https://${bucket}.s3.amazonaws.com"
        local response
        response=$(curl -sk -o /dev/null -w "%{http_code}" "$url" --max-time 5 2>/dev/null)
        
        case "$response" in
            200|403)
                echo "$bucket - Exists (HTTP $response)" >> "$output_file"
                print_warn "  → Found: $bucket (HTTP $response)"
                ((found++))
                
                # Test if listable
                if [[ "$response" == "200" ]]; then
                    local listing
                    listing=$(curl -sk "$url" --max-time 10 2>/dev/null)
                    if echo "$listing" | grep -q "<Key>"; then
                        echo "    SECURITY ISSUE: Bucket is publicly listable!" >> "$output_file"
                        print_error "    PUBLIC BUCKET: $bucket is listable!"
                    fi
                fi
                ;;
        esac
    done
    
    if [[ $found -gt 0 ]]; then
        print_success "Found $found S3 buckets"
    else
        print_info "No S3 buckets discovered"
    fi
    
    return 0
}

#==============================================================================
# AZURE BLOB STORAGE ENUMERATION
#==============================================================================

enumerate_azure_blobs() {
    local domain="$1"
    local output_file="$2"
    
    print_running "Enumerating Azure Blob Storage..."
    
    local account_names=(
        "${domain//.}"
        "${domain//./}"
        "$domain"
        "${domain//./-}"
    )
    
    local found=0
    
    for account in "${account_names[@]}"; do
        local url="https://${account}.blob.core.windows.net"
        local response
        response=$(curl -sk -o /dev/null -w "%{http_code}" "$url" --max-time 5 2>/dev/null)
        
        if [[ "$response" != "000" ]] && [[ "$response" != "404" ]]; then
            echo "$account - Azure Blob exists (HTTP $response)" >> "$output_file"
            print_warn "  → Found: $account (HTTP $response)"
            ((found++))
        fi
    done
    
    if [[ $found -gt 0 ]]; then
        print_success "Found $found Azure storage accounts"
    else
        print_info "No Azure storage accounts discovered"
    fi
}

#==============================================================================
# GCP STORAGE ENUMERATION
#==============================================================================

enumerate_gcp_buckets() {
    local domain="$1"
    local output_file="$2"
    
    print_running "Enumerating Google Cloud Storage..."
    
    local buckets=(
        "$domain"
        "${domain//./-}"
        "${domain//./}"
        "$domain-backup"
        "$domain-assets"
    )
    
    local found=0
    
    for bucket in "${buckets[@]}"; do
        local url="https://storage.googleapis.com/${bucket}"
        local response
        response=$(curl -sk -o /dev/null -w "%{http_code}" "$url" --max-time 5 2>/dev/null)
        
        case "$response" in
            200|403)
                echo "$bucket - GCS bucket exists (HTTP $response)" >> "$output_file"
                print_warn "  → Found: $bucket (HTTP $response)"
                ((found++))
                ;;
        esac
    done
    
    if [[ $found -gt 0 ]]; then
        print_success "Found $found GCS buckets"
    else
        print_info "No GCS buckets discovered"
    fi
}

#==============================================================================
# CDN DETECTION
#==============================================================================

detect_cdn() {
    local target="$1"
    local output_file="$2"
    
    print_running "Detecting CDN usage..."
    
    local headers
    headers=$(curl -skI "http://$target" 2>/dev/null)
    
    {
        echo "=== CDN Detection ==="
        
        # Cloudflare
        if echo "$headers" | grep -qi "cloudflare"; then
            echo "CDN: Cloudflare"
            echo "  Server: $(echo "$headers" | grep -i "server:" | cut -d':' -f2- | sed 's/^ *//')"
        fi
        
        # AWS CloudFront
        if echo "$headers" | grep -qi "cloudfront"; then
            echo "CDN: AWS CloudFront"
        fi
        
        # Akamai
        if echo "$headers" | grep -qi "akamai"; then
            echo "CDN: Akamai"
        fi
        
        # Fastly
        if echo "$headers" | grep -qi "fastly"; then
            echo "CDN: Fastly"
        fi
        
        # Determine via CNAME
        local cname
        cname=$(dig +short CNAME "$target" 2>/dev/null | head -1)
        if [[ -n "$cname" ]]; then
            echo "CNAME: $cname"
            
            case "$cname" in
                *cloudflare*) echo "CDN: Cloudflare (via CNAME)" ;;
                *cloudfront*) echo "CDN: CloudFront (via CNAME)" ;;
                *akamai*) echo "CDN: Akamai (via CNAME)" ;;
                *fastly*) echo "CDN: Fastly (via CNAME)" ;;
            esac
        fi
        
    } >> "$output_file"
}

#==============================================================================
# CLOUD PROVIDER DETECTION
#==============================================================================

detect_cloud_provider() {
    local target="$1"
    local output_file="$2"
    
    print_running "Detecting cloud provider..."
    
    # Get IP address
    local ip
    ip=$(dig +short A "$target" 2>/dev/null | head -1)
    
    if [[ -z "$ip" ]]; then
        print_warn "Could not resolve IP"
        return 1
    fi
    
    {
        echo "=== Cloud Provider Detection ==="
        echo "IP Address: $ip"
        
        # Reverse DNS for cloud provider hints
        local ptr
        ptr=$(dig +short -x "$ip" 2>/dev/null)
        
        if [[ -n "$ptr" ]]; then
            echo "PTR: $ptr"
            
            case "$ptr" in
                *amazonaws.com*) echo "Provider: AWS" ;;
                *azure*|*microsoft*) echo "Provider: Azure" ;;
                *googleusercontent.com*|*google.com*) echo "Provider: Google Cloud" ;;
                *digitalocean*) echo "Provider: DigitalOcean" ;;
                *linode*) echo "Provider: Linode" ;;
                *vultr*) echo "Provider: Vultr" ;;
            esac
        fi
        
    } >> "$output_file"
    
    print_success "Cloud provider detection complete"
}

#==============================================================================
# MAIN CLOUD ENUMERATION FUNCTION
#==============================================================================

run_cloud_enumeration() {
    local target="$1"
    local report_dir="${2:-.}"
    
    # Extract domain
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    
    print_info "Starting cloud infrastructure enumeration for: $domain"
    echo ""
    
    local output_dir="${report_dir}/cloud_enum"
    mkdir -p "$output_dir"
    
    local findings_file="${output_dir}/${domain}_cloud_findings.txt"
    
    # 1. S3 bucket enumeration
    enumerate_s3_buckets "$domain" "$findings_file"
    
    # 2. Azure blob storage
    enumerate_azure_blobs "$domain" "$findings_file"
    
    # 3. GCP storage
    enumerate_gcp_buckets "$domain" "$findings_file"
    
    # 4. CDN detection
    detect_cdn "$domain" "$findings_file"
    
    # 5. Cloud provider detection
    detect_cloud_provider "$domain" "$findings_file"
    
    # Generate summary
    local summary_file="${report_dir}/${domain}_cloud_enum.md"
    {
        echo "# Cloud Infrastructure Enumeration Report"
        echo ""
        echo "**Target:** $domain"
        echo "**Scan Date:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        echo "## Findings"
        echo '```'
        cat "$findings_file"
        echo '```'
        
    } > "$summary_file"
    
    print_success "Cloud enumeration complete: $summary_file"
    
    return 0
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat <<EOF
Usage: $0 <domain> [report_dir]

Cloud Infrastructure Detection Module
Enumerates cloud storage buckets and detects cloud providers.

Features:
  - AWS S3 bucket discovery
  - Azure Blob Storage detection
  - Google Cloud Storage enumeration
  - CDN detection (Cloudflare, CloudFront, Akamai, Fastly)
  - Cloud provider identification

Examples:
    $0 example.com
    $0 example.com ./reports
EOF
        exit 1
    fi
    
    run_cloud_enumeration "$@"
fi
