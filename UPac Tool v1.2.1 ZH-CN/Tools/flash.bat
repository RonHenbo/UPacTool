@ECHO OFF
:: ���ø������ߵ�·��
set "bin_path=%cd%\bin"
set "spd_dump_path=%cd%\bin\spd_dump"  :: SPDˢ������·��
set "adb_path=%cd%\bin\adb_fastboot\adb.exe"  :: ADB����·��
set "seven_zip_dir=%cd%\bin\7z"  :: 7-Zip��ѹ����·��
set "dump_files=%cd%\flash_files\dump"  :: ת���ļ�Ŀ¼
set "push_path=%cd%\flash_files\push"  :: �����ļ�Ŀ¼
set "flash_path=%cd%\flash_files"  :: ˢ���ļ���Ŀ¼

:load_set
:: ���������ļ�
if exist "%flash_path%\set.bat" (
    call "%flash_path%\set.bat"  :: ���������ļ�
    goto after_load
) else (
    echo ����δ�ҵ������ļ� set.bat
    goto load_package
)

:load_package
:: ����ˢ����
echo ���������ϰ�7z�ļ���
set /p package_path=�����ļ��󰴻س�: 
if not exist "%package_path%" (
    echo �ļ������ڣ�����������
    goto load_package
)
echo ���ڼ������ϰ�...
if exist flash_files rmdir /s /q flash_files  :: ������ļ�
"%seven_zip_dir%\7zr" x "%package_path%" -o"%cd%"  :: ��ѹˢ����
if errorlevel 1 (
    echo ��ѹʧ�ܣ������ļ�
    pause
    goto load_package
)
goto load_set

:after_load
:: ��鲢����dump_modeĬ��ֵ
if not defined dump_mode set dump_mode=kick_fxxk_avb

:: ����TWRP����·��
set "backup_path=%push_path%\TWRP\BACKUPS\%backup_name%"

:start
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
ECHO.3.��TWRP���ݻ�ԭϵͳ
ECHO.4.�����豸�ϵ�TWRP�����ļ�
set /p step=��ѡ��:
if %step%==2 goto format_data
if %step%==3 goto restore_system
if %step%==4 goto cleanup_backup
ECHO.�������
if defined UNATTENDED goto choose_step
pause
goto choose_step

:retry_unlock
ECHO.���Խ���...
:unlock
:: ����1������Bootloader
ECHO.=== ����1/3������Bootloader��ˢ�뾵�� ===
if not defined UNATTENDED (
    ECHO.�뽫�豸�ػ���Ȼ��ֱ�����ӵ���...
    pause
)
ECHO.���ڵȴ�dl_diag�볢�������豸����������ʣ��15���ӣ�
cd "%dump_files%"

:: ��ʹ��kick_fxxk_avbģʽ����
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
ECHO.=== ����2/3����ʽ��data���� ===
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

ECHO.����TWRP�ļ���...
:push_retry
"%adb_path%" push "%push_path%\." /sdcard/
"%adb_path%" push "%bin_path%\.twrps" /sdcard/TWRP/
if errorlevel 1 (
    echo �豸δ���ӣ�������TWRP�ļ���ʧ�ܣ�����...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto push_retry
)

goto restore_system

:restore_system
:: ����3����TWRP���ݻ�ԭϵͳ
ECHO.=== ����3/3����TWRP���ݻ�ԭϵͳ ===
"%adb_path%" shell reboot recovery
ECHO.�ȴ��豸����Recovery...
if not defined UNATTENDED (
    pause
)
