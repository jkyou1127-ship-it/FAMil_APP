@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0backend"

if not exist ".env" (
  set S1=%RANDOM%%RANDOM%%RANDOM%
  set S2=%RANDOM%%RANDOM%%RANDOM%
  (
    echo PORT=4000
    echo JWT_SECRET=famil_!S1!_!S2!_%DATE:~-4%%TIME:~0,2%%TIME:~3,2%
    echo DB_PATH=./data/famil.db
    echo CORS_ORIGIN=*
  ) > .env
)

if not exist "data" mkdir data
if not exist "uploads\profiles" mkdir uploads\profiles

rem firebase-service-account.json is a real credential and is never shipped
rem in the install zip. To avoid asking for it again on every update, keep
rem it in a fixed folder outside this (possibly version-specific) folder and
rem reuse it from there every time.
set "FAMIL_DATA_DIR=%USERPROFILE%\FAMil_APP"
if not exist "%FAMIL_DATA_DIR%" mkdir "%FAMIL_DATA_DIR%" >nul 2>nul
set "FAMIL_KEY=%FAMIL_DATA_DIR%\firebase-service-account.json"

if exist "firebase-service-account.json" copy /Y "firebase-service-account.json" "%FAMIL_KEY%" >nul 2>nul

if exist "%FAMIL_KEY%" goto :firebase_key_done
if exist "%FAMIL_DATA_DIR%\firebase-skip.flag" goto :firebase_key_done

echo.
echo [Optional] No Firebase service account key found yet.
echo It is only needed for push notifications and for login/status/
echo messenger to still work while the PC is turned off.
echo Paste the full path to the key file (.json) from the Firebase
echo console and press Enter, or just press Enter to skip for now.
echo (You will not be asked again either way.)
set "FAMIL_KEY_INPUT="
set /p "FAMIL_KEY_INPUT=Key file path: "

if not defined FAMIL_KEY_INPUT (
  echo. > "%FAMIL_DATA_DIR%\firebase-skip.flag"
  echo Skipped. You can add it later by placing firebase-service-account.json
  echo directly in "%FAMIL_DATA_DIR%".
  goto :firebase_key_done
)

set FAMIL_KEY_INPUT=!FAMIL_KEY_INPUT:"=!
if not exist "!FAMIL_KEY_INPUT!" (
  echo Could not find a file at that path, skipping.
  goto :firebase_key_done
)

findstr /C:"service_account" "!FAMIL_KEY_INPUT!" >nul 2>nul
if errorlevel 1 (
  echo That file does not look like a Firebase service account key, skipping.
  goto :firebase_key_done
)

copy /Y "!FAMIL_KEY_INPUT!" "%FAMIL_KEY%" >nul 2>nul
echo Saved. This key will be used automatically from now on.

:firebase_key_done
if exist "%FAMIL_KEY%" set "FIREBASE_SERVICE_ACCOUNT_PATH=%FAMIL_KEY%"

echo Starting the FAMil backend server...
start "FAMil Backend" /min "%~dp0node\node.exe" src\server.js

timeout /t 2 /nobreak >nul

echo Starting the FAMil app...
start "" "%~dp0app\famil_app.exe"
