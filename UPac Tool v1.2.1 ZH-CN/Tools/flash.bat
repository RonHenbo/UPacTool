@ECHO OFF
:: 设置各个工具的路径
set "bin_path=%cd%\bin"
set "spd_dump_path=%cd%\bin\spd_dump"  :: SPD刷机工具路径
set "adb_path=%cd%\bin\adb_fastboot\adb.exe"  :: ADB工具路径
set "seven_zip_dir=%cd%\bin\7z"  :: 7-Zip解压工具路径
set "dump_files=%cd%\flash_files\dump"  :: 转储文件目录
set "push_path=%cd%\flash_files\push"  :: 推送文件目录
set "flash_path=%cd%\flash_files"  :: 刷机文件根目录

:load_set
:: 加载配置文件
if exist "%flash_path%\set.bat" (
    call "%flash_path%\set.bat"  :: 调用配置文件
    goto after_load
) else (
    echo 错误：未找到配置文件 set.bat
    goto load_package
)

:load_package
:: 加载刷机包
echo 请拖入整合包7z文件：
set /p package_path=拖入文件后按回车: 
if not exist "%package_path%" (
    echo 文件不存在，请重新输入
    goto load_package
)
echo 正在加载整合包...
if exist flash_files rmdir /s /q flash_files  :: 清理旧文件
"%seven_zip_dir%\7zr" x "%package_path%" -o"%cd%"  :: 解压刷机包
if errorlevel 1 (
    echo 解压失败，请检查文件
    pause
    goto load_package
)
goto load_set

:after_load
:: 检查并设置dump_mode默认值
if not defined dump_mode set dump_mode=kick_fxxk_avb

:: 设置TWRP备份路径
set "backup_path=%push_path%\TWRP\BACKUPS\%backup_name%"

:start
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
ECHO.3.从TWRP备份还原系统
ECHO.4.清理设备上的TWRP备份文件
set /p step=请选择:
if %step%==2 goto format_data
if %step%==3 goto restore_system
if %step%==4 goto cleanup_backup
ECHO.输入错误
if defined UNATTENDED goto choose_step
pause
goto choose_step

:retry_unlock
ECHO.重试解锁...
:unlock
:: 步骤1：解锁Bootloader
ECHO.=== 步骤1/3：解锁Bootloader并刷入镜像 ===
if not defined UNATTENDED (
    ECHO.请将设备关机，然后直接连接电脑...
    pause
)
ECHO.卡在等待dl_diag请尝试重连设备或检查驱动（剩余15分钟）
cd "%dump_files%"

:: 仅使用kick_fxxk_avb模式解锁
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
ECHO.=== 步骤2/3：格式化data分区 ===
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

ECHO.推送TWRP文件夹...
:push_retry
"%adb_path%" push "%push_path%\." /sdcard/
"%adb_path%" push "%bin_path%\.twrps" /sdcard/TWRP/
if errorlevel 1 (
    echo 设备未连接，或推送TWRP文件夹失败，重试...
    if not defined UNATTENDED pause
    timeout /t 5 /nobreak >nul
    goto push_retry
)

goto restore_system

:restore_system
:: 步骤3：从TWRP备份还原系统
ECHO.=== 步骤3/3：从TWRP备份还原系统 ===
"%adb_path%" shell reboot recovery
ECHO.等待设备进入Recovery...
if not defined UNATTENDED (
    pause
)
