# WAES Docker Quick Start

## Building the Image

```bash
# Build WAES Docker image
docker build -t waes:latest .

# Or use Docker Compose
docker-compose build
```

## Running Scans

### Basic Scan

```bash
docker run --rm -v $(pwd)/report:/opt/waes/report waes:latest -u scanme.nmap.org
```

### Advanced Scan with HTML Report

```bash
docker run --rm -v $(pwd)/report:/opt/waes/report waes:latest \
    -u target.com -t advanced -H -J
```

### Using Profiles

```bash
docker run --rm \
    -v $(pwd)/report:/opt/waes/report \
    -v $(pwd)/profiles:/opt/waes/profiles \
    waes:latest -u target.com --profile ctf-box
```

### Batch Scanning

```bash
docker run --rm \
    -v $(pwd)/report:/opt/waes/report \
    -v $(pwd)/targets.txt:/opt/waes/targets.txt \
    waes:latest --targets targets.txt -t deep
```

### Interactive Mode

```bash
docker run -it --rm waes:latest /bin/bash
```

## Docker Compose

### Start Services

```bash
docker-compose up -d
```

### Run Scan

```bash
docker-compose run --rm waes -u target.com -t advanced -H
```

### View Logs

```bash
docker-compose logs -f waes
```

### Stop Services

```bash
docker-compose down
```

## Volume Mounts

- `/opt/waes/report` - Scan results
- `/opt/waes/profiles` - Custom profiles
- `/opt/waes/plugins` - Custom plugins

## Environment Variables

- `WAES_VERSION` - WAES version
- `SLACK_WEBHOOK_URL` - For Slack notifications (if plugin enabled)

## Examples

### CTF Box Scan

```bash
docker run --rm -v $(pwd)/report:/opt/waes/report \
    waes:latest -u 10.10.10.130 --profile ctf-box --parallel
```

### Stealth Bug Bounty Scan

```bash
docker run --rm -v $(pwd)/report:/opt/waes/report \
    waes:latest -u target.com --profile bug-bounty
```

### Multi-Target Scan

```bash
# Create targets.txt with one target per line
echo -e "target1.com\ntarget2.com\n10.10.10.0/28" > targets.txt

docker run --rm \
    -v $(pwd)/report:/opt/waes/report \
    -v $(pwd)/targets.txt:/opt/waes/targets.txt \
    waes:latest --targets targets.txt -t full -H
```

## Troubleshooting

### Permission Issues

Run with `--privileged` for full nmap functionality:

```bash
docker run --privileged --rm -v $(pwd)/report:/opt/waes/report \
    waes:latest -u target.com
```

### Network Issues

Use host networking for better compatibility:

```bash
docker run --network host --rm -v $(pwd)/report:/opt/waes/report \
    waes:latest -u target.com
```
