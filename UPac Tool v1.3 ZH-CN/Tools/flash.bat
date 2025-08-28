@ECHO OFF
setlocal enabledelayedexpansion

set "bin_path=%cd%\bin"
set "spd_dump_path=%cd%\bin\spd_dump" 
set "adb_path=%cd%\bin\adb_fastboot\adb.exe" 
set "seven_zip_dir=%cd%\bin\7z" 
set "dump_files=%cd%\flash_files\dump" 
set "push_path=%cd%\flash_files\push"  
set "flash_path=%cd%\flash_files" 
echo 关闭adb服务...
"%adb_path%" kill-server

:load_set
:: 加载配置文件
if exist "%flash_path%\set.bat" (
    call "%flash_path%\set.bat"  
    goto start
) else (
    echo 错误：未找到配置文件 set.bat
    goto load_package
)

:load_package
echo 请拖入整合包7z文件或flash_files文件夹：
set /p package_path=拖入文件或文件夹后按回车: 
set "package_path=%package_path:"=%"  :: 移除可能的引号

if exist "%package_path%\" (
    :: 输入的是文件夹
    echo 检测到文件夹输入...
    if not exist "%package_path%\set.bat" (
        echo 错误：文件夹中未找到 set.bat 配置文件
        pause
        goto load_package
    )
    echo 正在复制整合包文件夹...
    if exist flash_files rmdir /s /q flash_files
    xcopy "%package_path%" "flash_files" /E /I /H /Y
    if errorlevel 1 (
        echo 复制失败，请检查权限
        pause
        goto load_package
    )
    echo 文件夹复制成功！
    goto load_set
) else if exist "%package_path%" (
    echo 检测到文件输入...
    if /i not "%package_path:~-3%"==".7z" (
        echo 错误：只支持.7z格式的压缩包
        pause
        goto load_package
    )
    echo 正在加载整合包...
    if exist flash_files rmdir /s /q flash_files
    "%seven_zip_dir%\7zr" x "%package_path%" -o"%cd%"
    if errorlevel 1 (
        echo 解压失败，请检查文件
        pause
        goto load_package
    )
    goto load_set
) else (
    echo 文件或文件夹不存在，请重新输入
    goto load_package
)

:start
set "backup_path=%push_path%\TWRP\BACKUPS\%backup_name%"
title 展锐整合包Downloader - %device%  :: 设置窗口标题
ECHO.整合包信息已加载。
ECHO.===============================================================================
ECHO.                               整合包信息
ECHO.===============================================================================
ECHO. 适用型号: %device%
ECHO. 处理器: %soc% 
ECHO. 刷入的系统: %system%  
ECHO. 架构: %arch%  
ECHO. SAR设备: %sar_device%  
ECHO. A/B分区: %ab_device% 
ECHO. Treble支持: %treble%  
ECHO. BROM模式: %dump_mode%  
ECHO. 修复：%fix%  
ECHO. 扩展：%ext%  
ECHO. 制作: %maker%  
ECHO.===============================================================================
ECHO.by  独の光

:: 添加用户选择功能
:package_selection
ECHO.
ECHO.请选择操作:
ECHO.  1 - 使用当前整合包继续
ECHO.  2 - 加载另一个整合包
set /p choice=请输入选项 (1/2):

if /I "%choice%"=="2" goto load_package
if /I "%choice%"=="1" goto select_mode
ECHO.输入无效，请重新输入
goto package_selection

:select_mode
:: 选择操作模式
ECHO.请选择操作模式:
ECHO.1. 从第一步开始（完整流程）
ECHO.2. 从任意一步继续
set /p mode=请选择:
if %mode%==1 goto ask_unattended
if %mode%==2 goto ask_unattended_step
ECHO.输入错误
pause
goto select_mode

:ask_unattended
:: 询问是否无人值守模式
set /p unattended=是否进入无人值守模式？(1/2):
if /I "%unattended%"=="1" set UNATTENDED=1
goto unlock

:ask_unattended_step
set /p unattended=是否进入无人值守模式？(1/2):
if /I "%unattended%"=="2" set UNATTENDED=1
goto choose_step

:choose_step
:: 选择从哪一步继续
ECHO.请选择继续的步骤:
ECHO.2.格式化data为f2fs并推送TWRP文件夹
ECHO.3.刷入vendor分区
ECHO.4.从TWRP备份还原系统
set /p step=请选择:
if %step%==2 goto format_data
if %step%==3 goto flash_vendor
if %step%==4 goto restore_system
ECHO.输入错误
if defined UNATTENDED goto choose_step
pause
goto choose_step

