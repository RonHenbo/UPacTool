@ECHO OFF
setlocal enabledelayedexpansion

set "bin_path=%cd%\bin"
set "spd_dump_path=%cd%\bin\spd_dump"
set "adb_path=%cd%\bin\adb\"
set "seven_zip_dir=%cd%\bin\7z"
set "dump_files=%cd%\flash_files\dump"
set "push_path=%cd%\flash_files\push"
set "flash_path=%cd%\flash_files"
set "tools_path=%cd%"
"%adb_path%"\adb kill-server >nul 2>&1

:load_set
:: Load configuration file
if exist "%flash_path%\set.bat" (
    call "%flash_path%\set.bat"
    goto start
) else (
    echo Error: Configuration file set.bat not found
    goto load_package
)

:load_package
echo Please drag and drop the integration package 7z file or flash_files folder:
set /p package_path=Drag and drop the file or folder, then press Enter:
set "package_path=%package_path:"=%"  :: Remove possible quotes

if exist "%package_path%\" (
    :: Input is a folder
    echo Detected folder input...
    if not exist "%package_path%\set.bat" (
        echo Error: set.bat configuration file not found in the folder
        pause
        goto load_package
    )
    echo Copying integration package folder...
    if exist flash_files rmdir /s /q flash_files
    xcopy "%package_path%" "%tools_path%/flash_files" /E /I /H /Y
    if errorlevel 1 (
        echo Copy failed, please check permissions
        pause
        goto load_package
    )
    echo Folder copied successfully!
    goto load_set
) else if exist "%package_path%" (
    echo Detected file input...
    if /i not "%package_path:~-3%"==".7z" (
        echo Error: Only .7z format compressed files are supported
        pause
        goto load_package
    )
    echo Loading integration package...
    if exist flash_files rmdir /s /q flash_files
    "%seven_zip_dir%\7za" x -mmt "%package_path%" -o"%cd%"
    if errorlevel 1 (
        echo Extraction failed, please check the file
        pause
        goto load_package
    )
    goto load_set
) else (
    echo File or folder does not exist, please re-enter
    goto load_package
)

:start
set "backup_path=%push_path%\TWRP\BACKUPS\%backup_name%"
cls
title Spreadtrum Integration Package Downloader - %device%  :: Set window title
ECHO.Integration package information loaded.
ECHO.===============================================================================
ECHO.                               Integration Package Information
ECHO.===============================================================================
ECHO. Applicable Model: %device%
ECHO. Processor: %soc%
ECHO. System to Flash: %system%
ECHO. Architecture: %arch%
ECHO. SAR Device: %sar_device%
ECHO. A/B Partition: %ab_device%
ECHO. Treble Support: %treble%
ECHO. BROM Mode: %dump_mode%
ECHO. Fix: %fix%
ECHO. Extension: %ext%
ECHO. Made by: %maker%
ECHO.===============================================================================
ECHO.by 独の光

:: Add user selection function
:package_selection
ECHO.
ECHO.Please select an operation:
ECHO.  1 - Continue with the current integration package
ECHO.  2 - Load another integration package
set /p choice=Please enter your choice (1/2):

if /I "%choice%"=="2" goto load_package
if /I "%choice%"=="1" goto select_mode
ECHO.Invalid input, please re-enter
goto package_selection

:select_mode
:: Select operation mode
ECHO.Please select the operation mode:
ECHO.1. Start from the first step (complete process)
ECHO.2. Continue from any step
set /p mode=Please select:
if %mode%==1 goto ask_unattended
if %mode%==2 goto ask_unattended_step
ECHO.Input error
pause
goto select_mode

:ask_unattended
:: Ask if unattended mode is desired
set /p unattended=Enter unattended mode? (1/2):
if /I "%unattended%"=="1" set UNATTENDED=1
goto unlock

:ask_unattended_step
set /p unattended=Enter unattended mode? (1/2):
if /I "%unattended%"=="2" set UNATTENDED=1
goto choose_step

:choose_step
:: Choose which step to continue from
ECHO.Please select the step to continue from:
ECHO.2. Format data as f2fs and push TWRP folder
ECHO.3. Flash vendor partition
ECHO.4. Restore system from TWRP backup
set /p step=Please select:
if %step%==2 goto format_data
if %step%==3 goto flash_vendor
if %step%==4 goto restore_system
ECHO.Input error
if defined UNATTENDED goto choose_step
pause
goto choose_step

:retry_unlock
ECHO.Retrying unlock...
:unlock
:: Step 1: Unlock Bootloader
ECHO.=== Step 1/4: Unlock Bootloader and Flash Images ===
if not defined UNATTENDED (
    ECHO.Please power off the device, then connect directly to the computer...
    pause
)
ECHO.If stuck at 'waiting dl_diag', try reconnecting the device or checking drivers (15 minutes remaining)
cd "%dump_files%"

ECHO.Using kick_fxxk_avb mode to unlock...
"%spd_dump_path%"\spd_dump --wait 1000 --kickto 2 e splloader e splloader_bak reset
"%spd_dump_path%"\spd_dump --wait 1000 timeout 10000 fdl fdl1.bin %fdl1_path% fdl fdl2.bin %fdl2_path% exec  blk_size 65535 w splloader splloader.bin w uboot uboot.bin w trustos trustos.bin w recovery "%backup_path%"\recovery.emmc.win reboot-recovery

