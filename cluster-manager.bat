@echo off
REM 클러스터 관리 - Windows 배치 파일
REM Windows 환경에서 cluster-manager.sh를 실행합니다

setlocal enabledelayedexpansion

if "%1"=="" (
    echo 사용법: %0 [명령어] [옵션]
    echo.
    echo 명령어:
    echo   start       클러스터 시작
    echo   stop        클러스터 중지
    echo   restart     클러스터 재시작
    echo   status      클러스터 상태 확인
    echo   health      헬스체크 수행
    echo   ssh [vm]    특정 VM에 SSH 접속
    echo   info        클러스터 정보 출력
    echo   help        도움말 표시
    echo.
    echo 예시:
    echo   %0 status
    echo   %0 ssh mgmt
    echo   %0 health
    goto :end
)

REM Git Bash 확인
where git.exe >nul 2>&1
if %errorlevel% == 0 (
    REM Git Bash로 실행
    "C:\Program Files\Git\bin\bash.exe" -c "./cluster-manager.sh %*"
) else (
    REM WSL 확인
    where wsl.exe >nul 2>&1
    if %errorlevel% == 0 (
        REM WSL로 실행
        wsl bash -c "cd /mnt/c/sdn-autoscailing-project && ./cluster-manager.sh %*"
    ) else (
        echo [ERROR] Git Bash 또는 WSL이 필요합니다.
        echo Git for Windows를 설치하거나 WSL을 활성화해주세요.
    )
)

:end