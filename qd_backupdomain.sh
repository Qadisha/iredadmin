#!/bin/bash

DOMAINNAME=''
TMPSTORAGE='/home/vmail/temp'
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
    rm -Rf $TMPSTORAGE/*.tar.gz
else
    echo "Error: Temporary directory does not exists."
    mkdir -p $TMPSTORAGE
fi


#
#	DEPRECATED - Check the remote storage - NFS/ZFS
#
if [ -d "/home/emlstor/$DOMAINNAME" ] 
then
    echo "Remote directory exists." 
    ${CMD_COMPRESS} $TMPSTORAGE/${TIMESTAMP}_${DOMAINNAME}.tar.gz /home/emlstor/$DOMAINNAME

    # Store the archive to BackBlaze bucket
    ${CMD_B2} ${S3STORAGE} $TMPSTORAGE/${TIMESTAMP}_${DOMAINNAME}.tar.gz  ${TIMESTAMP}_${DOMAINNAME}.tar.gz 

else
    echo "Error: Remote directory does not exists."
fi

#
#       DEPRECATED - Check the remote storage - NFS/ZFS
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
#	Check the local storage 
#
if [ -d "/home/vmail2/$DOMAINNAME" ]
then
    echo "Local directory exists." 
    ${CMD_COMPRESS} $TMPSTORAGE/${TIMESTAMP}_${DOMAINNAME}.tar.gz /home/vmail2/$DOMAINNAME

    # Store the archive to BackBlaze bucket
    ${CMD_B2} ${S3STORAGE} $TMPSTORAGE/${TIMESTAMP}_${DOMAINNAME}.tar.gz  ${TIMESTAMP}_${DOMAINNAME}.tar.gz 

else
    echo "Error: Local directory does not exists."
fi

