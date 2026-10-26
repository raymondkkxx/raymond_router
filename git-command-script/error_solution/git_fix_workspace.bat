@echo off
setlocal enabledelayedexpansion

echo ======================================================
echo         Git Workspace Dirty State Resolver
echo ======================================================
echo.

:: 0. Verify Git PATH
git --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git is not found in PATH. Please ensure Git is installed.
    goto END
)

:: 1. Configure repository path (Defaults to two levels up)
for %%I in ("%~dp0..\..") do set "DEFAULT_DIR=%%~fI"

set /p "TARGET_DIR=Enter project root directory [Press ENTER for !DEFAULT_DIR!]: "
if "!TARGET_DIR!"=="" set "TARGET_DIR=!DEFAULT_DIR!"
set "TARGET_DIR=!TARGET_DIR:"=!"

for %%I in ("!TARGET_DIR!") do set "FULL_PATH=%%~fI"

echo.
echo Target project path: !FULL_PATH!
echo.

:: Validate directory
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
    echo [ERROR] The directory is not a valid Git repository: !FULL_PATH!
    goto END
)

:: 2. Check for pending Git operations (rebase / merge / cherry-pick)
set "HAS_PENDING_OP=0"
if exist ".git\rebase-apply" set "HAS_PENDING_OP=1"
if exist ".git\rebase-merge" set "HAS_PENDING_OP=1"
if exist ".git\MERGE_HEAD" set "HAS_PENDING_OP=1"
if exist ".git\CHERRY_PICK_HEAD" set "HAS_PENDING_OP=1"

if "!HAS_PENDING_OP!"=="1" (
    echo ------------------------------------------------------
    echo [ALERT] An interrupted Git operation was detected:
    if exist ".git\rebase-apply" echo   - Rebase in progress
    if exist ".git\rebase-merge" echo   - Rebase in progress
    if exist ".git\MERGE_HEAD" echo   - Merge in progress
    if exist ".git\CHERRY_PICK_HEAD" echo   - Cherry-pick in progress
    echo ------------------------------------------------------
    set /p "ABORT_OP=Do you want to abort the in-progress operation? [y/N]: "
    if /i "!ABORT_OP!"=="y" (
        if exist ".git\rebase-apply" git rebase --abort
        if exist ".git\rebase-merge" git rebase --abort
        if exist ".git\MERGE_HEAD" git merge --abort
        if exist ".git\CHERRY_PICK_HEAD" git cherry-pick --abort
        echo [OK] In-progress operation aborted.
    )
)

:CHECK_STATUS
:: 3. Inspect modified and untracked files
set "IS_DIRTY=0"
for /f "tokens=*" %%s in ('git status --porcelain 2^>nul') do set "IS_DIRTY=1"

if "!IS_DIRTY!"=="0" (
    echo ======================================================
    echo [SUCCESS] Working tree is already clean.
    echo Nothing to fix or commit.
    echo ======================================================
    goto END
)

echo ------------------------------------------------------
echo Current uncommitted / untracked changes:
echo ------------------------------------------------------
git status --short
echo ------------------------------------------------------
echo Please choose a repair option:
echo   [1] Stash: Save all changes and untracked files safely into Git stash
echo   [2] Discard: Permanently delete all local changes and untracked files
echo   [3] Commit: Stage and commit all changes into a new commit
echo   [4] Pop Stash: Restore previously saved stash to current workspace
echo   [5] View Diff: Show detailed file modifications
echo   [6] Exit: Keep changes untouched and exit
echo.

:SELECT_OPTION
set "user_choice="
set /p "user_choice=Enter option [1-6, Press ENTER for 1]: "
if "!user_choice!"=="" set "user_choice=1"

if "!user_choice!"=="1" goto OPTION_STASH
if "!user_choice!"=="2" goto OPTION_DISCARD
if "!user_choice!"=="3" goto OPTION_COMMIT
if "!user_choice!"=="4" goto OPTION_POP
if "!user_choice!"=="5" goto OPTION_DIFF
if "!user_choice!"=="6" goto END

echo [ERROR] Invalid choice. Please enter a number between 1 and 6.
goto SELECT_OPTION

:OPTION_STASH
echo.
echo Saving modified and untracked files to stash...
git stash push -u -m "Manual_stash_backup_%DATE%_%TIME%"
if errorlevel 1 (
    echo [ERROR] Stash failed.
) else (
    echo [SUCCESS] Workspace stashed successfully.
)
goto VERIFY_CLEAN

:OPTION_DISCARD
echo.
echo ======================================================
echo  WARNING: This will permanently wipe all local changes
echo  and delete all untracked files/folders!
echo ======================================================
set "CONFIRM_WIPE="
set /p "CONFIRM_WIPE=Are you sure you want to proceed? [y/N]: "
if /i not "!CONFIRM_WIPE!"=="y" (
    echo [INFO] Discard cancelled.
    goto CHECK_STATUS
)

echo Discarding modified files...
git reset --hard HEAD
echo Removing untracked files and directories...
git clean -fd
echo [SUCCESS] Working directory has been reset to HEAD.
goto VERIFY_CLEAN

:OPTION_COMMIT
echo.
set "COMMIT_MSG="
set /p "COMMIT_MSG=Enter commit message [Press ENTER for 'Auto-commit uncommitted workspace changes']: "
if "!COMMIT_MSG!"=="" set "COMMIT_MSG=Auto-commit uncommitted workspace changes"

git add -A
git commit -m "!COMMIT_MSG!"
if errorlevel 1 (
    echo [ERROR] Commit failed.
) else (
    echo [SUCCESS] All changes committed.
)
goto VERIFY_CLEAN

:OPTION_POP
echo.
echo Checking for available stashes...
git stash list
echo.
set /p "CONFIRM_POP=Apply and drop the latest stash? [y/N]: "
if /i "!CONFIRM_POP!"=="y" (
    git stash pop
)
goto CHECK_STATUS

:OPTION_DIFF
echo.
echo ======================================================
echo                     Diff Output
echo ======================================================
git diff
echo ======================================================
echo.
goto CHECK_STATUS

:VERIFY_CLEAN
echo.
echo Checking final workspace state:
git status --short > "%TEMP%\verify_status_%RANDOM%.tmp"
set "FINAL_DIRTY=0"
for /f "usebackq tokens=*" %%x in ("%TEMP%\verify_status_%RANDOM%.tmp") do set "FINAL_DIRTY=1"
del "%TEMP%\verify_status_%RANDOM%.tmp" 2>nul

if "!FINAL_DIRTY!"=="0" (
    echo [SUCCESS] Working tree is now completely CLEAN.
    echo You can now safely run your history truncation script.
) else (
    echo [WARNING] There are still uncommitted items:
    git status --short
)

:END
echo.
pause