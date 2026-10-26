@echo off
setlocal enabledelayedexpansion

echo ======================================================
echo          Git Commit Rollback ^& History Reset Tool
echo ======================================================
echo.

:: 1. Configure repository path with defaults
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

:: Smart path resolution
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
    goto FAILURE
)

cd /d "!FULL_PATH!" || (
    echo [ERROR] Failed to access target directory.
    goto FAILURE
)

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [ERROR] The directory is not a valid Git repository!
    goto FAILURE
)

:: 2. Fetch latest changes from remote
echo ------------------------------------------------------
echo [1/5] Fetching remote references and commit metadata...
echo ------------------------------------------------------
git fetch --all --prune --tags
if errorlevel 1 (
    echo [WARNING] Failed to fetch from remote. Check your network or credentials.
    echo [INFO] Continuing with local repository data...
) else (
    echo [OK] Remote metadata fetched successfully.
)
echo.

:: 3. List and select remote branch
echo ------------------------------------------------------
echo [2/5] Select remote branch:
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
    goto FAILURE
)

:CHOOSE_BRANCH
set "b_choice="
set /p "b_choice=Enter branch index [1-%b_count%]: "
if not defined branch_%b_choice% (
    echo [WARNING] Invalid input. Please enter a number between 1 and %b_count%.
    goto CHOOSE_BRANCH
)
set "SELECTED_BRANCH=!branch_%b_choice%!"

:: Parse remote name and local branch name (e.g., origin/main -> REMOTE=origin, LOCAL=main)
for /f "tokens=1* delims=/" %%A in ("%SELECTED_BRANCH%") do (
    set "REMOTE_NAME=%%A"
    set "LOCAL_BRANCH=%%B"
)

echo.
echo Selected Remote Branch: %SELECTED_BRANCH%
echo Target Local Branch:    %LOCAL_BRANCH%
echo Remote Name:            %REMOTE_NAME%
echo.

:: 4. List and select commit version
echo ------------------------------------------------------
echo [3/5] Select target rollback commit (showing latest 20):
echo ------------------------------------------------------
set c_count=0
for /f "tokens=1* delims= " %%a in ('git log %SELECTED_BRANCH% -n 20 --pretty^=format:"%%h %%ad [%%an] %%s" --date^=short') do (
    set /a c_count+=1
    set "commit_hash_!c_count!=%%a"
    set "commit_info_!c_count!=%%b"
    echo   [!c_count!] %%a - %%b
)

if %c_count% equ 0 (
    echo [ERROR] No commit history found on branch %SELECTED_BRANCH%!
    goto FAILURE
)

:CHOOSE_COMMIT
set "c_choice="
set /p "c_choice=Enter commit index [1-%c_count%]: "
if not defined commit_hash_%c_choice% (
    echo [WARNING] Invalid input. Please enter a number between 1 and %c_count%.
    goto CHOOSE_COMMIT
)
set "SELECTED_HASH=!commit_hash_%c_choice%!"
set "SELECTED_INFO=!commit_info_%c_choice%!"

echo.
echo Target Commit: %SELECTED_HASH% (%SELECTED_INFO%)
echo.

:: Safety confirmation prompt
echo ======================================================
echo [CRITICAL WARNING]
echo You are about to rollback branch '%LOCAL_BRANCH%' to commit %SELECTED_HASH%.
echo ALL COMMITS CREATED AFTER THIS COMMIT WILL BE PERMANENTLY REMOVED!
echo Untracked files and uncommitted changes will also be discarded.
echo ======================================================
set "CONFIRM="
set /p "CONFIRM=Are you sure you want to proceed? (Type 'YES' to confirm): "
if /i not "!CONFIRM!"=="YES" (
    echo.
    echo [ABORTED] Operation cancelled by user.
    goto END
)
echo.

:: 5. Switch branch, hard reset, and purge untracked files
echo ------------------------------------------------------
echo [4/5] Executing local rollback and cleaning workspace...
echo ------------------------------------------------------

echo [*] Checking out and binding local branch '%LOCAL_BRANCH%'...
git checkout -B "%LOCAL_BRANCH%" "%SELECTED_BRANCH%"
if errorlevel 1 (
    echo [ERROR] Failed to switch to branch '%LOCAL_BRANCH%'.
    goto FAILURE
)

echo [*] Hard resetting branch pointer to %SELECTED_HASH%...
git reset --hard %SELECTED_HASH%
if errorlevel 1 (
    echo [ERROR] Failed to reset branch to commit %SELECTED_HASH%.
    goto FAILURE
)

echo [*] Purging untracked files and directories...
git clean -fd
if errorlevel 1 (
    echo [WARNING] Untracked cleanup encountered minor issues.
)
echo [OK] Local branch rollback finished.
echo.

:: 6. Optional remote history truncation (Force Push)
echo ------------------------------------------------------
echo [5/5] Remote commit history synchronization
echo ------------------------------------------------------
echo To completely delete the commit history on the REMOTE server,
echo a force push is required.
echo.
set "PUSH_CONFIRM="
set /p "PUSH_CONFIRM=Do you want to force-push to %REMOTE_NAME%/%LOCAL_BRANCH%? [y/N]: "
set "PUSH_STATUS=Skipped by user"

if /i "!PUSH_CONFIRM!"=="y" (
    echo [*] Pushing changes to remote with lease check...
    git push --force-with-lease "%REMOTE_NAME%" "%LOCAL_BRANCH%"
    if errorlevel 1 (
        echo [WARNING] 'push --force-with-lease' rejected. Attempting standard force push...
        git push --force "%REMOTE_NAME%" "%LOCAL_BRANCH%"
        if errorlevel 1 (
            echo [ERROR] Failed to force-push to remote branch!
            set "PUSH_STATUS=Failed"
            goto FAILURE
        ) else (
            set "PUSH_STATUS=Succeeded (Force)"
        )
    ) else (
        set "PUSH_STATUS=Succeeded (Safe Force)"
    )
)

:: 7. Feedback & Verification Report
echo.
echo ======================================================
echo               EXECUTION REPORT: SUCCESS
echo ======================================================
echo  Repository:     !FULL_PATH!
echo  Branch:         !LOCAL_BRANCH!
echo  Current HEAD:   !SELECTED_HASH!
echo  Commit Message: !SELECTED_INFO!
echo  Remote Sync:    !PUSH_STATUS!
echo ======================================================
echo.
echo Current Commit History (Latest 5):
echo ------------------------------------------------------
git log -n 5 --oneline --graph --decorate
echo ------------------------------------------------------
echo [STATUS] Target commit rollback and history truncation completed.
goto END

:FAILURE
echo.
echo ======================================================
echo               EXECUTION REPORT: FAILED
echo ======================================================
echo [FATAL] An error occurred during the rollback process.
echo Please review the output above to diagnose the issue.
echo ======================================================

:END
echo.
pause