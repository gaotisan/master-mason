# Rutas y funciones compartidas por los scripts de tools\anim.
# No se ejecuta suelto: los demas lo cargan con  . "$PSScriptRoot\_comun.ps1"

$ErrorActionPreference = 'Stop'

# tools\anim esta dentro del proyecto: la raiz es el proyecto. Llamado por
# godot\tools (el enlace que quedo en el sitio de antes) sale godot\, y tools\ y
# raw\ se resuelven igual por los enlaces.
$RaizGodot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$FFmpeg    = Join-Path $RaizGodot 'tools\ffmpeg\bin\ffmpeg.exe'
$FFprobe   = Join-Path $RaizGodot 'tools\ffmpeg\bin\ffprobe.exe'
$RaizAnim  = Join-Path $RaizGodot 'raw\master_mason\anim'
$Fuentes   = Join-Path $RaizAnim '_fuentes'

# Las etapas del flujo, en orden. El numero delante es el orden de trabajo.
$EtapasJob = @('01_frames','02_contacto','03_seleccion','04_limpios','05_salida')

function Assert-Herramientas {
    if (-not (Test-Path $FFmpeg))  { throw "No encuentro ffmpeg en $FFmpeg" }
    if (-not (Test-Path $FFprobe)) { throw "No encuentro ffprobe en $FFprobe" }
}

function Get-CarpetaJob([string]$Job) {
    if ([string]::IsNullOrWhiteSpace($Job)) { throw 'Falta -Job (nombre de la animacion, p.ej. dominus_run)' }
    Join-Path $RaizAnim $Job
}

function Assert-Job([string]$Job) {
    $carpeta = Get-CarpetaJob $Job
    if (-not (Test-Path $carpeta)) { throw "El job '$Job' no existe. Crealo con:  .\nuevo.ps1 -Job $Job" }
    return $carpeta
}

function Get-Etapa([string]$Job, [string]$Etapa) {
    Join-Path (Assert-Job $Job) $Etapa
}

function New-Carpeta([string]$Ruta) {
    if (-not (Test-Path $Ruta)) { New-Item -ItemType Directory -Path $Ruta -Force | Out-Null }
}

function Clear-Carpeta([string]$Ruta) {
    New-Carpeta $Ruta
    Get-ChildItem -Path $Ruta -File | Remove-Item -Force -Confirm:$false
}

# Ejecuta ffmpeg y revienta si falla, en vez de seguir con salida a medias.
function Invoke-FFmpeg([string[]]$Argumentos) {
    Assert-Herramientas
    & $FFmpeg @Argumentos
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg fallo (codigo $LASTEXITCODE)" }
}

# Resuelve el video/imagen de origen de un job: el -Fuente dado, o el unico
# archivo que haya en _fuentes referenciado por fuente.txt del job.
function Resolve-Fuente([string]$Job, [string]$Fuente) {
    if ($Fuente) {
        if (-not (Test-Path $Fuente)) { throw "No existe la fuente: $Fuente" }
        return (Resolve-Path $Fuente).Path
    }
    $apunte = Join-Path (Assert-Job $Job) 'fuente.txt'
    if (Test-Path $apunte) {
        $ruta = (Get-Content $apunte -TotalCount 1).Trim()
        if ($ruta -and (Test-Path $ruta)) { return (Resolve-Path $ruta).Path }
        # La ruta es absoluta: en otra maquina (o si se mueve la carpeta) se busca
        # el mismo archivo en _fuentes.
        if ($ruta) {
            $aqui = Join-Path $Fuentes (Split-Path $ruta -Leaf)
            if (Test-Path $aqui) { return (Resolve-Path $aqui).Path }
        }
    }
    throw "El job '$Job' no tiene fuente. Pasa -Fuente <archivo> o apuntala en $apunte"
}

# "3,7,10-14,20" -> 3,7,10,11,12,13,14,20
function Expand-Rangos([string]$Texto) {
    $salida = New-Object System.Collections.Generic.List[int]
    foreach ($trozo in ($Texto -split ',')) {
        $t = $trozo.Trim()
        if (-not $t) { continue }
        if ($t -match '^(\d+)\s*-\s*(\d+)$') {
            $a = [int]$Matches[1]; $b = [int]$Matches[2]
            $a..$b | ForEach-Object { $salida.Add($_) }
        } elseif ($t -match '^\d+$') {
            $salida.Add([int]$t)
        } else {
            throw "No entiendo '$t' en la lista de frames. Formato: 3,7,10-14,20"
        }
    }
    if ($salida.Count -eq 0) { throw 'La lista de frames esta vacia' }
    return $salida
}

# Devuelve @{ Ancho; Alto } de un PNG, para comprobar que la hoja cuadra.
function Get-TamanoImagen([string]$Ruta) {
    Assert-Herramientas
    $txt = & $FFprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x $Ruta
    if ($LASTEXITCODE -ne 0) { throw "ffprobe fallo leyendo $Ruta" }
    $p = ($txt | Select-Object -First 1).Trim() -split 'x'
    return @{ Ancho = [int]$p[0]; Alto = [int]$p[1] }
}

# Copia los PNG a una carpeta temporal renumerados s_0001.png, s_0002.png...
# Asi ffmpeg los lee con el demuxer image2 (una secuencia de verdad) sin depender
# de como se llamen los originales. El demuxer concat descarta fotogramas con PNG.
function New-SecuenciaTemporal([System.IO.FileInfo[]]$Archivos, [string]$Nombre) {
    $dir = Join-Path $env:TEMP "anim_$Nombre"
    if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $i = 0
    foreach ($f in $Archivos) {
        $i++
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $dir ('s_{0:d4}.png' -f $i))
    }
    return $dir
}

# Ruta de fuente para drawtext, escapada como espera el parser de filtros.
function Get-FuenteTexto {
    $candidatas = @("$env:WINDIR\Fonts\consola.ttf", "$env:WINDIR\Fonts\arial.ttf")
    foreach ($f in $candidatas) { if (Test-Path $f) { return $f.Replace('\', '/').Replace(':', '\:') } }
    throw 'No encuentro ninguna fuente TTF para numerar la hoja de contactos'
}
