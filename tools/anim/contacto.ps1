<#
.SYNOPSIS
    Monta mosaicos numerados de 01_frames para elegir de un vistazo los del ciclo.
.DESCRIPTION
    El numero que ves pintado sobre cada casilla es el que pasas a elegir.ps1.
.EXAMPLE
    .\contacto.ps1 -Job dominus_run
.EXAMPLE
    .\contacto.ps1 -Job dominus_run -Cols 8 -Filas 6 -AnchoCasilla 200
#>
param(
    [Parameter(Mandatory = $true)][string]$Job,
    [int]$Cols = 6,
    [int]$Filas = 5,
    [int]$AnchoCasilla = 240
)
. "$PSScriptRoot\_comun.ps1"
Assert-Herramientas

$origen  = Get-Etapa $Job '01_frames'
$destino = Get-Etapa $Job '02_contacto'
$frames  = Get-ChildItem $origen -Filter 'f_*.png' | Sort-Object Name
if ($frames.Count -eq 0) { throw "No hay fotogramas en $origen. Lanza antes:  .\frames.ps1 -Job $Job" }
Clear-Carpeta $destino

$fuenteTexto = Get-FuenteTexto
$porHoja = $Cols * $Filas
$tam     = [Math]::Max(12, [int]($AnchoCasilla / 12))

$filtro = "scale=${AnchoCasilla}:-1:flags=lanczos," +
          "drawtext=fontfile='${fuenteTexto}':text='%{eif\:n+1\:d}':x=6:y=6:" +
          "fontsize=${tam}:fontcolor=yellow:box=1:boxcolor=black@0.6:boxborderw=4," +
          "tile=${Cols}x${Filas}:padding=4:margin=4:color=0x202020"

Invoke-FFmpeg @(
    '-hide_banner', '-loglevel', 'warning',
    '-framerate', '1', '-start_number', '1',
    '-i', (Join-Path $origen 'f_%04d.png'),
    '-vf', $filtro,
    '-fps_mode', 'passthrough',
    (Join-Path $destino 'contacto_%02d.png')
)

$hojas = (Get-ChildItem $destino -Filter '*.png').Count
Write-Host "$($frames.Count) fotogramas -> $hojas hoja(s) de $porHoja en $destino"
Write-Host "Siguiente:  .\elegir.ps1 -Job $Job -Frames `"3,7,10-14`""