ECHO.Operation complete! Bootloader unlocked and images flashed.
ECHO.The device will boot directly into TWRP recovery mode...

:unlock_confirm
if defined UNATTENDED goto format_data
set /p confirm=Successfully unlocked Bootloader and entered Recovery? [Y/N]:
if /I "%confirm%"=="Y" goto format_data
if /I "%confirm%"=="N" goto retry_unlock
ECHO.Input error, please enter Y or N
goto unlock_confirm

:format_data
:: Step 2: Format data partition
ECHO.=== Step 2/4: Format data partition ===
ECHO.Waiting for device to enter Recovery...

:wait_for_recovery_retry
"%adb_path%"\adb wait-for-recovery >nul 2>&1
if errorlevel 1 (
    echo Waiting for Recovery failed, closing ADB service and retrying...
    "%adb_path%"\adb kill-server >nul 2>&1
    timeout /t 5 /nobreak >nul
    goto wait_for_recovery_retry
)

:unmount_retry
"%adb_path%"\adb shell twrp unmount data
if errorlevel 1 (
    echo Mount failed, retrying...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto unmount_retry
)
:find_userdata
ECHO.Searching for userdata path...
cd "%adb_path%"
set userdata_path=
for /f "delims=" %%i in ('adb shell "find /dev/block -name userdata 2>/dev/null"') do (
    set userdata_path=%%i
    goto :userdata_found_format
)
cd "%tools_path%"
:userdata_found_format
if "%userdata_path%"=="" (
    echo Error: userdata not found
    pause
    goto find_userdata
)

ECHO.Formatting data with F2FS...
"%adb_path%"\adb shell mkfs.f2fs %userdata_path%
if errorlevel 1 (
    echo Format failed, retrying...
    if not defined UNATTENDED pause
    goto unmount_retry
)

ECHO.TWRP formatting...
:twrp_format_retry
"%adb_path%"\adb shell twrp format data
if errorlevel 1 (
    echo TWRP format failed, device may enter a boot loop...
    echo Attempting to fix...
    
    :: Use kick command to try connecting to the device
    "%spd_dump_path%"\spd_dump --wait 1000 --kickto 2
    
    :: Erase misc partition and reboot to Recovery
    "%spd_dump_path%"\spd_dump --wait 1000 e misc reboot-recovery
    
    echo Fix complete, waiting for device to re-enter Recovery...
    timeout /t 10 /nobreak >nul
    goto unmount_retry
)

ECHO.Format complete, rebooting device...
"%adb_path%"\adb reboot recovery
ECHO.Waiting for device to enter Recovery...
"%adb_path%"\adb wait-for-recovery >nul 2>&1

ECHO.Pushing TWRP folder, TWRP configuration file, and vendor.bin...
:push_retry
"%adb_path%"\adb push "%push_path%\." /sdcard/
"%adb_path%"\adb push "%bin_path%\.twrps" /sdcard/TWRP/
if errorlevel 1 (
    echo Device not connected, or file push failed, retrying...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto push_retry
)
ECHO.Format complete, rebooting device...
"%adb_path%"\adb reboot recovery

goto flash_vendor

:flash_vendor
cd %adb_path%
ECHO.=== Step 3/4: Flash vendor partition ===
ECHO.Waiting for device to enter Recovery...
"%adb_path%"\adb wait-for-recovery >nul 2>&1
ECHO.Searching for vendor path...
set vendor_path=
for /f "delims=" %%i in ('adb shell "find /dev/block -name by-name -type d 2>/dev/null"') do (
    set vendor_path=%%i
    goto :vendor_found_flash
)
cd "%tools_path%"
:vendor_found_flash
if "%vendor_path%"=="" (
    echo Error: vendor not found
    pause
    goto flash_vendor
)

ECHO.Flashing vendor partition...
:flash_vendor_retry
"%adb_path%"\adb shell "dd if=/sdcard/vendor.bin of=%vendor_path%/vendor"
if errorlevel 1 (
    echo Flash vendor partition failed, retrying...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto flash_vendor_retry
)

ECHO.Vendor partition flashed successfully!
goto restore_system

:restore_system
:: Step 4: Restore system from TWRP backup
ECHO.=== Step 4/4: Restore system from TWRP backup ===
ECHO.Restoring system from TWRP backup...
:restore_retry
"%adb_path%"\adb shell twrp restore /sdcard/TWRP/BACKUPS/%backup_name% SDRB
if errorlevel 1 (
    echo System restore failed, or device not connected, retrying...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto restore_retry
)

ECHO.Deleting TWRP backup folder and vendor.bin to free up space...
:delete_backup_retry
"%adb_path%"\adb shell rm -rf /sdcard/TWRP/BACKUPS/%backup_name%
if errorlevel 1 (
    echo Delete backup failed, retrying...
    timeout /t 2 /nobreak >nul
    goto delete_backup_retry
)

:delete_vendor_retry
"%adb_path%"\adb shell rm -f /sdcard/vendor.bin
if errorlevel 1 (
    echo Delete vendor.bin failed, retrying...
    timeout /t 2 /nobreak >nul
    goto delete_vendor_retry
)

ECHO.Operation successful! Rebooting device...
"%adb_path%"\adb reboot
ECHO.=== Congratulations! All steps completed! ===
ECHO.The device will now boot into the %system% system...
pause
goto start