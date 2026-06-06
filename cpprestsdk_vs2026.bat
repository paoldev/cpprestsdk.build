@echo off

setlocal

set BUILD_DIR=%~dp0
set CPPREST_DIR=%BUILD_DIR%\..\cpprestsdk
if not exist %CPPREST_DIR% (
echo Error: missing %CPPREST_DIR%
goto :eof
)

set DO_BUILD=0
set UPDATE_VCPKG=0

if /i "%1"=="build" (set DO_BUILD=1)
if /i "%2"=="build" (set DO_BUILD=1)
if /i "%1"=="update_vcpkg" (set UPDATE_VCPKG=1)
if /i "%2"=="update_vcpkg" (set UPDATE_VCPKG=1)

set DIR_SUFFIX=-vs2026
set VS_GENERATOR="Visual Studio 18 2026"
set VS_VERSION=18.0

set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
for /f "usebackq tokens=*" %%i in (`%VSWHERE% -version %VS_VERSION% -property installationPath`) do (
set VS_INSTALL_DIR=%%i
)

call "%VS_INSTALL_DIR%\VC\Auxiliary\Build\vcvarsall.bat" x64

rem Remove trailing slash from %BUILD_DIR% and '..' from %CPPREST_DIR%
pushd %BUILD_DIR%
set BUILD_DIR=%cd%
popd
pushd %CPPREST_DIR%
set CPPREST_DIR=%cd%
popd
set VCPKG_DIR=%CPPREST_DIR%\vcpkg
set VCPKG_TOOLCHAIN=%VCPKG_DIR%\scripts\buildsystems\vcpkg.cmake
rem Disable 'websockets' lib, since it doesn't compile with latest boost and asio libs.
rem Add 'CMAKE_POLICY_VERSION_MINIMUM' to support latest cmake versions without changing original CMakeLists.txt.
set COMMON_OPTIONS=-DCPPREST_EXCLUDE_WEBSOCKETS:BOOL=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.10
set STATIC_OPTIONS=-DVCPKG_TARGET_TRIPLET=x64-windows-static -DBUILD_SHARED_LIBS:BOOL=FALSE -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded$<$<CONFIG:Debug>:Debug>"

if %UPDATE_VCPKG% equ 1 (
echo.
echo Update vcpkg
pushd %CPPREST_DIR%
git submodule update --recursive --remote --checkout -- vcpkg
popd
pushd %VCPKG_DIR%
call bootstrap-vcpkg.bat -disableMetrics
popd
)

echo.
echo Install some dependencies, required by default 'compression' support (zlib) and 'asio' build (boost and openssl)
pushd %VCPKG_DIR%
set VCPKG_PKGS=boost-asio boost-system boost-date-time boost-regex openssl zlib
vcpkg.exe install --vcpkg-root %VCPKG_DIR% --triplet x64-windows %VCPKG_PKGS%
vcpkg.exe install --vcpkg-root %VCPKG_DIR% --triplet x64-windows-static %VCPKG_PKGS%
vcpkg.exe install --vcpkg-root %VCPKG_DIR% --triplet x64-uwp %VCPKG_PKGS%
vcpkg.exe upgrade --vcpkg-root %VCPKG_DIR% --no-dry-run
popd

rem Select 'cmake' from vcpkg, if it exists; usually, its version is greater than the one from Visual Studio.
set CMAKE_EXE=cmake.exe
for /f "usebackq delims=" %%i in (`findstr /C:"-windows-x86_64/bin/cmake.exe" "%VCPKG_DIR%\scripts\vcpkg-tools.json"`) do set CMAKE_PATH=%%i
set CMAKE_PATH=%CMAKE_PATH:      "executable": "=%
set CMAKE_PATH=%CMAKE_PATH:",=%
set CMAKE_DIR=%CMAKE_PATH:-x86_64/bin/cmake.exe=%
if exist "%VCPKG_DIR%\downloads\tools\%CMAKE_DIR%\%CMAKE_PATH%" (
set CMAKE_EXE="%VCPKG_DIR%\downloads\tools\%CMAKE_DIR%\%CMAKE_PATH%"
) else (
if "%VCPKG_DOWNLOADS%" neq "" (
if exist "%VCPKG_DOWNLOADS%\tools\%CMAKE_DIR%\%CMAKE_PATH%" (
set CMAKE_EXE="%VCPKG_DOWNLOADS%\tools\%CMAKE_DIR%\%CMAKE_PATH%"
)
)
)

