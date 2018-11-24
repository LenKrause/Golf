#!/bin/sh
# list bbx programs
PROG=$(file /u/CDI/LK/* | grep "BBx PGM" | awk -F: '{print $1}')
for i in $PROG; do
  echo $i
  dt_lst $i /u/CDI/LK/gitrepo/Golf/src Y
done
