# 🛠️ MiniToolKit

A collection of lightweight, focused utility tools for everyday productivity tasks. Each tool is designed to be minimal, efficient, and solve specific problems without unnecessary complexity.

> **Philosophy**: Small tools that do one thing well. Like a Swiss Army knife for digital workflows.

## 🎯 Tools Overview

### 📅 [TimetableToCalendar](./TimetableToCalendar/)
**Export FAP University timetables to calendar files**

A JavaScript bookmarklet/userscript that converts FAP (FPT University) timetable pages into `.ics` calendar files compatible with Google Calendar, Outlook, and Apple Calendar.

- **Language**: JavaScript
- **Type**: Browser bookmarklet/userscript
- **Use case**: Students who want to sync their university schedule with their personal calendar apps
- **Features**: Automatic timezone handling (Asia/Ho_Chi_Minh), bulk export, filename sanitization

### 📸 [ExifDateTUI](./ExifDateTUI/)
**Fix photo/video timestamps from filenames**

A PowerShell TUI (Text User Interface) script that updates photo and video metadata using timestamps embedded in filenames. Perfect for organizing media libraries before cloud uploads.

- **Language**: PowerShell
- **Type**: Command-line TUI application
- **Use case**: Photographers/users with mismatched EXIF dates who need to sync metadata with filenames
- **Features**: Multiple filename patterns, custom regex support, batch processing, Windows timestamp sync

## 🚀 Quick Start

### Prerequisites

- **For TimetableToCalendar**: Any modern web browser
- **For ExifDateTUI**: Windows PowerShell + [ExifTool](https://exiftool.org/)

### Usage

1. **Clone the repository**:
   ```bash
   git clone https://github.com/the-khiem7/MiniToolKit.git
   cd MiniToolKit
   ```

2. **Navigate to the tool you need**:
   ```bash
   cd TimetableToCalendar/    # For FAP timetable export
   # OR
   cd ExifDateTUI/           # For photo/video metadata fixing
   ```

3. **Follow the tool-specific README** for detailed instructions.

## 📁 Repository Structure

```
MiniToolKit/
├── README.md                    # This file
├── TimetableToCalendar/         # FAP timetable export tool
│   ├── README.md               # Detailed usage instructions
│   └── TimetableToCalendar.js  # Main script
└── ExifDateTUI/                # EXIF metadata fixing tool
    ├── README.md               # Detailed usage instructions
    ├── ExifDateTUI.ps1         # Main PowerShell script
    └── docs/                   # Documentation assets
        └── image.png
```

## 🤝 Contributing

We welcome contributions! Whether it's:

- 🐛 **Bug reports**: Found an issue? Create an issue with details
- ✨ **Feature requests**: Have an idea? Let's discuss it
- 🔧 **Code contributions**: PRs are welcome
- 📚 **Documentation**: Help improve our docs

### Contribution Guidelines

1. **Keep it minimal**: Tools should be lightweight and focused
2. **No unnecessary dependencies**: Prefer vanilla solutions when possible
3. **Clear documentation**: Include usage examples and clear README files
4. **Cross-platform when possible**: Consider compatibility across different systems

### Adding New Tools

When adding a new tool to the toolkit:

1. Create a new directory with a descriptive name
2. Include a comprehensive `README.md` with:
   - Clear description and use case
   - Installation instructions
   - Usage examples
   - Prerequisites
3. Keep the tool focused on solving one specific problem well
4. Update this main README to include your tool in the overview

## 📜 License

MIT License - see individual tool directories for any specific licensing information.

## 🙏 Credits

- **TimetableToCalendar**: Designed for FPT University students
- **ExifDateTUI**: Built with [ExifTool](https://exiftool.org/) by Phil Harvey

---

## 💡 Philosophy

Each tool in this toolkit follows these principles:

- **Simplicity**: Easy to understand and use
- **Focused**: Solves one problem really well
- **Lightweight**: Minimal dependencies and overhead
- **Practical**: Addresses real-world productivity needs

*"The best tool is the one you actually use."*