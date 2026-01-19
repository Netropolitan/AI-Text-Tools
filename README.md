# AI Text Tools

AI-powered text transformation for Windows using hotkeys. Select text anywhere, press a hotkey, and transform it using AI.

## Features

- **Multiple AI Providers**: OpenAI, Anthropic Claude, Google Gemini, and local Ollama
- **UK/US English Spelling**: Toggle between British and American English spelling in output
- **Customizable Hotkeys**: Default Ctrl+Shift+J for quick action, Ctrl+Shift+K for prompt menu
- **Custom Prompts**: Create and manage your own prompts
- **System Tray Integration**: Runs quietly in the background
- **Startup Options**: Run on Windows startup, start minimized to tray
- **Secure Credential Storage**: API keys stored with Base64 encoding

## Installation

### Quick Install (Recommended)

1. Download `AITextTools-Setup.exe` from the [Releases](https://github.com/Netropolitan/AI-Text-Tools/releases) page
2. Run the installer
3. Follow the setup wizard

### Manual Install

1. Download and extract the release ZIP
2. Run `AITextTools.exe`
3. Configure your API keys in the settings

## Usage

1. **Quick Action (Ctrl+Shift+J)**: Select text and press the hotkey to apply your default prompt
2. **Prompt Menu (Ctrl+Shift+K)**: Select text and press the hotkey to choose from available prompts

### Built-in Prompts

- Fix Grammar
- Improve Writing
- Make Professional
- Simplify
- Summarize
- Translate to English
- Ask AI (custom question)

## Configuration

### API Keys

Configure your API keys in the Settings window:

1. Right-click the system tray icon
2. Select "Settings"
3. Go to the "Models" tab for cloud providers or "Local" tab for Ollama
4. Enter your API key and click "Connect"

### Supported Providers

| Provider | API Key Required | Notes |
|----------|-----------------|-------|
| OpenAI | Yes | GPT-5, GPT-4, GPT-3.5-turbo |
| Anthropic | Yes | Claude 4.5 Sonnet, Claude 4 Opus/Sonnet/Haiku |
| Google Gemini | Yes | Gemini 3 Pro, Gemini 3 Flash |
| Ollama | No | Local models, requires Ollama installed |

## Requirements

- Windows 10 or later
- Internet connection (for cloud providers)
- [Ollama](https://ollama.ai) (optional, for local models)

**Note:** No additional software is required. The application is fully standalone.

## For Developers

If you want to modify the source code or build from source:

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Clone the repository
3. Run `src/main.ahk` with AutoHotkey v2, or compile with:
```batch
scripts\build-all.bat
```

## License

Licensed under CC BY-NC-ND (Creative Commons Attribution-NonCommercial-NoDerivatives).

## Author

(c) 2026 Jamie Bykov-Brett
Bykov-Brett Enterprises
[bykovbrett.net](https://bykovbrett.net)

---

Made with support from [Netropolitan Academy](https://netropolitan.xyz)

