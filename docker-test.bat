@echo off
setlocal
cd /d "%~dp0"
call load-env.bat

set "TEST_EXIT_CODE=1"
set "DOCKER_OS=%~1"
set "DOCKER_CONTEXT_ARGS="
set "DOCKER_TEST_OS_ARGS="
set "DOCKER_TEST_ENTRYPOINT_ARGS="
set "DOCKER_TEST_COMMAND_ARGS="

if not defined DOCKER_IMAGE (
    echo Missing DOCKER_IMAGE in .env
    goto test_done
)

if not defined DOCKER_TEST_CMD (
    echo Missing DOCKER_TEST_CMD in .env
    goto test_done
)

set "DOCKER_TEST_ARGS=%DOCKER_TEST_ARGS:~1,-1%"
set "DOCKER_TEST_ARGS=%DOCKER_TEST_ARGS:\"="%"
set "DOCKER_TEST_CMD=%DOCKER_TEST_CMD:~1,-1%"
set "DOCKER_TEST_CMD=%DOCKER_TEST_CMD:\"="%"

if defined DOCKER_OS (
    set "DOCKER_CONTEXT_ARGS=--context %DOCKER_OS%"
) else (
    for /f %%i in ('docker info --format "{{.OSType}}"') do set "DOCKER_OS=%%i"
)

if not defined DOCKER_OS (
    echo Failed to determine the Docker OS
    goto test_done
)

call set "DOCKER_TEST_OS_ARGS=%%DOCKER_TEST_ARGS_%DOCKER_OS%%%"

if not defined DOCKER_TEST_OS_ARGS (
    echo Missing DOCKER_TEST_ARGS_%DOCKER_OS% in .env
    goto test_done
)

set "DOCKER_TEST_OS_ARGS=%DOCKER_TEST_OS_ARGS:~1,-1%"
set "DOCKER_TEST_OS_ARGS=%DOCKER_TEST_OS_ARGS:\"="%"

if /i "%DOCKER_OS%"=="linux" (
    set "DOCKER_TEST_ENTRYPOINT_ARGS=--entrypoint /bin/sh"
    set "DOCKER_TEST_COMMAND_ARGS=-c "%DOCKER_TEST_CMD%""
) else if /i "%DOCKER_OS%"=="windows" (
    set "DOCKER_TEST_ENTRYPOINT_ARGS=--entrypoint powershell.exe"
    set "DOCKER_TEST_COMMAND_ARGS=-NonInteractive -NoProfile -Command "%DOCKER_TEST_CMD%""
) else (
    echo Unsupported Docker OS: %DOCKER_OS%
    goto test_done
)

docker %DOCKER_CONTEXT_ARGS% run --rm %DOCKER_TEST_ARGS% %DOCKER_TEST_OS_ARGS% %DOCKER_TEST_ENTRYPOINT_ARGS% tmp/%DOCKER_IMAGE%:latest %DOCKER_TEST_COMMAND_ARGS%
set "TEST_EXIT_CODE=%ERRORLEVEL%"

:test_done
pause
endlocal & exit /b %TEST_EXIT_CODE%
