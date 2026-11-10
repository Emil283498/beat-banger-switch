<#
.SYNOPSIS
    Re-encodes Beat Banger videos to 720p / max 30 fps for the Switch port.

.DESCRIPTION
    Godot decodes Theora on the CPU, in the main thread
    (VideoStreamPlaybackTheora::update -> video_write -> YUV->RGBA ->
    texture->update). The cost is roughly width * height * fps, so the game's
    1920x1080@60 videos (main menu background, splash intros) and the
    1920x1080@30 attract videos starve the console and make menus/videos
    stutter.

    This script scans:
      * <Game>\assets\video          (packaged into the .pck)
      * <Data>                       (the `data/` folder next to the .nro)
    and, for every .ogv that is above 720p or above -MaxFps, creates a
    720p / <=30 fps copy (libtheora + Vorbis). Files that already comply are
    skipped, so the script is safe to run again after a game update.

    Originals are copied to -Backup first (only once per file).

.PARAMETER Game
    Godot project folder (decompiled game). Default: D:\BeatBangerSwitch\game

.PARAMETER Data
    `data` folder of the build. Default:
    D:\BeatBangerSwitch\out\beat-banger\switch\beat-banger\data

.PARAMETER Backup
    Where the original videos are copied. Default:
    D:\BeatBangerSwitch\backups\videos-1080p

.PARAMETER Ffmpeg
    Path to ffmpeg.exe. Default: C:\ffmpeg\bin\ffmpeg.exe

.PARAMETER Ffprobe
    Path to ffprobe.exe. Default: C:\ffmpeg\bin\ffprobe.exe

.PARAMETER Height
    Target height. Default: 720 (width is computed keeping the aspect ratio).

.PARAMETER MaxFps
    Frame rate cap. Default: 30.

.PARAMETER Jobs
    How many ffmpeg processes run at the same time. Default: 3.

