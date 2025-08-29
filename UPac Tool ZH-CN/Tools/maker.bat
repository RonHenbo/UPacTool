@echo off
setlocal enabledelayedexpansion

title չ�����ϰ���������

set "tool_dir=%cd%"

set "spd_dump_path=%cd%\bin\spd_dump"
set "adb_path=%cd%\bin\adb_fastboot\"
set "seven_zip_dir=%cd%\bin\7z"
cd %adb_path%

:start
cls
echo ===============================================================================
echo.                        չ�����ϰ��������� By ���ι�
echo ===============================================================================
echo.

set /p "package_name=���������ϰ�����: "
if "!package_name!"=="" (
    echo ���ϰ����Ʋ���Ϊ��!
    timeout /t 2 /nobreak >nul
    goto start
)

set "work_dir=%cd%\!package_name!"
set "flash_files_dir=!work_dir!\flash_files"
set "dump_dir=!flash_files_dir!\dump"
set "push_dir=!flash_files_dir!\push"

echo �ر�adb����...
adb kill-server >nul 2>&1
if exist "!work_dir!" (
    rmdir /s /q "!work_dir!" >nul 2>&1
)

mkdir "!work_dir!" >nul 2>&1
mkdir "!flash_files_dir!" >nul 2>&1
mkdir "!dump_dir!" >nul 2>&1
mkdir "!push_dir!" >nul 2>&1

echo.
echo ��ȷ���豸��������������:
echo 1. �ѽ���Bootloader
echo 2. �ѽ���AVB��֤
echo 3. ��ˢ��TWRP�ָ�ģʽ
echo.
set /p "confirmed=�豸��������������? (Y/N): "

if /i not "!confirmed!"=="Y" (
    echo ��������豸׼���������ټ���
    rmdir /s /q "!work_dir!"
    pause
    goto start
)

echo.
echo ���ṩFDL�ļ���Ϣ...
echo.

:get_fdl1
set /p "fdl1_file=�������һ��FDL�ļ�: "
set "fdl1_file=!fdl1_file:"=!"
if not exist "!fdl1_file!" (
    echo �ļ������ڣ�����������
    goto get_fdl1
)

set /p "fdl1_path=�������һ��FDL�ļ���·����ַ: "
if "!fdl1_path!"=="" (
    echo ·����ַ����Ϊ��
    goto get_fdl1
)

copy /y "!fdl1_file!" "!dump_dir!\fdl1.bin" >nul

:get_fdl2
set /p "fdl2_file=������ڶ���FDL�ļ�: "
set "fdl2_file=!fdl2_file:"=!"
if not exist "!fdl2_file!" (
    echo �ļ������ڣ�����������
    goto get_fdl2
)

set /p "fdl2_path=������ڶ���FDL�ļ���·����ַ: "
if "!fdl2_path!"=="" (
    echo ·����ַ����Ϊ��
    goto get_fdl2
)

copy /y "!fdl2_file!" "!dump_dir!\fdl2.bin" >nul

echo.
echo ׼����ȡ�ײ��������ر��豸��Ȼ��ֱ�����ӵ���...
cd /d "!dump_dir!"
"%spd_dump_path%\spd_dump.exe" --wait 1000 --kickto 2 blk_size 65535 r splloader r trustos r uboot reboot-recovery

if errorlevel 1 (
    echo ��ȡ����ʧ�ܣ������豸���Ӻ�����
    pause
    goto cleanup
)

echo ������ȡ�ɹ�!
timeout /t 3 /nobreak >nul

echo �ȴ��豸����TWRP�ָ�ģʽ...
:wait_recovery
cd %adb_path%
adb wait-for-recovery >nul 2>&1
if errorlevel 1 (
    echo �豸δ����ָ�ģʽ�����ֶ�����TWRP�����������...
    pause
    goto wait_recovery
)

echo ���ڻ�ȡvendor·��...

for /f "tokens=*" %%a in ('adb shell "find /dev/block -name vendor"') do (
    set "vendor_path=%%a"
    goto :dd_vendor
)

:dd_vendor
adb shell "dd if=%vendor_path% of=/sdcard/vendor.bin"
if errorlevel 1 (
    echo.path:%vendor_path%
    echo ��ȡvendor����ʧ�ܣ�5�������...
    timeout /t 5 /nobreak >nul
    goto dd_vendor
)

