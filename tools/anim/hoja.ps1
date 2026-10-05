<#
.SYNOPSIS
    Monta el spritesheet final y la ficha con los datos que pide Godot.
.DESCRIPTION
    Coge 04_limpios (o 03_seleccion si aun no has retocado) y saca a 05_salida
    un PNG en rejilla sin margenes + un .txt con hframes/vframes/tamano de casilla,
    que es justo lo que hay que meter en el AnimatedSprite2D / SpriteFrames.

    Las casillas se pegan sin separacion, asi que la unica proteccion contra que
    una se mezcle con la vecina es el margen transparente que el personaje deja
    dentro de la suya. Al terminar se mide y se avisa si se queda corto.
.EXAMPLE
    .\hoja.ps1 -Job dominus_run
.EXAMPLE
    .\hoja.ps1 -Job dominus_run -Cols 4 -Fps 10
.EXAMPLE
    # reducida a la mitad para el juego; el master se queda intacto
    .\hoja.ps1 -Job magnus_corriendo -Cols 6 -Fps 24 -Escala 2
#>
param(
    [Parameter(Mandatory = $true)][string]$Job,
    [string]$Desde = '',
    [int]$Cols = 0,
    [double]$Fps = 12,
    [int]$Escala = 1,
    [int]$AnchoMaximo = 4096
)
. "$PSScriptRoot\_comun.ps1"
Assert-Herramientas

if (-not $Desde) {
    $Desde = '04_limpios'
    if ((Get-ChildItem (Get-Etapa $Job '04_limpios') -Filter '*.png' -ErrorAction SilentlyContinue).Count -eq 0) {
        $Desde = '03_seleccion'
        Write-Host '04_limpios esta vacia: uso 03_seleccion (sin retocar)'
    }
}

$origen  = Get-Etapa $Job $Desde
$destino = Get-Etapa $Job '05_salida'
New-Carpeta $destino
$lista = Get-ChildItem $origen -Filter '*.png' | Sort-Object Name
if ($lista.Count -eq 0) { throw "No hay PNG en $origen" }

# Godot corta la rejilla en casillas iguales: si un PNG no mide lo mismo, no cuadra.
$base = Get-TamanoImagen $lista[0].FullName
foreach ($f in $lista) {
    $t = Get-TamanoImagen $f.FullName
    if ($t.Ancho -ne $base.Ancho -or $t.Alto -ne $base.Alto) {
        throw "$($f.Name) mide $($t.Ancho)x$($t.Alto) y $($lista[0].Name) mide $($base.Ancho)x$($base.Alto). Todas las casillas deben medir igual."
    }
}

if ($Cols -le 0) {
    $Cols = [Math]::Max(1, [Math]::Min($lista.Count, [int][Math]::Floor($AnchoMaximo / $base.Ancho)))
}
$Filas = [int][Math]::Ceiling($lista.Count / [double]$Cols)

# Reduccion para el juego. Los PNG de 04_limpios se quedan a resolucion
# completa como master: si algun dia hace falta otra escala, se reexporta desde
# aqui sin repetir el keyeado ni la alineacion.
$anchoFinal = $base.Ancho
$altoFinal  = $base.Alto
$reducir = ''
if ($Escala -gt 1) {
    if (($base.Ancho % $Escala) -ne 0 -or ($base.Alto % $Escala) -ne 0) {
        throw ("La casilla $($base.Ancho)x$($base.Alto) no se divide exacta entre $Escala. " +
               'Redondear desplazaria el eje del personaje y se perderia la alineacion entre animaciones.')
    }
    $anchoFinal = $base.Ancho / $Escala
    $altoFinal  = $base.Alto / $Escala
    # Hay que premultiplicar antes de reducir: los pixeles transparentes conservan
    # el color del croma en su RGB, y al interpolar se colaria en el borde. Medido
    # sobre un fotograma: sin premultiplicar, 238 px con tinte verde; con ello, 102.
    # 'area' promedia las casillas de origen, que para una reduccion exacta es lo
    # correcto y no genera los rebotes de lanczos sobre el alfa premultiplicado.
    $reducir = "format=rgba,premultiply=inplace=1,scale=${anchoFinal}:${altoFinal}:flags=area,unpremultiply=inplace=1,"
}

$tmp    = New-SecuenciaTemporal $lista "hoja_$Job"
$salida = Join-Path $destino "${Job}_sheet.png"
try {
    Invoke-FFmpeg @('-hide_banner', '-loglevel', 'warning', '-y',
        '-framerate', '1', '-start_number', '1',
        '-i', (Join-Path $tmp 's_%04d.png'),
        '-vf', "${reducir}tile=${Cols}x${Filas}:padding=0:margin=0:color=0x00000000",
        '-frames:v', '1', '-update', '1', $salida)
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

$ficha = @(
    "animacion:  $Job",
    "origen:     $Desde",
    "hoja:       $(Split-Path $salida -Leaf)",
    "casilla:    $anchoFinal x $altoFinal px",
    "escala:     1/$Escala   (master en 04_limpios: $($base.Ancho) x $($base.Alto))",
    "hframes:    $Cols",
    "vframes:    $Filas",
    "fotogramas: $($lista.Count)   (las $($Cols * $Filas - $lista.Count) casillas sobrantes van vacias)",
    "fps:        $Fps",
    '',
    'En Godot: Sprite2D/AnimatedSprite2D -> Animation -> Hframes/Vframes con esos valores,',
    "o SpriteFrames -> Add frames from sheet, usando solo los primeros $($lista.Count)."
)
Set-Content -Path (Join-Path $destino "${Job}_sheet.txt") -Value $ficha -Encoding utf8

Write-Host "Hoja: $salida"
$ficha | Select-Object -First 8 | ForEach-Object { Write-Host "  $_" }

# La hoja es un atlas y Godot la muestrea con filtrado bilineal, ademas de
# generar mipmaps que promedian bloques de la hoja entera. Si el personaje llega
# al borde de su casilla, la de al lado se cuela por ahi. El margen transparente
# que queda alrededor es lo que lo impide, asi que conviene saber cuanto hay.
$python = (Get-Command python -ErrorAction SilentlyContinue)
if ($python) {
    & $python.Source "$PSScriptRoot\_margenes.py" $origen --escala $Escala | ForEach-Object { Write-Host $_ }
} else {
    Write-Host '  (sin python en el PATH: no se ha comprobado el margen entre casillas)'
}
