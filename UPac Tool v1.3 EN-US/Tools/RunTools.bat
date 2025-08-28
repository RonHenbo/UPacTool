@echo off
title UPac Tool v1.2 - Author: ¶À¤Î¹â, QQ: 3981750101

:main_menu
cls
echo ============================================
echo            UPac Tool v1.2
echo           Author: ¶À¤Î¹â
echo           QQ: 3981750101
echo ============================================
echo.
echo     Please select an option:
echo.
echo     1. Flash
echo     2. Create Integration Package
echo     3. Exit Tool
echo.
set /p choice=Please enter your choice (1/2/3):

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

echo Invalid input, press any key to try again...
pause >nul
goto main_menu

