@echo off
title UPac Tool v1.3.3 - ���ߣ����ι⣬QQ��3981750101

:main_menu
cls
echo ============================================
echo            UPac Tool v1.3.3
echo           ���ߣ����ι�
echo           QQ��3981750101
echo ============================================
echo.
echo     ��ѡ��Ҫִ�еĹ��ܣ�
echo.
echo     1. ˢ��
echo     2. �������ϰ�
echo     3. �˳�����
echo.
set /p choice=������ѡ��(1/2/3):

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

echo ������Ч���밴���������ѡ��...
pause >nul
goto main_menu
