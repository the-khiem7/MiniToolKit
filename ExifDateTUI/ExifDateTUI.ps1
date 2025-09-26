<# ======================================================================
  ExifDateTUI.ps1 — TUI sửa metadata (EXIF/QuickTime) theo timestamp
  lấy từ TÊN FILE. Phù hợp ảnh/video: MP4/JPG/JPEG/PNG/HEIC, v.v.

  YÊU CẦU:
  - exiftool.exe có trong PATH (gõ `exiftool -ver` phải hiện version)

  TÍNH NĂNG:
  - Chọn thư mục, quét đệ quy (optional)
  - Preview thời gian parse từ tên file
  - Apply: cập nhật metadata bằng exiftool
  - (Optional) Đồng bộ Windows timestamps (Creation/Modified/Access)
  - Built-in patterns + Custom regex (phải có nhóm tên y,M,d,h,m,s)

  DEBUG:
  - bật $debugMode = $true để in log chi tiết quá trình parse
====================================================================== #>

# ==========================[ GLOBAL SETTINGS ]========================== #
$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = "ExifDateTUI — Rename Metadata by Filename"
$debugMode = $false   # đổi thành $false nếu muốn tắt log debug

# =============================[ ASCII ART BANNER ]============================== #
$banner = @'
 /$$$$$$$$           /$$  /$$$$$$  /$$$$$$$              /$$            /$$$$$$$$ /$$   /$$ /$$$$$$
| $$_____/          |__/ /$$__  $$| $$__  $$            | $$           |__  $$__/| $$  | $$|_  $$_/
| $$       /$$   /$$ /$$| $$  \__/| $$  \ $$  /$$$$$$  /$$$$$$    /$$$$$$ | $$   | $$  | $$  | $$  
| $$$$$   |  $$ /$$/| $$| $$$$    | $$  | $$ |____  $$|_  $$_/   /$$__  $$| $$   | $$  | $$  | $$  
| $$__/    \  $$$$/ | $$| $$_/    | $$  | $$  /$$$$$$$  | $$    | $$$$$$$$| $$   | $$  | $$  | $$  
| $$        >$$  $$ | $$| $$      | $$  | $$ /$$__  $$  | $$ /$$| $$_____/| $$   | $$  | $$  | $$  
| $$$$$$$$ /$$/\  $$| $$| $$      | $$$$$$$/|  $$$$$$$  |  $$$$/|  $$$$$$$| $$   |  $$$$$$/ /$$$$$$
|________/|__/  \__/|__/|__/      |_______/  \_______/   \___/   \_______/|__/    \______/ |______/
 _             _____ _                _     _               _____ 
| |__  _   _  /__   \ |__   ___  /\ /\ |__ (_) ___ _ __ ___|___  |
| '_ \| | | |   / /\/ '_ \ / _ \/ //_/ '_ \| |/ _ \ '_ ` _ \  / / 
| |_) | |_| |  / /  | | | |  __/ __ \| | | | |  __/ | | | | |/ /  
|_.__/ \__, |  \/   |_| |_|\___\/  \/|_| |_|_|\___|_| |_| |_/_/   
       |___/                                                      
'@
Write-Host $banner -ForegroundColor Magenta

# =============================[ HELPERS ]=============================== #
function Test-ExifTool {
  $ex = Get-Command exiftool -ErrorAction SilentlyContinue
  if (-not $ex) {
    Write-Host "`n[!] Không tìm thấy exiftool trong PATH. Hãy cài và thêm vào PATH trước nhé." -ForegroundColor Red
    throw "exiftool not found"
  }
}

function Ask($msg, $default="") {
  if ($default) { return Read-Host "$msg [$default]" } 
  else { return Read-Host $msg }
}

function AskYesNo($msg, $default=$true) {
  $def = if ($default) { "Y/n" } else { "y/N" }
  # Only add (Y/n) if not present
  if ($msg -match "\(Y/n\)$" -or $msg -match "\(y/N\)$") {
    $prompt = $msg
  } else {
    $prompt = "$msg ($def)"
  }
  if ($global:debugMode) { Write-Host "[DEBUG] AskYesNo prompt: '$prompt'" -ForegroundColor DarkGray }
  $ans = Read-Host $prompt
  if ([string]::IsNullOrWhiteSpace($ans)) { return $default }
  return @("y","yes","1","true","t") -contains ($ans.ToLower())
}