echo ���ڴ���TWRP����...
set "timestamp=!date:~0,4!!date:~5,2!!date:~8,2!!time:~0,2!!time:~3,2!!time:~6,2!"
set "timestamp=!timestamp: =0!"

:retry_backup
adb shell "twrp backup SDRB !timestamp!"
if errorlevel 1 (
    echo ���ݴ���ʧ�ܣ�5�������...
    timeout /t 5 /nobreak >nul
    goto retry_backup
)

echo ���ڻ�ȡ�豸ID...
:retry_get_id
for /f "delims=" %%a in ('adb shell "ls /sdcard/TWRP/BACKUPS/" 2^>nul') do (
    set "DeviceID=%%a"
    goto :break_get_id
)
:break_get_id
if "!DeviceID!"=="" (
    echo �޷���ȡ�豸ID��5�������...
    timeout /t 5 /nobreak >nul
    goto retry_get_id
)
set "backup_name=!DeviceID!/!timestamp!"

echo ������ȡ�����ļ���vendor...
mkdir "!push_dir!\TWRP" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS\!DeviceID!" >nul 2>&1

:retry_pull
adb pull /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp! "!push_dir!\TWRP\BACKUPS\!DeviceID!\!timestamp!" && (
    adb pull /sdcard/vendor.bin "!push_dir!"
)
if errorlevel 1 (
    echo ��ȡ���ݻ�vendor����ʧ�ܣ�5�������...
    timeout /t 5 /nobreak >nul
    goto retry_pull
)

echo ��������豸�ϵı����ļ���vendor����...
:retry_clean_device
adb shell "rm -rf /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp! /sdcard/vendor.bin"
if errorlevel 1 (
    echo ����豸���ݺ�vendor����ʧ�ܣ�5�������...
    timeout /t 5 /nobreak >nul
    goto retry_clean_device
)

adb shell reboot
echo �ļ���ȡ��ɣ��豸�����������ڿ��ԶϿ������ˡ�

:: �ռ��豸��Ϣ
echo.
echo ���ṩ�豸��Ϣ...
echo.

set /p "device=�������豸�ͺ�: "
set /p "soc=�����봦�����ͺ�: "
set /p "system=������ϵͳ�汾: "
set /p "arch=�������豸�ܹ�(arm/arm64): "
set /p "sar_device=�Ƿ���SAR�豸(true/false): "
set /p "ab_device=�Ƿ���A/B�����豸(true/false): "
set /p "treble=������Treble֧����Ϣ: "
set /p "fix=�������޸�����: "
set /p "ext=��������չ����: "
set /p "maker=������������: "

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

:: ѯ���Ƿ�ѹ��
echo.
set /p "compress=�Ƿ�ѹ�����ϰ�? (Y/N): "
if /i "!compress!"=="Y" (
    echo ���ڴ�����ϰ�...
    cd /d "!work_dir!"
    "%seven_zip_dir%\7z.exe" a -mx9 -t7z "..\!package_name!.7z" "flash_files" >nul
    
    if errorlevel 1 (
        echo ���ʧ��
        set /p "cleanup_failed=�Ƿ��������ϰ��ļ�? (Y/N): "
        if /i "!cleanup_failed!"=="Y" (
            goto cleanup
        ) else (
            echo ���ϰ�������: !work_dir!
            goto final_message
        )
    )
    
    echo ����ɹ�!
    set /p "delete_source=�Ƿ�ɾ��Դ�ļ�? (Y/N): "
    if /i "!delete_source!"=="Y" (
        echo ����ɾ��Դ�ļ�...
        rmdir /s /q "!work_dir!" >nul 2>&1
        set "final_message=���ϰ��ѱ���Ϊ: %cd%\!package_name!.7z��Դ�ļ���ɾ��"
    ) else (
        set "final_message=���ϰ��ѱ���Ϊ: %cd%\!package_name!.7z��Դ�ļ�������: !work_dir!"
    )
) else (
    echo ����ѹ������
    set "final_message=���ϰ��ļ��ѱ�����: !work_dir!"
)

:final_message
cd /d "%tool_dir%"
echo �ر�adb����...
adb kill-server

echo.
echo ===============================================================================
echo ���ϰ��������!
echo !final_message!
echo ===============================================================================
echo.
pause
exit /b 0

:cleanup
cd /d "%tool_dir%"
echo �ر�adb����...
adb kill-server
if exist "!work_dir!" (
    echo ����������ʱ�ļ�...
    rmdir /s /q "!work_dir!" >nul 2>&1
)
goto final_message