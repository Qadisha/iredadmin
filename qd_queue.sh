#!/bin/bash


if [ $(date +%u)%2 == 0 ]; then
    # Recipient rejection permanent
     mailq | tail -n +2| awk 'BEGIN {RS = ""} /Recipient address rejected/ {print $1}' | postsuper -d -
     mailq | tail -n +2| awk 'BEGIN {RS = ""} /User unknown/ {print $1}' | postsuper -d -
    
    # Destination issues permanent
     mailq | tail -n +2| awk 'BEGIN {RS = ""} /No route to host/ {print $1}' |postsuper -d -
     mailq | tail -n +2| awk 'BEGIN {RS = ""} /Connection refused/ {print $1}' | postsuper -d -
else 
    # Recipient rejection temporary
     mailq | tail -n +2| awk 'BEGIN {RS = ""} /over quota/ {print $1}' | postsuper -d -
     mailq | tail -n +2| awk 'BEGIN {RS = ""} /Mailbox has exceeded the limit/ {print $1}' | postsuper -d -
     mailq | tail -n +2| awk 'BEGIN {RS = ""} /Mailbox full/ {print $1}' | postsuper -d -
    
    # Destination issues temporary
     mailq | tail -n +2| awk 'BEGIN {RS = ""} /Connection timed out/ {print $1}' | postsuper -d -
fi
