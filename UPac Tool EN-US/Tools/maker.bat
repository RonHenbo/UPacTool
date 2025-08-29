@echo off
setlocal enabledelayedexpansion

title Unisoc Integration Package Maker Tool By Duguang

:: Initialize tool paths
set "tool_dir=%~dp0"
set "spd_dump_path=%tool_dir%\bin\spd_dump\spd_dump.exe"
set "adb_path=%tool_dir%\bin\adb"
set "seven_zip_dir=%tool_dir%\bin\7z\7za.exe"

:: Verify necessary tools exist
if not exist "%spd_dump_path%" (
    echo Error: spd_dump.exe not found
    pause
    exit /b 1
)

if not exist "%adb_path%\adb.exe" (
    echo Error: adb.exe not found
    pause
    exit /b 1
)

if not exist "%seven_zip_dir%" (
    echo Warning: 7za.exe not found, unable to compress integration package
)

:: Main menu
:start
cls
echo ===============================================================================
echo.                        Unisoc Integration Package Maker Tool By Duguang
echo ===============================================================================
echo.

set "package_name="
set /p "package_name=Please enter the integration package name: "
if "!package_name!"=="" (
    echo Integration package name cannot be empty!
    timeout /t 2 /nobreak >nul
    goto start
)

:: Create working directory
echo Stopping adb service...
"%adb_path%"\adb.exe kill-server >nul 2>&1
set "work_dir=%tool_dir%\!package_name!"
set "flash_files_dir=!work_dir!\flash_files"
set "dump_dir=!flash_files_dir!\dump"
set "push_dir=!flash_files_dir!\push"

:: Clean up old directory
if exist "!work_dir!" (
    echo Found directory with same name, cleaning up...
    rmdir /s /q "!work_dir!" >nul 2>&1
    if exist "!work_dir!" (
        echo Unable to delete directory: !work_dir!
        pause
        goto start
    )
)

:: Create new directories
mkdir "!work_dir!" >nul 2>&1
if errorlevel 1 (
    echo Unable to create directory: !work_dir!
    pause
    goto start
)

mkdir "!flash_files_dir!" >nul 2>&1
mkdir "!dump_dir!" >nul 2>&1
mkdir "!push_dir!" >nul 2>&1

:: Device preparation confirmation
echo.
echo Please confirm the device meets the following conditions:
echo 1. Bootloader is unlocked
echo 2. AVB verification is disabled
echo 3. TWRP recovery is flashed
echo.
set "confirmed="
set /p "confirmed=Does the device meet the above conditions? (Y/N): "

if /i not "!confirmed!"=="Y" (
    echo Please complete device preparation first
    rmdir /s /q "!work_dir!" >nul 2>&1
    pause
    goto start
)

:: Get FDL file information
echo.
echo Please provide FDL file information...
echo.

:get_fdl1
set "fdl1_file="
set /p "fdl1_file=Please drag and drop the first FDL file: "
set "fdl1_file=!fdl1_file:"=!"
if not exist "!fdl1_file!" (
    echo File does not exist, please re-enter
    goto get_fdl1
)

set "fdl1_hex="
set /p "fdl1_hex=Please enter the path address for the first FDL file: 0x"
if "!fdl1_hex!"=="" (
    echo Path address cannot be empty
    goto get_fdl1
)
set "fdl1_path=0x!fdl1_hex!"

copy /y "!fdl1_file!" "!dump_dir!\fdl1.bin" >nul
if errorlevel 1 (
    echo Failed to copy FDL1 file
    goto cleanup
)

:get_fdl2
set "fdl2_file="
set /p "fdl2_file=Please drag and drop the second FDL file: "
set "fdl2_file=!fdl2_file:"=!"
if not exist "!fdl2_file!" (
    echo File does not exist, please re-enter
    goto get_fdl2
)

set "fdl2_hex="
set /p "fdl2_hex=Please enter the path address for the second FDL file: 0x"
if "!fdl2_hex!"=="" (
    echo Path address cannot be empty
    goto get_fdl2
)
set "fdl2_path=0x!fdl2_hex!"

copy /y "!fdl2_file!" "!dump_dir!\fdl2.bin" >nul
if errorlevel 1 (
    echo Failed to copy FDL2 file
    goto cleanup
)

:: Read low-level partitions
echo.
echo Preparing to read low-level partitions, please power off the device, then connect directly to the computer...
cd /d "!dump_dir!"
"%spd_dump_path%" --wait 1000 --kickto 2 blk_size 65535 r splloader r trustos r uboot reboot-recovery

if errorlevel 1 (
    echo Failed to read partitions, please check device connection and drivers
    echo Press any key to exit...
    pause
    goto cleanup
)

echo Partitions read successfully!
timeout /t 3 /nobreak >nul

:: Wait for device to enter TWRP recovery mode
echo Waiting for device to enter TWRP recovery mode...
set "retry_count=0"
:wait_recovery
"%adb_path%"\adb.exe wait-for-recovery

:: Get vendor path
echo Getting vendor path...
cd "%adb_path%"
set "vendor_path="
for /f "tokens=*" %%a in ('adb shell "find /dev/block -name vendor 2>/dev/null | head -1"') do (
    set "vendor_path=%%a"
)

if "!vendor_path!"=="" (
    echo Unable to find vendor partition
    goto cleanup
)

