@echo off
REM Abre el camino derecho del cruce, frontal, aparte del juego
REM (scenes/game/camino_derecho.tscn). Sin escena de antes, el peregrino esta quieto con el
REM baston en la mano; para probarlo guardado: camino_derecho.bat espalda
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
start "" "%GODOT%" --path "%PROJECT_DIR%." res://scenes/game/camino_derecho.tscn -- %*
endlocal
