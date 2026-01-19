# Changelog

All notable changes to AI Text Tools will be documented in this file.

## [1.4.10] - 2026-01-19

### Fixed
- Fixed binary download using ADODB.Stream instead of RawWrite (ComObjArray has no "Size" property error)

## [1.4.9] - 2026-01-19

### Improved
- Update success confirmation message shows version number after successful upgrade
- Version info included in error messages for easier troubleshooting
- Fixed registry version to use variable instead of hardcoded value

## [1.4.8] - 2026-01-19

### Fixed
- Installer now uses WinHTTP with proper redirect handling for GitHub downloads
- Tries both tag formats (v1.4.8 and 1.4.8) when downloading updates
- Better error messages showing which URL was attempted

## [1.4.7] - 2026-01-19

### Added
- License agreement in installer - must accept terms before proceeding
- Comprehensive Terms of Use and Disclaimer in application Settings
- Covers liability limitations, AI content warnings, data privacy, acceptable use

## [1.4.6] - 2026-01-19

### Fixed
- Installer now forcefully closes running instances before upgrading (using taskkill)
- Added validation for downloaded files - checks size > 500KB to catch HTML error pages
- Better error messages when download fails or file is invalid

## [1.4.5] - 2026-01-19

### Fixed
- **Critical:** Installer now downloads application files from GitHub when upgrading
- Previously, upgrades failed silently because Setup.exe was alone in temp folder
- Installer detects if running from download location and fetches AITextTools.exe and Uninstall.exe from the matching GitHub release

## [1.4.4] - 2026-01-19

### Improved
- Updater now constructs direct download URL as fallback when release assets aren't listed
- Download failures now offer to open releases page for manual download
- Validates downloaded file size to catch failed/empty downloads

## [1.4.3] - 2026-01-19

### Fixed
- Download update now offers to open releases page if no installer is attached to the release

## [1.4.2] - 2026-01-19

### Added
- "All Models" button in Models tab to refresh available models from provider
- Allows easy switching to newer models when older ones become outdated

## [1.4.1] - 2026-01-19

### Added
- First launch "install" event sent to analytics (distinct from "startup" events)
- Windows security warning instructions in README for non-technical users
- "Get API Key" links for each provider in Models tab
- Step-by-step API key setup instructions in README for non-technical users

### Changed
- Analytics payload now includes app_name field for multi-app tracking support
- Installer wizard now shows "Bykov-Brett Enterprises" branding
- About tab tagline changed to "./run the revolution."

## [1.3.0] - 2026-01-18

### Added
- Auto-update system with GitHub release checking
- Automatic monthly update check (1st of month at 2pm, or next online day)
- One-click download and install updates from Settings
- Installer upgrade mode (`/upgrade` flag) for seamless updates
- Anonymous usage analytics for active user tracking (opt-out available)
- UK/US English spelling toggle in General settings
- "Run on Windows startup" option in installer and settings
- "Start minimized to system tray" option
- Custom tray icon when running from source

### Changed
- Fully standalone distribution - no AutoHotkey installation required
- All executables are self-contained compiled binaries
- Simplified installer that only uses compiled executables
- App shows settings when launched manually, runs silently when auto-started
- Updated Anthropic default model to Claude Sonnet 4
- Gemini API now uses v1beta endpoint for latest models

### Fixed
- Installer "Finish" button showing cancel confirmation
- Uninstaller errors when closing running instances
- Application not launching after installation
- OpenAI API key not connecting (credential storage path issue)
- Anthropic "model not found" error on first connection
- Google Gemini not showing latest models

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
