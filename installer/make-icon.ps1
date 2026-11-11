# Membuat assets\airshare.ico (multi-ukuran, entri PNG). Dipanggil oleh build-installer.ps1.
param([string]$Out = (Join-Path $PSScriptRoot "..\assets\airshare.ico"))
Add-Type -AssemblyName System.Drawing

function New-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 2 * $r
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  $p
}

function New-IconPng([int]$s) {
  $bmp = New-Object System.Drawing.Bitmap($s, $s)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = "AntiAlias"
  $g.Clear([System.Drawing.Color]::Transparent)

  # Latar: kotak membulat biru
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Point(0, 0)), (New-Object System.Drawing.Point(0, $s)), [System.Drawing.Color]::FromArgb(59, 130, 246), [System.Drawing.Color]::FromArgb(29, 78, 216))
  $g.FillPath($bg, (New-RoundRect 0 0 $s $s ($s * 0.22)))

  # Monitor
  $white = [System.Drawing.Color]::White
  $pen = New-Object System.Drawing.Pen($white, [Math]::Max(1.5, $s * 0.07))
  $g.DrawPath($pen, (New-RoundRect ($s * 0.16) ($s * 0.20) ($s * 0.68) ($s * 0.46) ($s * 0.06)))
  $brush = New-Object System.Drawing.SolidBrush($white)
  $g.FillRectangle($brush, $s * 0.44, $s * 0.66, $s * 0.12, $s * 0.10)
  $g.FillPath($brush, (New-RoundRect ($s * 0.32) ($s * 0.75) ($s * 0.36) ($s * 0.07) ($s * 0.03)))

  # Ponsel di depan monitor
  $phoneBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(29, 78, 216))
  $g.FillPath($phoneBg, (New-RoundRect ($s * 0.56) ($s * 0.34) ($s * 0.26) ($s * 0.44) ($s * 0.06)))
  $g.FillPath($brush, (New-RoundRect ($s * 0.60) ($s * 0.38) ($s * 0.18) ($s * 0.36) ($s * 0.04)))

  $g.Dispose()
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  , $ms.ToArray()
}

$sizes = @(16, 24, 32, 48, 64, 128, 256)
$pngs = New-Object System.Collections.Generic.List[byte[]]
foreach ($s in $sizes) { $pngs.Add((New-IconPng $s)) }

New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$fs = [System.IO.File]::Create($Out)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $dim = [byte]($sizes[$i] % 256)
  $bw.Write($dim); $bw.Write($dim); $bw.Write([byte]0); $bw.Write([byte]0)
  $bw.Write([uint16]1); $bw.Write([uint16]32)
  $bw.Write([uint32]$pngs[$i].Length); $bw.Write([uint32]$offset)
  $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $bw.Write($p) }
$bw.Close()
Write-Host "Ikon dibuat: $((Resolve-Path $Out).Path)"