.PARAMETER Force
    Re-encode even if the file already complies.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\otimizar-videos-switch.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\otimizar-videos-switch.ps1 `
        -Game .\game -Data E:\switch\beat-banger\data -MaxFps 24
#>
[CmdletBinding()]
param(
    [string]$Game = "D:\BeatBangerSwitch\game",
    [string]$Data = "D:\BeatBangerSwitch\out\beat-banger\switch\beat-banger\data",
    [string]$Backup = "D:\BeatBangerSwitch\backups\videos-1080p",
    [string]$Ffmpeg = "C:\ffmpeg\bin\ffmpeg.exe",
    [string]$Ffprobe = "C:\ffmpeg\bin\ffprobe.exe",
    [int]$Height = 720,
    [int]$MaxFps = 30,
    [int]$Jobs = 3,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Log($msg, $color = "White") {
    Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg) -ForegroundColor $color
}

function Get-VideoInfo([string]$path) {
    $csv = & $Ffprobe -v error -select_streams v:0 -show_entries "stream=width,height,r_frame_rate" -of "csv=p=0" $path
    if (-not $csv) { return $null }
    $parts = ($csv | Out-String).Trim() -split ","
    if ($parts.Count -lt 3) { return $null }
    $w = [int]$parts[0]
    $h = [int]$parts[1]
    $fps = 0.0
    if ($parts[2] -match "^(\d+)/(\d+)$") {
        $den = [double]$matches[2]
        if ($den -gt 0) { $fps = [double]$matches[1] / $den }
    }
    $hasAudio = [bool](& $Ffprobe -v error -select_streams a:0 -show_entries "stream=index" -of "csv=p=0" $path)
    return [pscustomobject]@{ Width = $w; Height = $h; Fps = $fps; HasAudio = $hasAudio }
}

if (-not (Test-Path -LiteralPath $Ffmpeg)) {
    throw "ffmpeg not found at '$Ffmpeg'. Install it or pass -Ffmpeg C:\path\ffmpeg.exe"
}
if (-not (Test-Path -LiteralPath $Ffprobe)) {
    throw "ffprobe not found at '$Ffprobe'. Install it or pass -Ffprobe C:\path\ffprobe.exe"
}

$targets = New-Object System.Collections.ArrayList

function Add-Target([string]$dir, [string]$backupRoot) {
    if (-not (Test-Path -LiteralPath $dir)) { return }
    foreach ($f in (Get-ChildItem -LiteralPath $dir -Recurse -File -Filter *.ogv)) {
        if ($f.Name -like "*.tmp.ogv") { continue }
        [void]$targets.Add([pscustomobject]@{ Path = $f.FullName; Root = $dir; BackupRoot = $backupRoot })
    }
}

Add-Target (Join-Path $Game "assets\video") "game-assets\video"
Add-Target $Data "data"

if ($targets.Count -eq 0) { Log "No .ogv files found." "Yellow"; exit 0 }

$queue = New-Object System.Collections.Queue
foreach ($t in $targets) {
    $info = Get-VideoInfo $t.Path
    if (-not $info) { Log ("SKIP (no video stream): {0}" -f $t.Path) "Yellow"; continue }
    $need = $Force -or ($info.Height -gt $Height) -or ($info.Fps -gt $MaxFps)
    if (-not $need) {
        Log ("SKIP (already {0}p{1}): {2}" -f $info.Height, [int]$info.Fps, (Split-Path $t.Path -Leaf)) "DarkGray"
        continue
    }
    $queue.Enqueue([pscustomobject]@{ Item = $t; Info = $info })
}

Log ("To encode: {0} file(s), up to {1} parallel, target {2}p/{3}fps" -f $queue.Count, $Jobs, $Height, $MaxFps) "Cyan"
if ($queue.Count -eq 0) { exit 0 }

$running = New-Object System.Collections.ArrayList
$ok = 0
$failed = 0

while ($queue.Count -gt 0 -or $running.Count -gt 0) {
    while ($queue.Count -gt 0 -and $running.Count -lt $Jobs) {
        $job = $queue.Dequeue()
        $src = $job.Item.Path
        $tmp = [IO.Path]::ChangeExtension($src, ".tmp.ogv")
        $logFile = [IO.Path]::ChangeExtension($src, ".encode.log")
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }

        # NOTE: "$Height:flags" would be parsed as a scoped variable name -> use $().
        $vf = "scale=-2:$($Height):flags=bicubic"
        if ($job.Info.Fps -gt $MaxFps) { $vf += ",fps=$MaxFps" }
        $quality = if ((Split-Path $src -Leaf) -like "attract_*") { 6 } else { 7 }

        $argLine = "-hide_banner -loglevel error -y -i `"$src`" -map 0:v:0 -map 0:a? -vf `"$vf`" -pix_fmt yuv420p -c:v libtheora -q:v $quality -c:a libvorbis -q:a 4 `"$tmp`""

        Log ("START {0}  ({1}x{2} {3:0.##}fps -> {4}p)" -f (Split-Path $src -Leaf), $job.Info.Width, $job.Info.Height, $job.Info.Fps, $Height) "Cyan"
        $proc = Start-Process -FilePath $Ffmpeg -ArgumentList $argLine -NoNewWindow -PassThru -RedirectStandardError $logFile
        [void]$running.Add([pscustomobject]@{ Proc = $proc; Job = $job; Tmp = $tmp; Log = $logFile })
    }

    Start-Sleep -Seconds 2
    for ($i = $running.Count - 1; $i -ge 0; $i--) {
        $r = $running[$i]
        $r.Proc.Refresh()
        if (-not $r.Proc.HasExited) { continue }

        $src = $r.Job.Item.Path
        $size = 0
        if (Test-Path -LiteralPath $r.Tmp) { $size = (Get-Item -LiteralPath $r.Tmp).Length }
        # PowerShell 5.1 does not expose ExitCode reliably when -RedirectStandardError
        # is used, so validate the produced file instead of trusting the exit code.
        $probe = $null
        if ($size -gt 1024) { $probe = Get-VideoInfo $r.Tmp }
        if ($probe -and $probe.Width -gt 0 -and $probe.Height -le $Height) {
            $rel = $src.Substring($r.Job.Item.Root.Length).TrimStart('\')
            $bak = Join-Path (Join-Path $Backup $r.Job.Item.BackupRoot) $rel
            $bakDir = Split-Path -Parent $bak
            if (-not (Test-Path -LiteralPath $bakDir)) { New-Item -ItemType Directory -Path $bakDir -Force | Out-Null }
            if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $src -Destination $bak -Force }
            $oldSize = (Get-Item -LiteralPath $src).Length
            Move-Item -LiteralPath $r.Tmp -Destination $src -Force
            Log ("OK    {0}  {1:N1} MB -> {2:N1} MB" -f (Split-Path $src -Leaf), ($oldSize / 1MB), ($size / 1MB)) "Green"
            $ok++
        } else {
            Log ("FAIL  {0}  (ffmpeg exit {1})" -f (Split-Path $src -Leaf), $r.Proc.ExitCode) "Red"
            if (Test-Path -LiteralPath $r.Log) {
                Get-Content -LiteralPath $r.Log -Tail 5 | ForEach-Object { Log ("      " + $_) "DarkRed" }
            }
            $failed++
            if (Test-Path -LiteralPath $r.Tmp) { Remove-Item -LiteralPath $r.Tmp -Force -ErrorAction SilentlyContinue }
        }
        if (Test-Path -LiteralPath $r.Log) { Remove-Item -LiteralPath $r.Log -Force -ErrorAction SilentlyContinue }
        $running.RemoveAt($i)
    }
}

Log ("Done. encoded={0} failed={1}" -f $ok, $failed) "White"
Log "Re-export the .pck afterwards (exportar-pck.ps1) and copy data\ to the SD card." "Cyan"
if ($failed -gt 0) { exit 1 }
exit 0
