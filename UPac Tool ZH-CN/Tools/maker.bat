@echo off
setlocal enabledelayedexpansion

title 展锐整合包制作工具

set "tool_dir=%cd%"

set "spd_dump_path=%cd%\bin\spd_dump"
set "adb_path=%cd%\bin\adb_fastboot\"
set "seven_zip_dir=%cd%\bin\7z"
cd %adb_path%

:start
cls
echo ===============================================================================
echo.                        展锐整合包制作工具 By 独の光
echo ===============================================================================
echo.

set /p "package_name=请输入整合包名称: "
if "!package_name!"=="" (
    echo 整合包名称不能为空!
    timeout /t 2 /nobreak >nul
    goto start
)

set "work_dir=%cd%\!package_name!"
set "flash_files_dir=!work_dir!\flash_files"
set "dump_dir=!flash_files_dir!\dump"
set "push_dir=!flash_files_dir!\push"

echo 关闭adb服务...
adb kill-server >nul 2>&1
if exist "!work_dir!" (
    rmdir /s /q "!work_dir!" >nul 2>&1
)

mkdir "!work_dir!" >nul 2>&1
mkdir "!flash_files_dir!" >nul 2>&1
mkdir "!dump_dir!" >nul 2>&1
mkdir "!push_dir!" >nul 2>&1

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

set /p "fdl1_path=请输入第一个FDL文件的路径地址: "
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

set /p "fdl2_path=请输入第二个FDL文件的路径地址: "
if "!fdl2_path!"=="" (
    echo 路径地址不能为空
    goto get_fdl2
)

copy /y "!fdl2_file!" "!dump_dir!\fdl2.bin" >nul

echo.
echo 准备读取底层分区，请关闭设备，然后直接连接电脑...
cd /d "!dump_dir!"
"%spd_dump_path%\spd_dump.exe" --wait 1000 --kickto 2 blk_size 65535 r splloader r trustos r uboot reboot-recovery

if errorlevel 1 (
    echo 读取分区失败，请检查设备连接和驱动
    pause
    goto cleanup
)

echo 分区读取成功!
timeout /t 3 /nobreak >nul

echo 等待设备进入TWRP恢复模式...
:wait_recovery
cd %adb_path%
adb wait-for-recovery >nul 2>&1
if errorlevel 1 (
    echo 设备未进入恢复模式，请手动进入TWRP后按任意键继续...
    pause
    goto wait_recovery
)

echo 正在获取vendor路径...

for /f "tokens=*" %%a in ('adb shell "find /dev/block -name vendor"') do (
    set "vendor_path=%%a"
    goto :dd_vendor
)

:dd_vendor
adb shell "dd if=%vendor_path% of=/sdcard/vendor.bin"
if errorlevel 1 (
    echo.path:%vendor_path%
    echo 提取vendor分区失败，5秒后重试...
    timeout /t 5 /nobreak >nul
    goto dd_vendor
)

echo 正在创建TWRP备份...
set "timestamp=!date:~0,4!!date:~5,2!!date:~8,2!!time:~0,2!!time:~3,2!!time:~6,2!"
set "timestamp=!timestamp: =0!"

:retry_backup
adb shell "twrp backup SDRB !timestamp!"
if errorlevel 1 (
    echo 备份创建失败，5秒后重试...
    timeout /t 5 /nobreak >nul
    goto retry_backup
)

echo 正在获取设备ID...
:retry_get_id
for /f "delims=" %%a in ('adb shell "ls /sdcard/TWRP/BACKUPS/" 2^>nul') do (
    set "DeviceID=%%a"
    goto :break_get_id
)
:break_get_id
if "!DeviceID!"=="" (
    echo 无法获取设备ID，5秒后重试...
    timeout /t 5 /nobreak >nul
    goto retry_get_id
)
set "backup_name=!DeviceID!/!timestamp!"

echo 正在拉取备份文件和vendor...
mkdir "!push_dir!\TWRP" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS" >nul 2>&1
mkdir "!push_dir!\TWRP\BACKUPS\!DeviceID!" >nul 2>&1

:retry_pull
adb pull /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp! "!push_dir!\TWRP\BACKUPS\!DeviceID!\!timestamp!" && (
    adb pull /sdcard/vendor.bin "!push_dir!"
)
if errorlevel 1 (
    echo 拉取备份或vendor分区失败，5秒后重试...
    timeout /t 5 /nobreak >nul
    goto retry_pull
)

echo 正在清除设备上的备份文件和vendor分区...
:retry_clean_device
adb shell "rm -rf /sdcard/TWRP/BACKUPS/!DeviceID!/!timestamp! /sdcard/vendor.bin"
if errorlevel 1 (
    echo 清除设备备份和vendor分区失败，5秒后重试...
    timeout /t 5 /nobreak >nul
    goto retry_clean_device
)

adb shell reboot
echo 文件获取完成，设备已重启，现在可以断开连接了。

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

:: 询问是否压缩
echo.
set /p "compress=是否压缩整合包? (Y/N): "
if /i "!compress!"=="Y" (
    echo 正在打包整合包...
    cd /d "!work_dir!"
    "%seven_zip_dir%\7z.exe" a -mx9 -t7z "..\!package_name!.7z" "flash_files" >nul
    
    if errorlevel 1 (
        echo 打包失败
        set /p "cleanup_failed=是否清理整合包文件? (Y/N): "
        if /i "!cleanup_failed!"=="Y" (
            goto cleanup
        ) else (
            echo 整合包保留在: !work_dir!
            goto final_message
        )
    )
    
    echo 打包成功!
    set /p "delete_source=是否删除源文件? (Y/N): "
    if /i "!delete_source!"=="Y" (
        echo 正在删除源文件...
        rmdir /s /q "!work_dir!" >nul 2>&1
        set "final_message=整合包已保存为: %cd%\!package_name!.7z，源文件已删除"
    ) else (
        set "final_message=整合包已保存为: %cd%\!package_name!.7z，源文件保留在: !work_dir!"
    )
) else (
    echo 跳过压缩步骤
    set "final_message=整合包文件已保存在: !work_dir!"
)

:final_message
cd /d "%tool_dir%"
echo 关闭adb服务...
adb kill-server

echo.
echo ===============================================================================
echo 整合包制作完成!
echo !final_message!
echo ===============================================================================
echo.
pause
exit /b 0

:cleanup
cd /d "%tool_dir%"
echo 关闭adb服务...
adb kill-server
if exist "!work_dir!" (
    echo 正在清理临时文件...
    rmdir /s /q "!work_dir!" >nul 2>&1
)
goto final_message