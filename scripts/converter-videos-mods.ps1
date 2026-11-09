<#
.SYNOPSIS
    Converts Beat Banger mod videos from .webm to .ogv (Theora) on the PC.

.DESCRIPTION
    The Nintendo Switch build of Godot has Theora support but no ffmpeg and no
    VP8/VP9 decoder, so mod videos must be .ogv.

    For every X.webm under the mods folder this script:
      1. creates X.ogv next to it (libtheora, 720p, no audio);
      2. rewrites "X.webm" -> "X.ogv" in the .cfg files of the SAME mod folder.

    The original .webm is kept unless -ApagarWebm is passed.

.PARAMETER Pasta
    Mods folder, e.g. E:\switch\beat-banger\dados\mods.

.PARAMETER Ffmpeg
    Path to ffmpeg.exe. Default: C:\ffmpeg\bin\ffmpeg.exe

.PARAMETER Forcar
    Re-convert even if the .ogv is newer than the .webm.

.PARAMETER ApagarWebm
    Delete X.webm after X.ogv was created successfully.

.PARAMETER SemReescreverConfig
    Only convert; do not touch .cfg files.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\converter-videos-mods.ps1 `
        -Pasta "E:\switch\beat-banger\dados\mods"
#>
[CmdletBinding()]
param(
    [string]$Pasta = (Join-Path $PSScriptRoot "..\mods"),
    [string]$Ffmpeg = "C:\ffmpeg\bin\ffmpeg.exe",
    [switch]$Forcar,
    [switch]$ApagarWebm,
    [switch]$SemReescreverConfig
)

$ErrorActionPreference = "Stop"

function Info($msg, $cor = "White") { Write-Host $msg -ForegroundColor $cor }

Info "=== Beat Banger - mod video converter (webm -> ogv) ===" Cyan
Info "Mods folder : $Pasta"
Info "ffmpeg      : $Ffmpeg"

if (-not (Test-Path -LiteralPath $Ffmpeg)) {
    throw "ffmpeg not found at '$Ffmpeg'. Install it or pass -Ffmpeg C:\path\ffmpeg.exe"
}
if (-not (Test-Path -LiteralPath $Pasta)) {
    throw "Mods folder not found: '$Pasta'. Pass -Pasta with the correct path."
}

$base = (Resolve-Path -LiteralPath $Pasta).Path.TrimEnd('\')
$baseLen = $base.Length

$webms = @(Get-ChildItem -LiteralPath $base -Recurse -File -Filter *.webm -ErrorAction SilentlyContinue)
if ($webms.Count -eq 0) {
    Info "No .webm files found under '$base'." Yellow
    Info "Nothing to do." Yellow
    exit 0
}

Info ("Found {0} .webm file(s)." -f $webms.Count) White
Info ""

$prontos = New-Object System.Collections.Generic.List[System.IO.FileInfo]
$falhas = 0
$i = 0

foreach ($w in $webms) {
    $i++
    $destino = [System.IO.Path]::ChangeExtension($w.FullName, ".ogv")

    if ((-not $Forcar) -and (Test-Path -LiteralPath $destino)) {
        $ogvItem = Get-Item -LiteralPath $destino
        if ($ogvItem.LastWriteTime -ge $w.LastWriteTime -and $ogvItem.Length -gt 0) {
            Info ("[{0}/{1}] SKIP (ogv is up to date): {2}" -f $i, $webms.Count, $w.FullName) DarkGray
            $prontos.Add($w)
            continue
        }
    }

    Info ("[{0}/{1}] Converting: {2}" -f $i, $webms.Count, $w.FullName) Cyan

    $ffArgs = @(
        "-hide_banner", "-loglevel", "error", "-y",
        "-i", $w.FullName,
        "-map", "0:v:0",
        "-vf", "scale=-2:720:flags=lanczos",
        "-pix_fmt", "yuv420p",
        "-c:v", "libtheora",
        "-q:v", "8",
        "-an",
        $destino
    )

    & $Ffmpeg @ffArgs

    $ok = ($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $destino)
    if ($ok) { $ok = (Get-Item -LiteralPath $destino).Length -gt 0 }

    if (-not $ok) {
        Info ("    FAILED (ffmpeg exit {0})" -f $LASTEXITCODE) Red
        $falhas++
        if (Test-Path -LiteralPath $destino) {
            Remove-Item -LiteralPath $destino -Force -ErrorAction SilentlyContinue
        }
        continue
    }

    Info ("    OK -> {0}" -f $destino) Green
    $prontos.Add($w)

    if ($ApagarWebm) {
        Remove-Item -LiteralPath $w.FullName -Force -ErrorAction SilentlyContinue
        Info "    deleted original .webm" DarkGray
    }
}

Info ""
Info ("Converted/ready: {0}   failed: {1}" -f $prontos.Count, $falhas) White

if (-not $SemReescreverConfig -and $prontos.Count -gt 0) {
    $porMod = @{}
    foreach ($w in $prontos) {
        $rel = $w.FullName.Substring($baseLen).TrimStart('\')
        $topo = ($rel -split '\\')[0]
        if (-not $porMod.ContainsKey($topo)) {
            $porMod[$topo] = New-Object System.Collections.Generic.List[string]
        }
        if (-not $porMod[$topo].Contains($w.Name)) {
            $porMod[$topo].Add($w.Name)
        }
    }

    $cfgFiles = @(Get-ChildItem -LiteralPath $base -Recurse -File -Filter *.cfg -ErrorAction SilentlyContinue)
    $cfgAlterados = 0

    foreach ($c in $cfgFiles) {
        $relc = $c.FullName.Substring($baseLen).TrimStart('\')
        $topoc = ($relc -split '\\')[0]
        if (-not $porMod.ContainsKey($topoc)) { continue }

        $texto = Get-Content -LiteralPath $c.FullName -Raw -Encoding UTF8
        if ($null -eq $texto) { continue }
        $novo = $texto

        foreach ($webm in $porMod[$topoc]) {
            $ogv = [System.IO.Path]::ChangeExtension($webm, ".ogv")
            $padrao = [regex]::Escape($webm)
            $novo = [regex]::Replace($novo, $padrao, $ogv,
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }

        if ($novo -ne $texto) {
            [System.IO.File]::WriteAllText($c.FullName, $novo, (New-Object System.Text.UTF8Encoding($false)))
            $cfgAlterados++
            Info ("    config updated: {0}" -f $c.FullName) Yellow
        }
    }

    Info ("Config files updated: {0}" -f $cfgAlterados) White
}

Info ""
if ($falhas -gt 0) {
    Info "Some videos failed. Read the ffmpeg messages above." Red
    exit 1
}

Info "Done. Copy the mods folder (or the SD card) with the new .ogv files." Green
Info "Keep dados\game.sav and friends untouched." Green
exit 0
