@echo off
setlocal enabledelayedexpansion

title Gitee Remote Switch to SSH Tool

echo ======================================================
echo     Gitee Remote Switcher (Two Levels Below Project)
echo ======================================================
echo.

:: 1. Resolve default target directory (Two levels up from script)
for %%I in ("%~dp0..\..") do (
    set "DEFAULT_PROJECT_DIR=%%~fI"
    set "DEFAULT_PROJ_NAME=%%~nxI"
)

:: 2. Verify Git installation
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Git is not installed or not found in system PATH.
    goto :FAIL
)

:: 3. Check Gitee SSH key authentication
echo [1/4] Checking Gitee SSH authentication...
set "TEMP_SSH_LOG=%TEMP%\gitee_ssh_test_%RANDOM%.log"
ssh -T -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new git@gitee.com > "%TEMP_SSH_LOG%" 2>&1

findstr /i "successfully authenticated" "%TEMP_SSH_LOG%" >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] Gitee SSH authentication verified successfully!
) else (
    echo [WARNING] No valid Gitee SSH authentication detected.
    echo SSH test output:
    type "%TEMP_SSH_LOG%"
    echo.
    echo Notice: If you have not added your public key to Gitee, please configure it before pushing.
    set "FORCE_CONT="
    set /p "FORCE_CONT=Do you still want to switch remote URL to SSH? (y/N): "
    if /i not "!FORCE_CONT!"=="Y" (
        if exist "%TEMP_SSH_LOG%" del "%TEMP_SSH_LOG%" >nul 2>&1
        echo Operation aborted.
        goto :FAIL
    )
)
if exist "%TEMP_SSH_LOG%" del "%TEMP_SSH_LOG%" >nul 2>&1
echo.

:: 4. Locate target Git repository
echo [2/4] Confirm target repository root directory
echo Default path    : !DEFAULT_PROJECT_DIR!
echo Project name    : !DEFAULT_PROJ_NAME!
set "TARGET_DIR="
set /p "TARGET_DIR=Enter repository root path [Press ENTER for default]: "
if "!TARGET_DIR!"=="" set "TARGET_DIR=!DEFAULT_PROJECT_DIR!"
set "TARGET_DIR=!TARGET_DIR:"=!"

if not exist "!TARGET_DIR!" (
    echo [ERROR] Directory not found: !TARGET_DIR!
    goto :FAIL
)

cd /d "!TARGET_DIR!" || (
    echo [ERROR] Failed to access directory: !TARGET_DIR!
    goto :FAIL
)

git rev-parse --is-inside-work-tree >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Directory '!TARGET_DIR!' is not a valid Git repository.
    goto :FAIL
)
echo [OK] Active repository: !TARGET_DIR!
echo.

:: 5. Inspect and convert remote origin URL
echo [3/4] Checking remote 'origin' URL...
set "CURRENT_URL="
for /f "delims=" %%U in ('git remote get-url origin 2^>nul') do set "CURRENT_URL=%%U"

if not defined CURRENT_URL (
    echo [WARNING] No remote 'origin' configured in this repository.
    set "REPO_INPUT="
    set /p "REPO_INPUT=Enter Gitee repository path (e.g. username/repository): "
    set "REPO_INPUT=!REPO_INPUT:"=!"
    if "!REPO_INPUT:~-4!"==".git" set "REPO_INPUT=!REPO_INPUT:~0,-4!"
    set "TARGET_SSH_URL=git@gitee.com:!REPO_INPUT!.git"
    git remote add origin "!TARGET_SSH_URL!"
    echo [OK] Remote 'origin' added: !TARGET_SSH_URL!
) else if "!CURRENT_URL:~0,14!"=="git@gitee.com:" (
    echo [INFO] Remote 'origin' is already configured with SSH: !CURRENT_URL!
    set "TARGET_SSH_URL=!CURRENT_URL!"
) else (
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$u = $env:CURRENT_URL; $u = $u -replace '^https?://([^@]+@)?gitee\.com[:/]', 'git@gitee.com:'; if (-not $u.EndsWith('.git')) { $u += '.git' }; $u"`) do set "TARGET_SSH_URL=%%A"

    echo Current URL (HTTPS) : !CURRENT_URL!
    echo Target URL  (SSH)   : !TARGET_SSH_URL!
    echo.
    set "CONFIRM_SWITCH="
    set /p "CONFIRM_SWITCH=Switch remote 'origin' to this SSH URL? [Y/n]: "
    if "!CONFIRM_SWITCH!"=="" set "CONFIRM_SWITCH=Y"
    if /i "!CONFIRM_SWITCH!"=="Y" (
        git remote set-url origin "!TARGET_SSH_URL!"
        echo [OK] Remote URL updated to SSH successfully.
    ) else (
        echo Operation canceled.
        goto :FINISH
    )
)
echo.

:: 6. Verify remote connection and permissions
echo [4/4] Verifying remote repository access...
git ls-remote origin HEAD >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] SSH connection verified!
    echo Active remote configuration:
    git remote -v
    echo.
    echo ======================================================
    echo  Setup complete! Future pushes will no longer ask for passwords.
    echo ======================================================
) else (
    echo [WARNING] Unable to read remote repository via SSH. Please verify:
    echo 1. Your Gitee account has read/write permissions to this repository.
    echo 2. Your SSH public key was added to the matching Gitee account.
)
goto :FINISH

:FAIL
echo.
echo Execution terminated with errors.

:FINISH
echo.
pause