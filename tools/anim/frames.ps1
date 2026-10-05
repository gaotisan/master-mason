<#
.SYNOPSIS
    Saca fotogramas de un video a 01_frames del job.
.EXAMPLE
    .\frames.ps1 -Job dominus_run                          # todos (24 fps del video)
.EXAMPLE
    .\frames.ps1 -Job dominus_run -Desde 2.0 -Hasta 4.0     # solo ese tramo
.EXAMPLE
    .\frames.ps1 -Job dominus_run -Fps 12 -Ancho 720        # remuestrea y reduce
#>
param(
    [Parameter(Mandatory = $true)][string]$Job,
    [string]$Fuente,
    [double]$Desde = -1,
    [double]$Hasta = -1,
    [double]$Fps   = 0,
    [int]$Ancho    = 0,
    [switch]$Conservar
)
. "$PSScriptRoot\_comun.ps1"
Assert-Herramientas

$origen  = Resolve-Fuente $Job $Fuente
$destino = Get-Etapa $Job '01_frames'
if ($Conservar) { New-Carpeta $destino } else { Clear-Carpeta $destino }

$filtros = @()
if ($Fps   -gt 0) { $filtros += "fps=$($Fps.ToString([System.Globalization.CultureInfo]::InvariantCulture))" }
if ($Ancho -gt 0) { $filtros += "scale=${Ancho}:-1:flags=lanczos" }

$argumentos = @('-hide_banner', '-loglevel', 'warning')
if ($Desde -ge 0) { $argumentos += @('-ss', $Desde.ToString([System.Globalization.CultureInfo]::InvariantCulture)) }
if ($Hasta -ge 0) { $argumentos += @('-to', $Hasta.ToString([System.Globalization.CultureInfo]::InvariantCulture)) }
$argumentos += @('-i', $origen)
if ($filtros.Count -gt 0) { $argumentos += @('-vf', ($filtros -join ',')) }
$argumentos += @('-fps_mode', 'passthrough', '-start_number', '1',
                 (Join-Path $destino 'f_%04d.png'))

Invoke-FFmpeg $argumentos

$n = (Get-ChildItem $destino -Filter '*.png').Count
Write-Host "$n fotogramas en $destino"
Write-Host "Siguiente:  .\contacto.ps1 -Job $Job"
