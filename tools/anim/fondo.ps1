<#
.SYNOPSIS
    Quita el fondo liso y deja alfa limpio, sin halo, en 04_limpios.
.DESCRIPTION
    Antes de escribir guarda una copia intacta en _con_fondo\ del job, para poder
    comparar. Si esa copia ya existe no la pisa: la primera version con fondo se
    conserva siempre.
    El fondo se identifica por relleno desde el borde del cuadro, no por parecido
    de color: la barba blanca esta a distancia 12-16 del gris del fondo y una clave
    de color global se la come.
    En la frontera no se limita a bajar el alfa: deshace la mezcla con el fondo,
    que es lo que evita el contorno claro sobre escenas oscuras.
.EXAMPLE
    .\fondo.ps1 -Job dominus_run
.EXAMPLE
    .\fondo.ps1 -Job dominus_run -Tolerancia 8 -Radio 3
#>
param(
    [Parameter(Mandatory = $true)][string]$Job,
    [string]$Desde = '04_limpios',
    [string]$Hacia = '',
    [int]$Tolerancia = 10,
    [int]$Radio = 2,
    [string]$Fondo = '',
    # Derrame: el croma rebota en el personaje y le deja tinte en el borde.
    # -Derrame es a partir de que tinte se corrige lejos del borde, -DerrameBorde
    # cerca de el (donde siempre hay algo, asi que el umbral baja), y -DerrameObjetivo
    # a cuanto se deja. Ojo: los pixeles que caen JUSTO en el umbral se quedan ahi
    # sin corregir, asi que si ves un reborde de color uniforme, baja el umbral
    # de borde por debajo del valor que veas, no subas el objetivo.
    # Tamano por debajo del cual se borra cualquier grupo suelto que no sea el
    # personaje. El grupo mas grande no se toca nunca, asi que subiendolo se
    # quitan objetos enteros del decorado -- una piedra, un cartel -- y no solo
    # las motas del borde. Si el objeto llega a TOCAR al personaje en algun
    # fotograma pasan a ser un solo grupo y ese hay que arreglarlo aparte.
    [int]$Motas = -1,
    [int]$Derrame = -1,
    [int]$DerrameBorde = -1,
    [int]$DerrameObjetivo = -1,
    [switch]$SinCopia,
    [switch]$Rehacer
)
. "$PSScriptRoot\_comun.ps1"
Assert-Herramientas

$python = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $python) { throw 'Hace falta python en el PATH para quitar el fondo' }

$carpeta = Assert-Job $Job
$origen  = Get-Etapa $Job $Desde
if ((Get-ChildItem $origen -Filter '*.png' -ErrorAction SilentlyContinue).Count -eq 0) {
    throw "No hay PNG en $origen"
}
$destino = if ($Hacia) { Join-Path $carpeta $Hacia } else { $origen }

# Si la carpeta ya tiene alfa, volver a pasar por aqui destruiria el trabajo hecho:
# al releer las imagenes el fondo ya no es el gris del video, y el resultado seria
# basura. Ademas es justo donde vive el retoque a mano.
$primera = (Get-ChildItem $origen -Filter '*.png' | Sort-Object Name)[0]
$formato = (& $FFprobe -v error -select_streams v:0 -show_entries stream=pix_fmt `
                       -of csv=p=0 $primera.FullName | Select-Object -First 1).Trim()
if ($formato -match '^(rgba|bgra|argb|abgr|ya|pal8)' -and -not $Rehacer) {
    throw ("Las imagenes de $Desde ya tienen transparencia ($formato). " +
           'Volver a pasarlas por aqui las estropearia y borraria cualquier retoque a mano. ' +
           'Si de verdad quieres rehacerlo, parte de _con_fondo\ o pasa -Rehacer.')
}

if (-not $SinCopia) {
    $copia = Join-Path $carpeta "_con_fondo\$Desde"
    if (Test-Path $copia) {
        Write-Host "Ya habia copia con fondo en _con_fondo\$Desde (no se toca)"
    } else {
        New-Carpeta (Split-Path $copia -Parent)
        Copy-Item $origen -Destination $copia -Recurse -Force
        Write-Host "Copia con fondo guardada en _con_fondo\$Desde"
    }
}

$argumentos = @("$PSScriptRoot\_fondo.py", '--ffmpeg', $FFmpeg,
                '--entrada', $origen, '--salida', $destino,
                '--tolerancia', $Tolerancia, '--radio', $Radio)
if ($Fondo) { $argumentos += @('--fondo', $Fondo) }
if ($Motas -ge 0)            { $argumentos += @('--motas', $Motas) }
if ($Derrame -ge 0)          { $argumentos += @('--derrame', $Derrame) }
if ($DerrameBorde -ge 0)     { $argumentos += @('--derrame-borde', $DerrameBorde) }
if ($DerrameObjetivo -ge 0)  { $argumentos += @('--derrame-objetivo', $DerrameObjetivo) }

& $python.Source @argumentos
if ($LASTEXITCODE -ne 0) { throw "El keyeado fallo (codigo $LASTEXITCODE)" }

Write-Host ''
Write-Host "Siguiente:  .\ciclo.ps1 -Job $Job -Desde 04_limpios -Fps 24 -Fondo 101418"
