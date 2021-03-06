#!/bin/sh
#
# install Golf repo files and folders

echo Setting program permissions...
#sudo chmod a+rw /u/CDI/LK/*

echo Compiling programs...
umask 005
/u/basis/bbj/bin/bbjcpl -d/u/CDI/LK/pg6 ./$(dirname $0)/../src/* 2>/u/CDI/tmp/$$
if [ -s /u/CDI/tmp/$$ ]; then
  cat /u/CDI/tmp/$$ | mail -s "Golf compile errors" len@excellware.com
  echo Emailed list of compile errors
else
  echo No compile errors detected
fi
