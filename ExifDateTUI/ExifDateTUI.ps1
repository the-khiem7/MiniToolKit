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
====================================================================== #>

# ==========================[ GLOBAL SETTINGS ]========================== #
$ErrorActionPreference = 'Stop'
$host.UI.RawUI.WindowTitle = "ExifDateTUI — Rename Metadata by Filename"

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
# - Rx:   REGEX phải có nhóm tên y,M,d,h,m,s
# - Offset: số ký tự bỏ ở đầu tên file (ví dụ bỏ "VID"/"IMG_")
$BuiltInPatterns = @(
  @{ Name="VIDYYYYMMDDhhmmss (ví dụ VID20250105220723)"; 
     Rx='(?<y>\d{4})(?<M>\d{2})(?<d>\d{2})(?<h>\d{2})(?<m>\d{2})(?<s>\d{2})'; 
     Offset=3 }, # bỏ "VID"
  @{ Name="IMG_YYYYMMDD_HHMMSS (ví dụ IMG_20250105_220723)"; 
     Rx='(?<y>\d{4})(?<M>\d{2})(?<d>\d{2})[_-](?<h>\d{2})(?<m>\d{2})(?<s>\d{2})'; 
     Offset=4 }, # bỏ "IMG_"
  @{ Name="PXL_YYYYMMDD_HHMMSS (ví dụ PXL_20250105_220723)"; 
     Rx='(?<y>\d{4})(?<M>\d{2})(?<d>\d{2})[_-](?<h>\d{2})(?<m>\d{2})(?<s>\d{2})'; 
     Offset=4 }, # bỏ "PXL_"
  @{ Name="YYYY-MM-DD_hh.mm.ss (ví dụ 2025-01-05_22.07.23)";
     Rx='(?<y>\d{4})[-_](?<M>\d{2})[-_](?<d>\d{2})[_ ](?<h>\d{2})\.(?<m>\d{2})\.(?<s>\d{2})';
     Offset=0 },
  @{ Name="YYYYMMDD_hhmmss (ví dụ 20250105_220723)";
     Rx='(?<y>\d{4})(?<M>\d{2})(?<d>\d{2})[_-](?<h>\d{2})(?<m>\d{2})(?<s>\d{2})';
     Offset=0 },
  @{ Name="IMGYYYYMMDDhhmmss (ví dụ IMG20250105220012)";
     Rx='(?<y>\d{4})(?<M>\d{2})(?<d>\d{2})(?<h>\d{2})(?<m>\d{2})(?<s>\d{2})';
     Offset=3 }  # bỏ "IMG"
)

# ========================[ CORE: PARSE LOGIC ]========================== #
function Parse-DateFromName($nameNoExt, [regex]$rx, [int]$offset=0) {
  # Nếu có offset (bỏ prefix như VID/IMG/PXL), cắt phía trước
  $s = if ($offset -gt 0 -and $nameNoExt.Length -gt $offset) { $nameNoExt.Substring($offset) } else { $nameNoExt }
  $m = $rx.Match($s)
  if (-not $m.Success) { return $null }
  try {
    $y  = [int]$m.Groups['y'].Value
    $M  = [int]$m.Groups['M'].Value
    $d  = [int]$m.Groups['d'].Value
    $h  = [int]$m.Groups['h'].Value
    $mi = [int]$m.Groups['m'].Value
    $s  = [int]$m.Groups['s'].Value
    return Get-Date -Year $y -Month $M -Day $d -Hour $h -Minute $mi -Second $s
  } catch { return $null }
}

# =============================[ MAIN ]================================== #
try { Test-ExifTool } catch { return }

# ---- Input: Where to scan ----
Show-Header "Chọn thư mục nguồn"
$path = Ask "Path thư mục (Enter = current)" (Get-Location).Path
if ([string]::IsNullOrWhiteSpace($path)) { $path = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $path)) { Write-Host "[!] Path không tồn tại." -ForegroundColor Red; return }

$recurse     = AskYesNo "Quét đệ quy subfolders?" $true
$setFs       = AskYesNo "Đồng bộ luôn Windows timestamps (Creation/Modified/Access)?" $true
$extInput    = Ask "Phần mở rộng cần xử lý (ví dụ: mp4,jpg,heic; Enter = mặc định mp4,jpg,jpeg,png,heic)" "mp4,jpg,jpeg,png,heic"
$exts        = $extInput.Split(",") | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ }

# ---- Choose pattern ----
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

# ---- Scan & preview ----
Show-Header "Quét & Preview"
$files = Get-ChildItem -LiteralPath $path -File -Recurse:$recurse -ErrorAction SilentlyContinue `
  | Where-Object { $exts -contains $_.Extension.TrimStart('.').ToLower() }

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

# ---- Show first N rows ----
$take = [Math]::Min(20, $preview.Count)
if ($take -gt 0) {
  $preview[0..($take-1)] |
    Select-Object @{n="File";e={Split-Path $_.File -Leaf}},
                  @{n="Parsed";e={ if($_.Parsed){$_.Parsed.ToString("yyyy-MM-dd HH:mm:ss")} else {"(no-match)"} }} `
    | Format-Table -AutoSize
}

# ---- Stats (OK vs No-match) ----
$ok   = $preview | Where-Object { $_.Parsed }
$fail = $preview | Where-Object { -not $_.Parsed }
$okCount = $ok.Count
$noMatch = $fail.Count
Write-Host "`nTổng: $($preview.Count) | Parse OK: $okCount | Không match: $noMatch"

if ($okCount -eq 0) { Write-Host "[!] Không có file nào parse được. Dừng." -ForegroundColor Red; return }

# ---- Confirm apply ----
$confirm = AskYesNo "Tiến hành cập nhật metadata bằng exiftool cho $okCount file?" $true
if (-not $confirm) { Write-Host "Đã hủy."; return }

# ---- Apply metadata (and optional filesystem timestamps) ----
Show-Header "Đang cập nhật metadata (exiftool)…"
$updated = 0
foreach ($row in $ok) {
  $tsExif = (Format-Dt $row.Parsed) # yyyy:MM:dd HH:mm:ss
  try {
    # exiftool: cập nhật nhiều tag thời gian thường dùng
    & exiftool -overwrite_original -quiet `
      ("-AllDates=$tsExif") `
      ("-MediaCreateDate=$tsExif") `
      ("-TrackCreateDate=$tsExif") `
      ("-TrackModifyDate=$tsExif") `
      ("-FileModifyDate=$tsExif") `
      --ext lnk --ext url --ext json --ext xmp --ext srt --ext ass --ext txt --ext ini `
      $row.File | Out-Null

    if ($setFs) {
      $it = Get-Item -LiteralPath $row.File
      $it.CreationTime   = $row.Parsed
      $it.LastWriteTime  = $row.Parsed
      $it.LastAccessTime = $row.Parsed
    }
    $updated++
    Write-Host "[OK] $($row.File)" -ForegroundColor Green
  } catch {
    Write-Host "[FAIL] $($row.File) — $($_.Exception.Message)" -ForegroundColor Red
  }
}

# ---- Summary ----
Show-Header "Hoàn tất"
Write-Host "Đã cập nhật: $updated / $okCount file parse-được."
if ($noMatch -gt 0) {
  Write-Host "Không match: $noMatch file. Gợi ý: đổi pattern (regex) hoặc tên file." -ForegroundColor Yellow
}
Write-Host ""