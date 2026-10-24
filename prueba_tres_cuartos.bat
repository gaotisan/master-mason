@echo off
REM Banco de pruebas del peregrino en TRES CUARTOS (scenes/dev/prueba_tres_cuartos.tscn):
REM sin fondo, con rejilla en el suelo; las teclas salen en pantalla. Con el
REM baculo guardado: prueba_tres_cuartos.bat espalda
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
start "" "%GODOT%" --path "%PROJECT_DIR%." res://scenes/dev/prueba_tres_cuartos.tscn -- %*
endlocal
