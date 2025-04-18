#!/bin/sh
#	cgi script to start Tee Time Manager
#

# uncomment for testing mode
# echo "Content-type: text/plain"
# echo ""

# read Dynamo configuration
. /usr/cdi/.config

COMPCODE=LK
LOG=/u/CDI/$COMPCODE/web/log

echo `date` $REMOTE_ADDR $REQUEST_URI $COMPCODE >> $LOG/ttm_access.log
ERRORLOG=$LOG/ttm_error.log

# set initial bbx program to run
PGM=GW111

cd $SMSAPP
mkdir -m 777 TEMP 2>/dev/null
PATH=$SMSBIN:$PATH; export PATH
CONFIG=$SMSDIR/LK/config/config.bbx.ttm
TMPDIR=$SMSTMP; export TMPDIR

MAXTRIES=5

# set >>$ERRORLOG

umask 0
RETRIES=0
PROCERR=/u/CDI/tmp/ttm_procerr.$$

until [ $RETRIES -gt $MAXTRIES ]
do
  $BBXDIR/bbj -q -c"$CONFIG" -tIO CD/CDS011 - "$PGM" "$COMPCODE" "Scores_and_Charts" "$userinfo" 2>>$PROCERR

  if [ -s $PROCERR ]
     then
	RETRIES=`expr $RETRIES + 1`
	sleep 1
	read msg <$PROCERR
     else
	RETRIES=99
  fi
done

if [ ! "$RETRIES" = "99" ]
then
	echo `date` $msg >>$ERRORLOG 2>/dev/null
	echo "Content-type: text/plain"
	echo ""
	echo "The Tee Time Manager server is not available."
	echo "Please try again later."
	echo ""
	echo -e "Unable to service Tee Time Manager user\n$msg" | mail -s "Can't start Tee Time Manager" root,lenkrause76@gmail.com
else
	rm -f $PROCERR
fi
