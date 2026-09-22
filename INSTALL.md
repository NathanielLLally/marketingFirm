# Installation & Dependency Management

This project uses [Carton](https://metacpan.org/pod/Carton) to manage Perl dependencies declaratively via `cpanfile`.

## Quick Start

### 1. Install Carton (one-time setup)

```bash
cpan install Carton
# or via system package manager:
sudo apt install carton          # Debian/Ubuntu
sudo dnf install perl-Carton     # Fedora/RHEL
```

### 2. Install project dependencies

```bash
cd /space/git/marketingFirm
carton install
```

This creates `cpanfile.lock` (check in to git for reproducibility) and installs all dependencies into a local `local/` directory.

### 3. Run scripts with Carton

```bash
# Run via carton exec to use project-local modules
carton exec -- ./parsers/yellow_pages.pl bootstrap
carton exec -- ./parsers/yellow_pages.pl pending
carton exec -- ./parsers/yellow_pages.pl
```

Or set up `~/bin` symlinks as in `DEPS.md` and source the Carton environment:

```bash
eval $(carton exec env)
yellow_pages.pl bootstrap
```

## Systemd Service Example

To run the crawler as a service, use Carton in the ExecStart:

```ini
[Unit]
Description=Yellow Pages Crawler Worker
After=network.target postgresql.service

[Service]
Type=simple
User=crawler
WorkingDirectory=/space/git/marketingFirm
ExecStart=/usr/bin/carton exec -- ./parsers/yellow_pages.pl
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## Installing System Dependencies

Beyond Perl modules, you'll also need:

**PostgreSQL client libraries (required for DBD::Pg):**
```bash
# Debian/Ubuntu
sudo apt install libpq-dev

# Fedora/RHEL
sudo dnf install postgresql-devel
```

**OpenSSL development libraries (for Net::SSLeay / IO::Socket::SSL):**
```bash
# Debian/Ubuntu
sudo apt install libssl-dev

# Fedora/RHEL  
sudo dnf install openssl-devel
```

**Build tools (for compiling XS modules):**
```bash
# Debian/Ubuntu
sudo apt install build-essential

# Fedora/RHEL
sudo dnf install gcc perl-devel
```

## Configuration

Before running any scripts, create `~/.yellow_pages.conf`:

```ini
[dB]
dsn  = dbi:Pg:dbname=postgres;host=127.0.0.1
user = postgres
pass = your_password_here
```

For backward compatibility, the script also checks `~/.obiseo.conf` if the primary file is not found.

## Database Schema

Initialize the PostgreSQL schema:

```bash
psql -d postgres -U postgres -f etc/yellow_pages.sql
```

## Troubleshooting

**"Can't locate Module.pm":**
Make sure you ran `carton install` and are using `carton exec` to run scripts.

**"DBD::Pg not installed":**
System PostgreSQL dev libraries are missing; install `libpq-dev` (or equivalent) first.

**"Net::SSLeay not installed":**
System OpenSSL dev libraries are missing; install `libssl-dev` (or equivalent) first.

**Module version conflicts:**
Delete `local/` and `cpanfile.lock`, then run `carton install` again to get fresh lockfile.

## Reproducing Exact Environment

Share `cpanfile.lock` with team members; they can reproduce your exact versions:

```bash
carton install --deployment
```

The `--deployment` flag ensures versions match the lock file exactly and fails if the lock is stale.
