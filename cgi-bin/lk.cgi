#!/bin/sh
#	cgi script to start Excellware Dynaweb application
#

# uncomment for testing mode
# echo "Content-type: text/plain"
# echo ""

# read Dynamo configuration
. /usr/cdi/.config

# set Dynamo company code based on script name
COMPCODE=`echo $SCRIPT_NAME | cut -c 2-3 | tr a-z A-Z`
LOG=/u/CDI/$COMPCODE/web/log

echo `date` $REMOTE_ADDR $REQUEST_URI $COMPCODE >> $LOG/dw_access.log
ERRORLOG=$LOG/dw_error.log

# set initial bbx program to run
PGM=GW010

cd $SMSAPP
mkdir -m 777 TEMP 2>/dev/null
PATH=$SMSBIN:$PATH; export PATH
CONFIG=$SMSDIR/CD/config/config.bbx.dynaweb
TMPDIR=$SMSTMP; export TMPDIR

MAXTRIES=5

# set >>$ERRORLOG

umask 0
RETRIES=0
PROCERR=/u/CDI/tmp/dw_procerr.$$

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
	echo "The Dynaweb server is temporarily too busy."
	echo "Please try again later."
	echo ""
	echo "Dynaweb Administration has been notified"
	echo -e "Unable to service Dynaweb user, probably out of bbx user licenses\n$msg" | mail -s "Can't start Dynaweb - $COMPCODE" root,lenkrause76@gmail.com
else
	rm -f $PROCERR
fi
