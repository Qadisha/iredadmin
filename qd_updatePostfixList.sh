#!/bin/bash
while read p; do
  echo -e "$p\tOK" >> /etc/postfix/cidr
done <SOURCE_FILE
