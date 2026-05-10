#!/usr/bin/env bash
# =============================================================================
# timesync.sh — Align system clock and hardware clock on any Linux distro
# Supports: Ubuntu/Debian, AlmaLinux/CentOS/RHEL, and any systemd-based distro
# Run as root or with sudo
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()     { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()    { echo -e "${RED}[ERROR]${NC} $*"; }

# Must run as root
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root or with sudo."
    exit 1
fi

# -----------------------------------------------------------------------------
# 1. Detect distro and package manager
# -----------------------------------------------------------------------------
detect_distro() {
    if   command -v dnf  &>/dev/null; then PKG_MGR="dnf"
    elif command -v yum  &>/dev/null; then PKG_MGR="yum"
    elif command -v apt-get &>/dev/null; then PKG_MGR="apt-get"
    else
        err "Could not detect a supported package manager (dnf/yum/apt-get)."
        exit 1
    fi
    log "Package manager: $PKG_MGR"
}

# -----------------------------------------------------------------------------
# 2. Ensure an NTP client is installed
# -----------------------------------------------------------------------------
ensure_ntp_client() {
    # Prefer chrony > systemd-timesyncd > ntpdate (last resort)
    if command -v chronyd &>/dev/null; then
        NTP_CLIENT="chrony"
        ok "chrony is already installed."
        return
    fi

    if systemctl list-units --type=service 2>/dev/null | grep -q systemd-timesyncd; then
        NTP_CLIENT="timesyncd"
        ok "systemd-timesyncd is available."
        return
    fi

    log "No NTP client found. Installing chrony..."
    case $PKG_MGR in
        dnf|yum) $PKG_MGR install -y chrony ;;
        apt-get) apt-get install -y chrony ;;
    esac

    NTP_CLIENT="chrony"
    ok "chrony installed."
}

# -----------------------------------------------------------------------------
# 3. Show current time state
# -----------------------------------------------------------------------------
show_time_status() {
    echo ""
    log "=== Current time state ==="
    echo "  System time : $(date)"
    echo "  UTC time    : $(date -u)"
    if hwclock --show &>/dev/null 2>&1; then
        echo "  HW clock    : $(hwclock --show 2>/dev/null || echo 'unavailable')"
    fi
    if command -v timedatectl &>/dev/null; then
        timedatectl status 2>/dev/null || true
    fi
    echo ""
}

# -----------------------------------------------------------------------------
# 4. Ensure timezone is set (default UTC if unset/unknown)
# -----------------------------------------------------------------------------
ensure_timezone() {
    if command -v timedatectl &>/dev/null; then
        TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "")
        if [[ -z "$TZ" || "$TZ" == "n/a" ]]; then
            warn "Timezone not set. Setting to UTC."
            timedatectl set-timezone UTC
        else
            ok "Timezone is set to: $TZ"
        fi
    fi
}

# -----------------------------------------------------------------------------
# 5. Sync system clock via NTP
# -----------------------------------------------------------------------------
sync_clock() {
    log "Syncing system clock..."

    case $NTP_CLIENT in
        chrony)
            systemctl enable --now chronyd 2>/dev/null || true
            sleep 2
            # Force immediate sync
            chronyc makestep 2>/dev/null && ok "chrony: forced immediate step sync." || \
                warn "chrony makestep failed — chrony may still be syncing in background."
            ;;

        timesyncd)
            systemctl enable --now systemd-timesyncd 2>/dev/null || true
            if command -v timedatectl &>/dev/null; then
                timedatectl set-ntp true
                ok "systemd-timesyncd: NTP enabled."
                # Force sync by restarting
                systemctl restart systemd-timesyncd
                sleep 3
            fi
            ;;
    esac

    # Fallback: if neither worked cleanly, use ntpdate or sntp
    OFFSET=$(check_offset)
    if [[ $(echo "$OFFSET > 5 || $OFFSET < -5" | bc -l 2>/dev/null) == "1" ]]; then
        warn "Offset still large (${OFFSET}s). Trying forced ntpdate/sntp sync..."
        force_ntp_sync
    fi
}

# -----------------------------------------------------------------------------
# 6. Check current offset against a public NTP server
# -----------------------------------------------------------------------------
check_offset() {
    local offset=0
    if command -v chronyc &>/dev/null; then
        offset=$(chronyc tracking 2>/dev/null | awk '/System time/{print $4}' | sed 's/[^0-9.-]//g')
    elif command -v ntpq &>/dev/null; then
        offset=$(ntpq -p 2>/dev/null | awk 'NR>2{print $9}' | head -1 | sed 's/[^0-9.-]//g')
    fi
    echo "${offset:-0}"
}

# -----------------------------------------------------------------------------
# 7. Force sync with ntpdate or sntp as fallback
# -----------------------------------------------------------------------------
force_ntp_sync() {
    NTP_SERVERS=("pool.ntp.org" "time.cloudflare.com" "time.google.com")

    if command -v ntpdate &>/dev/null; then
        for srv in "${NTP_SERVERS[@]}"; do
            ntpdate -u "$srv" && ok "ntpdate synced from $srv." && return
        done
    elif command -v sntp &>/dev/null; then
        for srv in "${NTP_SERVERS[@]}"; do
            sntp -S "$srv" && ok "sntp synced from $srv." && return
        done
    else
        warn "ntpdate/sntp not available. Installing ntpdate..."
        case $PKG_MGR in
            dnf|yum) $PKG_MGR install -y ntpdate 2>/dev/null || true ;;
            apt-get) apt-get install -y ntpdate 2>/dev/null || true ;;
        esac
        for srv in "${NTP_SERVERS[@]}"; do
            ntpdate -u "$srv" 2>/dev/null && ok "ntpdate synced from $srv." && return
        done
    fi
    warn "All forced sync attempts failed. Check network connectivity."
}

# -----------------------------------------------------------------------------
# 8. Sync hardware clock from system clock
# -----------------------------------------------------------------------------
sync_hwclock() {
    if ! hwclock --show &>/dev/null 2>&1; then
        warn "Hardware clock not accessible (VM/container?). Skipping hwclock sync."
        return
    fi

    log "Syncing hardware clock from system clock..."
    hwclock --systohc --utc && ok "Hardware clock synced to system clock (UTC)." || \
        warn "hwclock sync failed — may not be available in this environment."
}

# -----------------------------------------------------------------------------
# 9. Final verification
# -----------------------------------------------------------------------------
verify() {
    echo ""
    log "=== Final time state ==="
    echo "  System time : $(date)"
    echo "  UTC time    : $(date -u)"
    if hwclock --show &>/dev/null 2>&1; then
        echo "  HW clock    : $(hwclock --show 2>/dev/null || echo 'unavailable')"
    fi

    if command -v chronyc &>/dev/null; then
        echo ""
        log "chrony tracking:"
        chronyc tracking 2>/dev/null || true
    elif command -v timedatectl &>/dev/null; then
        echo ""
        timedatectl status 2>/dev/null || true
    fi
    echo ""
    ok "Time sync complete."
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "================================================="
    echo "   timesync.sh — System & Hardware Clock Sync   "
    echo "================================================="
    detect_distro
    ensure_ntp_client
    show_time_status
    ensure_timezone
    sync_clock
    sync_hwclock
    verify
}

main
