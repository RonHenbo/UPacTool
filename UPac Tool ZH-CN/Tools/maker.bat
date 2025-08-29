@echo off
setlocal enabledelayedexpansion

title 展锐整合包制作工具 By 独の光

:: 初始化工具路径
set "tool_dir=%~dp0"
set "spd_dump_path=%tool_dir%\bin\spd_dump\spd_dump.exe"
set "adb_path=%tool_dir%\bin\adb"
set "seven_zip_dir=%tool_dir%\bin\7z\7za.exe"

:: 验证必要工具是否存在
if not exist "%spd_dump_path%" (
    echo 错误: 未找到 spd_dump.exe
    pause
    exit /b 1
)

if not exist "%adb_path%\adb.exe" (
    echo 错误: 未找到 adb.exe
    pause
    exit /b 1
)

if not exist "%seven_zip_dir%" (
    echo 警告: 未找到 7za.exe，将无法压缩整合包
)

:: 主菜单
:start
cls
echo ===============================================================================
echo.                        展锐整合包制作工具 By 独の光
echo ===============================================================================
echo.

set "package_name="
set /p "package_name=请输入整合包名称: "
if "!package_name!"=="" (
    echo 整合包名称不能为空!
    timeout /t 2 /nobreak >nul
    goto start
)

:: 创建工作目录
echo 关闭adb服务...
"%adb_path%"\adb.exe kill-server >nul 2>&1
set "work_dir=%tool_dir%\!package_name!"
set "flash_files_dir=!work_dir!\flash_files"
set "dump_dir=!flash_files_dir!\dump"
set "push_dir=!flash_files_dir!\push"

:: 清理旧目录
if exist "!work_dir!" (
    echo 发现同名目录，正在清理...
    rmdir /s /q "!work_dir!" >nul 2>&1
    if exist "!work_dir!" (
        echo 无法删除目录: !work_dir!
        pause
        goto start
    )
)

:: 创建新目录
mkdir "!work_dir!" >nul 2>&1
if errorlevel 1 (
    echo 无法创建目录: !work_dir!
    pause
    goto start
)

mkdir "!flash_files_dir!" >nul 2>&1
mkdir "!dump_dir!" >nul 2>&1
mkdir "!push_dir!" >nul 2>&1

:: 设备准备确认
echo.
echo 请确认设备已满足以下条件:
echo 1. 已解锁Bootloader
echo 2. 已禁用AVB验证
echo 3. 已刷入TWRP恢复模式
echo.
set "confirmed="
set /p "confirmed=设备已满足上述条件? (Y/N): "

if /i not "!confirmed!"=="Y" (
    echo 请先完成设备准备工作后再继续
    rmdir /s /q "!work_dir!" >nul 2>&1
    pause
    goto start
)

:: 获取FDL文件信息
echo.
echo 请提供FDL文件信息...
echo.

:get_fdl1
set "fdl1_file="
set /p "fdl1_file=请拖入第一个FDL文件: "
set "fdl1_file=!fdl1_file:"=!"
if not exist "!fdl1_file!" (
    echo 文件不存在，请重新输入
    goto get_fdl1
)

set "fdl1_hex="
set /p "fdl1_hex=请输入第一个FDL文件的路径地址: 0x"
if "!fdl1_hex!"=="" (
    echo 路径地址不能为空
    goto get_fdl1
)
set "fdl1_path=0x!fdl1_hex!"

copy /y "!fdl1_file!" "!dump_dir!\fdl1.bin" >nul
if errorlevel 1 (
    echo 复制FDL1文件失败
    goto cleanup
)

:get_fdl2
set "fdl2_file="
set /p "fdl2_file=请拖入第二个FDL文件: "
set "fdl2_file=!fdl2_file:"=!"
if not exist "!fdl2_file!" (
    echo 文件不存在，请重新输入
    goto get_fdl2
)

set "fdl2_hex="
set /p "fdl2_hex=请输入第二个FDL文件的路径地址: 0x"
if "!fdl2_hex!"=="" (
    echo 路径地址不能为空
    goto get_fdl2
)
set "fdl2_path=0x!fdl2_hex!"

copy /y "!fdl2_file!" "!dump_dir!\fdl2.bin" >nul
if errorlevel 1 (
    echo 复制FDL2文件失败
    goto cleanup
)

:: 读取底层分区
echo.
echo 准备读取底层分区，请关闭设备，然后直接连接电脑...
cd /d "!dump_dir!"
"%spd_dump_path%" --wait 1000 --kickto 2 blk_size 65535 r splloader r trustos r uboot reboot-recovery

if errorlevel 1 (
    echo 读取分区失败，请检查设备连接和驱动
    echo 按任意键退出...
    pause
    goto cleanup
)

echo 分区读取成功!
timeout /t 3 /nobreak >nul

:: 等待设备进入TWRP恢复模式
echo 等待设备进入TWRP恢复模式...
set "retry_count=0"
:wait_recovery
"%adb_path%"\adb.exe wait-for-recovery

:: 获取vendor路径
echo 正在获取vendor路径...
cd "%adb_path%"
set "vendor_path="
for /f "tokens=*" %%a in ('adb shell "find /dev/block -name vendor 2>/dev/null | head -1"') do (
    set "vendor_path=%%a"
)

if "!vendor_path!"=="" (
    echo 无法找到vendor分区
    goto cleanup
)

:: 提取vendor分区
echo 正在提取vendor分区...
set "retry_count=0"
:dd_vendor
"%adb_path%"\adb.exe shell "dd if=!vendor_path! of=/sdcard/vendor.bin"
if errorlevel 1 (
    echo 提取vendor分区失败，5秒后重试...
    timeout /t 5 /nobreak >nul
    goto dd_vendor
)

