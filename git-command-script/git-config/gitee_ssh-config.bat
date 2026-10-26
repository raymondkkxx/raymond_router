@echo off
setlocal enabledelayedexpansion

title Gitee SSH Automated Setup

echo ======================================================
echo            Gitee SSH Key Automated Setup
echo ======================================================
echo.

:: 1. Verify ssh-keygen and ssh availability
where ssh-keygen >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ssh-keygen is not found in system PATH.
    echo Please make sure OpenSSH Client or Git for Windows is installed.
    echo.
    pause
    exit /b 1
)

where ssh >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ssh command is not found in system PATH.
    echo.
    pause
    exit /b 1
)

:: 2. Prompt for Gitee email address
:PROMPT_EMAIL
set "GIT_EMAIL="
set /p "GIT_EMAIL=Enter your Gitee email address: "
if "%GIT_EMAIL%"=="" (
    echo [ERROR] Email address cannot be empty.
    goto PROMPT_EMAIL
)

set "SSH_DIR=%USERPROFILE%\.ssh"
set "KEY_PATH=%SSH_DIR%\id_ed25519"
set "PUB_PATH=%SSH_DIR%\id_ed25519.pub"
set "CONFIG_FILE=%SSH_DIR%\config"

:: 3. Create SSH Directory
if not exist "%SSH_DIR%" (
    mkdir "%SSH_DIR%" >nul 2>&1
)

:: 4. Generate Ed25519 Key Pair
if exist "%KEY_PATH%" (
    echo [INFO] Existing SSH key found at %KEY_PATH%
) else (
    echo [INFO] Generating new Ed25519 key pair...
    ssh-keygen -t ed25519 -C "%GIT_EMAIL%" -f "%KEY_PATH%" -N ""
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to generate SSH key pair.
        pause
        exit /b 1
    )
    echo [OK] SSH key generated.
)

:: 5. Configure SSH Client Config
if exist "%CONFIG_FILE%" (
    findstr /i "Host gitee.com" "%CONFIG_FILE%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [INFO] gitee.com entry already exists in %CONFIG_FILE%.
        goto SKIP_CONFIG
    )
)

echo [INFO] Writing SSH configuration...
>> "%CONFIG_FILE%" echo.
>> "%CONFIG_FILE%" echo Host gitee.com
>> "%CONFIG_FILE%" echo     HostName gitee.com
>> "%CONFIG_FILE%" echo     User git
>> "%CONFIG_FILE%" echo     IdentityFile ~/.ssh/id_ed25519
>> "%CONFIG_FILE%" echo     StrictHostKeyChecking no
echo [OK] Configured %CONFIG_FILE%.

:SKIP_CONFIG
:: 6. Display Public Key and copy to clipboard
echo.
echo ======================================================
echo  [ACTION REQUIRED] Add this public key to Gitee:
echo  1. Open: https://gitee.com/profile/sshkeys
echo  2. Set a Title (e.g. Windows-PC)
echo  3. Paste the key below into 'Key' (公钥):
echo     (The public key has been copied to your clipboard!)
echo ======================================================
echo.

if exist "%PUB_PATH%" (
    type "%PUB_PATH%"
    clip < "%PUB_PATH%"
) else (
    echo [ERROR] Public key file not found: %PUB_PATH%
    pause
    exit /b 1
)

echo.
echo ======================================================
echo.

:: 7. Verification Test
echo After saving the key on Gitee, press any key to test connection...
pause >nul
echo.
echo [INFO] Verifying authentication with Gitee...

set "TEST_LOG=%TEMP%\gitee_ssh_test.log"
ssh -T -o StrictHostKeyChecking=no git@gitee.com > "%TEST_LOG%" 2>&1

echo.
echo -------------------- Gitee Response -------------------
type "%TEST_LOG%"
echo -------------------------------------------------------
echo.

findstr /i "successfully authenticated" "%TEST_LOG%" >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] Gitee SSH connection verified successfully!
) else (
    echo [NOTICE] If the message above shows 'Hi <username>! You've successfully authenticated', it is working.
    echo Otherwise, please check if the public key was properly saved on Gitee.
)

if exist "%TEST_LOG%" del "%TEST_LOG%" >nul 2>&1

echo.
pause