<#
.SYNOPSIS
    Crea la carpeta de trabajo de una animacion frame a frame.
.DESCRIPTION
    Un "job" es una animacion: dominus_run, dominus_idle, dominus_punch...
    Deja las etapas 01..05 vacias y apunta de donde sale el material.
.EXAMPLE
    .\nuevo.ps1 -Job dominus_run -Fuente "$HOME\Downloads\podrias_animar_el_personaje_.mp4" -Mover
.EXAMPLE
    .\nuevo.ps1 -Job dominus_idle          # sin fuente: iras metiendo PNG a mano en 01_frames
#>
param(
    [Parameter(Mandatory = $true)][string]$Job,
    [string]$Fuente,
    [switch]$Mover,
    [string]$Nota
)
. "$PSScriptRoot\_comun.ps1"

$carpeta = Get-CarpetaJob $Job
New-Carpeta $carpeta
foreach ($etapa in $EtapasJob) { New-Carpeta (Join-Path $carpeta $etapa) }
New-Carpeta $Fuentes

if ($Fuente) {
    if (-not (Test-Path $Fuente)) { throw "No existe la fuente: $Fuente" }
    $origen  = (Resolve-Path $Fuente).Path
    $destino = Join-Path $Fuentes (Split-Path $origen -Leaf)
    if ($origen -ne $destino) {
        if (Test-Path $destino) {
            Write-Host "Ya estaba en _fuentes: $(Split-Path $destino -Leaf)"
        } elseif ($Mover) {
            Move-Item -LiteralPath $origen -Destination $destino
        } else {
            Copy-Item -LiteralPath $origen -Destination $destino
        }
    }
    Set-Content -Path (Join-Path $carpeta 'fuente.txt') -Value $destino -Encoding utf8
}

$ficha = Join-Path $carpeta 'job.txt'
if (-not (Test-Path $ficha)) {
    $lineas = @(
        "job:     $Job",
        "creado:  $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
        "fuente:  $(if ($Fuente) { Split-Path $Fuente -Leaf } else { '(pendiente)' })",
        "nota:    $Nota",
        '',
        'Flujo:',
        '  01_frames    fotogramas en bruto (frames.ps1, o PNG tuyos/de IA)',
        '  02_contacto  mosaicos numerados para elegir (contacto.ps1)',
        '  03_seleccion los elegidos, renombrados en orden (elegir.ps1)',
        '  04_limpios   retocados / sin fondo  <- aqui trabajas tu en GIMP',
        '  05_salida    spritesheet + ficha para Godot (hoja.ps1)'
    )
    Set-Content -Path $ficha -Value $lineas -Encoding utf8
}

Write-Host "Job listo: $carpeta"
Get-ChildItem $carpeta | Select-Object -ExpandProperty Name | ForEach-Object { Write-Host "  $_" }
