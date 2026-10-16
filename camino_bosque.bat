@echo off
REM Abre la escena del camino del bosque (scenes/game/camino_bosque.tscn), aparte
REM del juego: la imagen de Midjourney con la copa al viento, rayos de luz,
REM niebla, polvo y hojas cayendo. Se puede indicar otro Godot con GODOT.
REM Sin escena de antes, el peregrino llega con el baston en la mano; para
REM probarlo guardado: camino_bosque.bat espalda
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
start "" "%GODOT%" --path "%PROJECT_DIR%." res://scenes/game/camino_bosque.tscn -- %*
endlocal