:retry_unlock
ECHO.重试解锁...
:unlock
:: 步骤1：解锁Bootloader
ECHO.=== 步骤1/4：解锁Bootloader并刷入镜像 ===
if not defined UNATTENDED (
    ECHO.请将设备关机，然后直接连接电脑...
    pause
)
ECHO.卡在等待dl_diag请尝试重连设备或检查驱动（剩余15分钟）
cd "%dump_files%"

ECHO.使用kick_fxxk_avb模式解锁...
"%spd_dump_path%"\spd_dump --wait 1000 --kickto 2 e splloader e splloader_bak reset
"%spd_dump_path%"\spd_dump --wait 1000 timeout 10000 fdl fdl1.bin %fdl1_path% fdl fdl2.bin %fdl2_path% exec w splloader splloader.bin w uboot uboot.bin w trustos trustos.bin w recovery "%backup_path%"\recovery.emmc.win reboot-recovery

ECHO.操作完成！已解锁Bootloader并刷入镜像。
ECHO.开机将直接进入TWRP恢复模式...

:unlock_confirm
if defined UNATTENDED goto format_data
set /p confirm=是否成功解锁Bootloader并进入Recovery？[Y/N]：
if /I "%confirm%"=="Y" goto format_data
if /I "%confirm%"=="N" goto retry_unlock
ECHO.输入错误，请输入Y或N
goto unlock_confirm

:format_data
:: 步骤2：格式化数据分区
ECHO.=== 步骤2/4：格式化data分区 ===
ECHO.等待设备进入Recovery...
if not defined UNATTENDED (
    pause
)

ECHO.解除data分区挂载...
:unmount_retry
"%adb_path%" shell twrp unmount data
if errorlevel 1 (
    echo 设备未连接，或解除挂载失败，重试...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto unmount_retry
)

ECHO.格式化data分区为f2fs...
"%adb_path%" shell mkfs.f2fs /dev/block/by-name/userdata
if errorlevel 1 (
    echo 格式化失败，重试...
    if not defined UNATTENDED pause
    goto unmount_retry
)

ECHO.TWRP格式化...
:twrp_format_retry
"%adb_path%" shell twrp format data
if errorlevel 1 (
    echo TWRP格式化失败，重试...
    if not defined UNATTENDED pause
    goto twrp_format_retry
)

ECHO.格式化完成，正在重启设备...
"%adb_path%" reboot recovery
ECHO.等待设备进入Recovery...
if not defined UNATTENDED pause

ECHO.推送TWRP文件夹和vendor.bin...
:push_retry
"%adb_path%" push "%push_path%\." /sdcard/
if errorlevel 1 (
    echo 设备未连接，或推送文件失败，重试...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto push_retry
)

goto flash_vendor

:flash_vendor
:: 步骤3：刷入vendor分区
ECHO.=== 步骤3/4：刷入vendor分区 ===
ECHO.正在刷入vendor分区...
:flash_vendor_retry
"%adb_path%" shell dd if=/sdcard/vendor.bin of=/dev/block/by-name/vendor
if errorlevel 1 (
    echo 刷入vendor分区失败，重试...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto flash_vendor_retry
)

ECHO.刷入vendor分区完成！
goto restore_system

:restore_system
:: 步骤4：从TWRP备份还原系统
ECHO.=== 步骤4/4：从TWRP备份还原系统 ===
"%adb_path%" shell reboot recovery
ECHO.等待设备进入Recovery...
if not defined UNATTENDED (
    pause
)

ECHO.从TWRP备份还原系统...
:restore_retry
"%adb_path%" shell twrp restore /sdcard/TWRP/BACKUPS/%backup_name% SDRB
if errorlevel 1 (
    echo 恢复系统失败，或设备未连接，重试...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto restore_retry
)

ECHO.删除TWRP备份文件夹和vendor.bin以释放空间...
:delete_backup_retry
"%adb_path%" shell rm -rf /sdcard/TWRP/BACKUPS/%backup_name%
if errorlevel 1 (
    echo 删除备份失败，重试...
    timeout /t 2 /nobreak >nul
    goto delete_backup_retry
)

:delete_vendor_retry
"%adb_path%" shell rm -f /sdcard/vendor.bin
if errorlevel 1 (
    echo 删除vendor.bin失败，重试...
    timeout /t 2 /nobreak >nul
    goto delete_vendor_retry
)

ECHO.操作成功！正在重启设备...
"%adb_path%" reboot
ECHO.=== 恭喜！所有步骤已完成！ ===
ECHO.设备即将启动进入%system%系统...
pause
goto start