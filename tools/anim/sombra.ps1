<#
.SYNOPSIS
    Aplana la sombra que el personaje proyecta sobre el croma, en 03_seleccion.
.DESCRIPTION
    Va ANTES de centrar.ps1 y fondo.ps1, y solo hace falta si en el video la
    sombra se ve dura. Las dos herramientas siguientes miran distancia de color
    al fondo, y una sombra dura esta tan lejos del croma como el propio
    personaje: no hay umbral que las separe. Esta las separa por tono -- la
    sombra sigue siendo croma con menos luz -- y deja el fondo plano para que
    las otras dos funcionen como si nunca hubiera habido sombra.

    Guarda copia intacta en _con_sombra\ del job, y no la pisa nunca.
.EXAMPLE
    .\sombra.ps1 -Job aracnobat_volando
.EXAMPLE
    .\sombra.ps1 -Job aracnobat_volando -Tolerancia 18 -Radio 4
#>
param(
    [Parameter(Mandatory = $true)][string]$Job,
    [string]$Desde = '03_seleccion',
    [string]$Hacia = '',
    [int]$Tolerancia = 25,
    [int]$Holgura = 12,
    [int]$Radio = 3,
    [int]$Islotes = 24,
    [string]$Fondo = '',
    [switch]$SinCopia
)
. "$PSScriptRoot\_comun.ps1"
Assert-Herramientas

$python = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $python) { throw 'Hace falta python en el PATH para aplanar la sombra' }

$carpeta = Assert-Job $Job
$origen  = Get-Etapa $Job $Desde
if ((Get-ChildItem $origen -Filter '*.png' -ErrorAction SilentlyContinue).Count -eq 0) {
    throw "No hay PNG en $origen"
}
$destino = if ($Hacia) { Join-Path $carpeta $Hacia } else { $origen }

# Con alfa ya puesto esto no pinta nada: el fondo ya no existe y lo unico que
# haria es pintar de verde lo que sea transparente.
$primera = (Get-ChildItem $origen -Filter '*.png' | Sort-Object Name)[0]
$formato = (& $FFprobe -v error -select_streams v:0 -show_entries stream=pix_fmt `
                       -of csv=p=0 $primera.FullName | Select-Object -First 1).Trim()
if ($formato -match '^(rgba|bgra|argb|abgr|ya|pal8)') {
    throw ("Las imagenes de $Desde ya tienen transparencia ($formato). " +
           'La sombra se aplana ANTES de quitar el fondo, sobre los fotogramas en bruto.')
}

if (-not $SinCopia) {
    $copia = Join-Path $carpeta "_con_sombra\$Desde"
    if (Test-Path $copia) {
        Write-Host "Ya habia copia con sombra en _con_sombra\$Desde (no se toca)"
    } else {
        New-Carpeta (Split-Path $copia -Parent)
        Copy-Item $origen -Destination $copia -Recurse -Force
        Write-Host "Copia con sombra guardada en _con_sombra\$Desde"
    }
}

$argumentos = @("$PSScriptRoot\_sombra.py", '--ffmpeg', $FFmpeg,
                '--entrada', $origen, '--salida', $destino,
                '--tolerancia', $Tolerancia, '--holgura', $Holgura,
                '--radio', $Radio, '--islotes', $Islotes)
if ($Fondo) { $argumentos += @('--fondo', $Fondo) }

& $python.Source @argumentos
if ($LASTEXITCODE -ne 0) { throw "El aplanado de sombra fallo (codigo $LASTEXITCODE)" }

Write-Host ''
Write-Host "Siguiente:  .\centrar.ps1 -Job $Job"
