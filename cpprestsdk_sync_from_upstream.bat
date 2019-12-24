@echo off

pushd %~dp0\..\cpprestsdk

git checkout master
git fetch upstream
git rebase upstream/master
git push origin master

popd