function Format-Dt($dt) { $dt.ToString("yyyy:MM:dd HH:mm:ss") }

function Show-Header($title) {
  $line = '─' * ($title.Length + 8)
  Write-Host "┌$line┐" -ForegroundColor Cyan
  Write-Host ("│    $title    │") -ForegroundColor Cyan
  Write-Host "└$line┘" -ForegroundColor Cyan
}

# Helper: Show a single-line box for a message
function Show-BoxMessage($msg, $fg='White') {
  $width = $msg.Length + 4
  $line = '─' * ($width-2)
  Write-Host "┌$line┐" -ForegroundColor $fg
  Write-Host ("│ $msg │") -ForegroundColor $fg
  Write-Host "└$line┘" -ForegroundColor $fg
}

function Get-BoxTop($width, $fg) {
  $line = '─' * ($width-2)
  return @{ str = "┌$line┐"; fg = $fg }
}
function Get-BoxMiddle($text, $width, $fg) {
  $padLen = $width-2
  $padText = $text.PadLeft([int](($padLen+$text.Length)/2)).PadRight($padLen)
  return @{ str = "│$padText│"; fg = $fg }
}
function Get-BoxBottom($width, $fg) {
  $line = '─' * ($width-2)
  return @{ str = "└$line┘"; fg = $fg }
}

# ========================[ BUILT-IN PATTERNS ]========================== #
# Mỗi pattern có:
# - Name: mô tả
# - Rx:   REGEX phải có nhóm tên year,mon,day,hour,minute,second
# - Offset: số ký tự bỏ ở đầu tên file (ví dụ bỏ "VID"/"IMG_")
$BuiltInPatterns = @(
  @{ Name="VIDYYYYMMDDhhmmss"; Example="VID20250105220723";
    Rx='(?<year>\d{4})(?<mon>\d{2})(?<day>\d{2})(?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})'; 
    Offset=3 }, # bỏ "VID"
  @{ Name="IMG_YYYYMMDD_HHMMSS"; Example="IMG_20250105_220723";
    Rx='(?<year>\d{4})(?<mon>\d{2})(?<day>\d{2})[_-](?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})'; 
    Offset=4 }, # bỏ "IMG_"
  @{ Name="PXL_YYYYMMDD_HHMMSS"; Example="PXL_20250105_220723";
    Rx='(?<year>\d{4})(?<mon>\d{2})(?<day>\d{2})[_-](?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})'; 
    Offset=4 }, # bỏ "PXL_"
  @{ Name="YYYY-MM-DD_hh.mm.ss"; Example="2025-01-05_22.07.23";
    Rx='(?<year>\d{4})[-_](?<mon>\d{2})[-_](?<day>\d{2})[_ ](?<hour>\d{2})\.(?<minute>\d{2})\.(?<second>\d{2})';
    Offset=0 },
  @{ Name="YYYYMMDD_hhmmss"; Example="20250105_220723";
    Rx='(?<year>\d{4})(?<mon>\d{2})(?<day>\d{2})[_-](?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})';
    Offset=0 },
  @{ Name="IMGYYYYMMDDhhmmss"; Example="IMG20250105220012";
    Rx='(?<year>\d{4})(?<mon>\d{2})(?<day>\d{2})(?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})';
    Offset=3 }  # bỏ "IMG"
)

