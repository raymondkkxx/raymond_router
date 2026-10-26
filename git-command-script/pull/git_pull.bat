@echo off
setlocal enabledelayedexpansion

echo ======================================================
echo       Git Remote Branch ^& Sync to Latest Tool
echo ======================================================
echo.

:: 1. Configure repository path with defaults (Resolve two levels up)
for %%I in ("%~dp0..\..") do (
    set "DEFAULT_DIR=%%~fI"
    set "DEFAULT_PROJ=%%~nxI"
)

set /p "TARGET_DIR=Enter base directory path [Press ENTER for !DEFAULT_DIR!]: "
if "!TARGET_DIR!"=="" set "TARGET_DIR=!DEFAULT_DIR!"
set "TARGET_DIR=!TARGET_DIR:"=!"

set /p "TARGET_PROJ=Enter project folder name [Press ENTER for !DEFAULT_PROJ!]: "
if "!TARGET_PROJ!"=="" set "TARGET_PROJ=!DEFAULT_PROJ!"
set "TARGET_PROJ=!TARGET_PROJ:"=!"

:: Smart path resolution: Prevent duplicate nesting if TARGET_DIR is already the project root
set "FULL_PATH=!TARGET_DIR!\!TARGET_PROJ!"
if not exist "!FULL_PATH!" (
    for %%P in ("!TARGET_DIR!") do set "CUR_FOLDER=%%~nxP"
    if /i "!CUR_FOLDER!"=="!TARGET_PROJ!" (
        set "FULL_PATH=!TARGET_DIR!"
    ) else if exist "!TARGET_DIR!\.git" (
        set "FULL_PATH=!TARGET_DIR!"
    )
)

echo.
echo Target project path: !FULL_PATH!
echo.

:: Validate directory and Git workspace
if not exist "!FULL_PATH!" (
    echo [ERROR] Directory not found: !FULL_PATH!
    goto END
)

cd /d "!FULL_PATH!" || (
    echo [ERROR] Failed to access target directory.
    goto END
)

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [ERROR] The directory is not a valid Git repository!
    goto END
)

:: 2. Fetch latest changes from remote
echo ------------------------------------------------------
echo [1/3] Fetching remote branches and metadata...
echo ------------------------------------------------------
git fetch --all --prune --tags
if errorlevel 1 (
    echo [WARNING] Failed to fetch from remote. Check your network or credentials.
    echo Proceeding with local cache...
)
echo.

:: 3. List and select remote branch
echo ------------------------------------------------------
echo [2/3] Select a remote branch:
echo ------------------------------------------------------
set b_count=0
for /f "tokens=*" %%i in ('git branch -r --no-color ^| findstr /v /c:"origin/HEAD"') do (
    set "raw_b=%%i"
    set "raw_b=!raw_b: =!"
    set /a b_count+=1
    set "branch_!b_count!=!raw_b!"
    echo   [!b_count!] !raw_b!
)

if %b_count% equ 0 (
    echo [ERROR] No remote branches found!
    goto END
)

:CHOOSE_BRANCH
set "b_choice="
set /p "b_choice=Enter branch index [1-%b_count%]: "
if not defined branch_%b_choice% (
    echo [INFO] Invalid input. Please enter a valid number.
    goto CHOOSE_BRANCH
)
set "SELECTED_BRANCH=!branch_%b_choice%!"
echo.
echo Selected remote branch: %SELECTED_BRANCH%
echo.

:: 4. Extract local branch name and synchronize to latest
echo ------------------------------------------------------
echo [3/3] Switching and synchronizing to the latest version...
echo Warning: Untracked files and local uncommitted changes will be wiped.
echo ------------------------------------------------------

:: 截取分支名称（去除开头的 "origin/"）
for /f "tokens=1* delims=/" %%a in ("%SELECTED_BRANCH%") do set "LOCAL_BRANCH_NAME=%%b"

:: 切换到该分支（若本地无此分支，自动基于远程分支创建并跟踪）
git checkout -B !LOCAL_BRANCH_NAME! %SELECTED_BRANCH%
if errorlevel 1 (
    echo [ERROR] Failed to checkout branch !LOCAL_BRANCH_NAME!!
    goto END
)

:: 强制将本地分支指针同步到远程分支的最新提交
git reset --hard %SELECTED_BRANCH%
git clean -fd

echo.
echo ======================================================
echo Success! Branch [!LOCAL_BRANCH_NAME!] is now synchronized to latest:
echo ======================================================
git log -1 --stat
echo ======================================================

:END
echo.
pause