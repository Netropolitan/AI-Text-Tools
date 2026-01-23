#Requires AutoHotkey v2.0
#SingleInstance Force

; Set DPI awareness before any GUI operations (P7 from PITFALLS.md)
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

; Compiler directives for EXE
;@Ahk2Exe-SetName AI Text Tools
;@Ahk2Exe-SetDescription AI-powered text transformation
;@Ahk2Exe-SetVersion 1.5.5
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Jamie Bykov-Brett
;@Ahk2Exe-SetCompanyName Bykov-Brett Enterprises

; Core libraries
#Include lib\cJson.ahk
#Include lib\cursor.ahk
#Include core\config.ahk
#Include core\http.ahk
#Include core\selection.ahk
#Include core\hotkeys.ahk
#Include core\prompts.ahk
#Include core\custom-prompts.ahk
#Include core\credentials.ahk
#Include core\orchestrator.ahk
#Include core\updater.ahk
#Include core\beta.ahk

; Providers
#Include providers\base.ahk
#Include providers\openai.ahk
#Include providers\ollama.ahk
#Include providers\anthropic.ahk
#Include providers\gemini.ahk
#Include providers\beta.ahk
#Include providers\factory.ahk

; UI
#Include ui\popup.ahk
#Include ui\menu.ahk
#Include ui\tray.ahk
#Include ui\theme.ahk
#Include ui\settings-providers.ahk
#Include ui\settings-prompts.ahk
#Include ui\settings.ahk

; Application initialization
global AppConfig := ConfigManager()

; Initialize theme manager
ThemeManager.Load(AppConfig)

; Initialize custom prompts (must be before PromptMenu uses them)
CustomPromptManager.Load(AppConfig)

; Initialize orchestrator
Orchestrator.Initialize(AppConfig)

; Initialize beta manager
BetaManager.Init(AppConfig)

; Initialize hotkeys
HotkeyManager.Initialize(OnQuickAction, OnPromptMenu, AppConfig)

; Initialize system tray
TrayManager.Initialize()

; Check if this is the first launch (for install analytics)
isFirstLaunch := AppConfig.Get("General", "FirstLaunch", "1") = "1"

; Initialize automatic update checking and analytics
UpdateManager.InitializeAutoCheck(AppConfig, isFirstLaunch)

; Mark first launch as done
AppConfig.Set("General", "FirstLaunch", "0")

; Check if started from Windows startup (with /startup flag)
isStartupLaunch := false
for arg in A_Args {
    if (arg = "/startup" || arg = "-startup" || arg = "--startup") {
        isStartupLaunch := true
        break
    }
}

; Check if should start minimized (from settings)
startMinimized := AppConfig.Get("General", "StartMinimized", "0") = "1"

; Auto-connect silently if credentials exist
SetTimer () => AutoConnectProvider(), -500

; Show settings window:
; - If launched from startup: respect StartMinimized setting
; - If launched manually (clicked icon): always show settings
if isStartupLaunch {
    ; Launched from Windows startup - respect StartMinimized setting
    if !startMinimized {
        SetTimer () => SettingsWindow.Show(), -200
    }
} else {
    ; Launched manually (clicked icon) - always show settings
    SetTimer () => SettingsWindow.Show(), -200
}

/**
 * Quick action handler - apply default prompt to selected text
 * Called when user presses Ctrl+Shift+J
 */
OnQuickAction() {
    Orchestrator.QuickAction()
}

/**
 * Prompt menu handler - show prompt selection menu
 * Called when user presses Ctrl+Shift+K
 */
OnPromptMenu() {
    ; Get selected text first
    result := TextSelection.GetSelectedText()
    if !result.success {
        TrayTip "AI Text Tools", result.error, 2
        return
    }

    ; Show prompt menu
    PromptMenu.Show(result.text)
}

/**
 * Auto-connect to provider on startup (silent)
 * Checks if credentials exist and refreshes provider
 */
AutoConnectProvider() {
    global AppConfig

    defaultProvider := AppConfig.Get("General", "DefaultProvider", "openai")

    ; Check if provider has credentials (or is Ollama which doesn't need them)
    if defaultProvider = "ollama" {
        ; Test Ollama connection silently
        url := AppConfig.Get("Provider_Ollama", "BaseUrl", "http://localhost:11434")
        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("GET", url "/api/tags", true)
            whr.SetTimeouts(3000, 3000, 3000, 3000)
            whr.Send()
            whr.WaitForResponse(3)

            if whr.Status = 200 {
                ; Connected successfully - silent
                Orchestrator.RefreshProvider()
            }
        } catch {
            ; Silent fail
        }
    } else {
        ; For cloud providers, check if API key exists
        if CredentialManager.Exists(defaultProvider) {
            ; Credentials exist, refresh provider
            Orchestrator.RefreshProvider()
        }
        ; If no credentials, just stay disconnected - user can configure in settings
    }
}

; Keep script running
Persistent
