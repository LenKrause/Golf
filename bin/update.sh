#!/bin/sh
# pull Golf from github and install bbj programs

cd /u/CDI/LK/gitrepo/Golf
git pull

/u/basis/bbj/bin/bbjcpl -d/u/CDI/LK/bbj/ src/*.bbj