# ========================[ CORE: PARSE LOGIC ]========================== #
function AutoDetect-DatePattern($nameNoExt, $patterns) {
  if ($debugMode) { Write-Host "[DEBUG] AutoDetect-DatePattern: $nameNoExt" -ForegroundColor DarkGray }
  foreach ($pat in $patterns) {
    $rx = [regex]$pat.Rx
    $offset = [int]$pat.Offset
    $candidate = if ($offset -gt 0 -and $nameNoExt.Length -gt $offset) {
      $nameNoExt.Substring($offset)
    } else {
      $nameNoExt
    }
    if ($debugMode) { Write-Host ("[DEBUG] Try pattern: {0} | Offset={1} | Candidate='{2}' | Regex='{3}'" -f $pat.Name, $offset, $candidate, $rx.ToString()) -ForegroundColor DarkGray }
    $m = $rx.Match($candidate)
    if ($debugMode) { Write-Host ("[DEBUG] Match result: Success={0}" -f $m.Success) -ForegroundColor DarkGray }
    if ($m.Success) { if ($debugMode) { Write-Host ("[DEBUG] >>> Matched pattern: {0}" -f $pat.Name) -ForegroundColor Green }; return $pat }
  }
  if ($debugMode) { Write-Host "[DEBUG] >>> No pattern matched!" -ForegroundColor Red }
  return $null
}
function Parse-DateFromName($nameNoExt, [regex]$rx, [int]$offset=0) {
  if ($debugMode) { Write-Host "[DEBUG] Original name: $nameNoExt" -ForegroundColor DarkGray }

  # cắt prefix theo offset (VID/IMG/PXL...)
  $candidate = if ($offset -gt 0 -and $nameNoExt.Length -gt $offset) { 
    $nameNoExt.Substring($offset) 
  } else { 
    $nameNoExt 
  }
  if ($debugMode) { Write-Host "[DEBUG] After offset($offset): $candidate" -ForegroundColor DarkGray }

  # match regex
  $m = $rx.Match($candidate)
  if ($debugMode) { Write-Host "[DEBUG] Regex: $($rx.ToString()) | Success=$($m.Success)" -ForegroundColor DarkGray }
  if (-not $m.Success) { return $null }

  try {
    $gy = $m.Groups['year'];   $gM = $m.Groups['mon'];    $gd = $m.Groups['day']
    $gh = $m.Groups['hour'];   $gmin = $m.Groups['minute']; $gs = $m.Groups['second']

    if (-not ($gy.Success -and $gM.Success -and $gd.Success -and $gh.Success -and $gmin.Success -and $gs.Success)) {
      if ($debugMode) { Write-Host "[DEBUG] One or more groups missing." -ForegroundColor Red }
      return $null
    }

    $year = [int]$gy.Value
    $mon  = [int]$gM.Value
    $day  = [int]$gd.Value
    $hour = [int]$gh.Value
    $min  = [int]$gmin.Value
    $sec  = [int]$gs.Value

    if ($debugMode) {
      Write-Host "[DEBUG] Parsed groups => year=$year mon=$mon day=$day hour=$hour minute=$min second=$sec" -ForegroundColor DarkGray
    }

    # validate sơ bộ
    if ($mon -lt 1 -or $mon -gt 12 -or $day -lt 1 -or $day -gt 31 -or
        $hour -lt 0 -or $hour -gt 23 -or $min -lt 0 -or $min -gt 59 -or
        $sec -lt 0 -or $sec -gt 59) {
      if ($debugMode) { Write-Host "[DEBUG] Invalid date/time range." -ForegroundColor Red }
      return $null
    }

    return Get-Date -Year $year -Month $mon -Day $day -Hour $hour -Minute $min -Second $sec
  }
  catch {
    if ($debugMode) { Write-Host "[DEBUG] Exception while parsing: $($_.Exception.Message)" -ForegroundColor Red }
    return $null
  }
}


# =============================[ MAIN ]================================== #
try { Test-ExifTool } catch { return }

Show-Header "Chọn thư mục nguồn"

$path = Ask "📁 Path thư mục (Enter = current)" (Get-Location).Path
if ([string]::IsNullOrWhiteSpace($path)) { $path = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $path)) { Write-Host "[!] Path không tồn tại." -ForegroundColor Red; return }

$recurse     = AskYesNo "🔄 Quét đệ quy subfolders?" $true
$setFs       = AskYesNo "🕒 Đồng bộ luôn Windows timestamps (Creation/Modified/Access)?" $true

# Tự động nhận diện phần mở rộng đa phương tiện phổ biến
$mediaExts = @('jpg','jpeg','png','heic','mp4','mov','avi','mkv','webm','gif','bmp','tiff','wav','mp3','aac','flac','ogg','3gp','mpg','mpeg')
$exts = $mediaExts
Write-Host "[INFO] Đang tự động nhận diện các file đa phương tiện: $($exts -join ', ')" -ForegroundColor Cyan