echo.
echo Selected cmake: %CMAKE_EXE%
echo.
%CMAKE_EXE% --version

if %DO_BUILD% equ 1 (
set BUILD_CMD=%CMAKE_EXE% --build . --config Debug ^& %CMAKE_EXE% --build . --config Release
) else (
set BUILD_CMD=echo.
)

echo.
echo Apply cpprestsdk patches from vcpkg (please ignore any error when calling this batch multiple times)
set PATCH_DIR=%BUILD_DIR%\patches
pushd %CPPREST_DIR%
git apply %PATCH_DIR%\fix-find-openssl.patch
git apply %PATCH_DIR%\fix-narrowing.patch
git apply %PATCH_DIR%\fix-uwp.patch
git apply %PATCH_DIR%\fix-clang-dllimport.patch
git apply %PATCH_DIR%\fix-asio-error.patch
git apply %PATCH_DIR%\fix-incomplete-json-value.patch
git apply %PATCH_DIR%\remove-stdext-checked-array-iterator-1836.patch
git apply %PATCH_DIR%\remove-openprot-1844.diff
popd

echo.
set CONFIGURATION=winhttp-x64-windows%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
%CMAKE_EXE% -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

echo.
set CONFIGURATION=winhttp-x64-windows-static%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
%CMAKE_EXE% -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% %STATIC_OPTIONS% "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

rem This configuration requires custom 'narrow-strings' patch to enable the new feature
echo.
set CONFIGURATION=winhttp-x64-windows-narrow%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
%CMAKE_EXE% -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% -DCPPREST_FORCE_NARROW_STRINGS:BOOL=TRUE "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

rem This configuration requires custom 'narrow-strings' patch to enable the new feature
echo.
set CONFIGURATION=winhttp-x64-windows-static-narrow%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
%CMAKE_EXE% -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% %STATIC_OPTIONS% -DCPPREST_FORCE_NARROW_STRINGS:BOOL=TRUE "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

rem This configuration requires custom 'asio' patch to compile
echo.
set CONFIGURATION=asio-x64-windows%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
%CMAKE_EXE% -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% -DCPPREST_HTTP_CLIENT_IMPL=asio -DCPPREST_HTTP_LISTENER_IMPL=asio -DCMAKE_CXX_FLAGS="/DCPPREST_FORCE_HTTP_CLIENT_ASIO /EHsc" "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

rem This configuration requires custom 'asio' patch to compile
echo.
set CONFIGURATION=asio-x64-windows-static%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
%CMAKE_EXE% -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% %STATIC_OPTIONS% -DCPPREST_HTTP_CLIENT_IMPL=asio -DCPPREST_HTTP_LISTENER_IMPL=asio -DCMAKE_CXX_FLAGS="/DCPPREST_FORCE_HTTP_CLIENT_ASIO /EHsc" "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

rem This configuration requires "Microsoft.VisualStudio.Component.Windows10SDK" (e.g. 10.0.19041.0).
rem If only Windows11SDK is installed (>= 10.0.22000.0, Microsoft.VisualStudio.Component.Windows11Sdk),
rem at least cmake >= 4.3.0 is required.
echo.
set CONFIGURATION=winrt-x64-uwp%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
%CMAKE_EXE% -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% -DCMAKE_SYSTEM_NAME=WindowsStore -DCMAKE_SYSTEM_VERSION=10.0 "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd
