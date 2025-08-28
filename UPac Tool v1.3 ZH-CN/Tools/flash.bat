@ECHO OFF
setlocal enabledelayedexpansion

set "bin_path=%cd%\bin"
set "spd_dump_path=%cd%\bin\spd_dump" 
set "adb_path=%cd%\bin\adb_fastboot\adb.exe" 
set "seven_zip_dir=%cd%\bin\7z" 
set "dump_files=%cd%\flash_files\dump" 
set "push_path=%cd%\flash_files\push"  
set "flash_path=%cd%\flash_files" 
echo �ر�adb����...
"%adb_path%" kill-server

:load_set
:: ���������ļ�
if exist "%flash_path%\set.bat" (
    call "%flash_path%\set.bat"  
    goto start
) else (
    echo ����δ�ҵ������ļ� set.bat
    goto load_package
)

:load_package
echo ���������ϰ�7z�ļ���flash_files�ļ��У�
set /p package_path=�����ļ����ļ��к󰴻س�: 
set "package_path=%package_path:"=%"  :: �Ƴ����ܵ�����

if exist "%package_path%\" (
    :: ��������ļ���
    echo ��⵽�ļ�������...
    if not exist "%package_path%\set.bat" (
        echo �����ļ�����δ�ҵ� set.bat �����ļ�
        pause
        goto load_package
    )
    echo ���ڸ������ϰ��ļ���...
    if exist flash_files rmdir /s /q flash_files
    xcopy "%package_path%" "flash_files" /E /I /H /Y
    if errorlevel 1 (
        echo ����ʧ�ܣ�����Ȩ��
        pause
        goto load_package
    )
    echo �ļ��и��Ƴɹ���
    goto load_set
) else if exist "%package_path%" (
    echo ��⵽�ļ�����...
    if /i not "%package_path:~-3%"==".7z" (
        echo ����ֻ֧��.7z��ʽ��ѹ����
        pause
        goto load_package
    )
    echo ���ڼ������ϰ�...
    if exist flash_files rmdir /s /q flash_files
    "%seven_zip_dir%\7zr" x "%package_path%" -o"%cd%"
    if errorlevel 1 (
        echo ��ѹʧ�ܣ������ļ�
        pause
        goto load_package
    )
    goto load_set
) else (
    echo �ļ����ļ��в����ڣ�����������
    goto load_package
)

:start
set "backup_path=%push_path%\TWRP\BACKUPS\%backup_name%"
title չ�����ϰ�Downloader - %device%  :: ���ô��ڱ���
ECHO.���ϰ���Ϣ�Ѽ��ء�
ECHO.===============================================================================
ECHO.                               ���ϰ���Ϣ
ECHO.===============================================================================
ECHO. �����ͺ�: %device%
ECHO. ������: %soc% 
ECHO. ˢ���ϵͳ: %system%  
ECHO. �ܹ�: %arch%  
ECHO. SAR�豸: %sar_device%  
ECHO. A/B����: %ab_device% 
ECHO. Treble֧��: %treble%  
ECHO. BROMģʽ: %dump_mode%  
ECHO. �޸���%fix%  
ECHO. ��չ��%ext%  
ECHO. ����: %maker%  
ECHO.===============================================================================
ECHO.by  ���ι�

:: ����û�ѡ����
:package_selection
ECHO.
ECHO.��ѡ�����:
ECHO.  1 - ʹ�õ�ǰ���ϰ�����
ECHO.  2 - ������һ�����ϰ�
set /p choice=������ѡ�� (1/2):

if /I "%choice%"=="2" goto load_package
if /I "%choice%"=="1" goto select_mode
ECHO.������Ч������������
goto package_selection

:select_mode
:: ѡ�����ģʽ
ECHO.��ѡ�����ģʽ:
ECHO.1. �ӵ�һ����ʼ���������̣�
ECHO.2. ������һ������
set /p mode=��ѡ��:
if %mode%==1 goto ask_unattended
if %mode%==2 goto ask_unattended_step
ECHO.�������
pause
goto select_mode

:ask_unattended
:: ѯ���Ƿ�����ֵ��ģʽ
set /p unattended=�Ƿ��������ֵ��ģʽ��(1/2):
if /I "%unattended%"=="1" set UNATTENDED=1
goto unlock

:ask_unattended_step
set /p unattended=�Ƿ��������ֵ��ģʽ��(1/2):
if /I "%unattended%"=="2" set UNATTENDED=1
goto choose_step

:choose_step
:: ѡ�����һ������
ECHO.��ѡ������Ĳ���:
ECHO.2.��ʽ��dataΪf2fs������TWRP�ļ���
ECHO.3.ˢ��vendor����
ECHO.4.��TWRP���ݻ�ԭϵͳ
set /p step=��ѡ��:
if %step%==2 goto format_data
if %step%==3 goto flash_vendor
if %step%==4 goto restore_system
ECHO.�������
if defined UNATTENDED goto choose_step
pause
goto choose_step

