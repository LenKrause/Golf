#!/bin/sh
# pull Golf from github and install bbj programs

cd /u/CDI/LK/gitrepo/Golf
git pull

# compile code
/u/basis/bbj/bin/bbjcpl -d/u/CDI/LK/bbj/ src/*.bbj src/GW111

# copy css
cp css/*.css /u/CDI/LK/web/dynaweb/

# copy updater script
cp bin/gitgolf.sh /u/CDI/bin/
