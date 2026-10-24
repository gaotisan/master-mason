@echo off
REM Prueba de FALSO 3D del peregrino (sin baculo): 8 direcciones por un suelo en perspectiva.
REM Flechas o WASD andar, +/- velocidad, C color igualado/original, R al centro, G rejilla, Esc salir. No toca el juego.
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
start "" "%GODOT%" --path "%PROJECT_DIR%." res://scenes/dev/prueba_falso3d.tscn
endlocal
