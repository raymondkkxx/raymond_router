@echo off
chcp 65001 >nul
title nx30proTTL 串口工具

echo ==========================================
echo nx30pro TTL 检测工具
echo Using SimplySerial
echo getpicion.com勇爱设计network出品
echo ==========================================
echo  _             _          _
echo   __ _    ___  ^| ^|_   _ __   (_)   ___  (_)   ___    _ __         ___    ___    _ __ ___
echo  / _` ^|  / _ \ ^| __^| ^| '_ \  ^| ^|  / __^| ^| ^|  / _ \  ^| '_ \       / __^|  / _ \  ^| '_ ` _ \
echo ^| (_^| ^| ^|  __/ ^| ^|_  ^| ^|_) ^| ^| ^| ^| (__  ^| ^| ^| (_) ^| ^| ^| ^| ^|  _  ^| (__  ^| (_) ^| ^| ^| ^| ^| ^| ^|
echo  \__, ^|  \___^|  \__^| ^| .__/  ^|_^|  \___^| ^|_^|  \___/  ^|_^| ^|_^| (_)  \___^|  \___/  ^|_^| ^|_^| ^|_^|_^|
echo " |___/               |_|"

echo 更多教程工具尽在getpicion.com
echo.

:: ===== 第一步：输入串口号 =====
set /p comPort=请输入串口号（如 3 表示 COM3）:
set "comPort=%comPort:COM=%"
set "comPort=%comPort:com=%"

:: ===== 第二步：确认SimplySerial路径 =====
set SS=.\mtk_uartboot\SimplySerial\ss.exe
if not exist "%SS%" (
    echo 错误：未找到 SimplySerial 工具！
    echo 请确保路径为：.\mtk_uartboot\SimplySerial\ss.exe
    pause
    exit /b
)

echo.
echo 使用串口 COM%comPort% @115200（nx30pro固定波特率）
echo 提示：先不要给路由器上电，按回车后再通电！
echo.
pause

:: ===== 第三步：仅打开串口（后台运行）=====
echo 正在打开串口 COM%comPort%...
start "" "%SS%" --com:%comPort% --baud:115200 --quiet
timeout /t 2 >nul

echo.
echo ==========================================
echo 如果你已看到跑代码进度，说明连接成功,如果失败检查原因断电重试
echo Web Failsafe: 勇爱设计network荣誉出品
echo ==========================================
pause