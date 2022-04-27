#!/bin/sh
# pull Golf from github and install bbj programs

cd /u/CDI/LK/gitrepo/Golf
git pull

# compile code
/u/basis/bbj/bin/bbjcpl -d/u/CDI/LK/bbj/ src/*.bbj src/GW011 src/GW111

# copy css
cp css/*.css /u/CDI/LK/web/dynaweb/
