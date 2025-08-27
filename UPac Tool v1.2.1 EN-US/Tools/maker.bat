@echo off
setlocal enabledelayedexpansion

title Unisoc Integration Package Maker

:: Set tool paths
set "spd_dump_path=%cd%\bin\spd_dump"
set "adb_path=%cd%\bin\adb_fastboot\adb"
set "seven_zip_dir=%cd%\bin\7z"

:: Check if necessary tools exist
if not exist "%spd_dump_path%\spd_dump.exe" (
    echo Error: spd_dump tool not found
    pause
    exit /b 1
)

if not exist "%adb_path%.exe" (
    echo Error: adb tool not found
    pause
    exit /b 1
)

if not exist "%seven_zip_dir%\7zr.exe" (
    echo Error: 7zr tool not found
    pause
    exit /b 1
)

:start
cls
echo ===============================================================================
echo.                        Unisoc Integration Package Maker By ¶À¤Î¹â
echo ===============================================================================
echo.

:: Ask for package name
set /p "package_name=Please enter the integration package name: "
if "!package_name!"=="" (
    echo Package name cannot be empty!
    timeout /t 2 /nobreak >nul
    goto start
)

:: Create working directory
set "work_dir=%cd%\!package_name!"
set "flash_files_dir=!work_dir!\flash_files"
set "dump_dir=!flash_files_dir!\dump"
set "push_dir=!flash_files_dir!\push"

:: If working directory exists, delete it
if exist "!work_dir!" (
    rmdir /s /q "!work_dir!" >nul 2>&1
)

:: Create new working directory
mkdir "!work_dir!" >nul 2>&1
mkdir "!flash_files_dir!" >nul 2>&1
mkdir "!dump_dir!" >nul 2>&1
mkdir "!push_dir!" >nul 2>&1

:: Check device preparation status
echo.
echo Please confirm the device meets the following conditions:
echo 1. Bootloader is unlocked
echo 2. AVB verification is disabled
echo 3. TWRP recovery is installed
echo.
set /p "confirmed=Does the device meet these conditions? (Y/N): "

if /i not "!confirmed!"=="Y" (
    echo Please complete device preparation before continuing
    rmdir /s /q "!work_dir!"
    pause
    goto start
)

:: Get FDL files
echo.
echo Please provide FDL file information...
echo.

:get_fdl1
set /p "fdl1_file=Please drag and drop the first FDL file: "
set "fdl1_file=!fdl1_file:"=!"
if not exist "!fdl1_file!" (
    echo File does not exist, please try again
    goto get_fdl1
)

set /p "fdl1_path=Please enter the path address for the first FDL file (e.g., 0x5000): "
if "!fdl1_path!"=="" (
    echo Path address cannot be empty
    goto get_fdl1
)

copy /y "!fdl1_file!" "!dump_dir!\fdl1.bin" >nul

:get_fdl2
set /p "fdl2_file=Please drag and drop the second FDL file: "
set "fdl2_file=!fdl2_file:"=!"
if not exist "!fdl2_file!" (
    echo File does not exist, please try again
    goto get_fdl2
)

set /p "fdl2_path=Please enter the path address for the second FDL file (e.g., 0x9efffe00): "
if "!fdl2_path!"=="" (
    echo Path address cannot be empty
    goto get_fdl2
)

copy /y "!fdl2_file!" "!dump_dir!\fdl2.bin" >nul

:: Read device partitions
echo.
echo Please power off the device, then connect directly to the computer...
pause

echo Reading device partitions...
cd /d "!dump_dir!"
"%spd_dump_path%\spd_dump" --wait 1000 --kickto 2 r splloader r trustos r uboot reboot-recovery

if errorlevel 1 (
    echo Failed to read partitions, please check device connection and drivers
    pause
    goto cleanup
)

echo Partitions read successfully!
timeout /t 3 /nobreak >nul

:: Wait for device to enter Recovery
echo Waiting for device to enter TWRP recovery mode...
:wait_recovery
"%adb_path%" wait-for-recovery >nul 2>&1
if errorlevel 1 (
    echo Device not in recovery mode, please manually enter TWRP and press any key to continue...
    pause
    goto wait_recovery
)

:: Create backup
echo Creating TWRP backup...
set "timestamp=!date:~0,4!!date:~5,2!!date:~8,2!!time:~0,2!!time:~3,2!!time:~6,2!"
set "timestamp=!timestamp: =0!"

"%adb_path%" shell "twrp backup SDRB !timestamp!"

if errorlevel 1 (
    echo Backup creation failed
    pause
    goto cleanup
)

:: Get device ID and pull backup
echo Getting device ID...
for /f "delims=" %%a in ('"%adb_path%" get-serialno 2^>nul') do set "DeviceID=%%a"

if "!DeviceID!"=="" (
    echo Unable to get device ID
    set "DeviceID=unknown"
)

set "backup_name=!DeviceID!/!timestamp!"

:: Pull backup files
echo Pulling backup files...
mkdir "!push_dir!\TWRP" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS\!DeviceID!" >nul 2>&1

"%adb_path%" pull /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp! "!push_dir!\TWRP\BACKUPS\!DeviceID!\!timestamp!"\

if errorlevel 1 (
    echo Failed to pull backup
    pause
    goto cleanup
)

:: Clear backup from device
echo Clearing backup from device...
"%adb_path%" shell "rm -rf /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp!"

:: Collect device information
echo.
echo Please provide device information...
echo.

set /p "device=Please enter device model: "
set /p "soc=Please enter processor model: "
set /p "system=Please enter system version: "
set /p "arch=Please enter device architecture (arm/arm64): "
set /p "sar_device=Is this a SAR device? (true/false): "
set /p "ab_device=Is this an A/B partition device? (true/false): "
set /p "treble=Please enter Treble support information: "
set /p "fix=Please enter fix content: "
set /p "ext=Please enter extension content: "
set /p "maker=Please enter creator name: "

:: Generate set.bat file
(
echo ::in_flash_files_set_ini
echo set "backup_name=!backup_name!"
echo set "fdl1_path=!fdl1_path!"
echo set "fdl2_path=!fdl2_path!"
echo set "device=!device!"
echo set "soc=!soc!"
echo set "system=!system!"
echo set "arch=!arch!"
echo set "sar_device=!sar_device!"
echo set "ab_device=!ab_device!"
echo set "treble=!treble!"
echo set "fix=!fix!"
echo set "ext=!ext!"
echo set "maker=!maker!"
) > "!flash_files_dir!\set.bat"

:: Package integration package
echo Packaging integration package...
cd /d "!work_dir!"
"%seven_zip_dir%\7zr" a -mx9 -t7z "..\!package_name!.7z" "flash_files" >nul

if errorlevel 1 (
    echo Packaging failed
    pause
    goto cleanup
)

:: Clean up working directory
:cleanup
cd /d "%cd%"
rmdir /s /q "!work_dir!"

echo.
echo ===============================================================================
echo Integration package creation completed!
echo Package saved as: %cd%\!package_name!.7z
echo ===============================================================================
echo.
pause
