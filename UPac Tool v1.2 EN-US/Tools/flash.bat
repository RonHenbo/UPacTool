@ECHO OFF
:: Set tool paths
set "bin_path=%cd%\bin"
set "spd_dump_path=%cd%\bin\spd_dump"  :: SPD flashing tool path
set "adb_path=%cd%\bin\adb_fastboot\adb.exe"  :: ADB tool path
set "seven_zip_dir=%cd%\bin\7z"  :: 7-Zip extraction tool path
set "dump_files=%cd%\flash_files\dump"  :: Dump files directory
set "push_path=%cd%\flash_files\push"  :: Push files directory
set "flash_path=%cd%\flash_files"  :: Root directory for flashing files

:load_set
:: Load configuration file
if exist "%flash_path%\set.bat" (
    call "%flash_path%\set.bat"  :: Call configuration file
    goto after_load
) else (
    echo Error: Configuration file set.bat not found
    goto load_package
)

:load_package
:: Load flashing package
echo Please drag and drop the 7z package file:
set /p package_path=Drop file and press Enter:  :: Get user input for package path
if not exist "%package_path%" (
    echo File does not exist, please try again
    goto load_package
)
echo Loading package...
if exist flash_files rmdir /s /q flash_files  :: Clean old files
"%seven_zip_dir%\7zr" x "%package_path%" -o"%cd%"  :: Extract package
if errorlevel 1 (
    echo Extraction failed, please check the file
    pause
    goto load_package
)
goto load_set

:after_load
:: Check and set dump_mode default value
if not defined dump_mode set dump_mode=kick_fxxk_avb

:: Set TWRP backup path
set "backup_path=%push_path%\TWRP\BACKUPS\%backup_name%"

:start
title Unisoc Package Downloader - %device%  :: Set window title
ECHO.Package information loaded.
ECHO.===============================================================================
ECHO.                               Package Information
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
ECHO.by 独の光

:: Add user selection function
:package_selection
ECHO.
ECHO.Please select an operation:
ECHO.  1 - Continue with current package
ECHO.  2 - Load another package
set /p choice=Please enter your choice (1/2):

if /I "%choice%"=="2" goto load_package
if /I "%choice%"=="1" goto select_mode
ECHO.Invalid input, please try again
goto package_selection

:select_mode
:: Select operation mode
ECHO.Please select operation mode:
ECHO.1. Start from step 1 (complete process)
ECHO.2. Continue from any step
set /p mode=Please select:
if %mode%==1 goto ask_unattended
if %mode%==2 goto ask_unattended_step
ECHO.Invalid input
pause
goto select_mode

:ask_unattended
:: Ask for unattended mode
set /p unattended=Enable unattended mode? (1/2):
if /I "%unattended%"=="1" set UNATTENDED=1
goto unlock

:ask_unattended_step
set /p unattended=Enable unattended mode? (1/2):
if /I "%unattended%"=="2" set UNATTENDED=1
goto choose_step

:choose_step
:: Select which step to continue from
ECHO.Please select step to continue from:
ECHO.2. Format data as f2fs and push TWRP folder
ECHO.3. Restore system from TWRP backup
set /p step=Please select:
if %step%==2 goto format_data
if %step%==3 goto restore_system
ECHO.Invalid input
if defined UNATTENDED goto choose_step
pause
goto choose_step

:retry_unlock
ECHO.Retrying unlock...
:unlock
:: Step 1: Unlock Bootloader
ECHO.=== Step 1/3: Unlock Bootloader and flash images ===
if not defined UNATTENDED (
    ECHO.Please power off the device and connect directly to computer...
    pause
)
ECHO.If stuck at waiting dl_diag, try reconnecting device or check drivers (15 minutes remaining)
cd "%dump_files%"

:: Use only kick_fxxk_avb mode for unlock
ECHO.Using kick_fxxk_avb mode to unlock...
"%spd_dump_path%"\spd_dump --wait 1000 --kickto 2 e splloader e splloader_bak reset
"%spd_dump_path%"\spd_dump --wait 1000 timeout 10000 fdl fdl1.bin %fdl1_path% fdl fdl2.bin %fdl2_path% exec w splloader splloader.bin w uboot uboot.bin w trustos trustos.bin w recovery "%backup_path%"\recovery.emmc.win reboot-recovery

ECHO.Operation completed! Bootloader unlocked and images flashed.
ECHO.Device will boot directly into TWRP recovery mode...

:unlock_confirm
if defined UNATTENDED goto format_data
set /p confirm=Successfully unlocked Bootloader and entered Recovery? [Y/N]:
if /I "%confirm%"=="Y" goto format_data
if /I "%confirm%"=="N" goto retry_unlock
ECHO.Invalid input, please enter Y or N
goto unlock_confirm

:format_data
:: Step 2: Format data partition
ECHO.=== Step 2/3: Format data partition ===
ECHO.Waiting for device to enter Recovery...
if not defined UNATTENDED (
    pause
)

ECHO.Unmounting data partition...
:unmount_retry
"%adb_path%" shell twrp unmount data
if errorlevel 1 (
    echo Device not connected or unmount failed, retrying...
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

ECHO.Formatting completed, rebooting device...
"%adb_path%" reboot recovery
ECHO.Waiting for device to enter Recovery...
if not defined UNATTENDED pause

ECHO.Pushing TWRP folder...
:push_retry
"%adb_path%" push "%push_path%\." /sdcard/
"%adb_path%" push "%bin_path%\.twrps" /sdcard/TWRP/
if errorlevel 1 (
    echo Device not connected or failed to push TWRP folder, retrying...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto push_retry
)

goto restore_system

:restore_system
:: Step 3: Restore system from TWRP backup
ECHO.=== Step 3/3: Restore system from TWRP backup ===
"%adb_path%" shell reboot recovery
ECHO.Waiting for device to enter Recovery...
if not defined UNATTENDED (
    pause
)

ECHO.Restoring system from TWRP backup...
:restore_retry
"%adb_path%" shell twrp restore /sdcard/TWRP/BACKUPS/%backup_name% SDRB
if errorlevel 1 (
    echo System restore failed or device not connected, retrying...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto restore_retry
)

ECHO.Deleting TWRP backup folder to free up space...
:delete_backup_retry
"%adb_path%" shell rm -rf /sdcard/TWRP/BACKUPS/%backup_name%
if errorlevel 1 (
    echo Failed to delete backup, retrying...
    timeout /t 2 /nobreak >nul
    goto delete_backup_retry
)

ECHO.Operation successful! Rebooting device...
"%adb_path%" reboot
ECHO.=== Congratulations! All steps completed! ===
ECHO.Device will now boot into %system% system...
pause
goto start
