# AI Text Tools

AI-powered text transformation for Windows using hotkeys. Select text anywhere, press a hotkey, and transform it using AI.

![AI Text Tools Demo](https://25517737.fs1.hubspotusercontent-eu1.net/hubfs/25517737/AI-Text-Tools.gif)

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

1. Download the [full release ZIP](https://github.com/Netropolitan/AI-Text-Tools/archive/refs/heads/main.zip)
2. Extract all files to a folder
3. Run `AITextTools-Setup.exe` from the extracted folder
4. Follow the setup wizard

**Important:** The installer needs all three files (`AITextTools.exe`, `AITextTools-Setup.exe`, and `Uninstall.exe`) to be in the same folder. Don't download just the setup file on its own.

### Windows Security Warning

When you run the installer, Windows may show a security warning saying "Windows protected your PC" or "Unknown publisher". This is normal for new software that hasn't been submitted to Microsoft for verification.

**To continue with the installation:**

1. Click **"More info"** (the text link, not a button)
2. Click **"Run anyway"**

The application is safe to use. This warning appears because the software is independently developed and code-signing certificates are expensive.

### Manual Install

1. Download and extract the release ZIP
2. Run `AITextTools.exe`
3. Configure your API keys in the settings

## Video Demo

[![AI Text Tools Demo](https://img.youtube.com/vi/bYSQ_B3JLjU/0.jpg)](https://youtube.com/shorts/bYSQ_B3JLjU)

## Usage

1. **Quick Action (Ctrl+Shift+J)**: Select text and press the hotkey to apply your default prompt
2. **Prompt Menu (Ctrl+Shift+K)**: Select text and press the hotkey to choose from available prompts

### Built-in Prompts

**Writing:**
- Fix spelling & grammar
- Rewrite for clarity
- Make shorter / Make longer
- Make professional
- Simplify language
- Humanify language

**Analysis:**
- Proofread (detailed)
- Summarise
- Explain
- Find action items

**Other:**
- Continue writing
- Convert to/from legalese
- Optimise code
- Ask AI (custom question)

## Configuration

### API Keys

Configure your API keys in the Settings window:

1. Right-click the system tray icon
2. Select "Settings"
3. Go to the "Models" tab for cloud providers or "Local" tab for Ollama
4. Enter your API key and click "Connect"

### Getting an API Key

Each AI provider requires you to create an account and get an API key. Here's how:

#### OpenAI (ChatGPT)
1. Go to [platform.openai.com](https://platform.openai.com/api-keys)
2. Sign up or log in with your account
3. Click "Create new secret key"
4. Copy the key (you won't be able to see it again)
5. Add payment details in Billing - OpenAI charges based on usage (typically pennies per request)

#### Anthropic (Claude)
1. Go to [console.anthropic.com](https://console.anthropic.com/settings/keys)
2. Sign up or log in with your account
3. Click "Create Key"
4. Copy the key
5. Add payment details in Billing - Anthropic charges based on usage

#### Google Gemini
1. Go to [aistudio.google.com](https://aistudio.google.com/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the key
5. Gemini offers a free tier with generous limits

**Tip:** You only need ONE provider to use AI Text Tools. If you're unsure which to choose, Google Gemini is free to start with.

### Supported Providers

| Provider | API Key Required | Notes |
|----------|-----------------|-------|
| OpenAI | Yes | GPT-5, GPT-4, GPT-3.5-turbo |
| Anthropic | Yes | Claude 4.5 Sonnet, Claude 4 Opus/Sonnet/Haiku |
| Google Gemini | Yes | Gemini 3 Pro, Gemini 3 Flash |
| Ollama | No | Local models, requires Ollama installed |

### Recommended Models

For everyday text tasks, these models offer the best balance of speed, quality, and cost:

| Provider | Recommended Model | Why |
|----------|------------------|-----|
| OpenAI | GPT-4.1 nano | Fast and very affordable |
| Anthropic | Claude Haiku 4.5 | Quick responses, low cost |
| Google Gemini | Gemini 2.5 Flash-Lite | Free tier available, fast |

These lightweight models are ideal for grammar fixes, rewrites, and quick text improvements. You can always switch to more powerful models for complex tasks.

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

## Credits

- [ecornell/ai-tools-ahk](https://github.com/ecornell/ai-tools-ahk) - Original AHK AI tools inspiration
- [Serenity](https://autohotkey.com/board/topic/32608-changing-the-system-cursor/) - System cursor modification
- [iseahound](https://github.com/iseahound/SetSystemCursor) - SetSystemCursor implementation

## License

Licensed under CC BY-NC-ND (Creative Commons Attribution-NonCommercial-NoDerivatives).

## Author

(c) 2026 Jamie Bykov-Brett
Bykov-Brett Enterprises
[bykovbrett.net](https://bykovbrett.net)

---

Made with support from [Netropolitan Academy](https://netropolitan.xyz)