:: 创建TWRP备份
echo 正在创建TWRP备份...
set "timestamp=!date:~0,4!!date:~5,2!!date:~8,2!!time:~0,2!!time:~3,2!!time:~6,2!"
set "timestamp=!timestamp: =0!"

set "retry_count=0"
:retry_backup
"%adb_path%"\adb.exe shell "twrp backup SDRB !timestamp!"
if errorlevel 1 (
    echo 备份创建失败，5秒后重试...
    timeout /t 5 /nobreak >nul
    goto retry_backup
)

:: 获取设备ID
echo 正在获取设备ID...
set "DeviceID="
set "retry_count=0"
:retry_get_id
for /f "delims=" %%a in ('adb shell "ls /sdcard/TWRP/BACKUPS/" 2^>nul') do (
    set "DeviceID=%%a"
)
if "!DeviceID!"=="" (
    set /a "retry_count+=1"
    if !retry_count! geq 5 (
        echo 无法获取设备ID，请检查TWRP备份是否创建成功
        goto cleanup
    )
    echo 无法获取设备ID，5秒后重试...
    timeout /t 5 /nobreak >nul
    goto retry_get_id
)

set "backup_name=!DeviceID!/!timestamp!"

:: 拉取备份文件和vendor
echo 正在拉取备份文件和vendor...
cd "%tool_dir%"
mkdir "!push_dir!\TWRP" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS\!DeviceID!" >nul 2>&1

set "retry_count=0"
:retry_pull
"%adb_path%"\adb.exe pull /sdcard/TWRP/BACKUPS/!backup_name! "!push_dir!\TWRP\BACKUPS\!DeviceID!\!timestamp!"
if errorlevel 1 (
    echo 拉取备份失败，5秒后重试...
    timeout /t 5 /nobreak >nul
    goto retry_pull
)

set "retry_count=0"
:retry_pull_vendor
"%adb_path%"\adb.exe pull /sdcard/vendor.bin "!push_dir!"
if errorlevel 1 (
    echo 拉取vendor分区失败，5秒后重试...
    timeout /t 5 /nobreak >nul
    goto retry_pull_vendor
)

:: 清除设备上的文件
echo 正在清除设备上的备份文件和vendor分区...
set "retry_count=0"
:retry_clean_device
"%adb_path%"\adb.exe shell "rm -rf /sdcard/TWRP/BACKUPS/!backup_name! /sdcard/vendor.bin"
if errorlevel 1 (
    echo 清除设备文件失败，5秒后重试...
    timeout /t 5 /nobreak >nul
    goto retry_clean_device
)

:skip_clean
"%adb_path%"\adb.exe shell reboot
echo 文件获取完成，设备已重启，现在可以断开连接了。

:: 收集设备信息
echo.
echo 请提供设备信息...
echo.

set "device="
set /p "device=请输入设备型号: "

set "soc="
set /p "soc=请输入处理器型号: "

set "system="
set /p "system=请输入系统版本: "

set "arch="
set /p "arch=请输入设备架构(arm/arm64): "

set "sar_device="
set /p "sar_device=是否是SAR设备(true/false): "

set "ab_device="
set /p "ab_device=是否是A/B分区设备(true/false): "

set "treble="
set /p "treble=请输入Treble支持信息: "

set "fix="
set /p "fix=请输入修复内容: "

set "ext="
set /p "ext=请输入扩展内容: "

set "maker="
set /p "maker=请输入制作者: "

:: 创建配置文件
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
set /p "compress=是否压缩整合包? (Y/N): "

if /i "!compress!"=="Y" (
    if not exist "%seven_zip_dir%" (
        echo 7za.exe不存在，无法压缩整合包
        goto skip_compress
    )
    
    echo 正在打包整合包...
    cd /d "!work_dir!"
    "%seven_zip_dir%" a -mmt -mx9 -t7z "..\!package_name!.7z" "flash_files"
    if errorlevel 1 (
        echo 打包失败
        set "cleanup_failed="
        set /p "cleanup_failed=是否清理整合包文件? (Y/N): "
        if /i "!cleanup_failed!"=="Y" (
            goto cleanup
        ) else (
            echo 整合包保留在: !work_dir!
            goto final_message
        )
    )
    
    echo 打包成功!
    for %%A in ("..\!package_name!.7z") do set "archive_size_mb=%%~zA"
    set /a "archive_size_mb=!archive_size_mb!/1048576"
    
    set "delete_source="
    set /p "delete_source=是否删除源文件? (Y/N): "
    if /i "!delete_source!"=="Y" (
        echo 正在删除源文件...
        rmdir /s /q "!work_dir!" >nul 2>&1
        set "final_message=整合包已保存为: %tool_dir%!package_name!.7z (!archive_size_mb! MB)，源文件已删除"
    ) else (
        set "final_message=整合包已保存为: %tool_dir%!package_name!.7z (!archive_size_mb! MB)，源文件保留在: !work_dir!"
    )
) else (
    :skip_compress
    echo 跳过压缩步骤
    set "final_message=整合包文件已保存在: !work_dir!"
)

:cleanup
echo 关闭adb服务...
"%adb_path%"\adb.exe kill-server >nul 2>&1
echo 正在清理临时文件...
rmdir /s /q "!work_dir!" >nul 2>&1
echo 已清理临时文件

:final_message
echo.
echo ===============================================================================
echo 整合包制作完成!
echo !final_message!
echo ===============================================================================
echo.
pause