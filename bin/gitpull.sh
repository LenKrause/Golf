#!/bin/sh -e
# download Golf repo from github
# checkout feature branch, master, or prior commit
# compile bbj programs

USAGE="$0 FeatureBranch | master | some-commit-hash"

if [ "$#" -ne 1 ]; then
  echo ""
  echo "Provide FeatureBranch, master, or commit hash"
  echo $USAGE
  echo ""
  exit 1
fi

cd /u/CDI/LK/gitrepo/Golf
unset SSH_ASKPASS

git fetch
git checkout $1
if [ $? -ne 0 ]; then
  echo "Unable to checkout branch $1"
  exit 1
fi

sh ./bin/install.sh
