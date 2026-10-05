<#
.SYNOPSIS
    Copia los fotogramas elegidos a 03_seleccion, renombrados en orden de reproduccion.
.DESCRIPTION
    Los numeros son los que salen pintados en la hoja de contactos.
    El orden que escribes es el orden de la animacion: puedes repetir y volver atras.
.EXAMPLE
    .\elegir.ps1 -Job dominus_run -Frames "12,15,18,21,24,27"
.EXAMPLE
    .\elegir.ps1 -Job dominus_run -Frames "12-20" -Prefijo run
#>
param(
    [Parameter(Mandatory = $true)][string]$Job,
    [Parameter(Mandatory = $true)][string]$Frames,
    [string]$Prefijo = 'p',
    [string]$Desde = '01_frames'
)
. "$PSScriptRoot\_comun.ps1"

$origen  = Get-Etapa $Job $Desde
$destino = Get-Etapa $Job '03_seleccion'
$numeros = Expand-Rangos $Frames
$lista   = Get-ChildItem $origen -Filter '*.png' | Sort-Object Name
if ($lista.Count -eq 0) { throw "No hay PNG en $origen" }

foreach ($n in $numeros) {
    if ($n -lt 1 -or $n -gt $lista.Count) {
        throw "El frame $n no existe: en $Desde hay $($lista.Count) (1..$($lista.Count))"
    }
}

Clear-Carpeta $destino
# Numeracion con las cifras que hagan falta (2 minimo): con p_01..p_99 y luego
# p_100, el orden por nombre pone p_100 antes que p_11 y todo lo que viene
# detras (centrar, fondo, hoja) lee los fotogramas desordenados.
$cifras = [Math]::Max(2, ([string]$numeros.Count).Length)
$i = 0
foreach ($n in $numeros) {
    $i++
    $nombre = ('{0}_{1:d' + $cifras + '}.png') -f $Prefijo, $i
    Copy-Item -LiteralPath $lista[$n - 1].FullName -Destination (Join-Path $destino $nombre)
}

Set-Content -Path (Join-Path (Assert-Job $Job) 'seleccion.txt') `
    -Value @("origen: $Desde", "frames: $Frames", "orden:  $($numeros -join ' ')") -Encoding utf8

Write-Host "$i pose(s) en $destino"
Write-Host "Siguiente:  .\ciclo.ps1 -Job $Job -Fps 12     (para ver si engancha)"
