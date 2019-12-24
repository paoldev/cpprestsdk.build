@echo off

setlocal

set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
for /f "usebackq tokens=*" %%i in (`%VSWHERE% -version 16.0 -property installationPath`) do (
set VS_INSTALL_DIR=%%i
)

call "%VS_INSTALL_DIR%\Common7\Tools\VsDevCmd.bat"

set BUILD_DIR=%~dp0
set CPPREST_DIR=%BUILD_DIR%\..\cpprestsdk
set VCPKG_DIR=%CPPREST_DIR%\vcpkg
set VCPKG_TOOLCHAIN=%VCPKG_DIR%\scripts\buildsystems\vcpkg.cmake
set STATIC_OPTIONS=-DVCPKG_TARGET_TRIPLET=x64-windows-static -DBUILD_SHARED_LIBS:BOOL=FALSE -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded$<$<CONFIG:Debug>:Debug>"

if /I "%1"=="build" (
set BUILD_CMD=cmake --build . --config Debug ^& cmake --build . --config Release
) else (
set BUILD_CMD=echo.
)

echo.
echo winhttp-x64-windows
mkdir "%BUILD_DIR%\winhttp-x64-windows"
pushd "%BUILD_DIR%\winhttp-x64-windows"
cmake -G "Visual Studio 16 2019" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

echo.
echo winhttp-x64-windows-narrow
mkdir "%BUILD_DIR%\winhttp-x64-windows-narrow"
pushd "%BUILD_DIR%\winhttp-x64-windows-narrow"
cmake -G "Visual Studio 16 2019" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" -DCPPREST_FORCE_NARROW_STRINGS:BOOL=TRUE "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

echo.
echo winhttp-x64-windows-static
mkdir "%BUILD_DIR%\winhttp-x64-windows-static"
pushd "%BUILD_DIR%\winhttp-x64-windows-static"
cmake -G "Visual Studio 16 2019" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %STATIC_OPTIONS% "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

echo.
echo winhttp-x64-windows-static-narrow
mkdir "%BUILD_DIR%\winhttp-x64-windows-static-narrow"
pushd "%BUILD_DIR%\winhttp-x64-windows-static-narrow"
cmake -G "Visual Studio 16 2019" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %STATIC_OPTIONS% -DCPPREST_FORCE_NARROW_STRINGS:BOOL=TRUE "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

echo.
echo asio-x64-windows
mkdir "%BUILD_DIR%\asio-x64-windows"
pushd "%BUILD_DIR%\asio-x64-windows"
cmake -G "Visual Studio 16 2019" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" -DCPPREST_HTTP_CLIENT_IMPL=asio -DCPPREST_HTTP_LISTENER_IMPL=asio -DCMAKE_CXX_FLAGS="/DCPPREST_FORCE_HTTP_CLIENT_ASIO /EHsc" "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

echo.
echo asio-x64-windows-static
mkdir "%BUILD_DIR%\asio-x64-windows-static"
pushd "%BUILD_DIR%\asio-x64-windows-static"
cmake -G "Visual Studio 16 2019" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" %STATIC_OPTIONS% -DCPPREST_HTTP_CLIENT_IMPL=asio -DCPPREST_HTTP_LISTENER_IMPL=asio -DCMAKE_CXX_FLAGS="/DCPPREST_FORCE_HTTP_CLIENT_ASIO /EHsc" "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd

echo.
echo winrt-x64-uwp
mkdir "%BUILD_DIR%\winrt-x64-uwp"
pushd "%BUILD_DIR%\winrt-x64-uwp"
cmake -G "Visual Studio 16 2019" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%" -DCMAKE_SYSTEM_NAME=WindowsStore -DCMAKE_SYSTEM_VERSION=10.0 "%CPPREST_DIR%\Release"
%BUILD_CMD%
popd
