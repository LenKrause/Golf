#!/bin/sh
# pull Golf from github and install bbj programs

cd /u/CDI/LK/gitrepo/Golf
git pull

# compile code
/u/basis/bbj/bin/bbjcpl -d/u/CDI/LK/bbj/ src/*.bbj src/GW011 src/GW045 src/GW111 src/GR03A

# copy css
cp css/*.css /u/CDI/LK/web/dynaweb/
