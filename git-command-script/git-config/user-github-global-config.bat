@echo off
setlocal enabledelayedexpansion

title Git User Identity Setup

echo ======================================================
echo           Git User Identity Configuration
echo ======================================================
echo.

:: 1. Verify Git installation
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Git is not installed or not found in system PATH.
    goto :FAIL
)

:: 2. Detect current configuration
set "CURRENT_NAME="
for /f "delims=" %%i in ('git config --global user.name 2^>nul') do set "CURRENT_NAME=%%i"

set "CURRENT_EMAIL="
for /f "delims=" %%i in ('git config --global user.email 2^>nul') do set "CURRENT_EMAIL=%%i"

echo [INFO] Current Global Git Identity:
if defined CURRENT_NAME (
    echo   user.name  : !CURRENT_NAME!
) else (
    echo   user.name  : (Not configured)
)

if defined CURRENT_EMAIL (
    echo   user.email : !CURRENT_EMAIL!
) else (
    echo   user.email : (Not configured)
)
echo ------------------------------------------------------
echo.

:: 3. Prompt for user.name
:PROMPT_NAME
set "INPUT_NAME="
if defined CURRENT_NAME (
    set /p "INPUT_NAME=Enter your Git user name [Press ENTER for '!CURRENT_NAME!']: "
    if "!INPUT_NAME!"=="" set "INPUT_NAME=!CURRENT_NAME!"
) else (
    set /p "INPUT_NAME=Enter your Git user name (e.g. GitHub username): "
)
set "INPUT_NAME=!INPUT_NAME:"=!"

if "!INPUT_NAME!"=="" (
    echo [WARNING] Name cannot be empty. Please enter a valid name.
    goto :PROMPT_NAME
)

:: 4. Prompt for user.email
:PROMPT_EMAIL
set "INPUT_EMAIL="
if defined CURRENT_EMAIL (
    set /p "INPUT_EMAIL=Enter your Git email [Press ENTER for '!CURRENT_EMAIL!']: "
    if "!INPUT_EMAIL!"=="" set "INPUT_EMAIL=!CURRENT_EMAIL!"
) else (
    set /p "INPUT_EMAIL=Enter your Git email (e.g. GitHub email): "
)
set "INPUT_EMAIL=!INPUT_EMAIL:"=!"

if "!INPUT_EMAIL!"=="" (
    echo [WARNING] Email cannot be empty. Please enter a valid email.
    goto :PROMPT_EMAIL
)

:: 5. Select configuration scope
echo.
echo Configuration Scope:
echo   1) Global (--global) - Apply to all repositories on this machine [Default]
echo   2) Local  (--local)  - Apply only to the current repository
set "SCOPE_CHOICE="
set /p "SCOPE_CHOICE=Select scope [1/2, default: 1]: "
if "!SCOPE_CHOICE!"=="" set "SCOPE_CHOICE=1"

if "!SCOPE_CHOICE!"=="2" (
    git rev-parse --is-inside-work-tree >nul 2>&1
    if !errorlevel! neq 0 (
        echo [WARNING] Current directory is not a Git repository. Falling back to global scope.
        set "SCOPE_FLAG=--global"
    ) else (
        set "SCOPE_FLAG=--local"
    )
) else (
    set "SCOPE_FLAG=--global"
)

:: 6. Apply configuration
git config !SCOPE_FLAG! user.name "!INPUT_NAME!"
git config !SCOPE_FLAG! user.email "!INPUT_EMAIL!"

:: 7. Verify updated configuration
set "VERIFY_NAME="
for /f "delims=" %%i in ('git config !SCOPE_FLAG! user.name 2^>nul') do set "VERIFY_NAME=%%i"

set "VERIFY_EMAIL="
for /f "delims=" %%i in ('git config !SCOPE_FLAG! user.email 2^>nul') do set "VERIFY_EMAIL=%%i"

echo.
echo ======================================================
echo [SUCCESS] Git identity configured successfully!
echo Scope      : !SCOPE_FLAG!
echo user.name  : !VERIFY_NAME!
echo user.email : !VERIFY_EMAIL!
echo ======================================================
echo.
goto :FINISH

:FAIL
echo.
echo Execution terminated with errors.

:FINISH
pause