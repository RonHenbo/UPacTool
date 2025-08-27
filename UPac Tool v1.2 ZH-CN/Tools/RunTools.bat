@echo off
title UPac Tool v1.2 - 作者：独の光，QQ：3981750101

:main_menu
cls
echo ============================================
echo            UPac Tool v1.2
echo           作者：独の光
echo           QQ：3981750101
echo ============================================
echo.
echo     请选择要执行的功能：
echo.
echo     1. 刷机
echo     2. 制作整合包
echo     3. 退出工具
echo.
set /p choice=请输入选项(1/2/3):

if "%choice%"=="1" (
    cls
    call flash.bat
    goto main_menu
)

if "%choice%"=="2" (
    cls
    call maker.bat
    goto main_menu
)

if "%choice%"=="3" (
    exit
)

echo 输入无效，请按任意键重新选择...
pause >nul
goto main_menu