:: Extract vendor partition
echo Extracting vendor partition...
set "retry_count=0"
:dd_vendor
"%adb_path%"\adb.exe shell "dd if=!vendor_path! of=/sdcard/vendor.bin"
if errorlevel 1 (
    echo Failed to extract vendor partition, retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto dd_vendor
)

:: Create TWRP backup
echo Creating TWRP backup...
set "timestamp=!date:~0,4!!date:~5,2!!date:~8,2!!time:~0,2!!time:~3,2!!time:~6,2!"
set "timestamp=!timestamp: =0!"

set "retry_count=0"
:retry_backup
"%adb_path%"\adb.exe shell "twrp backup SDRB !timestamp!"
if errorlevel 1 (
    echo Backup creation failed, retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto retry_backup
)

:: Get device ID
echo Getting device ID...
set "DeviceID="
set "retry_count=0"
:retry_get_id
for /f "delims=" %%a in ('adb shell "ls /sdcard/TWRP/BACKUPS/" 2^>nul') do (
    set "DeviceID=%%a"
)
if "!DeviceID!"=="" (
    set /a "retry_count+=1"
    if !retry_count! geq 5 (
        echo Unable to get device ID, please check if TWRP backup was created successfully
        goto cleanup
    )
    echo Unable to get device ID, retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto retry_get_id
)

set "backup_name=!DeviceID!/!timestamp!"

:: Pull backup files and vendor
echo Pulling backup files and vendor...
cd "%tool_dir%"
mkdir "!push_dir!\TWRP" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS\!DeviceID!" >nul 2>&1

set "retry_count=0"
:retry_pull
"%adb_path%"\adb.exe pull /sdcard/TWRP/BACKUPS/!backup_name! "!push_dir!\TWRP\BACKUPS\!DeviceID!\!timestamp!"
if errorlevel 1 (
    echo Failed to pull backup, retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto retry_pull
)

set "retry_count=0"
:retry_pull_vendor
"%adb_path%"\adb.exe pull /sdcard/vendor.bin "!push_dir!"
if errorlevel 1 (
    echo Failed to pull vendor partition, retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto retry_pull_vendor
)

:: Clean up files on device
echo Cleaning up backup files and vendor partition on device...
set "retry_count=0"
:retry_clean_device
"%adb_path%"\adb.exe shell "rm -rf /sdcard/TWRP/BACKUPS/!backup_name! /sdcard/vendor.bin"
if errorlevel 1 (
    echo Failed to clean device files, retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto retry_clean_device
)

:skip_clean
"%adb_path%"\adb.exe shell reboot
echo File retrieval complete, device has rebooted, you can disconnect now.

:: Collect device information
echo.
echo Please provide device information...
echo.

set "device="
set /p "device=Please enter device model: "

set "soc="
set /p "soc=Please enter processor model: "

set "system="
set /p "system=Please enter system version: "

set "arch="
set /p "arch=Please enter device architecture (arm/arm64): "

set "sar_device="
set /p "sar_device=Is this a SAR device? (true/false): "

set "ab_device="
set /p "ab_device=Is this an A/B partition device? (true/false): "

set "treble="
set /p "treble=Please enter Treble support information: "

set "fix="
set /p "fix=Please enter fix content: "

set "ext="
set /p "ext=Please enter extended content: "

set "maker="
set /p "maker=Please enter maker name: "

:: Create configuration file
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

echo.
set "compress="
set /p "compress=Compress the integration package? (Y/N): "

if /i "!compress!"=="Y" (
    if not exist "%seven_zip_dir%" (
        echo 7za.exe does not exist, unable to compress integration package
        goto skip_compress
    )
    
    echo Packaging integration package...
    cd /d "!work_dir!"
    "%seven_zip_dir%" a -mmt -mx9 -t7z "..\!package_name!.7z" "flash_files"
    if errorlevel 1 (
        echo Packaging failed
        set "cleanup_failed="
        set /p "cleanup_failed=Clean up integration package files? (Y/N): "
        if /i "!cleanup_failed!"=="Y" (
            goto cleanup
        ) else (
            echo Integration package retained at: !work_dir!
            goto final_message
        )
    )
    
    echo Packaging successful!
    for %%A in ("..\!package_name!.7z") do set "archive_size_mb=%%~zA"
    set /a "archive_size_mb=!archive_size_mb!/1048576"
    
    set "delete_source="
    set /p "delete_source=Delete source files? (Y/N): "
    if /i "!delete_source!"=="Y" (
        echo Deleting source files...
        rmdir /s /q "!work_dir!" >nul 2>&1
        set "final_message=Integration package saved as: %tool_dir%!package_name!.7z (!archive_size_mb! MB), source files deleted"
    ) else (
        set "final_message=Integration package saved as: %tool_dir%!package_name!.7z (!archive_size_mb! MB), source files retained at: !work_dir!"
    )
) else (
    :skip_compress
    echo Skipping compression step
    set "final_message=Integration package files saved at: !work_dir!"
)

:cleanup
echo Stopping adb service...
"%adb_path%"\adb.exe kill-server >nul 2>&1
echo Cleaning up temporary files...
rmdir /s /q "!work_dir!" >nul 2>&1
echo Temporary files cleaned up

:final_message
echo.
echo ===============================================================================
echo Integration package creation complete!
echo !final_message!
echo ===============================================================================
echo.
pause