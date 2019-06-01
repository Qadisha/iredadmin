#
#   Check the accounts with a password change in the latest 4 hours and notify the owner about this.
#
#!/bin/bash
USER=''
PASSWORD=''
DBNAME=''
NOW=$(date -d '4 hours ago' +"%Y-%m-%d %H:%M")

mysql --batch -u$USER -p$PASSWORD $DBNAME -N -e "SELECT username FROM mailbox where modified >= '$NOW'" | while read -r col1;
do
        
        /usr/sbin/sendmail -t <<-EOF
        From: sender@senderdomain.it
        To: receiver@receiverdomain.it
        Subject: Password changed

        Ehy somebody change the password for $col1
        Please check you've requested this.
        
        Thanks

        --
        Support Team

        EOF

done