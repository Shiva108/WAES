![GitHub Logo](/assets/banner.png)

# WAES - Web Auto Enum & Scanner

**Version 1.2.77**

WAES is a professional-grade bash-based web enumeration and reconnaissance platform designed for Capture The Flag (CTF) competitions, Bug Bounty hunting, and Penetration Testing. It automates the complex workflow of security scanning by orchestrating best-in-class tools into a unified, high-performance pipeline.

---

## 🚀 Key Features

### Core Capabilities

- **Multi-Stage Engine**: 4 scan levels from Fast Recon (`fast`) to Advanced Exploitation (`advanced`).
- **Parallel Execution**: Concurrent usage of scanning tools for 3-5x faster results.
- **Smart Profiles**: Pre-tuned configurations for CTF, Bug Bounties, and Web Apps.
- **Batch Scanning**: Native support for list-based and CIDR network scanning.

### Advanced Modules

- **Stealth Mode**: User-Agent rotation, proxy support, and timing evasion techniques.
- **OSINT Recon**: Subdomain enumeration, Certificate Transparency, and Google Dorks.
- **Parameter Discovery**: Advanced parameter mining and hidden input detection.
- **Containerization**: Full Docker and Docker Compose support for portable deployment.
- **Continuous Monitoring**: Change detection, baseline comparisons, and cron scheduling.

### Reporting & Output

- **Multi-Format**: JSON, XML, CSV, Markdown, and HTML reports.
- **Structured Data**: Machine-readable outputs for pipeline integration.
- **Detailed Artifacts**: Organized directory structure for every scan target.

---

## 📂 Repository Structure

```text
WAES/
├── waes.sh                 # Main CLI entry point
├── waes-watch.sh           # Continuous monitoring & baselining script
├── install.sh              # Dependency installer
├── lib/
│   ├── osint_scanner.sh    # Subdomain & OSINT module
│   ├── param_discovery.sh  # Parameter discovery engine
│   ├── stealth.sh          # Evasion configuration library
│   ├── batch_scanner.sh    # Multi-target orchestrator
│   ├── parallel_scan.sh    # Job queue & concurrency manager
│   ├── profile_loader.sh   # YAML profile parser
│   ├── plugin_manager.sh   # Plugin hook system
│   └── exporters/          # JSON, XML, CSV, MD generators
├── profiles/               # Scan configuration profiles (YAML)
├── plugins/                # Extension scripts (Slack, etc.)
├── report/                 # Default output directory
└── docker-compose.yml      # Container orchestration config
```

---

## 🛠️ Installation

### Native Installation

Requires a Linux environment (Kali Linux recommended).

```bash
git clone https://github.com/Shiva108/WAES.git
cd WAES
chmod +x install.sh
sudo ./install.sh
```

_The installer automatically detects your package manager and installs dependencies like nmap, nikto, gobuster, etc._

### Docker Installation

Run WAES in a container to avoid dependency conflicts.

```bash
# Build the image
docker build -t waes:latest .

# Or using Compose
docker-compose up -d
```

---

## 📖 Usage Guide

### Basic Scans

```bash
# Standard scan (HTTP)
sudo ./waes.sh -u 10.10.10.130

# HTTPS Deep Scan
sudo ./waes.sh -u target.com -s -t deep

# Generate HTML & JSON reports
sudo ./waes.sh -u target.com -t advanced -H -J
```

### Profile-Based Scanning

Use pre-tuned profiles for specific scenarios:

```bash
# Capture The Flag (Aggressive)
sudo ./waes.sh -u 10.10.10.130 --profile ctf-box

# Bug Bounty (Stealthy)
sudo ./waes.sh -u target.com --profile bug-bounty

# Available profiles: ctf-box, web-app, bug-bounty, quick-scan
```

### Batch & Parallel Scanning

Scan entire networks or lists of domains efficiently:

```bash
# Scan a list of targets (supports CIDR)
sudo ./waes.sh --targets targets.txt --parallel

# Targets file example:
# 192.168.1.10
# 10.10.10.0/24
# example.com
```

### Docker Usage

```bash
# Run a transient scan container
docker run --rm -v $(pwd)/report:/opt/waes/report waes:latest -u scanme.nmap.org

# Run with a profile
docker run --rm -v $(pwd)/report:/opt/waes/report waes:latest \
    -u target.com --profile ctf-box
```

### Stealth Mode

Activate evasion techniques before scanning:

```bash
# Source the stealth library
source lib/stealth.sh

# Configure level (low, medium, high, paranoid)
configure_stealth_mode high

# Run scan
sudo ./waes.sh -u target.com --profile bug-bounty
```

---

## 🧩 Plugins & Extensions

WAES supports a hook-based plugin system.

**Managing Plugins:**

```bash
./lib/plugin_manager.sh list
./lib/plugin_manager.sh load slack_notify
```

**Enabled Plugins:**

- **Slack Notify**: Sends webhook alerts on scan start/finish/findings.
- **Custom Scanner**: Template for integrating proprietary tools.

---

## 🤝 Contribution

We welcome contributions!

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/amazing-feature`.
3. Commit your changes: `git commit -m 'Add amazing feature'`.
4. Push to the branch: `git push origin feature/amazing-feature`.
5. Open a Pull Request.

Please ensure all new scripts pass `bash -n` syntax checks.

---

## 📜 License

This project is licensed under the **GPL-2.0 License**. See the `LICENSE` file for details.

---

## 📞 Author & Contact

**Shiva @ CPH:SEC**

- GitHub: [Shiva108](https://github.com/Shiva108)

---

### Verified Production Release - v1.2.77
