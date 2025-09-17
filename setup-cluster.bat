@echo off
REM 통합 DevOps 클러스터 설정 - Windows 배치 파일
REM Windows 환경에서 bash 스크립트를 실행합니다

setlocal enabledelayedexpansion

echo ================================================================
echo              통합 DevOps 클러스터 설정 (Windows)
echo ================================================================
echo.

REM 현재 디렉토리 확인
if not exist "setup-cluster.sh" (
    echo [ERROR] setup-cluster.sh 파일을 찾을 수 없습니다.
    echo 프로젝트 디렉토리에서 실행해주세요.
    pause
    exit /b 1
)

REM 실행 방법 확인
echo 사용 가능한 실행 방법을 확인 중...
echo.

REM Git Bash 확인
where git.exe >nul 2>&1
if %errorlevel% == 0 (
    echo [1] Git Bash 사용 (권장)
    set HAS_GIT=1
) else (
    echo [1] Git Bash 없음
    set HAS_GIT=0
)

REM WSL 확인
where wsl.exe >nul 2>&1
if %errorlevel% == 0 (
    echo [2] WSL 사용 가능
    set HAS_WSL=1
) else (
    echo [2] WSL 없음
    set HAS_WSL=0
)

echo.
echo ================================================================

REM 실행 방법 선택
if %HAS_GIT% == 1 (
    echo Git Bash를 사용해서 설정을 시작합니다...
    echo.
    
    REM Git Bash에서 스크립트 실행
    "C:\Program Files\Git\bin\bash.exe" -c "./setup-cluster.sh"
    
    if %errorlevel% == 0 (
        echo.
        echo [SUCCESS] 클러스터 설정이 완료되었습니다!
        echo.
        echo 관리 명령어:
        echo   클러스터 상태:    "C:\Program Files\Git\bin\bash.exe" -c "./cluster-manager.sh status"
        echo   헬스체크:        "C:\Program Files\Git\bin\bash.exe" -c "./cluster-manager.sh health"
        echo   VM 접속:         "C:\Program Files\Git\bin\bash.exe" -c "./cluster-manager.sh ssh mgmt"
    ) else (
        echo.
        echo [ERROR] 설정 중 오류가 발생했습니다.
        echo 수동으로 문제를 확인해주세요.
    )
    
) else if %HAS_WSL% == 1 (
    echo WSL을 사용해서 설정을 시작합니다...
    echo.
    
    REM WSL에서 스크립트 실행
    wsl bash -c "cd /mnt/c/sdn-autoscailing-project && chmod +x *.sh && chmod +x scripts/provisioning/*.sh && ./setup-cluster.sh"
    
    if %errorlevel% == 0 (
        echo.
        echo [SUCCESS] 클러스터 설정이 완료되었습니다!
        echo.
        echo 관리 명령어:
        echo   클러스터 상태:    wsl bash -c "cd /mnt/c/sdn-autoscailing-project && ./cluster-manager.sh status"
        echo   헬스체크:        wsl bash -c "cd /mnt/c/sdn-autoscailing-project && ./cluster-manager.sh health"
        echo   VM 접속:         wsl bash -c "cd /mnt/c/sdn-autoscailing-project && ./cluster-manager.sh ssh mgmt"
    ) else (
        echo.
        echo [ERROR] 설정 중 오류가 발생했습니다.
    )
    
) else (
    echo.
    echo [ERROR] 실행 가능한 환경을 찾을 수 없습니다.
    echo.
    echo 다음 중 하나를 설치해주세요:
    echo   1. Git for Windows ^(Git Bash 포함^): https://git-scm.com/download/win
    echo   2. WSL ^(Windows Subsystem for Linux^): wsl --install
    echo.
    echo 또는 PowerShell에서 직접 실행:
    echo   bash ./setup-cluster.sh
)

echo.
pause