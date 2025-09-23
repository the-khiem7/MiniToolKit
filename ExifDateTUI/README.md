# 📸 ExifDateTUI

A simple **PowerShell TUI** script that uses [`exiftool`](https://exiftool.org/) to update photo/video metadata (`AllDates`, `MediaCreateDate`, etc.) and optionally Windows file timestamps (`CreationTime`, `LastWriteTime`, `LastAccessTime`) based on **timestamps embedded in filenames**.

> ✨ Perfect for syncing photo & video dates before uploading to Google Photos, OneDrive, iCloud, etc.

![](/ExifDateTUI/docs/image.png)

---

## 🚀 Features

- Interactive Text User Interface (TUI)
- Built-in filename patterns:
  - `VIDYYYYMMDDhhmmss` → e.g. `VID20250105220723.mp4`
  - `IMG_YYYYMMDD_HHMMSS` → e.g. `IMG_20250105_220723.jpg`
  - `PXL_YYYYMMDD_HHMMSS` → e.g. `PXL_20250105_220723.jpg`
  - `YYYY-MM-DD_hh.mm.ss` → e.g. `2025-01-05_22.07.23.jpg`
  - `YYYYMMDD_hhmmss` → e.g. `20250105_220723.jpg`
  - `IMGYYYYMMDDhhmmss` → e.g. `IMG20250105220012.jpg`
- Custom regex support (`(?<year>\d{4})(?<mon>\d{2})...`)
- Debug mode: log regex matching, parsed groups, and applied timestamps
- Applies to multiple extensions (`mp4, jpg, jpeg, png, heic, ...`)

---

## 📥 Installation

1. Install [ExifTool](https://exiftool.org/)  
   - Windows users: download `exiftool(-k).exe`, rename to `exiftool.exe`, and add folder to `PATH`.

2. Clone or download this repository:
   ```powershell
   git clone https://github.com/your-username/ExifDateTUI.git
   cd ExifDateTUI
````

3. Run the script:

   ```powershell
   .\ExifDateTUI.ps1
   ```

---

## 🖥️ Usage

When running, you will be prompted:

1. Select folder to scan
2. Choose whether to recurse subfolders
3. Choose whether to sync Windows file timestamps
4. Select extensions to process (default: `mp4,jpg,jpeg,png,heic`)
5. Pick filename pattern **or** enter custom regex
6. Preview results
7. Confirm to apply updates

Example run:

```powershell
=== Chọn thư mục nguồn ===
Path thư mục (Enter = current) [C:\Users\...\Photos]:
Quét đệ quy subfolders? (Y/n): Y
Đồng bộ luôn Windows timestamps? (Y/n): Y
Phần mở rộng cần xử lý [mp4,jpg,jpeg,png,heic]: jpg

=== Chọn pattern để parse thời gian từ tên ===
1. VIDYYYYMMDDhhmmss (VID20250105220723)
...
6. IMGYYYYMMDDhhmmss (IMG20250105220012)
C. Custom regex
Chọn (1..6 hoặc C) [1]: 6
```

---

## 🔧 Debug Mode

Set `$debugMode = $true` in `ExifDateTUI.ps1` to see:

```
[DEBUG] Original name: IMG20250105220012
[DEBUG] After offset(3): 20250105220012
[DEBUG] Regex: (?<year>\d{4})(?<mon>\d{2})...
[DEBUG] Parsed groups => year=2025 mon=01 day=05 hour=22 minute=00 second=12
```

---

## 📂 Example Supported Filenames

| Filename                  | Parsed Date         |
| ------------------------- | ------------------- |
| `VID20231226211714.mp4`   | 2023-12-26 21:17:14 |
| `VID_20220130_220908.mp4` | 2022-01-30 22:09:08 |
| `IMG20250105220012.jpg`   | 2025-01-05 22:00:12 |
| `PXL_20250105_220723.jpg` | 2025-01-05 22:07:23 |

---

## ⚠️ Notes

* Always back up your files before batch processing!
* ExifTool overwrites metadata in place (`-overwrite_original`).
* Script skips unrelated extensions (`.json`, `.txt`, `.xmp`, etc.).

---

## 🛠️ Roadmap

* [ ] Add more built-in patterns (Samsung, GoPro, DJI, etc.)
* [ ] Add CLI args to bypass TUI (headless mode)
* [ ] Publish as PowerShell module

---

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.

---

## ❤️ Credits

* [ExifTool by Phil Harvey](https://exiftool.org/)
* Inspired by the need to fix thousands of unsynced Google Photos uploads 😉