Show-Header "Quét & Preview"
$files = Get-ChildItem -LiteralPath $path -File -Recurse:$recurse -ErrorAction SilentlyContinue `
  | Where-Object { $exts -contains $_.Extension.TrimStart('.').ToLower() }

if ($debugMode) {
  $allFiles = Get-ChildItem -LiteralPath $path -File -Recurse:$recurse -ErrorAction SilentlyContinue
  Write-Host "[DEBUG] Tổng số file tìm thấy: $($allFiles.Count)" -ForegroundColor DarkGray
  foreach ($ff in $allFiles) {
    Write-Host "[DEBUG] File: $($ff.Name) | ext=$($ff.Extension.TrimStart('.').ToLower())" -ForegroundColor DarkGray
  }
}

if ($debugMode) {
  Write-Host "[DEBUG] Extensions filter: $($exts -join ', ')" -ForegroundColor DarkGray
  foreach($ff in $files) {
    $ext = $ff.Extension.TrimStart('.')
    Write-Host "[DEBUG] Found: $($ff.Name) | ext=$ext" -ForegroundColor DarkGray
  }
}

if (-not $files) { Write-Host "[!] Không tìm thấy file phù hợp." -ForegroundColor Yellow; return }

$preview = @()

foreach ($f in $files) {
  if ($debugMode) { Write-Host "[DEBUG] Preview: $($f.Name)" -ForegroundColor DarkGray }
  $nameNoExt = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $pat = AutoDetect-DatePattern $nameNoExt $BuiltInPatterns
  if ($pat) {
  if ($debugMode) { Write-Host "[DEBUG] Matched pattern: $($pat.Name)" -ForegroundColor DarkGray }
    $dt = Parse-DateFromName -nameNoExt $nameNoExt -rx ([regex]$pat.Rx) -offset ([int]$pat.Offset)
  if ($debugMode) { Write-Host "[DEBUG] Parse-DateFromName result: $dt" -ForegroundColor DarkGray }
    $preview += [pscustomobject]@{
      File   = $f.FullName
      Parsed = if ($dt) { $dt } else { $null }
      Pattern = $pat.Name
    }
  } else {
    $preview += [pscustomobject]@{
      File   = $f.FullName
      Parsed = $null
      Pattern = "(no pattern)"
    }
  }
}

# Preview list

$take = [Math]::Min(20, $files.Count)
if ($take -gt 0) {
  Write-Host "┌──────────────────────────┬───────────────────────┬───────────────────────────────┐" -ForegroundColor Yellow
  Write-Host "│ Pattern                  │ Parsed                │ File                          │" -ForegroundColor Yellow
  Write-Host "├──────────────────────────┼───────────────────────┼───────────────────────────────┤" -ForegroundColor Yellow
  for ($i=0; $i -lt $take; $i++) {
    $f = $files[$i]
    $nameNoExt = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    $pat = AutoDetect-DatePattern $nameNoExt $BuiltInPatterns
    if ($pat) {
      $dt = Parse-DateFromName -nameNoExt $nameNoExt -rx ([regex]$pat.Rx) -offset ([int]$pat.Offset)
      $parsed = if ($dt) { $dt.ToString("yyyy-MM-dd HH:mm:ss") } else { "❌ no-match" }
      $patName = $pat.Name.PadRight(24)
    } else {
      $parsed = "❌ no-match"
      $patName = "(no pattern)".PadRight(24)
    }
    $file = (Split-Path $f.FullName -Leaf).PadRight(29)
    Write-Host ("│ {0} │ {1,-21} │ {2} │" -f $patName, $parsed, $file) -ForegroundColor White
  }
  Write-Host "└──────────────────────────┴───────────────────────┴───────────────────────────────┘" -ForegroundColor Yellow
}

# Stats
$ok   = $preview | Where-Object { $_.Parsed }

$fail = $preview | Where-Object { -not $_.Parsed }
$okCount = $ok.Count
$noMatch = $fail.Count

# Show summary stats in three separate boxes with new labels
$box1 = "TOTAL: $($preview.Count)"

$box2 = "OK: $okCount"
$box3 = "NO-MATCH: $noMatch"
$w1 = 12; $w2 = 14; $w3 = 16
Write-Host ""
# Build arrays correctly
$tops = @()
$tops += Get-BoxTop $w1 'Cyan'
$tops += Get-BoxTop $w2 'Green'
$tops += Get-BoxTop $w3 'Yellow'
$mids = @()
$mids += Get-BoxMiddle $box1 $w1 'Cyan'
$mids += Get-BoxMiddle $box2 $w2 'Green'
$mids += Get-BoxMiddle $box3 $w3 'Yellow'
$bots = @()
$bots += Get-BoxBottom $w1 'Cyan'
$bots += Get-BoxBottom $w2 'Green'
$bots += Get-BoxBottom $w3 'Yellow'

# Print all tops in one line
for ($i=0; $i -lt $tops.Count; $i++) {
  Write-Host $tops[$i].str -ForegroundColor $tops[$i].fg -NoNewline
  Write-Host " " -NoNewline
}
Write-Host ""
# Print all middles in one line
for ($i=0; $i -lt $mids.Count; $i++) {
  Write-Host $mids[$i].str -ForegroundColor $mids[$i].fg -NoNewline
  Write-Host " " -NoNewline
}
Write-Host ""
# Print all bottoms in one line
for ($i=0; $i -lt $bots.Count; $i++) {
  Write-Host $bots[$i].str -ForegroundColor $bots[$i].fg -NoNewline
  Write-Host " " -NoNewline
}
Write-Host ""


if ($okCount -eq 0) { Write-Host "[!] Không có file nào parse được. Dừng." -ForegroundColor Red; return }

# Show confirmation box UI (no Y/n)
$confirmMsg = "Tiến hành cập nhật metadata bằng exiftool cho $okCount file?"
Show-BoxMessage $confirmMsg 'Magenta'
Write-Host '(Y/n):' -ForegroundColor Magenta
$confirm = AskYesNo ' ' $true
if (-not $confirm) { Write-Host "Đã hủy."; return }

Show-Header "Đang cập nhật metadata (exiftool)…"
$updated = 0
foreach ($row in $ok) {
  if ($debugMode) { Write-Host "[DEBUG] Update metadata for: $($row.File)" -ForegroundColor DarkGray }
  $nameNoExt = [IO.Path]::GetFileNameWithoutExtension($row.File)
  $pat = AutoDetect-DatePattern $nameNoExt $BuiltInPatterns
    if ($debugMode) { Write-Host "[DEBUG] Detected pattern for update: $($pat.Name)" -ForegroundColor DarkGray }
  if ($pat) {
    if ($debugMode) { Write-Host "[DEBUG] Parse-DateFromName for update: $dt" -ForegroundColor DarkGray }
    $dt = Parse-DateFromName -nameNoExt $nameNoExt -rx ([regex]$pat.Rx) -offset ([int]$pat.Offset)
    $tsExif = (Format-Dt $dt)
    if ($debugMode) { Write-Host "[DEBUG] Applying timestamp $tsExif to $($row.File)" -ForegroundColor DarkGray }
    try {
      & exiftool -overwrite_original -quiet `
        ("-AllDates=$tsExif") `
        ("-MediaCreateDate=$tsExif") `
        ("-TrackCreateDate=$tsExif") `
        ("-TrackModifyDate=$tsExif") `
        ("-FileModifyDate=$tsExif") `
        $row.File | Out-Null

      if ($setFs) {
        $it = Get-Item -LiteralPath $row.File
        $it.CreationTime   = $dt
        $it.LastWriteTime  = $dt
        $it.LastAccessTime = $dt
        if ($debugMode) { Write-Host "[DEBUG] Updated filesystem timestamps" -ForegroundColor DarkGray }
      }
      $updated++
      Write-Host ("✔ $($row.File)") -ForegroundColor Green
    } catch {
      Write-Host ("✗ $($row.File) — $($_.Exception.Message)") -ForegroundColor Red
    }
  } else {
    Write-Host ("✗ $($row.File) — Không detect được pattern!") -ForegroundColor Red
  }
}

Show-Header "Hoàn tất"
Write-Host "Đã cập nhật: $updated / $okCount file parse-được."
if ($noMatch -gt 0) {
  Write-Host "Không match: $noMatch file. Gợi ý: đổi pattern (regex) hoặc tên file." -ForegroundColor Yellow
}
Write-Host ""