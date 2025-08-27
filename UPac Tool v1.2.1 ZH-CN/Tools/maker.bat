@echo off
setlocal enabledelayedexpansion

title չ�����ϰ���������

:: ���ù���·��
set "spd_dump_path=%cd%\bin\spd_dump"
set "adb_path=%cd%\bin\adb_fastboot\adb"
set "seven_zip_dir=%cd%\bin\7z"

:: ����Ҫ�����Ƿ����
if not exist "%spd_dump_path%\spd_dump.exe" (
    echo ����δ�ҵ�spd_dump����
    pause
    exit /b 1
)

if not exist "%adb_path%.exe" (
    echo ����δ�ҵ�adb����
    pause
    exit /b 1
)

if not exist "%seven_zip_dir%\7zr.exe" (
    echo ����δ�ҵ�7zr����
    pause
    exit /b 1
)

:start
cls
echo ===============================================================================
echo.                        չ�����ϰ��������� By ���ι�
echo ===============================================================================
echo.

:: ѯ�����ϰ�����
set /p "package_name=���������ϰ�����: "
if "!package_name!"=="" (
    echo ���ϰ����Ʋ���Ϊ��!
    timeout /t 2 /nobreak >nul
    goto start
)

:: ���������ļ���
set "work_dir=%cd%\!package_name!"
set "flash_files_dir=!work_dir!\flash_files"
set "dump_dir=!flash_files_dir!\dump"
set "push_dir=!flash_files_dir!\push"

:: ��������ļ����Ѵ��ڣ�ֱ��ɾ��
if exist "!work_dir!" (
    rmdir /s /q "!work_dir!" >nul 2>&1
)

:: �����µĹ����ļ���
mkdir "!work_dir!" >nul 2>&1
mkdir "!flash_files_dir!" >nul 2>&1
mkdir "!dump_dir!" >nul 2>&1
mkdir "!push_dir!" >nul 2>&1
:: ����豸׼��״̬
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

:: ��ȡFDL�ļ�
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

set /p "fdl1_path=�������һ��FDL�ļ���·����ַ(��0x5000): "
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

set /p "fdl2_path=������ڶ���FDL�ļ���·����ַ(��0x9efffe00): "
if "!fdl2_path!"=="" (
    echo ·����ַ����Ϊ��
    goto get_fdl2
)

copy /y "!fdl2_file!" "!dump_dir!\fdl2.bin" >nul

:: ��ȡ�豸����
echo.
echo ��ر��豸��Ȼ��ֱ�����ӵ���...
pause

echo ���ڶ�ȡ�豸����...
cd /d "!dump_dir!"
"%spd_dump_path%\spd_dump" --wait 1000 --kickto 2 r splloader r trustos r uboot reboot-recovery

if errorlevel 1 (
    echo ��ȡ����ʧ�ܣ������豸���Ӻ�����
    pause
    goto cleanup
)

echo ������ȡ�ɹ�!
timeout /t 3 /nobreak >nul

:: �ȴ��豸����Recovery
echo �ȴ��豸����TWRP�ָ�ģʽ...
:wait_recovery
"%adb_path%" wait-for-recovery >nul 2>&1
if errorlevel 1 (
    echo �豸δ����ָ�ģʽ�����ֶ�����TWRP�����������...
    pause
    goto wait_recovery
)

:: ��������
echo ���ڴ���TWRP����...
set "timestamp=!date:~0,4!!date:~5,2!!date:~8,2!!time:~0,2!!time:~3,2!!time:~6,2!"
set "timestamp=!timestamp: =0!"

"%adb_path%" shell "twrp backup SDRB !timestamp!"

if errorlevel 1 (
    echo ���ݴ���ʧ��
    pause
    goto cleanup
)

:: ��ȡ�豸ID����ȡ����
echo ���ڻ�ȡ�豸ID...
for /f "delims=" %%a in ('"%adb_path%" get-serialno 2^>nul') do set "DeviceID=%%a"

if "!DeviceID!"=="" (
    echo �޷���ȡ�豸ID
    set "DeviceID=unknown"
)

set "backup_name=!DeviceID!/!timestamp!"

:: ��ȡ�����ļ�
echo ������ȡ�����ļ�...
mkdir "!push_dir!\TWRP" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS\!DeviceID!" >nul 2>&1

"%adb_path%" pull /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp! "!push_dir!\TWRP\BACKUPS\!DeviceID!\!timestamp!"\

if errorlevel 1 (
    echo ��ȡ����ʧ��
    pause
    goto cleanup
)

:: ����豸�ϵı����ļ�
echo ��������豸�ϵı����ļ�...
"%adb_path%" shell "rm -rf /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp!"

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

:: ����set.bat�ļ�
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

:: ������ϰ�
echo ���ڴ�����ϰ�...
cd /d "!work_dir!"
"%seven_zip_dir%\7zr" a -mx9 -t7z "..\!package_name!.7z" "flash_files" >nul

if errorlevel 1 (
    echo ���ʧ��
    pause
    goto cleanup
)

:: ������Ŀ¼
:cleanup
cd /d "%cd%"
rmdir /s /q "!work_dir!"

echo.
echo ===============================================================================
echo ���ϰ��������!
echo ���ϰ��ѱ���Ϊ: %cd%\!package_name!.7z
echo ===============================================================================
echo.
pause
