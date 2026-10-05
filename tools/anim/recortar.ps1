<#
.SYNOPSIS
    Recorta un tramo de un video y lo deja como fuente nueva en raw\...\anim\_fuentes.
.DESCRIPTION
    Reconvierte (no copia el flujo) para que el corte caiga en el segundo exacto
    y no en el fotograma clave mas cercano.
.EXAMPLE
    .\recortar.ps1 -Fuente "..\..\raw\master_mason\anim\_fuentes\video.mp4" -Desde 6
.EXAMPLE
    .\recortar.ps1 -Fuente video.mp4 -Desde 2.5 -Hasta 7 -Nombre dominus_run_bueno
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Fuente,
    [double]$Desde = 0,
    [double]$Hasta = -1,
    [string]$Nombre,
    [switch]$SinAudio
)
. "$PSScriptRoot\_comun.ps1"
Assert-Herramientas

if (-not (Test-Path $Fuente)) { throw "No existe la fuente: $Fuente" }
$origen = (Resolve-Path $Fuente).Path
New-Carpeta $Fuentes

$inv = [System.Globalization.CultureInfo]::InvariantCulture
function Etiqueta([double]$s) { $s.ToString('0.##', $inv).Replace('.', 'p') }

if (-not $Nombre) {
    $base   = [System.IO.Path]::GetFileNameWithoutExtension($origen)
    $tramo  = if ($Hasta -ge 0) { "$(Etiqueta $Desde)-$(Etiqueta $Hasta)s" } else { "$(Etiqueta $Desde)s-fin" }
    $Nombre = "${base}_$tramo"
}
$salida = Join-Path $Fuentes "$Nombre.mp4"

$argumentos = @('-hide_banner', '-loglevel', 'warning', '-y')
if ($Desde -gt 0) { $argumentos += @('-ss', $Desde.ToString($inv)) }
if ($Hasta -ge 0) { $argumentos += @('-to', $Hasta.ToString($inv)) }
$argumentos += @('-i', $origen,
                 '-c:v', 'libx264', '-crf', '17', '-preset', 'slow', '-pix_fmt', 'yuv420p')
$argumentos += if ($SinAudio) { @('-an') } else { @('-c:a', 'aac', '-b:a', '160k') }
$argumentos += $salida

Invoke-FFmpeg $argumentos

Write-Host "Corte: $salida"
& $FFprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,nb_frames `
    -show_entries format=duration -of default=noprint_wrappers=1 $salida
Write-Host ''
Write-Host "Siguiente:  .\nuevo.ps1 -Job <nombre> -Fuente `"$salida`""
