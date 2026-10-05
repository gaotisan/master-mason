<#
.SYNOPSIS
    Recorta al personaje y le quita el paneo de camara, dejandolo listo en 04_limpios.
.DESCRIPTION
    Lee 03_seleccion, mide la silueta de cada fotograma y recorta una casilla del
    mismo tamano en todos, anclada al eje del tronco (las piernas no cuentan: se
    mueven). El bote vertical de la carrera se conserva.
    Despues te toca a ti quitar el fondo en GIMP, sobre lo que deja aqui.
.EXAMPLE
    .\centrar.ps1 -Job dominus_run
.EXAMPLE
    .\centrar.ps1 -Job dominus_run -Margen 40 -Sobrescribir
.EXAMPLE
    # casilla y suelo comunes a varias animaciones del mismo personaje
    .\centrar.ps1 -Job magnus_corriendo  -Ancho 584 -Alto 688 -MargenSuelo 30 -Sobrescribir
    .\centrar.ps1 -Job magnus_respirando -Ancho 584 -Alto 688 -MargenSuelo 30 -Sobrescribir
.EXAMPLE
    # camara quieta: misma ventana exacta en todas, sin medir nada por fotograma
    .\centrar.ps1 -Job aracnobat_volando -Ancho 1088 -Alto 680 -Eje 640 -Techo 38
#>
param(
    [Parameter(Mandatory = $true)][string]$Job,
    [string]$Desde = '03_seleccion',
    [int]$Margen = 24,
    [int]$Ancho = 0,
    [int]$Alto = 0,
    [int]$MargenSuelo = -1,
    [double]$Eje = -1,
    [int]$Techo = -1,
    [switch]$Sobrescribir
)
. "$PSScriptRoot\_comun.ps1"
Assert-Herramientas

$python = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $python) { throw 'Hace falta python en el PATH para centrar los fotogramas' }

$origen  = Get-Etapa $Job $Desde
$destino = Get-Etapa $Job '04_limpios'
if ((Get-ChildItem $destino -File -ErrorAction SilentlyContinue).Count -gt 0 -and -not $Sobrescribir) {
    throw "04_limpios ya tiene trabajo dentro. Si quieres rehacerlo, pasa -Sobrescribir"
}
Clear-Carpeta $destino

$argumentos = @("$PSScriptRoot\_centrar.py", '--ffmpeg', $FFmpeg,
                '--entrada', $origen, '--salida', $destino, '--margen', $Margen)
if ($Ancho -gt 0) { $argumentos += @('--ancho', $Ancho) }
if ($Alto  -gt 0) { $argumentos += @('--alto',  $Alto) }
if ($MargenSuelo -ge 0) { $argumentos += @('--suelo-margen', $MargenSuelo) }
if ($Eje   -ge 0) { $argumentos += @('--eje',   $Eje.ToString([System.Globalization.CultureInfo]::InvariantCulture)) }
if ($Techo -ge 0) { $argumentos += @('--techo', $Techo) }

& $python.Source @argumentos
if ($LASTEXITCODE -ne 0) { throw "El centrado fallo (codigo $LASTEXITCODE)" }

Write-Host ''
Write-Host "Siguiente:  .\ciclo.ps1 -Job $Job -Desde 04_limpios -Fps 24"
