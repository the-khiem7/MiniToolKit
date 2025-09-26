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
$debugMode = $true   # đổi thành $false nếu muốn tắt log debug

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
  $ans = Read-Host "$msg ($def)"
  if ([string]::IsNullOrWhiteSpace($ans)) { return $default }
  return @("y","yes","1","true","t") -contains ($ans.ToLower())
}

function Format-Dt($dt) { $dt.ToString("yyyy:MM:dd HH:mm:ss") }

function Show-Header($title) {
  Write-Host "`n=== $title ===" -ForegroundColor Cyan
}

# ========================[ BUILT-IN PATTERNS ]========================== #
# Mỗi pattern có:
# - Name: mô tả
# - Rx:   REGEX phải có nhóm tên year,mon,day,hour,minute,second
# - Offset: số ký tự bỏ ở đầu tên file (ví dụ bỏ "VID"/"IMG_")
$BuiltInPatterns = @(
  @{ Name="VIDYYYYMMDDhhmmss (ví dụ VID20250105220723)"; 
     Rx='(?<year>\d{4})(?<mon>\d{2})(?<day>\d{2})(?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})'; 
     Offset=3 }, # bỏ "VID"
  @{ Name="IMG_YYYYMMDD_HHMMSS (ví dụ IMG_20250105_220723)"; 
     Rx='(?<year>\d{4})(?<mon>\d{2})(?<day>\d{2})[_-](?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})'; 
     Offset=4 }, # bỏ "IMG_"
  @{ Name="PXL_YYYYMMDD_HHMMSS (ví dụ PXL_20250105_220723)"; 
     Rx='(?<year>\d{4})(?<mon>\d{2})(?<day>\d{2})[_-](?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})'; 
     Offset=4 }, # bỏ "PXL_"
  @{ Name="YYYY-MM-DD_hh.mm.ss (ví dụ 2025-01-05_22.07.23)";
     Rx='(?<year>\d{4})[-_](?<mon>\d{2})[-_](?<day>\d{2})[_ ](?<hour>\d{2})\.(?<minute>\d{2})\.(?<second>\d{2})';
     Offset=0 },
  @{ Name="YYYYMMDD_hhmmss (ví dụ 20250105_220723)";
     Rx='(?<year>\d{4})(?<mon>\d{2})(?<day>\d{2})[_-](?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})';
     Offset=0 },
  @{ Name="IMGYYYYMMDDhhmmss (ví dụ IMG20250105220012)";
     Rx='(?<year>\d{4})(?<mon>\d{2})(?<day>\d{2})(?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})';
     Offset=3 }  # bỏ "IMG"
)

# ========================[ CORE: PARSE LOGIC ]========================== #
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
$path = Ask "Path thư mục (Enter = current)" (Get-Location).Path
if ([string]::IsNullOrWhiteSpace($path)) { $path = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $path)) { Write-Host "[!] Path không tồn tại." -ForegroundColor Red; return }

$recurse     = AskYesNo "Quét đệ quy subfolders?" $true
$setFs       = AskYesNo "Đồng bộ luôn Windows timestamps (Creation/Modified/Access)?" $true
$extInput    = Ask "Phần mở rộng cần xử lý (ví dụ: mp4,jpg,heic; Enter = mặc định mp4,jpg,jpeg,png,heic)" "mp4,jpg,jpeg,png,heic"
$exts        = $extInput.Split(",") | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ }

Show-Header "Chọn pattern để parse thời gian từ tên"
for ($i=0; $i -lt $BuiltInPatterns.Count; $i++) {
  "{0}. {1}" -f ($i+1), $BuiltInPatterns[$i].Name | Write-Host
}
Write-Host "C. Custom regex (phải có nhóm tên: y,M,d,h,m,s)" -ForegroundColor Yellow
$choice = Ask "Chọn (1..$($BuiltInPatterns.Count) hoặc C)" "1"

$rx = $null; $offset = 0
if ($choice -match '^[cC]$') {
  $rxText  = Ask "Nhập regex (ví dụ: (?<y>\d{4})(?<M>\d{2})(?<d>\d{2})(?<h>\d{2})(?<m>\d{2})(?<s>\d{2}))" 
  if ([string]::IsNullOrWhiteSpace($rxText)) { Write-Host "[!] Regex rỗng." -ForegroundColor Red; return }
  try { $rx = [regex]$rxText } catch { Write-Host "[!] Regex không hợp lệ." -ForegroundColor Red; return }
  $offset = [int](Ask "Offset ký tự cần bỏ đầu tên file (số nguyên, Enter=0)" "0")
} else {
  $idx = [int]$choice - 1
  if ($idx -lt 0 -or $idx -ge $BuiltInPatterns.Count) { Write-Host "[!] Lựa chọn không hợp lệ." -ForegroundColor Red; return }
  $rx     = [regex]$($BuiltInPatterns[$idx].Rx)
  $offset = [int]$($BuiltInPatterns[$idx].Offset)
}

Show-Header "Quét & Preview"
$files = Get-ChildItem -LiteralPath $path -File -Recurse:$recurse -ErrorAction SilentlyContinue `
  | Where-Object { $exts -contains $_.Extension.TrimStart('.').ToLower() }

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
  $nameNoExt = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $dt = Parse-DateFromName -nameNoExt $nameNoExt -rx $rx -offset $offset
  $preview += [pscustomobject]@{
    File   = $f.FullName
    Parsed = if ($dt) { $dt } else { $null }
  }
}

# Preview list
$take = [Math]::Min(20, $preview.Count)
if ($take -gt 0) {
  $preview[0..($take-1)] |
    Select-Object @{n="File";e={Split-Path $_.File -Leaf}},
                  @{n="Parsed";e={ if($_.Parsed){$_.Parsed.ToString("yyyy-MM-dd HH:mm:ss")} else {"(no-match)"} }} `
    | Format-Table -AutoSize
}

# Stats
$ok   = $preview | Where-Object { $_.Parsed }
$fail = $preview | Where-Object { -not $_.Parsed }
$okCount = $ok.Count
$noMatch = $fail.Count
Write-Host "`nTổng: $($preview.Count) | Parse OK: $okCount | Không match: $noMatch"

if ($okCount -eq 0) { Write-Host "[!] Không có file nào parse được. Dừng." -ForegroundColor Red; return }

$confirm = AskYesNo "Tiến hành cập nhật metadata bằng exiftool cho $okCount file?" $true
if (-not $confirm) { Write-Host "Đã hủy."; return }

Show-Header "Đang cập nhật metadata (exiftool)…"
$updated = 0
foreach ($row in $ok) {
  $tsExif = (Format-Dt $row.Parsed)
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
      $it.CreationTime   = $row.Parsed
      $it.LastWriteTime  = $row.Parsed
      $it.LastAccessTime = $row.Parsed
      if ($debugMode) { Write-Host "[DEBUG] Updated filesystem timestamps" -ForegroundColor DarkGray }
    }
    $updated++
    Write-Host "[OK] $($row.File)" -ForegroundColor Green
  } catch {
    Write-Host "[FAIL] $($row.File) — $($_.Exception.Message)" -ForegroundColor Red
  }
}

Show-Header "Hoàn tất"
Write-Host "Đã cập nhật: $updated / $okCount file parse-được."
if ($noMatch -gt 0) {
  Write-Host "Không match: $noMatch file. Gợi ý: đổi pattern (regex) hoặc tên file." -ForegroundColor Yellow
}
Write-Host ""