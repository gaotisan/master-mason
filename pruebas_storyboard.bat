@echo off
REM Abre la prueba de storyboard jugable (scenes/pruebas_storyboard), aparte
REM del juego y de las pruebas de camara: plano lateral -> mirador (camino en
REM profundidad) -> niebla -> vuelta. Se puede indicar otro Godot con GODOT.
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
start "" "%GODOT%" --path "%PROJECT_DIR%." res://scenes/pruebas_storyboard/storyboard.tscn
endlocal
