@echo off

setlocal

set DIR_SUFFIX=-vs2026
set VS_GENERATOR="Visual Studio 18 2026"
set VS_VERSION=18.0

set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
for /f "usebackq tokens=*" %%i in (`%VSWHERE% -version %VS_VERSION% -property installationPath`) do (
set VS_INSTALL_DIR=%%i
)

call "%VS_INSTALL_DIR%\VC\Auxiliary\Build\vcvarsall.bat" x64

set BUILD_DIR=%~dp0
set CPPREST_DIR=%BUILD_DIR%\..\cpprestsdk
set VCPKG_DIR=%CPPREST_DIR%\vcpkg
set VCPKG_TOOLCHAIN=%VCPKG_DIR%\scripts\buildsystems\vcpkg.cmake
rem Disable 'websockets' lib, since it doesn't compile with latest boost and asio libs.
set COMMON_OPTIONS=-DCPPREST_EXCLUDE_WEBSOCKETS:BOOL=ON
set STATIC_OPTIONS=-DVCPKG_TARGET_TRIPLET=x64-windows-static -DBUILD_SHARED_LIBS:BOOL=FALSE -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded$<$<CONFIG:Debug>:Debug>"

if /I "%1"=="build" (
set BUILD_CMD=cmake --build . --config Debug ^& cmake --build . --config Release
) else (
set BUILD_CMD=echo.
)

echo.
echo Install some dependencies, required by default 'compression' support (zlib) and 'asio' build (boost and openssl)
pushd %VCPKG_DIR%
set VCPKG_PKGS=boost-asio boost-system boost-date-time boost-regex openssl zlib
vcpkg.exe install --vcpkg-root %VCPKG_DIR% --triplet x64-windows %VCPKG_PKGS%
vcpkg.exe install --vcpkg-root %VCPKG_DIR% --triplet x64-windows-static %VCPKG_PKGS%
vcpkg.exe install --vcpkg-root %VCPKG_DIR% --triplet x64-uwp %VCPKG_PKGS%
popd

echo.
echo Apply cpprestsdk patches from vcpkg (please ignore any error when calling this batch multiple times)
set PATCH_DIR=%VCPKG_DIR%\ports\cpprestsdk
pushd %CPPREST_DIR%
git apply %PATCH_DIR%\fix-find-openssl.patch
git apply %PATCH_DIR%\fix_narrowing.patch
git apply %PATCH_DIR%\fix-uwp.patch
git apply %PATCH_DIR%\fix-clang-dllimport.patch
git apply %PATCH_DIR%\silence-stdext-checked-array-iterators-warning.patch
git apply %PATCH_DIR%\fix-asio-error.patch
popd

echo.
set CONFIGURATION=winhttp-x64-windows%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
cmake -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

echo.
set CONFIGURATION=winhttp-x64-windows-static%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
cmake -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% %STATIC_OPTIONS% "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

rem This configuration requires custom 'narrow-strings' patch to enable the new feature
echo.
set CONFIGURATION=winhttp-x64-windows-narrow%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
cmake -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% -DCPPREST_FORCE_NARROW_STRINGS:BOOL=TRUE "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

rem This configuration requires custom 'narrow-strings' patch to enable the new feature
echo.
set CONFIGURATION=winhttp-x64-windows-static-narrow%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
cmake -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% %STATIC_OPTIONS% -DCPPREST_FORCE_NARROW_STRINGS:BOOL=TRUE "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

rem This configuration requires custom 'asio' patch to compile
echo.
set CONFIGURATION=asio-x64-windows%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
cmake -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% -DCPPREST_HTTP_CLIENT_IMPL=asio -DCPPREST_HTTP_LISTENER_IMPL=asio -DCMAKE_CXX_FLAGS="/DCPPREST_FORCE_HTTP_CLIENT_ASIO /EHsc" "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

rem This configuration requires custom 'asio' patch to compile
echo.
set CONFIGURATION=asio-x64-windows-static%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
cmake -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% %STATIC_OPTIONS% -DCPPREST_HTTP_CLIENT_IMPL=asio -DCPPREST_HTTP_LISTENER_IMPL=asio -DCMAKE_CXX_FLAGS="/DCPPREST_FORCE_HTTP_CLIENT_ASIO /EHsc" "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

rem This configuration requires "Microsoft.VisualStudio.Component.Windows10SDK" (e.g. 10.0.19041.0).
rem If only Windows11SDK is installed (>= 10.0.22000.0, Microsoft.VisualStudio.Component.Windows11Sdk),
rem at least cmake > 4.2.1 is required (not yet available).
echo.
set CONFIGURATION=winrt-x64-uwp%DIR_SUFFIX%
echo %CONFIGURATION%
mkdir "%BUILD_DIR%\%CONFIGURATION%"
pushd "%BUILD_DIR%\%CONFIGURATION%"
cmake -G %VS_GENERATOR% -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %COMMON_OPTIONS% -DCMAKE_SYSTEM_NAME=WindowsStore -DCMAKE_SYSTEM_VERSION=10.0 "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd
