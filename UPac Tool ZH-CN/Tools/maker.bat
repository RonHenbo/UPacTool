@echo off
setlocal enabledelayedexpansion

title չ�����ϰ��������� By ���ι�

:: ��ʼ������·��
set "tool_dir=%~dp0"
set "spd_dump_path=%tool_dir%\bin\spd_dump\spd_dump.exe"
set "adb_path=%tool_dir%\bin\adb"
set "seven_zip_dir=%tool_dir%\bin\7z\7za.exe"

:: ��֤��Ҫ�����Ƿ����
if not exist "%spd_dump_path%" (
    echo ����: δ�ҵ� spd_dump.exe
    pause
    exit /b 1
)

if not exist "%adb_path%\adb.exe" (
    echo ����: δ�ҵ� adb.exe
    pause
    exit /b 1
)

if not exist "%seven_zip_dir%" (
    echo ����: δ�ҵ� 7za.exe�����޷�ѹ�����ϰ�
)

:: ���˵�
:start
cls
echo ===============================================================================
echo.                        չ�����ϰ��������� By ���ι�
echo ===============================================================================
echo.

set "package_name="
set /p "package_name=���������ϰ�����: "
if "!package_name!"=="" (
    echo ���ϰ����Ʋ���Ϊ��!
    timeout /t 2 /nobreak >nul
    goto start
)

:: ��������Ŀ¼
echo �ر�adb����...
"%adb_path%"\adb.exe kill-server >nul 2>&1
set "work_dir=%tool_dir%\!package_name!"
set "flash_files_dir=!work_dir!\flash_files"
set "dump_dir=!flash_files_dir!\dump"
set "push_dir=!flash_files_dir!\push"

:: �����Ŀ¼
if exist "!work_dir!" (
    echo ����ͬ��Ŀ¼����������...
    rmdir /s /q "!work_dir!" >nul 2>&1
    if exist "!work_dir!" (
        echo �޷�ɾ��Ŀ¼: !work_dir!
        pause
        goto start
    )
)

:: ������Ŀ¼
mkdir "!work_dir!" >nul 2>&1
if errorlevel 1 (
    echo �޷�����Ŀ¼: !work_dir!
    pause
    goto start
)

mkdir "!flash_files_dir!" >nul 2>&1
mkdir "!dump_dir!" >nul 2>&1
mkdir "!push_dir!" >nul 2>&1

:: �豸׼��ȷ��
echo.
echo ��ȷ���豸��������������:
echo 1. �ѽ���Bootloader
echo 2. �ѽ���AVB��֤
echo 3. ��ˢ��TWRP�ָ�ģʽ
echo.
set "confirmed="
set /p "confirmed=�豸��������������? (Y/N): "

if /i not "!confirmed!"=="Y" (
    echo ��������豸׼���������ټ���
    rmdir /s /q "!work_dir!" >nul 2>&1
    pause
    goto start
)

:: ��ȡFDL�ļ���Ϣ
echo.
echo ���ṩFDL�ļ���Ϣ...
echo.

:get_fdl1
set "fdl1_file="
set /p "fdl1_file=�������һ��FDL�ļ�: "
set "fdl1_file=!fdl1_file:"=!"
if not exist "!fdl1_file!" (
    echo �ļ������ڣ�����������
    goto get_fdl1
)

set "fdl1_hex="
set /p "fdl1_hex=�������һ��FDL�ļ���·����ַ: 0x"
if "!fdl1_hex!"=="" (
    echo ·����ַ����Ϊ��
    goto get_fdl1
)
set "fdl1_path=0x!fdl1_hex!"

copy /y "!fdl1_file!" "!dump_dir!\fdl1.bin" >nul
if errorlevel 1 (
    echo ����FDL1�ļ�ʧ��
    goto cleanup
)

:get_fdl2
set "fdl2_file="
set /p "fdl2_file=������ڶ���FDL�ļ�: "
set "fdl2_file=!fdl2_file:"=!"
if not exist "!fdl2_file!" (
    echo �ļ������ڣ�����������
    goto get_fdl2
)

set "fdl2_hex="
set /p "fdl2_hex=������ڶ���FDL�ļ���·����ַ: 0x"
if "!fdl2_hex!"=="" (
    echo ·����ַ����Ϊ��
    goto get_fdl2
)
set "fdl2_path=0x!fdl2_hex!"

copy /y "!fdl2_file!" "!dump_dir!\fdl2.bin" >nul
if errorlevel 1 (
    echo ����FDL2�ļ�ʧ��
    goto cleanup
)

:: ��ȡ�ײ����
echo.
echo ׼����ȡ�ײ��������ر��豸��Ȼ��ֱ�����ӵ���...
cd /d "!dump_dir!"
"%spd_dump_path%" --wait 1000 --kickto 2 blk_size 65535 r splloader r trustos r uboot reboot-recovery

if errorlevel 1 (
    echo ��ȡ����ʧ�ܣ������豸���Ӻ�����
    echo ��������˳�...
    pause
    goto cleanup
)

echo ������ȡ�ɹ�!
timeout /t 3 /nobreak >nul

:: �ȴ��豸����TWRP�ָ�ģʽ
echo �ȴ��豸����TWRP�ָ�ģʽ...
set "retry_count=0"
:wait_recovery
"%adb_path%"\adb.exe wait-for-recovery

:: ��ȡvendor·��
echo ���ڻ�ȡvendor·��...
cd "%adb_path%"
set "vendor_path="
for /f "tokens=*" %%a in ('adb shell "find /dev/block -name vendor 2>/dev/null | head -1"') do (
    set "vendor_path=%%a"
)

if "!vendor_path!"=="" (
    echo �޷��ҵ�vendor����
    goto cleanup
)

:: ��ȡvendor����
echo ������ȡvendor����...
set "retry_count=0"
:dd_vendor
"%adb_path%"\adb.exe shell "dd if=!vendor_path! of=/sdcard/vendor.bin"
if errorlevel 1 (
    echo ��ȡvendor����ʧ�ܣ�5�������...
    timeout /t 5 /nobreak >nul
    goto dd_vendor
)

:: ����TWRP����
echo ���ڴ���TWRP����...
set "timestamp=!date:~0,4!!date:~5,2!!date:~8,2!!time:~0,2!!time:~3,2!!time:~6,2!"
set "timestamp=!timestamp: =0!"

set "retry_count=0"
:retry_backup
"%adb_path%"\adb.exe shell "twrp backup SDRB !timestamp!"
if errorlevel 1 (
    echo ���ݴ���ʧ�ܣ�5�������...
    timeout /t 5 /nobreak >nul
    goto retry_backup
)

:: ��ȡ�豸ID
echo ���ڻ�ȡ�豸ID...
set "DeviceID="
set "retry_count=0"
:retry_get_id
for /f "delims=" %%a in ('adb shell "ls /sdcard/TWRP/BACKUPS/" 2^>nul') do (
    set "DeviceID=%%a"
)
if "!DeviceID!"=="" (
    set /a "retry_count+=1"
    if !retry_count! geq 5 (
        echo �޷���ȡ�豸ID������TWRP�����Ƿ񴴽��ɹ�
        goto cleanup
    )
    echo �޷���ȡ�豸ID��5�������...
    timeout /t 5 /nobreak >nul
    goto retry_get_id
)

set "backup_name=!DeviceID!/!timestamp!"

:: ��ȡ�����ļ���vendor
echo ������ȡ�����ļ���vendor...
cd "%tool_dir%"
mkdir "!push_dir!\TWRP" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS\!DeviceID!" >nul 2>&1

set "retry_count=0"
:retry_pull
"%adb_path%"\adb.exe pull /sdcard/TWRP/BACKUPS/!backup_name! "!push_dir!\TWRP\BACKUPS\!DeviceID!\!timestamp!"
if errorlevel 1 (
    echo ��ȡ����ʧ�ܣ�5�������...
    timeout /t 5 /nobreak >nul
    goto retry_pull
)

