# Installing sublist3r for OSIRA

OSIRA requires sublist3r for subdomain enumeration.

## Option 1: Install via apt (Kali/Parrot - Recommended)

```bash
sudo apt install sublist3r
```

## Option 2: Install via pip (Other distros)

```bash
sudo pip3 install sublist3r
```

```bash
cd /opt
sudo git clone https://github.com/aboul3la/Sublist3r.git
cd Sublist3r
sudo pip3 install -r requirements.txt
sudo ln -s /opt/Sublist3r/sublist3r.py /usr/local/bin/sublist3r
sudo chmod +x /usr/local/bin/sublist3r
```

## Option 3: Skip OSIRA (Already Implemented)

WAES now gracefully handles missing sublist3r:

- OSIRA attempts to run
- If sublist3r missing, warning displayed
- Scan continues without subdomain enumeration

```bash
[~] OSIRA skipped (missing dependencies: sublist3r)
```

## Verify Installation

```bash
which sublist3r
sublist3r -h
```

## Alternative: Disable OSIRA

If you don't need subdomain enumeration:

```bash
# Remove execute permission
chmod -x external/OSIRA/osira.sh

# WAES will skip OSIRA automatically
```

## Test After Installation

```bash
sudo ./waes.sh -u example.com -p 80 -t deep
```

OSIRA should now complete successfully.
