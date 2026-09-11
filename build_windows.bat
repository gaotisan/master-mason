@echo off
setlocal
REM Exporta Master Mason para Windows usando el Godot local.
REM Requiere las plantillas de exportacion 4.6.2 instaladas en %APPDATA%\Godot\export_templates\4.6.2.stable

set PROJECT_DIR=%~dp0
set GODOT=%PROJECT_DIR%..\Godot_v4.6.2\Godot_v4.6.2-stable_win64_console.exe
set BUILD_DIR=%PROJECT_DIR%_builds\pc
set EXE=%BUILD_DIR%\master_mason.exe

if not exist "%GODOT%" (
    echo ERROR: no se encuentra Godot en "%GODOT%"
    exit /b 1
)

echo Limpiando build anterior...
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
mkdir "%BUILD_DIR%"

echo Exportando (Windows Desktop)...
"%GODOT%" --headless --path "%PROJECT_DIR%." --export-release "Windows Desktop" "%EXE%"
if errorlevel 1 (
    echo ERROR en la exportacion
    exit /b 1
)

echo.
echo Build OK:
dir /b "%BUILD_DIR%"

if /I "%~1"=="run" (
    echo Lanzando el juego...
    start "" "%EXE%"
)
endlocal
