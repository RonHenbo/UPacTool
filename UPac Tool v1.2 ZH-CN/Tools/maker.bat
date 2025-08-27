@echo off
setlocal enabledelayedexpansion

title 展锐整合包制作工具

:: 设置工具路径
set "spd_dump_path=%cd%\bin\spd_dump"
set "adb_path=%cd%\bin\adb_fastboot\adb"
set "seven_zip_dir=%cd%\bin\7z"

:: 检查必要工具是否存在
if not exist "%spd_dump_path%\spd_dump.exe" (
    echo 错误：未找到spd_dump工具
    pause
    exit /b 1
)

if not exist "%adb_path%.exe" (
    echo 错误：未找到adb工具
    pause
    exit /b 1
)

if not exist "%seven_zip_dir%\7zr.exe" (
    echo 错误：未找到7zr工具
    pause
    exit /b 1
)

:start
cls
echo ===============================================================================
echo.                        展锐整合包制作工具 By 独の光
echo ===============================================================================
echo.

:: 询问整合包名称
set /p "package_name=请输入整合包名称: "
if "!package_name!"=="" (
    echo 整合包名称不能为空!
    timeout /t 2 /nobreak >nul
    goto start
)

:: 创建工作文件夹
set "work_dir=%cd%\!package_name!"
set "flash_files_dir=!work_dir!\flash_files"
set "dump_dir=!flash_files_dir!\dump"
set "push_dir=!flash_files_dir!\push"

:: 如果工作文件夹已存在，直接删除
if exist "!work_dir!" (
    rmdir /s /q "!work_dir!" >nul 2>&1
)

:: 创建新的工作文件夹
mkdir "!work_dir!" >nul 2>&1
mkdir "!flash_files_dir!" >nul 2>&1
mkdir "!dump_dir!" >nul 2>&1
mkdir "!push_dir!" >nul 2>&1
:: 检查设备准备状态
echo.
echo 请确认设备已满足以下条件:
echo 1. 已解锁Bootloader
echo 2. 已禁用AVB验证
echo 3. 已刷入TWRP恢复模式
echo.
set /p "confirmed=设备已满足上述条件? (Y/N): "

if /i not "!confirmed!"=="Y" (
    echo 请先完成设备准备工作后再继续
    rmdir /s /q "!work_dir!"
    pause
    goto start
)

:: 获取FDL文件
echo.
echo 请提供FDL文件信息...
echo.

:get_fdl1
set /p "fdl1_file=请拖入第一个FDL文件: "
set "fdl1_file=!fdl1_file:"=!"
if not exist "!fdl1_file!" (
    echo 文件不存在，请重新输入
    goto get_fdl1
)

set /p "fdl1_path=请输入第一个FDL文件的路径地址(如0x5000): "
if "!fdl1_path!"=="" (
    echo 路径地址不能为空
    goto get_fdl1
)

copy /y "!fdl1_file!" "!dump_dir!\fdl1.bin" >nul

:get_fdl2
set /p "fdl2_file=请拖入第二个FDL文件: "
set "fdl2_file=!fdl2_file:"=!"
if not exist "!fdl2_file!" (
    echo 文件不存在，请重新输入
    goto get_fdl2
)

set /p "fdl2_path=请输入第二个FDL文件的路径地址(如0x9efffe00): "
if "!fdl2_path!"=="" (
    echo 路径地址不能为空
    goto get_fdl2
)

copy /y "!fdl2_file!" "!dump_dir!\fdl2.bin" >nul

:: 读取设备分区
echo.
echo 请关闭设备，然后直接连接电脑...
pause

echo 正在读取设备分区...
cd /d "!dump_dir!"
"%spd_dump_path%\spd_dump" --wait 1000 --kickto 2 r splloader r trustos r uboot reboot-recovery

if errorlevel 1 (
    echo 读取分区失败，请检查设备连接和驱动
    pause
    goto cleanup
)

echo 分区读取成功!
timeout /t 3 /nobreak >nul

:: 等待设备进入Recovery
echo 等待设备进入TWRP恢复模式...
:wait_recovery
"%adb_path%" wait-for-recovery >nul 2>&1
if errorlevel 1 (
    echo 设备未进入恢复模式，请手动进入TWRP后按任意键继续...
    pause
    goto wait_recovery
)

:: 创建备份
echo 正在创建TWRP备份...
set "timestamp=!date:~0,4!!date:~5,2!!date:~8,2!!time:~0,2!!time:~3,2!!time:~6,2!"
set "timestamp=!timestamp: =0!"

"%adb_path%" shell "twrp backup SDRB !timestamp!"

if errorlevel 1 (
    echo 备份创建失败
    pause
    goto cleanup
)

:: 获取设备ID并拉取备份
echo 正在获取设备ID...
for /f "delims=" %%a in ('"%adb_path%" get-serialno 2^>nul') do set "DeviceID=%%a"

if "!DeviceID!"=="" (
    echo 无法获取设备ID
    set "DeviceID=unknown"
)

set "backup_name=!DeviceID!/!timestamp!"

:: 拉取备份文件
echo 正在拉取备份文件...
mkdir "!push_dir!\TWRP" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS\!DeviceID!" >nul 2>&1

"%adb_path%" pull /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp! "!push_dir!\TWRP\BACKUPS\!DeviceID!\!timestamp!"\

if errorlevel 1 (
    echo 拉取备份失败
    pause
    goto cleanup
)

:: 清除设备上的备份文件
echo 正在清除设备上的备份文件...
"%adb_path%" shell "rm -rf /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp!"

:: 收集设备信息
echo.
echo 请提供设备信息...
echo.

set /p "device=请输入设备型号: "
set /p "soc=请输入处理器型号: "
set /p "system=请输入系统版本: "
set /p "arch=请输入设备架构(arm/arm64): "
set /p "sar_device=是否是SAR设备(true/false): "
set /p "ab_device=是否是A/B分区设备(true/false): "
set /p "treble=请输入Treble支持信息: "
set /p "fix=请输入修复内容: "
set /p "ext=请输入扩展内容: "
set /p "maker=请输入制作者: "

:: 生成set.bat文件
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

:: 打包整合包
echo 正在打包整合包...
cd /d "!work_dir!"
"%seven_zip_dir%\7zr" a -mx9 -t7z "..\!package_name!.7z" "flash_files" >nul

if errorlevel 1 (
    echo 打包失败
    pause
    goto cleanup
)

:: 清理工作目录
:cleanup
cd /d "%cd%"
rmdir /s /q "!work_dir!"

echo.
echo ===============================================================================
echo 整合包制作完成!
echo 整合包已保存为: %cd%\!package_name!.7z
echo ===============================================================================
echo.
pause