:retry_unlock
ECHO.���Խ���...
:unlock
:: ����1������Bootloader
ECHO.=== ����1/4������Bootloader��ˢ�뾵�� ===
if not defined UNATTENDED (
    ECHO.�뽫�豸�ػ���Ȼ��ֱ�����ӵ���...
    pause
)
ECHO.���ڵȴ�dl_diag�볢�������豸����������ʣ��15���ӣ�
cd "%dump_files%"

ECHO.ʹ��kick_fxxk_avbģʽ����...
"%spd_dump_path%"\spd_dump --wait 1000 --kickto 2 e splloader e splloader_bak reset
"%spd_dump_path%"\spd_dump --wait 1000 timeout 10000 fdl fdl1.bin %fdl1_path% fdl fdl2.bin %fdl2_path% exec w splloader splloader.bin w uboot uboot.bin w trustos trustos.bin w recovery "%backup_path%"\recovery.emmc.win reboot-recovery

ECHO.������ɣ��ѽ���Bootloader��ˢ�뾵��
ECHO.������ֱ�ӽ���TWRP�ָ�ģʽ...

:unlock_confirm
if defined UNATTENDED goto format_data
set /p confirm=�Ƿ�ɹ�����Bootloader������Recovery��[Y/N]��
if /I "%confirm%"=="Y" goto format_data
if /I "%confirm%"=="N" goto retry_unlock
ECHO.�������������Y��N
goto unlock_confirm

:format_data
:: ����2����ʽ�����ݷ���
ECHO.=== ����2/4����ʽ��data���� ===
ECHO.�ȴ��豸����Recovery...
if not defined UNATTENDED (
    pause
)

ECHO.���data��������...
:unmount_retry
"%adb_path%" shell twrp unmount data
if errorlevel 1 (
    echo �豸δ���ӣ���������ʧ�ܣ�����...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto unmount_retry
)

ECHO.��ʽ��data����Ϊf2fs...
"%adb_path%" shell mkfs.f2fs /dev/block/by-name/userdata
if errorlevel 1 (
    echo ��ʽ��ʧ�ܣ�����...
    if not defined UNATTENDED pause
    goto unmount_retry
)

ECHO.TWRP��ʽ��...
:twrp_format_retry
"%adb_path%" shell twrp format data
if errorlevel 1 (
    echo TWRP��ʽ��ʧ�ܣ�����...
    if not defined UNATTENDED pause
    goto twrp_format_retry
)

ECHO.��ʽ����ɣ����������豸...
"%adb_path%" reboot recovery
ECHO.�ȴ��豸����Recovery...
if not defined UNATTENDED pause

ECHO.����TWRP�ļ��к�vendor.bin...
:push_retry
"%adb_path%" push "%push_path%\." /sdcard/
if errorlevel 1 (
    echo �豸δ���ӣ��������ļ�ʧ�ܣ�����...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto push_retry
)

goto flash_vendor

:flash_vendor
:: ����3��ˢ��vendor����
ECHO.=== ����3/4��ˢ��vendor���� ===
ECHO.����ˢ��vendor����...
:flash_vendor_retry
"%adb_path%" shell dd if=/sdcard/vendor.bin of=/dev/block/by-name/vendor
if errorlevel 1 (
    echo ˢ��vendor����ʧ�ܣ�����...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto flash_vendor_retry
)

ECHO.ˢ��vendor������ɣ�
goto restore_system

:restore_system
:: ����4����TWRP���ݻ�ԭϵͳ
ECHO.=== ����4/4����TWRP���ݻ�ԭϵͳ ===
"%adb_path%" shell reboot recovery
ECHO.�ȴ��豸����Recovery...
if not defined UNATTENDED (
    pause
)

ECHO.��TWRP���ݻ�ԭϵͳ...
:restore_retry
"%adb_path%" shell twrp restore /sdcard/TWRP/BACKUPS/%backup_name% SDRB
if errorlevel 1 (
    echo �ָ�ϵͳʧ�ܣ����豸δ���ӣ�����...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto restore_retry
)

ECHO.ɾ��TWRP�����ļ��к�vendor.bin���ͷſռ�...
:delete_backup_retry
"%adb_path%" shell rm -rf /sdcard/TWRP/BACKUPS/%backup_name%
if errorlevel 1 (
    echo ɾ������ʧ�ܣ�����...
    timeout /t 2 /nobreak >nul
    goto delete_backup_retry
)

:delete_vendor_retry
"%adb_path%" shell rm -f /sdcard/vendor.bin
if errorlevel 1 (
    echo ɾ��vendor.binʧ�ܣ�����...
    timeout /t 2 /nobreak >nul
    goto delete_vendor_retry
)

ECHO.�����ɹ������������豸...
"%adb_path%" reboot
ECHO.=== ��ϲ�����в�������ɣ� ===
ECHO.�豸������������%system%ϵͳ...
pause
goto start