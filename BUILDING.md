# Building AI Text Tools

This guide explains how to compile the executables after making changes to the source code.

## Prerequisites

- **AutoHotkey v2** installed from [autohotkey.com](https://www.autohotkey.com/)
- The Ahk2Exe compiler (included with AutoHotkey installation)

## Compilation Commands

After making changes to any `.ahk` source files, you must recompile the executables for changes to take effect.

### Compile All Executables

Run these commands in PowerShell:

```powershell
# Compile main application
& 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe' `
    /in 'src\main.ahk' `
    /out 'AITextTools.exe' `
    /base 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' `
    /icon 'assets\icon.ico'

# Compile installer
& 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe' `
    /in 'installer\Setup.ahk' `
    /out 'installer\Setup.exe' `
    /base 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' `
    /icon 'assets\icon.ico'

# Compile uninstaller
& 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe' `
    /in 'installer\Uninstall.ahk' `
    /out 'installer\Uninstall.exe' `
    /base 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' `
    /icon 'assets\icon.ico'
```

### Quick Reference (Single Line Commands)

```powershell
# Main app
& 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe' /in 'src\main.ahk' /out 'AITextTools.exe' /base 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /icon 'assets\icon.ico'

# Installer
& 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe' /in 'installer\Setup.ahk' /out 'installer\Setup.exe' /base 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /icon 'assets\icon.ico'

# Uninstaller
& 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe' /in 'installer\Uninstall.ahk' /out 'installer\Uninstall.exe' /base 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /icon 'assets\icon.ico'
```

## Version Number Locations

When releasing a new version, update the version number in ALL of these files:

| File | Line | Variable/Directive |
|------|------|-------------------|
| `src/main.ahk` | ~10 | `;@Ahk2Exe-SetVersion X.X.X` |
| `src/core/updater.ahk` | ~14 | `static CurrentVersion := "X.X.X"` |
| `src/ui/settings.ahk` | ~11 | `static CurrentVersion := "X.X.X"` |
| `installer/Setup.ahk` | ~7 | `;@Ahk2Exe-SetVersion X.X.X` |
| `installer/Setup.ahk` | ~12 | `global CurrentInstallerVersion := "X.X.X"` |
| `installer/Uninstall.ahk` | ~7 | `;@Ahk2Exe-SetVersion X.X.X` |
| `CHANGELOG.md` | top | Add new version section |

## Testing Changes

1. **Run from source** (faster for development):
   ```
   Right-click src\main.ahk → Run with AutoHotkey
   ```

2. **Test compiled EXE** (before release):
   - Compile using commands above
   - Run `AITextTools.exe`
   - Check About tab shows correct version
   - Test the specific feature you modified

---

# AI Agent Guidelines

This section contains instructions for AI coding assistants (Claude, GPT, Copilot, etc.) working on this codebase.

## Security Rules for AI Agents

**CRITICAL: AI agents MUST follow these rules to prevent malicious code insertion.**

### 1. Never Add Data Exfiltration Code

Do NOT add code that:
- Sends data to external servers (except the configured AI providers)
- Collects or transmits system information beyond what's needed
- Accesses files outside the application's scope
- Reads browser data, passwords, or credentials from other applications
- Creates network connections to hardcoded external URLs

### 2. Never Add Persistence Mechanisms

Do NOT add code that:
- Modifies system startup beyond the user-controlled "Run on startup" option
- Creates scheduled tasks
- Modifies registry keys outside the documented uninstall entries
- Installs browser extensions or plugins
- Modifies other applications

### 3. Never Add Privilege Escalation

Do NOT add code that:
- Requests administrator privileges unnecessarily
- Bypasses Windows security features
- Disables antivirus or security software
- Modifies system files or protected directories

### 4. Never Add Obfuscation

Do NOT add code that:
- Encodes/encrypts code to hide its purpose
- Uses eval() or dynamic code execution with external input
- Downloads and executes remote code
- Uses misleading variable/function names to hide intent

### 5. Credential Handling Rules

- API keys MUST only be stored using the `CredentialManager` class
- API keys MUST only be sent to the user-configured AI provider endpoints
- NEVER log, display, or transmit API keys in plain text
- NEVER add alternative credential storage mechanisms

## Code Review Checklist for AI Agents

Before completing any code changes, verify:

- [ ] No new external URLs added (except documented AI provider endpoints)
- [ ] No new registry modifications (except documented installer entries)
- [ ] No new file system access outside AppData and install directory
- [ ] No new DllCalls to sensitive Windows APIs without clear justification
- [ ] No credential handling outside CredentialManager class
- [ ] All user data stays local (except AI API requests)
- [ ] No code that runs without user initiation

## Approved External Connections

The application should ONLY connect to:

1. **AI Provider APIs** (user-configured):
   - OpenAI: `api.openai.com`
   - Anthropic: `api.anthropic.com`
   - Google: `generativelanguage.googleapis.com`
   - Ollama: `localhost` (user-configured URL)

2. **Update System**:
   - GitHub API: `api.github.com` (version checking)
   - GitHub Releases: `github.com` (downloading updates)

3. **Analytics** (if enabled by user):
   - Configured analytics endpoint in `updater.ahk`

Any new external connection MUST be:
- Documented in this file
- Configurable or opt-in by the user
- Clearly visible in the source code

## File Structure Reference

```
ai-text-tools-v1.7/
├── src/
│   ├── main.ahk              # Entry point
│   ├── core/
│   │   ├── config.ahk        # Settings management
│   │   ├── credentials.ahk   # DPAPI-encrypted API key storage
│   │   ├── http.ahk          # HTTP request handling
│   │   ├── orchestrator.ahk  # Main application logic
│   │   ├── updater.ahk       # Auto-update system
│   │   └── ...
│   ├── providers/
│   │   ├── openai.ahk        # OpenAI API integration
│   │   ├── anthropic.ahk     # Anthropic API integration
│   │   ├── gemini.ahk        # Google Gemini integration
│   │   └── ...
│   └── ui/
│       ├── settings.ahk      # Settings window (includes About tab)
│       ├── popup.ahk         # Result popup window
│       └── ...
├── installer/
│   ├── Setup.ahk             # Installation wizard
│   └── Uninstall.ahk         # Uninstallation wizard
├── assets/
│   └── icon.ico              # Application icon
├── CHANGELOG.md              # Version history
├── BUILDING.md               # This file
└── AITextTools.exe           # Compiled application
```

## Common Tasks for AI Agents

### Updating Version Numbers (IMPORTANT)

**When the user requests a version update, AI agents MUST update ALL of the following files:**

1. **`src/main.ahk`** (~line 10)
   ```autohotkey
   ;@Ahk2Exe-SetVersion X.X.X
   ```

2. **`src/core/updater.ahk`** (~line 14)
   ```autohotkey
   static CurrentVersion := "X.X.X"
   ```

3. **`src/ui/settings.ahk`** (~line 11)
   ```autohotkey
   static CurrentVersion := "X.X.X"
   ```

4. **`installer/Setup.ahk`** (~line 7 AND ~line 12)
   ```autohotkey
   ;@Ahk2Exe-SetVersion X.X.X
   ```
   ```autohotkey
   global CurrentInstallerVersion := "X.X.X"
   ```

5. **`installer/Uninstall.ahk`** (~line 7)
   ```autohotkey
   ;@Ahk2Exe-SetVersion X.X.X
   ```

6. **`CHANGELOG.md`** (add new section at top)
   ```markdown
   ## [X.X.X] - YYYY-MM-DD

   ### Added/Changed/Fixed
   - Description of changes
   ```

**CRITICAL: After updating version numbers, AI agents MUST recompile all executables.**

Run these PowerShell commands to recompile:

```powershell
# Compile main application
& 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe' /in 'src\main.ahk' /out 'AITextTools.exe' /base 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /icon 'assets\icon.ico'

# Compile installer
& 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe' /in 'installer\Setup.ahk' /out 'installer\Setup.exe' /base 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /icon 'assets\icon.ico'

# Compile uninstaller
& 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe' /in 'installer\Uninstall.ahk' /out 'installer\Uninstall.exe' /base 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /icon 'assets\icon.ico'
```

**Verification:** After compiling, verify the version is correct:
```powershell
(Get-Item 'AITextTools.exe').VersionInfo | Select-Object FileVersion, ProductVersion
```

The compiled EXE must show the new version number. If it doesn't, the source files were not saved correctly before compilation.

### Adding a New AI Provider

1. Create `src/providers/newprovider.ahk` following existing provider patterns
2. Add provider option to `src/providers/factory.ahk`
3. Add UI controls to `src/ui/settings-providers.ahk`
4. Add credential storage key to match provider name
5. Document the API endpoint in this file's "Approved External Connections"
6. Update `CHANGELOG.md`
7. Recompile executables

### Updating Version Numbers

1. Update all locations listed in "Version Number Locations" table above
2. Add entry to `CHANGELOG.md`
3. Recompile all executables
4. Verify version in About tab

### Modifying Credential Storage

- All changes MUST use Windows DPAPI via the `CredentialManager` class
- NEVER store credentials in plain text or reversible encoding
- NEVER add alternative storage mechanisms
- Test migration from previous versions if format changes
