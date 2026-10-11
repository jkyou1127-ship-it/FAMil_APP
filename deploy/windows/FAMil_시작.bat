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

rem firebase-service-account.json은 민감한 키라 설치 zip에는 들어있지 않다.
rem 버전을 새로 받을 때마다 다시 넣어야 하는 불편을 없애려고, 한 번 이
rem 폴더에 넣어두면 업데이트와 무관하게 항상 같은 자리에 보관해두고 그걸
rem 계속 쓴다.
set "FAMIL_DATA_DIR=%USERPROFILE%\FAMil_APP"
if not exist "%FAMIL_DATA_DIR%" mkdir "%FAMIL_DATA_DIR%" >nul 2>nul

if exist "firebase-service-account.json" (
  copy /Y "firebase-service-account.json" "%FAMIL_DATA_DIR%\firebase-service-account.json" >nul 2>nul
)
if exist "%FAMIL_DATA_DIR%\firebase-service-account.json" (
  set "FIREBASE_SERVICE_ACCOUNT_PATH=%FAMIL_DATA_DIR%\firebase-service-account.json"
)

echo FAMil 백엔드 서버를 시작합니다...
start "FAMil Backend" /min "%~dp0node\node.exe" src\server.js

timeout /t 2 /nobreak >nul

echo FAMil APP을 실행합니다...
start "" "%~dp0app\famil_app.exe"
