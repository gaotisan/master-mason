<#
.SYNOPSIS
    Datos de un video o imagen: resolucion, fps, duracion, numero de fotogramas.
.EXAMPLE
    .\info.ps1 "$HOME\Downloads\podrias_animar_el_personaje_.mp4"
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Ruta
)
. "$PSScriptRoot\_comun.ps1"
Assert-Herramientas

if (-not (Test-Path $Ruta)) { throw "No existe: $Ruta" }
$Ruta = (Resolve-Path $Ruta).Path

& $FFprobe -v error -show_entries format=duration,size,format_name `
    -show_entries stream=codec_type,codec_name,width,height,r_frame_rate,nb_frames `
    -of default=noprint_wrappers=1 $Ruta
if ($LASTEXITCODE -ne 0) { throw "ffprobe fallo leyendo $Ruta" }
