#!/bin/sh
#
# install Golf repo files and folders

echo Setting program permissions...
#sudo chmod a+rw /u/CDI/LK/*

echo Compiling bbj programs...
umask 005
/u/basis/bbj/bin/bbjcpl -d/u/CDI/LK/ ./$(dirname $0)/../src/*
