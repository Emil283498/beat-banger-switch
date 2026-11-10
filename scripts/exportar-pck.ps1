<#
.SYNOPSIS
    Imports a Godot project and exports a .pck for the Nintendo Switch port.

.DESCRIPTION
    Runs `godot --headless --import`, then `godot --headless --export-pack`,
    then verifies the PCK index:
      * no `data/` entries (game assets must stay outside the PCK);
      * `cacert.crt` included when the project has one (needed for HTTPS).

    The temporary file MUST end in `.pck`, otherwise Godot refuses to export.

.PARAMETER Projeto
    Decompiled/patched Godot project folder (contains project.godot).

.PARAMETER Destino
    Output .pck path.

.PARAMETER Godot
    Path to the Godot 4.7.2 console executable. If omitted, `godot` from PATH.

.PARAMETER Preset
    Export preset name in export_presets.cfg. Default: Switch.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\exportar-pck.ps1 `
        -Projeto .\game -Destino .\out\beat-banger.pck `
        -Godot "C:\Tools\Godot472\Godot_v4.7.2-stable_win64_console.exe"
#>
[CmdletBinding()]
param(
    [string]$Projeto = (Join-Path $PSScriptRoot "..\game"),
    [string]$Destino = (Join-Path $PSScriptRoot "..\out\beat-banger.pck"),
    [string]$Godot = "",
    [string]$Preset = "Switch"
)

$ErrorActionPreference = "Stop"

function Resolve-GodotExe {
    param([string]$Path)
    if ($Path) {
        if (-not (Test-Path -LiteralPath $Path)) { throw "Godot not found: $Path" }
        return (Resolve-Path -LiteralPath $Path).Path
    }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "Godot not found. Pass -Godot C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
}

function Test-PckIndex {
    param([string]$Path, [bool]$ExpectCert)

    $fs = [IO.File]::OpenRead($Path)
    try {
        $head = New-Object byte[] 40
        if ($fs.Read($head, 0, 40) -ne 40) { throw "PCK too small: $Path" }
        if ([Text.Encoding]::ASCII.GetString($head, 0, 4) -ne "GDPC") {
            throw "Not a Godot PCK (missing GDPC magic): $Path"
        }

        $dirOffset = [BitConverter]::ToUInt64($head, 32)
        $indexLen = [int]($fs.Length - $dirOffset)
        if ($indexLen -le 4) { throw "Invalid PCK index offset: $dirOffset" }

        $buf = New-Object byte[] $indexLen
        $fs.Position = $dirOffset
        $read = $fs.Read($buf, 0, $indexLen)
        if ($read -ne $indexLen) { throw "Short read of PCK index" }

        $count = [BitConverter]::ToUInt32($buf, 0)
        $pos = 4
        $hasCert = $false
        $hasData = $false
        $videoCount = 0

        for ($i = 0; $i -lt $count; $i++) {
            $pathLen = [BitConverter]::ToUInt32($buf, $pos)
            $pos += 4
            $entry = [Text.Encoding]::UTF8.GetString($buf, $pos, $pathLen).TrimEnd([char]0)
            $pos += $pathLen + 36   # offset(8) + size(8) + md5(16) + flags(4)
            if ($entry -eq "cacert.crt") { $hasCert = $true }
            if ($entry.StartsWith("data/")) { $hasData = $true }
            if ($entry.StartsWith("assets/video/") -and $entry.EndsWith(".ogv")) { $videoCount++ }
        }

        Write-Host ("   header: file_base={0}, dir_offset={1}, entries={2}" -f `
            [BitConverter]::ToUInt64($head, 24), $dirOffset, $count)

        if ($hasData) { throw "PCK contains data/ entries - game assets must stay outside the PCK" }
        Write-Host ("   OK: no data/ entries ({0} files)" -f $count)

        # attract_screen.gd loads its videos at runtime (load() instead of preload()),
        # so the exporter must keep them because of include_filter="*.crt,*.ogv".
        Write-Host ("   assets/video/*.ogv in PCK: {0}" -f $videoCount)
        if ($videoCount -eq 0) {
            throw "PCK has no assets/video/*.ogv - check include_filter in export_presets.cfg"
        }

        if ($ExpectCert) {
            if (-not $hasCert) { throw "PCK is missing cacert.crt (HTTPS will not work)" }
            Write-Host "   OK: cacert.crt included"
        }
        return $count
    }
    finally {
        $fs.Dispose()
    }
}

$godotExe = Resolve-GodotExe $Godot
$projetoPath = (Resolve-Path -LiteralPath $Projeto).Path
$destinoPath = [IO.Path]::GetFullPath($Destino)

if (-not (Test-Path -LiteralPath (Join-Path $projetoPath "project.godot"))) {
    throw "Godot project not found: $projetoPath\project.godot"
}
if (-not (Test-Path -LiteralPath (Join-Path $projetoPath "export_presets.cfg"))) {
    throw "export_presets.cfg not found in $projetoPath"
}

$presetsText = Get-Content -LiteralPath (Join-Path $projetoPath "export_presets.cfg") -Raw
$presetPattern = '(?m)^name="?' + [regex]::Escape($Preset) + '"?\s*$'
if ($presetsText -notmatch $presetPattern) {
    throw "Preset '$Preset' not found in export_presets.cfg"
}

$destinoDir = Split-Path -Parent $destinoPath
if (-not (Test-Path -LiteralPath $destinoDir)) {
    New-Item -ItemType Directory -Path $destinoDir -Force | Out-Null
}

$hasCert = Test-Path -LiteralPath (Join-Path $projetoPath "cacert.crt")

Write-Host "== Godot:  $godotExe"
Write-Host "== Project: $projetoPath"
Write-Host "== Output:  $destinoPath"
Write-Host ""

Write-Host "== 1/3 Importing resources (may take several minutes)..."
& $godotExe --headless --path $projetoPath --import
if ($LASTEXITCODE -ne 0) { throw "Godot --import failed (exit $LASTEXITCODE)" }

$tmp = "$destinoPath.novo.pck"
if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }

Write-Host "== 2/3 Exporting PCK to $tmp ..."
& $godotExe --headless --path $projetoPath --export-pack $Preset $tmp
if ($LASTEXITCODE -ne 0) { throw "Godot --export-pack failed (exit $LASTEXITCODE)" }
if (-not (Test-Path -LiteralPath $tmp)) { throw "Export produced no file: $tmp" }

Write-Host "== 3/3 Verifying PCK index..."
$files = Test-PckIndex -Path $tmp -ExpectCert $hasCert

$tmpInfo = Get-Item -LiteralPath $tmp
if ($tmpInfo.Length -lt 1024) { throw "Exported PCK looks too small: $($tmpInfo.Length) bytes" }

if (Test-Path -LiteralPath $destinoPath) { Remove-Item -LiteralPath $destinoPath -Force }
Move-Item -LiteralPath $tmp -Destination $destinoPath

$info = Get-Item -LiteralPath $destinoPath
Write-Host ("OK: {0} ({1:N0} bytes, {2} entries)" -f $destinoPath, $info.Length, $files) -ForegroundColor Green

# Godot writes warnings/errors to stderr even on success; PowerShell 5.1 may leave
# $LASTEXITCODE = 1 and turn a successful run into a non-zero process exit code.
exit 0
