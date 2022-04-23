@echo off

set FSO_GIT=https://github.com/scp-fs2open/fs2open.github.com.git
set QTVERSION=5.12.5
set QTBASE=https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/qt5_5125/qt.qt5.5125.win64_msvc2017_64/5.12.5-0-201909090442qtbase-Windows-Windows_10-MSVC2017-Windows-Windows_10-X86_64.7z
set QTTOOLS=https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/qt5_5125/qt.qt5.5125.win64_msvc2017_64/5.12.5-0-201909090442qttools-Windows-Windows_10-MSVC2017-Windows-Windows_10-X86_64.7z
set LIBARCHIVE=https://github.com/libarchive/libarchive/releases/download/v3.5.1/libarchive-v3.5.1-win64.zip

echo ==^> Looking for dependencies

curl --help > NUL
if errorlevel 1 goto :curl_missing

tar --help > NUL
if errorlevel 1 goto :tar_missing

cmake --help > NUL
if errorlevel 1 goto :cmake_missing

:detect_vs
echo ==^> Detecting Visual Studio

set "wherepath=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer"
if not exist "%wherepath%" set "wherepath=%ProgramFiles%\Microsoft Visual Studio\Installer"
if not exist "%wherepath%" goto :vswhere_missing

for /f "usebackq tokens=*" %%i in (`"%wherepath%\vswhere" -latest -property installationPath`) do set "vspath=%%i"
set "vsvars_path=%vspath%\VC\Auxiliary\Build\vcvarsall.bat"
if not exist "%vsvars_path%" goto :vs_missing

call "%vsvars_path%" amd64

if exist CMakeLists.txt goto :skip_clone
if exist src (
	cd src
	goto :skip_clone
)

git --help > NUL
if errorlevel 1 goto :git_missing

echo ==^> Downloading FSO source
git clone "%FSO_GIT%" src
cd src
git submodule update --init

:skip_clone

if not exist .vscode mkdir .vscode
cd .vscode


if exist qt goto :skip_qt
if exist libarchive\bin\bsdtar.exe goto :skip_libarchive

echo ==^> Downloading libarchive
curl -Lo libarchive.zip "%LIBARCHIVE%"
tar -xf libarchive.zip
del libarchive.zip

:skip_libarchive
if exist qtbase.7z goto :skip_qtbase
echo ==^> Downloading Qt Base
curl -Lo qtbase.7z "%QTBASE%"

:skip_qtbase
if exist qttools.7z goto :skip_qttools
echo ==^> Downloading Qt Tools
curl -Lo qttools.7z "%QTTOOLS%"

:skip_qttools
:: We need bsdtar from libarchive instead of Windows' pre-installed bsdtar because that one doesn't support LZMA
echo ==^> Unpacking Qt archives
libarchive\bin\bsdtar -xf qtbase.7z
libarchive\bin\bsdtar -xf qttools.7z

move "%QTVERSION%/msvc2017_64" qt
rd /S /Q "%QTVERSION%"
del qtbase.7z qttools.7z
rd /S /Q libarchive

:: Make sure qmake -query QT_INSTALL_BINS works properly
echo [Paths] > qt\bin\qt.conf
echo Prefix = .. >> qt\bin\qt.conf
echo. >> qt\bin\qt.conf

:skip_qt

set "qtdir=%CD%\qt\lib\cmake\Qt5"
cd ..

if exist build rd /S /Q build
mkdir build
cd build

echo ==^> Running CMake
set CC=cl
set CXX=cl
cmake -GNinja "-DQt5_DIR=%qtdir%" -DFSO_BUILD_QTFRED=ON -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=1 ..
if errorlevel 1 goto :cmake_error

copy compile_commands.json ..
copy "%~dp0settings.json" ..\.vscode
copy "%~dp0extensions.json" ..\.vscode

echo ==^> Done

:ask_cleanup
set /P answer=Delete setup script? [Y/n]: 

if "%answer%" == "" goto :cleanup
if "%answer%" == "y" goto :cleanup
if "%answer%" == "Y" goto :cleanup
if "%answer%" == "n" goto :skip_cleanup

echo Please enter either Y, y or n.
goto :ask_cleanup

:cleanup
:: anything past this line won't be executed because cmd.exe won't be able to read it (since we deleted ourselves)
del "%~dp0settings.json" "%~dp0extensions.json" "%~dp0setup.bat"

:skip_cleanup

pause
exit /b 0

:curl_missing
set tool=curl
goto :win10_error

:tar_missing
set tool=tar
goto :win10_error

:win10_error
echo.
echo Command "%tool%" could not be found. It's pre-installed on all recent Windows 10
echo versions. Please make sure that your system is updated and if that doesn't help,
echo ping ngld to help.
echo.
pause
exit /b 1

:cmake_missing
if exist "C:\Program Files\CMake" (
  set "PATH=C:\Program Files\CMake\bin;%PATH%"
  echo Added CMake folder to the PATH.

  cmake --help > NUL
  if not errorlevel 1 goto :detect_vs
)

echo.
echo You haven't installed CMake, yet. Please go to https://cmake.org/download/
echo download and run the installer, then run this script again.
echo.
pause
exit /b 1

:git_missing
echo.
echo You don't have Git for Windows installed or disabled the CLI integration.
echo Please install / modify it or download the FSO source code and move this
echo file in the root folder (where the CMakeLists.txt and .editorconfig files are)
echo and run it again.
echo.
pause
exit /b 1

:cmake_error
echo.
echo CMake failed. Please check the last few messages for details.
echo.
pause
exit /b 1

:vswhere_missing
echo.
echo Could not find vswhere.exe on your system. Did you run the Visual Studio installer?
echo.
pause
exit /b 1

:vs_missing
echo.
echo Could not detect Visual Studio. Did you install it? The installer is present
echo which means you just have to launch it to install VS...
echo.
pause
exit /b 1
