@echo off
setlocal enabledelayedexpansion

title Unisoc Integration Package Maker

set "tool_dir=%cd%"

set "spd_dump_path=%cd%\bin\spd_dump"
set "adb_path=%cd%\bin\adb_fastboot\adb"
set "seven_zip_dir=%cd%\bin\7z"

:start
cls
echo ===============================================================================
echo.                         Unisoc Integration Package Maker By Duguang
echo ===============================================================================
echo.

set /p "package_name=Please enter the integration package name: "
if "!package_name!"=="" (
    echo Integration package name cannot be empty!
    timeout /t 2 /nobreak >nul
    goto start
)

set "work_dir=%cd%\!package_name!"
set "flash_files_dir=!work_dir!\flash_files"
set "dump_dir=!flash_files_dir!\dump"
set "push_dir=!flash_files_dir!\push"

echo Stopping adb server...
"%adb_path%" kill-server
if exist "!work_dir!" (
    rmdir /s /q "!work_dir!" >nul 2>&1
)

mkdir "!work_dir!" >nul 2>&1
mkdir "!flash_files_dir!" >nul 2>&1
mkdir "!dump_dir!" >nul 2>&1
mkdir "!push_dir!" >nul 2>&1

echo.
echo Please confirm the device meets the following conditions:
echo 1. Bootloader is unlocked
echo 2. AVB verification is disabled
echo 3. TWRP recovery is flashed
echo.
set /p "confirmed=Does the device meet the above conditions? (Y/N): "

if /i not "!confirmed!"=="Y" (
    echo Please complete device preparation first
    rmdir /s /q "!work_dir!"
    pause
    goto start
)

echo.
echo Please provide FDL file information...
echo.

:get_fdl1
set /p "fdl1_file=Please drag and drop the first FDL file: "
set "fdl1_file=!fdl1_file:"=!"
if not exist "!fdl1_file!" (
    echo File does not exist, please re-enter
    goto get_fdl1
)

set /p "fdl1_path=Please enter the path address for the first FDL file: "
if "!fdl1_path!"=="" (
    echo Path address cannot be empty
    goto get_fdl1
)

copy /y "!fdl1_file!" "!dump_dir!\fdl1.bin" >nul

:get_fdl2
set /p "fdl2_file=Please drag and drop the second FDL file: "
set "fdl2_file=!fdl2_file:"=!"
if not exist "!fdl2_file!" (
    echo File does not exist, please re-enter
    goto get_fdl2
)

set /p "fdl2_path=Please enter the path address for the second FDL file: "
if "!fdl2_path!"=="" (
    echo Path address cannot be empty
    goto get_fdl2
)

copy /y "!fdl2_file!" "!dump_dir!\fdl2.bin" >nul

echo.
echo Preparing to read underlying partitions, please power off the device, then connect directly to the computer...
cd /d "!dump_dir!"
"%spd_dump_path%\spd_dump" --wait 1000 --kickto 2 r splloader r trustos r uboot reboot-recovery

if errorlevel 1 (
    echo Failed to read partitions, please check device connection and drivers
    pause
    goto cleanup
)

echo Partitions read successfully!
timeout /t 3 /nobreak >nul

echo Waiting for device to enter TWRP recovery mode...
:wait_recovery
"%adb_path%" wait-for-recovery >nul 2>&1
if errorlevel 1 (
    echo Device did not enter recovery mode, please manually enter TWRP and press any key to continue...
    pause
    goto wait_recovery
)

echo Extracting vendor partition...
:dd_vendor
"%adb_path%" shell "dd if=/dev/block/by-name/vendor of=/sdcard/vendor.bin"
if errorlevel 1 (
    echo Failed to extract vendor partition, retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto dd_vendor
)

echo Creating TWRP backup...
set "timestamp=!date:~0,4!!date:~5,2!!date:~8,2!!time:~0,2!!time:~3,2!!time:~6,2!"
set "timestamp=!timestamp: =0!"

:retry_backup
"%adb_path%" shell "twrp backup SDRB !timestamp!"
if errorlevel 1 (
    echo Backup creation failed, retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto retry_backup
)

echo Getting device ID...
:retry_get_id
for /f "delims=" %%a in ('"%adb_path%" get-serialno 2^>nul') do set "DeviceID=%%a"

if "!DeviceID!"=="" (
    echo Unable to get device ID, retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto retry_get_id
)

set "backup_name=!DeviceID!/!timestamp!"

echo Pulling backup files and vendor...
mkdir "!push_dir!\TWRP" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS\!DeviceID!" >nul 2>&1

:retry_pull
 "%adb_path%" pull /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp! "!push_dir!\TWRP\BACKUPS\!DeviceID!\!timestamp!" && (
     "%adb_path%" pull /sdcard/vendor.bin "!push_dir!"
 )
if errorlevel 1 (
    echo Failed to pull backup or vendor partition, retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto retry_pull
)

echo Cleaning up backup files and vendor partition on device...
:retry_clean_device
"%adb_path%" shell "rm -rf /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp! /sdcard/vendor.bin"
if errorlevel 1 (
    echo Failed to clean device backup and vendor partition, retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto retry_clean_device
)

"%adb_path%" shell reboot
echo File acquisition completed, device has rebooted, you can disconnect now.
:: Collect device information
echo.
echo Please provide device information...
echo.

set /p "device=Please enter device model: "
set /p "soc=Please enter processor model: "
set /p "system=Please enter system version: "
set /p "arch=Please enter device architecture (arm/arm64): "
set /p "sar_device=Is it a SAR device? (true/false): "
set /p "ab_device=Is it an A/B partition device? (true/false): "
set /p "treble=Please enter Treble support information: "
set /p "fix=Please enter fix content: "
set /p "ext=Please enter extension content: "
set /p "maker=Please enter maker: "

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

:: Ask about compression
echo.
set /p "compress=Compress the integration package? (Y/N): "
if /i "!compress!"=="Y" (
    echo Packaging integration package...
    cd /d "!work_dir!"
    "%seven_zip_dir%\7zr" a -mx9 -t7z "..\!package_name!.7z" "flash_files" >nul
    
    if errorlevel 1 (
        echo Packaging failed
        set /p "cleanup_failed=Clean up integration package files? (Y/N): "
        if /i "!cleanup_failed!"=="Y" (
            goto cleanup
        ) else (
            echo Integration package retained at: !work_dir!
            goto final_message
        )
    )
    
    echo Packaging successful!
    set /p "delete_source=Delete source files? (Y/N): "
    if /i "!delete_source!"=="Y" (
        echo Deleting source files...
        rmdir /s /q "!work_dir!" >nul 2>&1
        set "final_message=Integration package saved as: %cd%\!package_name!.7z, source files deleted"
    ) else (
        set "final_message=Integration package saved as: %cd%\!package_name!.7z, source files retained at: !work_dir!"
    )
) else (
    echo Skipping compression step
    set "final_message=Integration package files saved at: !work_dir!"
)

:final_message
cd /d "%tool_dir%"
echo Stopping adb server...
"%adb_path%" kill-server

echo.
echo ===============================================================================
echo Integration package creation completed!
echo !final_message!
echo ===============================================================================
echo.
pause
exit /b 0

:cleanup
cd /d "%tool_dir%"
echo Stopping adb server...
"%adb_path%" kill-server
if exist "!work_dir!" (
    echo Cleaning temporary files...
    rmdir /s /q "!work_dir!" >nul 2>&1
)
goto final_message