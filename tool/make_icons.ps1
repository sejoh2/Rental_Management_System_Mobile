param([string]$Letter = 'K')

# Draws the app icon images from the brand mark: the orange square with a white letter,
# in Space Grotesk Bold as on the web. Run from the project folder after renaming:
#   powershell -File tool/make_icons.ps1 -Letter X
# then: dart run flutter_launcher_icons ; dart run flutter_native_splash:create
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$out = Join-Path $root 'assets\icon'
New-Item -ItemType Directory -Force $out | Out-Null

$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $root 'assets\fonts\SpaceGrotesk-Bold.ttf'))
$family = $fonts.Families[0]

$orange = [System.Drawing.Color]::FromArgb(193, 68, 14)

function Draw([string]$Name, [int]$Size, [string]$Background, [double]$LetterScale) {
  $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
  $g = [System.Drawing.Graphics]::FromImage($bitmap)
  $g.SmoothingMode = 'AntiAlias'
  $g.TextRenderingHint = 'AntiAliasGridFit'
  $g.Clear([System.Drawing.Color]::Transparent)

  if ($Background -eq 'square') {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush $orange), 0, 0, $Size, $Size)
  } elseif ($Background -eq 'rounded') {
    $r = [int]($Size * 0.22); $d = $r * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc($Size - $d, 0, $d, $d, 270, 90)
    $path.AddArc($Size - $d, $Size - $d, $d, $d, 0, 90)
    $path.AddArc(0, $Size - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush $orange), $path)
  }

  $font = New-Object System.Drawing.Font($family, ($Size * $LetterScale), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $format = New-Object System.Drawing.StringFormat
  $format.Alignment = 'Center'
  $format.LineAlignment = 'Center'
  $box = New-Object System.Drawing.RectangleF 0, ($Size * 0.01), $Size, $Size
  $g.DrawString($Letter, $font, [System.Drawing.Brushes]::White, $box, $format)

  $g.Dispose()
  $bitmap.Save((Join-Path $out $Name), [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
  "made assets/icon/$Name"
}

# The full icon (older Android, iOS): orange to the edges, the phone rounds the corners.
Draw 'icon.png' 1024 'square' 0.56
# Android adaptive icon: the letter alone, inside the area no phone crops; the orange is the background colour.
Draw 'foreground.png' 1024 'none' 0.38
# The splash screen: the rounded brand mark, as on the web.
Draw 'splash.png' 512 'rounded' 0.56
