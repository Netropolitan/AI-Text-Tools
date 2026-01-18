# Changelog

All notable changes to AI Text Tools will be documented in this file.

## [1.3.0] - 2026-01-18

### Changed
- Fully standalone distribution - no AutoHotkey installation required
- All executables are self-contained compiled binaries
- Simplified installer that only uses compiled executables

### Fixed
- Installer "Finish" button showing cancel confirmation
- Uninstaller errors when closing running instances
- Application not launching after installation

## [1.2.0] - 2026-01-18

### Added
- Professional installer wizard for easy installation
- Uninstaller wizard accessible from About tab
- Settings now stored in AppData (works with Program Files installation)
- Add/Remove Programs integration

### Changed
- Improved installation experience for non-technical users
- Settings migration from old location to AppData

### Fixed
- "Access denied" error when installing to Program Files
- Settings persistence issues with restricted folders

## [1.1.0] - 2026-01-15

### Added
- "Ask AI" prompt with custom question dialog
- Dynamic model lists fetched from providers
- Default provider checkbox on Models and Local tabs
- Anthropic Claude provider support
- Google Gemini provider support
- Theme support (follows system dark/light mode)

### Changed
- Improved provider connection status indicators
- Better error handling for API connections
- Reorganized settings tabs (Models, Local, Prompts)

### Fixed
- "Control is destroyed" error when closing settings during connection
- Model dropdown not updating after provider connection

## [1.0.0] - 2026-01-10

### Added
- Initial release
- OpenAI GPT support
- Ollama local model support
- System tray integration
- Customizable hotkeys (Ctrl+Shift+J, Ctrl+Shift+K)
- Built-in prompts (Fix Grammar, Improve Writing, etc.)
- Custom prompt management
- Secure API key storage using Windows Credential Manager
