@echo off

pushd %~dp0\..\cpprestsdk

git remote add upstream https://github.com/microsoft/cpprestsdk

git remote show origin
git remote show upstream

popd
