@echo off
REM Prueba de la hoja LIMPIA del peregrino de perfil (tools/anim/hojas/limpiar.py) en dark_stage:
REM H cambia entre la hoja del juego (la limpia, desde el 2026-10-22) y la ANTERIOR, K pone un fondo claro detras.
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
start "" "%GODOT%" --path "%PROJECT_DIR%." res://scenes/dev/prueba_perfil_limpio.tscn
endlocal
