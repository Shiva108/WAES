#!/usr/bin/env python3
"""
ResolveIP - Bulk DNS resolution utility
Part of WAES - Web Auto Enum & Scanner

Resolves domain names to IP addresses from a file input.
Supports concurrent resolution and multiple output formats.
"""

import argparse
import socket
import sys
import json
import csv
from concurrent.futures import ThreadPoolExecutor, as_completed
from io import StringIO
from typing import Optional, List, Tuple, Dict, Any


# Default settings
DEFAULT_TIMEOUT = 5
DEFAULT_THREADS = 10


def resolve_single(domain: str, timeout: float = DEFAULT_TIMEOUT) -> Tuple[str, Optional[str], Optional[str]]:
    """
    Resolve a single domain to its IP address.
    
    Args:
        domain: Domain name to resolve
        timeout: Socket timeout in seconds
        
    Returns:
        Tuple of (domain, ip_address, error_message)
    """
    domain = domain.strip()
    if not domain:
        return (domain, None, "Empty domain")
    
    # Set socket timeout
    socket.setdefaulttimeout(timeout)
    
    try:
        ip_address = socket.gethostbyname(domain)
        return (domain, ip_address, None)
    except socket.gaierror as e:
        return (domain, None, f"DNS error: {e}")
    except socket.timeout:
        return (domain, None, "Timeout")
    except Exception as e:
        return (domain, None, str(e))


def resolve_from_file(
    filepath: str,
    threads: int = DEFAULT_THREADS,
    timeout: float = DEFAULT_TIMEOUT,
    show_errors: bool = False
) -> List[Tuple[str, Optional[str], Optional[str]]]:
    """
    Resolve multiple domains from a file concurrently.
    
    Args:
        filepath: Path to file containing domains (one per line)
        threads: Number of concurrent threads
        timeout: Socket timeout per resolution
        show_errors: Whether to include failed resolutions
        
    Returns:
        List of (domain, ip, error) tuples
    """
    results: List[Tuple[str, Optional[str], Optional[str]]] = []
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            domains = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"Error: File not found: {filepath}", file=sys.stderr)
        sys.exit(1)
    except IOError as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        sys.exit(1)
    
    if not domains:
        print("Warning: No domains found in file", file=sys.stderr)
        return results
    
    with ThreadPoolExecutor(max_workers=threads) as executor:
        futures = {
            executor.submit(resolve_single, domain, timeout): domain
            for domain in domains
        }
        
        for future in as_completed(futures):
            result = future.result()
            if show_errors or result[1] is not None:
                results.append(result)
    
    return results


def output_plain(results: List[Tuple[str, Optional[str], Optional[str]]], iponly: bool = False) -> None:
    """Output results as plain text."""
    for domain, ip, error in results:
        if iponly:
            if ip:
                print(ip)
            else:
                print('-')
        else:
            if ip:
                print(f"{domain} -> {ip}")
            elif error:
                print(f"{domain} -> ERROR: {error}")


def output_csv(results: List[Tuple[str, Optional[str], Optional[str]]]) -> None:
    """Output results as CSV."""
    buffer = StringIO()
    writer = csv.writer(buffer)
    writer.writerow(['domain', 'ip', 'error'])
    
    for domain, ip, error in results:
        writer.writerow([domain, ip or '', error or ''])
    
    print(buffer.getvalue())


def output_json(results: List[Tuple[str, Optional[str], Optional[str]]]) -> None:
    """Output results as JSON."""
    data: List[Dict[str, Any]] = []
    
    for domain, ip, error in results:
        entry: Dict[str, Any] = {'domain': domain}
        if ip:
            entry['ip'] = ip
        if error:
            entry['error'] = error
        data.append(entry)
    
    print(json.dumps(data, indent=2))


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='ResolveIP - Bulk DNS resolution utility',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s domains.txt                  # Basic resolution
  %(prog)s domains.txt --ip-only        # Output IPs only
  %(prog)s domains.txt -f json          # JSON output
  %(prog)s domains.txt -t 20 -T 3       # 20 threads, 3s timeout
        """
    )
    
    parser.add_argument(
        'inputfile',
        help='File containing domains to resolve (one per line)'
    )
    
    parser.add_argument(
        '-f', '--format',
        choices=['plain', 'csv', 'json'],
        default='plain',
        help='Output format (default: plain)'
    )
    
    parser.add_argument(
        '--ip-only',
        action='store_true',
        help='Output only IP addresses (or - for failures)'
    )
    
    parser.add_argument(
        '-e', '--errors',
        action='store_true',
        help='Include failed resolutions in output'
    )
    
    parser.add_argument(
        '-t', '--threads',
        type=int,
        default=DEFAULT_THREADS,
        help=f'Number of concurrent threads (default: {DEFAULT_THREADS})'
    )
    
    parser.add_argument(
        '-T', '--timeout',
        type=float,
        default=DEFAULT_TIMEOUT,
        help=f'Resolution timeout in seconds (default: {DEFAULT_TIMEOUT})'
    )
    
    parser.add_argument(
        '-q', '--quiet',
        action='store_true',
        help='Suppress informational messages'
    )
    
    args = parser.parse_args()
    
    if not args.quiet:
        print(f"[*] Resolving domains from: {args.inputfile}", file=sys.stderr)
        print(f"[*] Threads: {args.threads}, Timeout: {args.timeout}s", file=sys.stderr)
    
    # Perform resolution
    results = resolve_from_file(
        args.inputfile,
        threads=args.threads,
        timeout=args.timeout,
        show_errors=args.errors
    )
    
    if not args.quiet:
        success_count = sum(1 for _, ip, _ in results if ip)
        print(f"[+] Resolved {success_count}/{len(results)} domains", file=sys.stderr)
        print("", file=sys.stderr)
    
    # Output results
    if args.format == 'json':
        output_json(results)
    elif args.format == 'csv':
        output_csv(results)
    else:
        output_plain(results, iponly=args.ip_only)
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
