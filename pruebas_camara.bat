@echo off
REM Abre las pruebas de camara (scenes/pruebas_camara), aparte del juego.
REM   pruebas_camara.bat          menu (1 capas, 2 planos)
REM   pruebas_camara.bat capas    directo a la de capas (Inside)
REM   pruebas_camara.bat planos   directo a la de planos fijos (Alone in the Dark)
REM   pruebas_camara.bat vitrina  directo al peregrino 3D
REM Se puede indicar otro Godot con la variable de entorno GODOT.
setlocal
set PROJECT_DIR=%~dp0
if "%GODOT%"=="" set GODOT=%PROJECT_DIR%..\..\engine\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
start "" "%GODOT%" --path "%PROJECT_DIR%." res://scenes/pruebas_camara/menu_pruebas_camara.tscn -- %1
endlocal
