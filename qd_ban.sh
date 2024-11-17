#!/bin/bash

# Path to the mail log file
LOGFILE="/var/log/mail.log"

# Time window in seconds (last hour = 3600 seconds)
TIME_WINDOW=3600

# URL to the whitelist file
WHITELIST_URL="https://raw.githubusercontent.com/Qadisha/rspamd/refs/heads/main/qadisha_ip_Wlist.txt"

# Temporary file to store the downloaded whitelist
WHITELIST_FILE="/tmp/ip_whitelist.txt"

# Name of the ipset set for blocked IPs
IPSET_NAME="blocked_ips"

# Lock file to ensure only one instance is running
LOCKFILE="/tmp/sasl_blocker.lock"

# Function to create and acquire the lock
acquire_lock() {
    exec 200>"$LOCKFILE" || exit 1
    flock -n 200 || { echo "Another instance of the script is already running. Exiting."; exit 1; }
}

# Function to release the lock
release_lock() {
    flock -u 200
    rm -f "$LOCKFILE"
}

# Function to initialize ipset
initialize_ipset() {
    if ! ipset list "$IPSET_NAME" &>/dev/null; then
        echo "Creating ipset: $IPSET_NAME"
        ipset create "$IPSET_NAME" hash:ip maxelem 100000 timeout 3600
        iptables -I INPUT -m set --match-set "$IPSET_NAME" src -j DROP
    fi
}

# Function to update the whitelist
update_whitelist() {
    echo "Updating IP whitelist from $WHITELIST_URL..."
    curl -s -o "$WHITELIST_FILE" "$WHITELIST_URL"
    if [[ $? -ne 0 ]]; then
        echo "Failed to download whitelist file. Proceeding without an update."
    else
        echo "Whitelist updated."
    fi
}

# Function to unblock whitelisted IPs
unblock_whitelisted_ips() {
    echo "Unblocking whitelisted IPs from ipset..."
    while IFS= read -r ip; do
        if ipset test "$IPSET_NAME" "$ip" &>/dev/null; then
            echo "Removing whitelisted IP: $ip"
            ipset del "$IPSET_NAME" "$ip"
        fi
    done < "$WHITELIST_FILE"
}

# Function to check and block IPs
check_and_block_ips() {
    echo "Checking log file for failed SASL authentication attempts..."
    # Get the current timestamp
    CURRENT_TIME=$(date +%s)
    
    # Extract failed authentication attempts in the last hour for PLAIN and LOGIN methods
    grep -E "SASL (PLAIN|LOGIN) authentication failed" "$LOGFILE" | while read -r line; do
        # Extract the timestamp and IP address from the log entry
        LOG_TIMESTAMP=$(echo "$line" | awk '{print $1, $2, $3}')
        IP=$(echo "$line" | grep -oP 'unknown\[\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
        
        # Convert the log timestamp to seconds since epoch
        LOG_TIME=$(date --date="$LOG_TIMESTAMP" +%s)
        
        # Check if the log entry is within the time window
        if (( CURRENT_TIME - LOG_TIME <= TIME_WINDOW )); then
            # Skip if the IP is in the whitelist
            if grep -q "$IP" "$WHITELIST_FILE"; then
                echo "Skipping whitelisted IP: $IP"
                continue
            fi

            # Add the IP to the ipset if not already present
            if ! ipset test "$IPSET_NAME" "$IP" &>/dev/null; then
                echo "Blocking IP: $IP"
                ipset add "$IPSET_NAME" "$IP"
            fi
        fi
    done
}

# Main execution
acquire_lock
trap release_lock EXIT

# Initialize ipset
initialize_ipset

# Initial whitelist update
update_whitelist

# Run the script periodically (every 5 minutes)
while true; do
    # Update the whitelist
    update_whitelist

    # Unblock any IPs that are now whitelisted
    unblock_whitelisted_ips

    # Check and block offending IPs
    check_and_block_ips

    sleep 300
done
