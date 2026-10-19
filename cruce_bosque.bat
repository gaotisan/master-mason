@echo off
REM Abre la escena del cruce del bosque (scenes/game/cruce_bosque.tscn), aparte
REM del juego: el contraplano del camino del bosque, con el peregrino de espaldas
REM y los tres caminos (el del centro, a la casa de Dominus). Se puede indicar
REM otro Godot con GODOT. Sin escena de antes, el peregrino esta quieto con el
REM baston en la mano; para probarlo guardado: cruce_bosque.bat espalda
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
start "" "%GODOT%" --path "%PROJECT_DIR%." res://scenes/game/cruce_bosque.tscn -- %*
endlocal
