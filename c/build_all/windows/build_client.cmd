@REM Copyright (c) Microsoft. All rights reserved.
@REM Licensed under the MIT license. See LICENSE file in the project root for full license information.

@setlocal EnableExtensions EnableDelayedExpansion
@echo off

set current-path=%~dp0
rem // remove trailing slash
set current-path=%current-path:~0,-1%

set build-root=%current-path%\..\..
rem // resolve to fully qualified path
for %%i in ("%build-root%") do set build-root=%%~fi

rem -----------------------------------------------------------------------------
rem -- check prerequisites
rem -----------------------------------------------------------------------------

rem -----------------------------------------------------------------------------
rem -- parse script arguments
rem -----------------------------------------------------------------------------

rem // default build options
set build-clean=0
set build-config=
set build-platform=Win32
set CMAKE_use_wsio=OFF
set CMAKE_build_python=OFF
set CMAKE_build_javawrapper=OFF
set CMAKE_no_logging=OFF

:args-loop
if "%1" equ "" goto args-done
if "%1" equ "--config" goto arg-build-config
if "%1" equ "--cmake_generator" goto arg-cmake-generator
if "%1" equ "--platform" goto arg-build-platform
if "%1" equ "--use-websockets" goto arg-use-websockets
if "%1" equ "--buildpython" goto arg-build-python
if "%1" equ "--build-javawrapper" goto arg-build-javawrapper
if "%1" equ "--no-logging" goto arg-no-logging
if "%1" equ "--build_dir" goto arg-build-dir
call :usage && exit /b 1

:arg-build-config
shift
if "%1" equ "" call :usage && exit /b 1
set build-config=%1
goto args-continue

:arg-cmake-generator
shift
if [%1] equ [] call :usage && exit /b 1
set CMAKE_generator=%1
goto args-continue

:arg-build-platform
shift
if "%1" equ "" call :usage && exit /b 1
set build-platform=%1
goto args-continue

:arg-use-websockets
set CMAKE_use_wsio=ON
goto args-continue

:arg-build-python
set CMAKE_build_python=2.7
if "%2"=="" goto args-continue
set PyVer=%2
if "%PyVer:~0,2%"=="--" goto args-continue
set CMAKE_build_python=%PyVer%
shift
goto args-continue

:arg-build-javawrapper
set CMAKE_build_javawrapper=ON 
goto args-continue

:arg-no-logging
set CMAKE_no_logging=ON 
goto args-continue

:arg-build-dir
shift
if "%1" equ "" call :usage && exit /b 1
set build_dir=%1
goto args-continue

:args-continue
shift
goto args-loop

:args-done
set cmake-output=cmake_%build-platform%

if [%CMAKE_generator%] equ [] (
   if not "%build-platform%" equ "Win32" (
       set CMAKE_generator=Visual Studio 14 Win64
   )
)

if "%build_dir%" equ "" set build_dir=%USERPROFILE%\%cmake-output%


rem -----------------------------------------------------------------------------
rem -- build with CMAKE
rem -----------------------------------------------------------------------------

if %CMAKE_use_wsio% == ON (
	echo WebSockets support only available for x86 platform.
)

echo CMAKE Output Path: %build_dir%

rmdir /s/q %build_dir%
rem no error checking

mkdir %build_dir%
rem no error checking

pushd %build_dir%

set cmake_command=cmake %build-root%
if not [%CMAKE_generator%] equ [] (
   set cmake_command=%cmake_command% -G %CMAKE_generator%
)
if "%build-platform%" equ "Win32" (
   set cmake_command=%cmake_command% -Duse_wsio:BOOL=%CMAKE_use_wsio%
)
set cmake_command=%cmake_command% -Dbuild_python:STRING=%CMAKE_build_python% -Dbuild_javawrapper:BOOL=%CMAKE_build_javawrapper% -Dno_logging:BOOL=%CMAKE_no_logging%

echo ***Running CMAKE ***
%cmake_command%
if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!


if not defined build-config (
	echo ***Building both configurations***
	msbuild /m azure_iot_sdks.sln /p:Configuration=Release
	if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
	msbuild /m azure_iot_sdks.sln /p:Configuration=Debug
	if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
) else (
	echo ***Building %build-config% only***
	msbuild /m azure_iot_sdks.sln /p:Configuration=%build-config%
	if not !ERRORLEVEL!==0 exit /b !ERRORLEVEL!
)

popd
goto :eof


:usage
echo build_client.cmd [options]
echo options:
echo  --config ^<value^>         [Debug] build configuration (e.g. Debug, Release)
echo  --platform ^<value^>       [Win32] build platform (e.g. Win32, x64, ...)
echo  --buildpython ^<value^>    [2.7]   build python extension (e.g. 2.7, 3.4, ...)
echo  --no-logging               Disable logging
echo  --cmake_generator ^<value^> Cmake generator to be used, otherwise default according to platform is used
echo  --build_dir ^<value^>      defines the build directory, otherwise build directory is set to the users home directory
goto :eof
