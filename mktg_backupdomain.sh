#!/bin/bash

DOMAINNAME=''
TMPSTORAGE='/root/backup/mailboxes/migrated'
S3STORAGE='emailold'

# Commands.
CMD_DATE='/bin/date'
CMD_COMPRESS='/bin/tar -czvf'
CMD_B2='/root/b2 upload-file '

# Date.
YEAR="$(${CMD_DATE} +%Y)"
MONTH="$(${CMD_DATE} +%m)"
DAY="$(${CMD_DATE} +%d)"
TIME="$(${CMD_DATE} +%H.%M.%S)"
TIMESTAMP="${YEAR}-${MONTH}-${DAY}"

#
#	Prepare temp storage
#
if [ -d "$TMPSTORAGE" ]
then
    echo "Temporary storage directory exists."
    # rm -Rf $TMPSTORAGE/*.tar.gz
else
    echo "Error: Temporary directory does not exists."
    mkdir -p $TMPSTORAGE
fi


#
#	DEPRECATED Check the remote storage - NFS/ZFS 
#
if [ -d "/var/vmail/$DOMAINNAME" ] 
then
    echo "Remote directory exists." 
    ${CMD_COMPRESS} $TMPSTORAGE/${TIMESTAMP}_${DOMAINNAME}.tar.gz /var/vmail/$DOMAINNAME

    # Store the archive to BackBlaze bucket
    ${CMD_B2} ${S3STORAGE} $TMPSTORAGE/${TIMESTAMP}_${DOMAINNAME}.tar.gz  ${TIMESTAMP}_${DOMAINNAME}.tar.gz 

else
    echo "Error: Remote directory does not exists."
fi


#
#       Check the remote storage - NFS/ZFS
#
if [ -d "/home/vmailnew/$DOMAINNAME" ]
then
    echo "Remote directory exists."
    ${CMD_COMPRESS} $TMPSTORAGE/${TIMESTAMP}_${DOMAINNAME}.tar.gz /home/vmailnew/$DOMAINNAME

    # Store the archive to BackBlaze bucket
    ${CMD_B2} ${S3STORAGE} $TMPSTORAGE/${TIMESTAMP}_${DOMAINNAME}.tar.gz  ${TIMESTAMP}_${DOMAINNAME}.tar.gz

else
    echo "Error: Remote directory does not exists."
fi

#
#       Check the remote storage - NFS/ZFS - Temporary domains no longer hosted
#
if [ -d "/home/vmailnew/OLD/$DOMAINNAME" ]
then
    echo "Remote directory exists."
    ${CMD_COMPRESS} $TMPSTORAGE/${TIMESTAMP}_${DOMAINNAME}.tar.gz /home/vmailnew/OLD/$DOMAINNAME

    # Store the archive to BackBlaze bucket
    ${CMD_B2} ${S3STORAGE} $TMPSTORAGE/${TIMESTAMP}_${DOMAINNAME}.tar.gz  ${TIMESTAMP}_${DOMAINNAME}.tar.gz

else
    echo "Error: Remote directory does not exists."
fi

