@echo off
rem 先切到 UTF-8，运行完再切回 936
chcp 65001 >nul
title h3cnx30pro（MT7981）串口TTL救砖debricksolution

set "FIP_FILE=mt7981_h3c_magic-nx30-pro-fip-debrick-only-fixed-parts_20241010.bin"
echo  _             _          _
echo   __ _    ___  ^| ^|_   _ __   (_)   ___  (_)   ___    _ __         ___    ___    _ __ ___
echo  / _` ^|  / _ \ ^| __^| ^| '_ \  ^| ^|  / __^| ^| ^|  / _ \  ^| '_ \       / __^|  / _ \  ^| '_ ` _ \
echo ^| (_^| ^| ^|  __/ ^| ^|_  ^| ^|_) ^| ^| ^| ^| (__  ^| ^| ^| (_) ^| ^| ^| ^| ^|  _  ^| (__  ^| (_) ^| ^| ^| ^| ^| ^| ^|
echo  \__, ^|  \___^|  \__^| ^| .__/  ^|_^|  \___^| ^|_^|  \___/  ^|_^| ^|_^| (_)  \___^|  \___/  ^|_^| ^|_^| ^|_^|_^|
echo " |___/               |_|"
echo 勇爱设计network出品
echo 更多教程工具尽在getpicion.com
echo release by getpicion.com
echo h3cnx30pro救砖TTL工具debrick
echo 请输入串口号input com (如 3):
set /p comPort=

set "comPort=%comPort:COM=%"
set "comPort=%comPort:com=%"

echo 使用串口 COM%comPort%
echo.

echo 选择波特率Baudrate:
echo 1. 正常normal (921600 / 1500000)
echo 2. 低速 low(115200 / 115200)
set /p baudRate=

if "%baudRate%"=="2" (
    set BromBaudRate=115200
    set Bl2BaudRate=115200
) else (
    set BromBaudRate=921600
    set Bl2BaudRate=1500000
)

set "bl2Path=.\mtk_uartboot\bl2-ram-boot\mt7981-ddr3-bl2-ram-boot.bin"
set "fipPath=.\mtk_uartboot\fip-debrick-only\%FIP_FILE%"

echo 程序启动后请立刻给路由器插上电源Plug the router in immediately after the program starts
echo Web Failsafe: http://192.168.1.1/uboot.html
echo.

.\mtk_uartboot\mtk_uartboot.exe -s COM%comPort% -p "%bl2Path%" -a -f "%fipPath%" --brom-load-baudrate %BromBaudRate% --bl2-load-baudrate %Bl2BaudRate%

timeout /t 1 >nul
.\mtk_uartboot\SimplySerial\ss.exe --com:%comPort% --baud:115200 --quiet
