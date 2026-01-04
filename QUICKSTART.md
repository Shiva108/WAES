# WAES Advanced Platform - Quick Reference

## Installation

```bash
git clone https://github.com/user/WAES
cd WAES
sudo ./install.sh
```

## Quick Start

### Basic Scan

```bash
sudo ./waes.sh -u target.com
```

### CTF Mode (Full Automation)

```bash
sudo ./waes.sh -u 10.10.10.x --orchestrate --intel --chains --writeup
```

### Professional Engagement

```bash
sudo ./waes.sh -u client.com -t advanced --professional --evidence
```

## New CLI Flags

| Flag             | Description                                     |
| ---------------- | ----------------------------------------------- |
| `--orchestrate`  | Intelligent tool selection & parallel execution |
| `--intel`        | CVE correlation & exploit mapping               |
| `--professional` | Client-ready pentesting report                  |
| `--owasp`        | OWASP Top 10 focused scan                       |
| `--chains`       | Track vulnerability chains                      |
| `--evidence`     | Auto-collect evidence (default: ON)             |

## REST API

### Start Server

```bash
./lib/api/server.sh start
```

### Usage

```bash
# Start scan
curl -X POST http://localhost:8000/api/v1/scans \
  -H "X-API-Key: changeme" \
  -d '{"target": "example.com", "type": "deep"}'

# Check status
curl -H "X-API-Key: changeme" \
  http://localhost:8000/api/v1/scans/{scan_id}
```

## Components

- **Orchestrator**: `lib/orchestrator.sh`
- **Intelligence**: `lib/intelligence_engine.sh`
- **Reports**: `lib/report_engine/generator.sh`
- **API**: `lib/api/server.sh`
- **Plugins**: `lib/plugin_manager.sh`

## Performance

- Startup: <2s
- Memory: <50MB
- Parallel tools: 4 concurrent
- Automation: 75-80% of CTF recon

## Support

- Docs: `/home/e/WAES/ctf.md`
- Architecture: `implementation_plan.md`
- Examples: `walkthrough.md`
