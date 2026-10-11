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
rem 버전을 새로 받을 때마다 다시 넣어야 하는 불편을 없애려고, 한 번만 이
rem 폴더에 넣어두면(또는 최초 설치 시 아래 안내에 따라 한 번만 입력하면)
rem 업데이트와 무관하게 항상 같은 자리에 보관해두고 그걸 계속 쓴다.
set "FAMIL_DATA_DIR=%USERPROFILE%\FAMil_APP"
if not exist "%FAMIL_DATA_DIR%" mkdir "%FAMIL_DATA_DIR%" >nul 2>nul
set "FAMIL_KEY=%FAMIL_DATA_DIR%\firebase-service-account.json"

if exist "firebase-service-account.json" (
  copy /Y "firebase-service-account.json" "%FAMIL_KEY%" >nul 2>nul
)

rem 아직 키가 없고(최초 설치) 이전에 "안 쓸래요"라고 답한 적도 없다면,
rem 설치 과정에서 딱 한 번만 물어본다. 다음부터는 묻지 않는다.
if not exist "%FAMIL_KEY%" if not exist "%FAMIL_DATA_DIR%\firebase-skip.flag" (
  echo.
  echo [선택] Firebase 서비스 계정 키가 아직 없습니다 — PC가 꺼져 있을 때도
  echo        로그인/상태창/매신저를 쓰거나, 푸시 알림을 받으려면 필요해요.
  echo        지금 설정하려면 Firebase 콘솔에서 받은 키 파일(.json)의 전체
  echo        경로를 아래에 붙여넣고 Enter를 누르세요. 지금 넘어가려면 그냥
  echo        Enter만 누르면 되고, 나중에 다시 묻지 않습니다.
  set "FAMIL_KEY_INPUT="
  set /p "FAMIL_KEY_INPUT=키 파일 경로: "
  if defined FAMIL_KEY_INPUT (
    set FAMIL_KEY_INPUT=!FAMIL_KEY_INPUT:"=!
    if exist "!FAMIL_KEY_INPUT!" (
      findstr /C:"service_account" "!FAMIL_KEY_INPUT!" >nul 2>nul
      if errorlevel 1 (
        echo 그 파일은 Firebase 서비스 계정 키처럼 보이지 않아 건너뜁니다.
      ) else (
        copy /Y "!FAMIL_KEY_INPUT!" "%FAMIL_KEY%" >nul 2>nul
        echo 저장했습니다. 다음부터는 자동으로 이 키를 사용합니다.
      )
    ) else (
      echo 그 경로에서 파일을 찾을 수 없어 건너뜁니다.
    )
  ) else (
    echo. > "%FAMIL_DATA_DIR%\firebase-skip.flag"
    echo 건너뛰었습니다. 나중에 쓰려면 "%FAMIL_DATA_DIR%" 폴더에
    echo firebase-service-account.json 파일을 직접 넣어주세요.
  )
)

if exist "%FAMIL_KEY%" set "FIREBASE_SERVICE_ACCOUNT_PATH=%FAMIL_KEY%"

echo FAMil 백엔드 서버를 시작합니다...
start "FAMil Backend" /min "%~dp0node\node.exe" src\server.js

timeout /t 2 /nobreak >nul

echo FAMil APP을 실행합니다...
start "" "%~dp0app\famil_app.exe"
