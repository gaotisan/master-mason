<#
.SYNOPSIS
    Previsualiza el ciclo como GIF/APNG, para ver si engancha antes de tocar Godot.
.DESCRIPTION
    Si los PNG ya tienen alfa, pasa -Fondo con un color: el GIF solo admite
    transparencia de un bit y sin componer sobre un color se ve sucio. Ademas
    asi compruebas el personaje sobre el tono real de la escena.
.EXAMPLE
    .\ciclo.ps1 -Job dominus_run -Fps 24
.EXAMPLE
    .\ciclo.ps1 -Job dominus_run -Desde 04_limpios -Fps 24 -Fondo 14100E
.EXAMPLE
    .\ciclo.ps1 -Job dominus_run -Formato apng          # conserva la transparencia
#>
param(
    [Parameter(Mandatory = $true)][string]$Job,
    [double]$Fps = 12,
    [string]$Desde = '03_seleccion',
    [ValidateSet('gif', 'apng')][string]$Formato = 'gif',
    [int]$Ancho = 0,
    [string]$Fondo = ''
)
. "$PSScriptRoot\_comun.ps1"
Assert-Herramientas

$origen  = Get-Etapa $Job $Desde
$destino = Get-Etapa $Job '05_salida'
New-Carpeta $destino
$lista = Get-ChildItem $origen -Filter '*.png' | Sort-Object Name
if ($lista.Count -eq 0) { throw "No hay PNG en $origen" }

$tmp    = New-SecuenciaTemporal $lista "ciclo_$Job"
$inv    = [System.Globalization.CultureInfo]::InvariantCulture
$escala = if ($Ancho -gt 0) { "scale=${Ancho}:-1:flags=lanczos," } else { '' }
$sufijo = if ($Fondo) { "_sobre$Fondo" } else { '' }
$salida = Join-Path $destino "ciclo_$Job$sufijo.$Formato"

try {
    $entrada = @('-hide_banner', '-loglevel', 'warning', '-y')
    if ($Fondo) {
        $t = Get-TamanoImagen $lista[0].FullName
        $entrada += @('-f', 'lavfi', '-i',
                      ('color=c=0x{0}:s={1}x{2}:r={3}' -f $Fondo, $t.Ancho, $t.Alto, $Fps.ToString($inv)))
    }
    $entrada += @('-framerate', $Fps.ToString($inv), '-start_number', '1',
                  '-i', (Join-Path $tmp 's_%04d.png'))
    $componer = if ($Fondo) { '[0][1]overlay=shortest=1:format=auto,' } else { '' }

    if ($Formato -eq 'gif') {
        $filtro = "${componer}${escala}split[a][b];[a]palettegen=reserve_transparent=1[p];[b][p]paletteuse=dither=bayer"
        Invoke-FFmpeg ($entrada + @('-lavfi', $filtro, '-loop', '0', $salida))
    } else {
        $filtro = "${componer}${escala}null"
        Invoke-FFmpeg ($entrada + @('-lavfi', $filtro, '-plays', '0', '-f', 'apng', $salida))
    }
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "$($lista.Count) poses a $Fps fps -> $salida"