set "retry_count=0"
:retry_pull_vendor
"%adb_path%"\adb.exe pull /sdcard/vendor.bin "!push_dir!"
if errorlevel 1 (
    echo ��ȡvendor����ʧ�ܣ�5�������...
    timeout /t 5 /nobreak >nul
    goto retry_pull_vendor
)

:: ����豸�ϵ��ļ�
echo ��������豸�ϵı����ļ���vendor����...
set "retry_count=0"
:retry_clean_device
"%adb_path%"\adb.exe shell "rm -rf /sdcard/TWRP/BACKUPS/!backup_name! /sdcard/vendor.bin"
if errorlevel 1 (
    echo ����豸�ļ�ʧ�ܣ�5�������...
    timeout /t 5 /nobreak >nul
    goto retry_clean_device
)

:skip_clean
"%adb_path%"\adb.exe shell reboot
echo �ļ���ȡ��ɣ��豸�����������ڿ��ԶϿ������ˡ�

:: �ռ��豸��Ϣ
echo.
echo ���ṩ�豸��Ϣ...
echo.

set "device="
set /p "device=�������豸�ͺ�: "

set "soc="
set /p "soc=�����봦�����ͺ�: "

set "system="
set /p "system=������ϵͳ�汾: "

set "arch="
set /p "arch=�������豸�ܹ�(arm/arm64): "

set "sar_device="
set /p "sar_device=�Ƿ���SAR�豸(true/false): "

set "ab_device="
set /p "ab_device=�Ƿ���A/B�����豸(true/false): "

set "treble="
set /p "treble=������Treble֧����Ϣ: "

set "fix="
set /p "fix=�������޸�����: "

set "ext="
set /p "ext=��������չ����: "

set "maker="
set /p "maker=������������: "

:: ���������ļ�
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
set /p "compress=�Ƿ�ѹ�����ϰ�? (Y/N): "

if /i "!compress!"=="Y" (
    if not exist "%seven_zip_dir%" (
        echo 7za.exe�����ڣ��޷�ѹ�����ϰ�
        goto skip_compress
    )
    
    echo ���ڴ�����ϰ�...
    cd /d "!work_dir!"
    "%seven_zip_dir%" a -mmt -mx9 -t7z "..\!package_name!.7z" "flash_files"
    if errorlevel 1 (
        echo ���ʧ��
        set "cleanup_failed="
        set /p "cleanup_failed=�Ƿ��������ϰ��ļ�? (Y/N): "
        if /i "!cleanup_failed!"=="Y" (
            goto cleanup
        ) else (
            echo ���ϰ�������: !work_dir!
            goto final_message
        )
    )
    
    echo ����ɹ�!
    for %%A in ("..\!package_name!.7z") do set "archive_size_mb=%%~zA"
    set /a "archive_size_mb=!archive_size_mb!/1048576"
    
    set "delete_source="
    set /p "delete_source=�Ƿ�ɾ��Դ�ļ�? (Y/N): "
    if /i "!delete_source!"=="Y" (
        echo ����ɾ��Դ�ļ�...
        rmdir /s /q "!work_dir!" >nul 2>&1
        set "final_message=���ϰ��ѱ���Ϊ: %tool_dir%!package_name!.7z (!archive_size_mb! MB)��Դ�ļ���ɾ��"
    ) else (
        set "final_message=���ϰ��ѱ���Ϊ: %tool_dir%!package_name!.7z (!archive_size_mb! MB)��Դ�ļ�������: !work_dir!"
    )
) else (
    :skip_compress
    echo ����ѹ������
    set "final_message=���ϰ��ļ��ѱ�����: !work_dir!"
)

:cleanup
echo �ر�adb����...
"%adb_path%"\adb.exe kill-server >nul 2>&1
echo ����������ʱ�ļ�...
rmdir /s /q "!work_dir!" >nul 2>&1
echo ��������ʱ�ļ�

:final_message
echo.
echo ===============================================================================
echo ���ϰ��������!
echo !final_message!
echo ===============================================================================
echo.
pause