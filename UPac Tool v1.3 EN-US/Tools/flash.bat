@ECHO OFF
setlocal enabledelayedexpansion

set "bin_path=%cd%\bin"
set "spd_dump_path=%cd%\bin\spd_dump"
set "adb_path=%cd%\bin\adb_fastboot\adb.exe"
set "seven_zip_dir=%cd%\bin\7z"
set "dump_files=%cd%\flash_files\dump"
set "push_path=%cd%\flash_files\push"
set "flash_path=%cd%\flash_files"
echo Stopping adb server...
"%adb_path%" kill-server

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
echo Please drag and drop the integration package .7z file or flash_files folder:
set /p package_path=Drag and drop the file or folder and press Enter:
set "package_path=%package_path:"=%"  :: Remove possible quotes

if exist "%package_path%\" (
    :: Input is a folder
    echo Folder input detected...
    if not exist "%package_path%\set.bat" (
        echo Error: set.bat configuration file not found in folder
        pause
        goto load_package
    )
    echo Copying integration package folder...
    if exist flash_files rmdir /s /q flash_files
    xcopy "%package_path%" "flash_files" /E /I /H /Y
    if errorlevel 1 (
        echo Copy failed, please check permissions
        pause
        goto load_package
    )
    echo Folder copied successfully!
    goto load_set
) else if exist "%package_path%" (
    echo File input detected...
    if /i not "%package_path:~-3%"==".7z" (
        Error: Only .7z format compressed packages are supported
        pause
        goto load_package
    )
    echo Loading integration package...
    if exist flash_files rmdir /s /q flash_files
    "%seven_zip_dir%\7zr" x "%package_path%" -o"%cd%"
    if errorlevel 1 (
        echo Extraction failed, please check file
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
title Unisoc Integration Package Downloader - %device%  :: Set window title
ECHO.Integration package information loaded.
ECHO.===============================================================================
ECHO.                               Integration Package Information
ECHO.===============================================================================
ECHO. Device Model: %device%
ECHO. Processor: %soc%
ECHO. System to Flash: %system%
ECHO. Architecture: %arch%
ECHO. SAR Device: %sar_device%
ECHO. A/B Partition: %ab_device%
ECHO. Treble Support: %treble%
ECHO. BROM Mode: %dump_mode%
ECHO. Fix: %fix%
ECHO. Extension: %ext%
ECHO. Maker: %maker%
ECHO.===============================================================================
ECHO.by  Duguang

:: Add user selection function
:package_selection
ECHO.
ECHO.Please select operation:
ECHO.  1 - Continue with current integration package
ECHO.  2 - Load another integration package
set /p choice=Please enter option (1/2):

if /I "%choice%"=="2" goto load_package
if /I "%choice%"=="1" goto select_mode
ECHO.Invalid input, please re-enter
goto package_selection

:select_mode
:: Select operation mode
ECHO.Please select operation mode:
ECHO.1. Start from step one (full process)
ECHO.2. Continue from any step
set /p mode=Please select:
if %mode%==1 goto ask_unattended
if %mode%==2 goto ask_unattended_step
ECHO.Input error
pause
goto select_mode

:ask_unattended
:: Ask if unattended mode
set /p unattended=Enter unattended mode? (1/2):
if /I "%unattended%"=="1" set UNATTENDED=1
goto unlock

:ask_unattended_step
set /p unattended=Enter unattended mode? (1/2):
if /I "%unattended%"=="2" set UNATTENDED=1
goto choose_step

:choose_step
:: Select which step to continue from
ECHO.Please select the step to continue from:
ECHO.2.Format data as f2fs and push TWRP folder
ECHO.3.Flash vendor partition
ECHO.4.Restore system from TWRP backup
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
ECHO.=== Step 1/4: Unlock Bootloader and flash images ===
if not defined UNATTENDED (
    ECHO.Please power off the device, then connect directly to the computer...
    pause
)
ECHO.If stuck at 'waiting dl_diag', try reconnecting device or check drivers (15 minutes remaining)
cd "%dump_files%"

ECHO.Using kick_fxxk_avb mode to unlock...
"%spd_dump_path%"\spd_dump --wait 1000 --kickto 2 e splloader e splloader_bak reset
"%spd_dump_path%"\spd_dump --wait 1000 timeout 10000 fdl fdl1.bin %fdl1_path% fdl fdl2.bin %fdl2_path% exec w splloader splloader.bin w uboot uboot.bin w trustos trustos.bin w recovery "%backup_path%"\recovery.emmc.win reboot-recovery

ECHO.Operation completed! Bootloader unlocked and images flashed.
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
if not defined UNATTENDED (
    pause
)

ECHO.Unmounting data partition...
:unmount_retry
"%adb_path%" shell twrp unmount data
if errorlevel 1 (
    echo Device not connected, or unmount failed, retrying...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto unmount_retry
)

ECHO.Formatting data partition as f2fs...
"%adb_path%" shell mkfs.f2fs /dev/block/by-name/userdata
if errorlevel 1 (
    echo Formatting failed, retrying...
    if not defined UNATTENDED pause
    goto unmount_retry
)

ECHO.TWRP formatting...
:twrp_format_retry
"%adb_path%" shell twrp format data
if errorlevel 1 (
    echo TWRP formatting failed, retrying...
    if not defined UNATTENDED pause
    goto twrp_format_retry
)

ECHO.Formatting completed, restarting device...
"%adb_path%" reboot recovery
ECHO.Waiting for device to enter Recovery...
if not defined UNATTENDED pause

ECHO.Pushing TWRP folder and vendor.bin...
:push_retry
"%adb_path%" push "%push_path%\." /sdcard/
if errorlevel 1 (
    echo Device not connected, or file push failed, retrying...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto push_retry
)

goto flash_vendor

:flash_vendor
:: Step 3: Flash vendor partition
ECHO.=== Step 3/4: Flash vendor partition ===
ECHO.Flashing vendor partition...
:flash_vendor_retry
"%adb_path%" shell dd if=/sdcard/vendor.bin of=/dev/block/by-name/vendor
if errorlevel 1 (
    echo Flashing vendor partition failed, retrying...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto flash_vendor_retry
)

ECHO.Vendor partition flashed successfully!
goto restore_system

:restore_system
:: Step 4: Restore system from TWRP backup
ECHO.=== Step 4/4: Restore system from TWRP backup ===
"%adb_path%" shell reboot recovery
ECHO.Waiting for device to enter Recovery...
if not defined UNATTENDED (
    pause
)

ECHO.Restoring system from TWRP backup...
:restore_retry
"%adb_path%" shell twrp restore /sdcard/TWRP/BACKUPS/%backup_name% SDRB
if errorlevel 1 (
    echo System restore failed, or device not connected, retrying...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto restore_retry
)

ECHO.Deleting TWRP backup folder and vendor.bin to free up space...
:delete_backup_retry
"%adb_path%" shell rm -rf /sdcard/TWRP/BACKUPS/%backup_name%
if errorlevel 1 (
    echo Failed to delete backup, retrying...
    timeout /t 2 /nobreak >nul
    goto delete_backup_retry
)

:delete_vendor_retry
"%adb_path%" shell rm -f /sdcard/vendor.bin
if errorlevel 1 (
    echo Failed to delete vendor.bin, retrying...
    timeout /t 2 /nobreak >nul
    goto delete_vendor_retry
)

ECHO.Operation successful! Restarting device...
"%adb_path%" reboot
ECHO.=== Congratulations! All steps completed! ===
ECHO.Device is about to boot into %system% system...
pause
goto start