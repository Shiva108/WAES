# WAES - Web Auto Enum & Scanner
# Official Docker Image

FROM kalilinux/kali-rolling:latest

LABEL maintainer="WAES Project"
LABEL description="Web Application Enumeration & Security Scanner"
LABEL version="1.2.0"

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Update and install dependencies
RUN apt-get update && apt-get install -y \
    nmap \
    nikto \
    gobuster \
    dirb \
    whatweb \
    wafw00f \
    uniscan \
    git \
    curl \
    wget \
    dnsutils \
    jq \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Optional tools (install if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    sslscan \
    testssl.sh \
    && rm -rf /var/lib/apt/lists/* || true

# Install Python tools
RUN pip3 install --no-cache-dir \
    requests \
    beautifulsoup4 || true

# Create application directory
WORKDIR /opt/waes

# Copy WAES files
COPY . /opt/waes/

# Make scripts executable
RUN chmod +x /opt/waes/*.sh /opt/waes/lib/*.sh /opt/waes/lib/exporters/*.sh

# Create reports directory
RUN mkdir -p /opt/waes/report

# Set up volume for reports
VOLUME ["/opt/waes/report"]

# Set working directory for scans
WORKDIR /opt/waes

# Default command
ENTRYPOINT ["/opt/waes/waes.sh"]
CMD ["--help"]

# Usage examples:
# Build: docker build -t waes:latest .
# Run: docker run -v $(pwd)/report:/opt/waes/report waes:latest -u scanme.nmap.org
# Interactive: docker run -it waes:latest /bin/bash
