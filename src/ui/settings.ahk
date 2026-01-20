/**
 * SettingsWindow - Main settings GUI
 *
 * Provides tabbed interface for application settings.
 * Tabs: General, Providers, Local, Prompts, About, Disclaimer
 */

class SettingsWindow {
    static Gui := ""
    static Tabs := ""
    static CurrentVersion := "1.5.3"
    static GitHubRepo := "https://github.com/Netropolitan/AI-Text-Tools"

    /**
     * Show settings window
     * Creates window if not exists, activates if already open
     */
    static Show() {
        ; Prevent multiple instances
        if this.Gui {
            WinActivate(this.Gui)
            return
        }

        ; DPI awareness (P7 from PITFALLS.md)
        DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

        ; Load theme
        ThemeManager.Load(AppConfig)

        ; Create GUI
        this.Gui := Gui("+Resize -MaximizeBox", "AI Text Tools Settings")
        this.Gui.SetFont("s10", "Segoe UI")

        ; Apply theme
        ThemeManager.Apply(this.Gui)

        ; Tab control
        this.Tabs := this.Gui.Add("Tab3", "w550 h450", ["General", "Models", "Local", "Prompts", "About", "Disclaimer"])

        ; General tab - basic settings
        this.Tabs.UseTab("General")
        this.BuildGeneralTab()

        ; Models tab - cloud provider configuration
        this.Tabs.UseTab("Models")
        ProvidersTab.Build(this.Gui, AppConfig)

        ; Local tab - Ollama/local models
        this.Tabs.UseTab("Local")
        LocalTab.Build(this.Gui, AppConfig)

        ; Prompts tab
        this.Tabs.UseTab("Prompts")
        PromptsTab.Build(this.Gui, AppConfig)

        ; About tab
        this.Tabs.UseTab("About")
        this.BuildAboutTab()

        ; Disclaimer tab
        this.Tabs.UseTab("Disclaimer")
        this.BuildDisclaimerTab()

        ; Reset tab focus
        this.Tabs.UseTab()

        ; Save button (outside tabs)
        saveBtn := this.Gui.Add("Button", "x430 y460 w120", "Save Settings")
        saveBtn.OnEvent("Click", (*) => this.OnSave())

        ; Event handlers
        this.Gui.OnEvent("Close", (*) => this.Close())
        this.Gui.OnEvent("Escape", (*) => this.Close())

        ; Show centered
        this.Gui.Show("w570 h500")
    }

    ; Update UI controls (for updating status after check)
    static UpdateStatusText := ""
    static UpdateButton := ""
    static UpdateAvailable := false
    static UpdateInstallerPath := ""

    /**
     * Build General tab content
     */
    static BuildGeneralTab() {
        y := 40

        ; Version & Updates section
        this.Gui.Add("Text", "x20 y" y " +0x200", "Version")
        y += 25

        this.Gui.Add("Text", "x20 y" y, "Current Version:")
        this.Gui.Add("Text", "x120 y" y, "v" . this.CurrentVersion)

        this.UpdateStatusText := this.Gui.Add("Text", "x200 y" y " w200 c666666", "")
        this.UpdateButton := this.Gui.Add("Button", "x400 y" (y-4) " w130 h24", "Check for Updates")
        this.UpdateButton.OnEvent("Click", (*) => this.OnCheckForUpdates())
        y += 35

        ; Info about default provider
        this.Gui.Add("Text", "x20 y" y " c666666", "Set your default provider using the 'Default' checkbox on the Providers or Local tab.")
        y += 35

        ; Language section
        this.Gui.Add("Text", "x20 y" y " +0x200", "Language")
        y += 25

        this.Gui.Add("Text", "x20 y" y, "English Spelling:")
        spellingDropdown := this.Gui.Add("DropDownList", "x150 y" (y-3) " w200 vSpellingVariant", ["UK English", "US English"])
        currentSpelling := AppConfig.Get("General", "SpellingVariant", "UK")
        spellingDropdown.Choose(currentSpelling = "US" ? 2 : 1)
        y += 35

        ; Hotkeys section
        this.Gui.Add("Text", "x20 y" y " +0x200", "Hotkeys")  ; 0x200 = SS_CENTERIMAGE (bold-like)
        y += 25

        this.Gui.Add("Text", "x20 y" y, "Quick Action:")
        quickKeyEdit := this.Gui.Add("Hotkey", "x150 y" (y-3) " w200 vQuickActionKey")
        currentQuick := AppConfig.Get("Hotkeys", "QuickAction", "^+j")
        quickKeyEdit.Value := currentQuick
        y += 30

        this.Gui.Add("Text", "x20 y" y, "Prompt Menu:")
        menuKeyEdit := this.Gui.Add("Hotkey", "x150 y" (y-3) " w200 vPromptMenuKey")
        currentMenu := AppConfig.Get("Hotkeys", "PromptMenu", "^+k")
        menuKeyEdit.Value := currentMenu
        y += 40

        ; Startup options section
        this.Gui.Add("Text", "x20 y" y " +0x200", "Startup")
        y += 25

        ; Run on Windows startup
        startupCheck := this.Gui.Add("Checkbox", "x20 y" y " vRunOnStartup", "Run on Windows startup")
        if this.IsStartupEnabled()
            startupCheck.Value := 1
        y += 25

        ; Start minimized to tray
        trayCheck := this.Gui.Add("Checkbox", "x20 y" y " vStartMinimized", "Start minimized to system tray")
        if AppConfig.Get("General", "StartMinimized", "0") = "1"
            trayCheck.Value := 1
        y += 30

        ; Updates & Analytics section
        this.Gui.Add("Text", "x20 y" y " +0x200", "Updates && Analytics")
        y += 25

        ; Auto-check for updates
        autoUpdateCheck := this.Gui.Add("Checkbox", "x20 y" y " vAutoCheckUpdates", "Automatically check for updates (monthly)")
        if AppConfig.Get("Updates", "AutoCheck", "1") = "1"
            autoUpdateCheck.Value := 1
        y += 25

        ; Anonymous analytics
        analyticsCheck := this.Gui.Add("Checkbox", "x20 y" y " vAnalyticsEnabled", "Help improve AI Text Tools (anonymous usage data)")
        if AppConfig.Get("Updates", "Analytics", "1") = "1"
            analyticsCheck.Value := 1
    }

    /**
     * Helper to select dropdown item by value
     */
    static SelectDropdownItem(dropdown, value, items) {
        for i, item in items {
            if StrLower(item) = StrLower(value) {
                dropdown.Choose(i)
                return
            }
        }
        dropdown.Choose(1)
    }

    /**
     * Check if startup registry entry exists
     */
    static IsStartupEnabled() {
        try {
            RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", "AITextTools")
            return true
        } catch {
            return false
        }
    }

    /**
     * Build About tab content
     */
    static BuildAboutTab() {
        y := 40
        x := 20

        ; App title and version
        this.Gui.SetFont("Bold s14")
        this.Gui.Add("Text", "x" x " y" y " w500", "AI Text Tools")
        this.Gui.SetFont("Norm s10")
        y += 25

        this.Gui.Add("Text", "x" x " y" y " w500 c666666", "AI Text Tools for Windows")
        y += 30

        ; Version section
        this.Gui.SetFont("Bold")
        this.Gui.Add("Text", "x" x " y" y, "Version")
        this.Gui.SetFont("Norm")
        y += 22

        this.Gui.Add("Text", "x" x " y" y, "v" this.CurrentVersion)
        updateBtn := this.Gui.Add("Button", "x" (x+80) " y" (y-4) " w120 h24", "Check for Updates")
        updateBtn.OnEvent("Click", (*) => this.CheckForUpdates())
        uninstallBtn := this.Gui.Add("Button", "x" (x+210) " y" (y-4) " w80 h24", "Uninstall")
        uninstallBtn.OnEvent("Click", (*) => this.Uninstall())
        y += 35

        ; Netropolitan Academy section
        this.Gui.SetFont("Bold")
        this.Gui.Add("Text", "x" x " y" y, "Netropolitan Academy")
        this.Gui.SetFont("Norm")
        y += 22

        this.Gui.Add("Text", "x" x " y" y " c666666", "./run the revolution.")
        y += 20

        netroLink := this.Gui.Add("Text", "x" x " y" y " c0066CC", "netropolitan.xyz")
        netroLink.OnEvent("Click", (*) => Run("https://netropolitan.xyz/"))
        y += 35

        ; Developer section
        this.Gui.SetFont("Bold")
        this.Gui.Add("Text", "x" x " y" y, "Developer")
        this.Gui.SetFont("Norm")
        y += 22

        this.Gui.Add("Text", "x" x " y" y, "(c) 2026 Jamie Bykov-Brett")
        y += 20

        this.Gui.Add("Text", "x" x " y" y, "Bykov-Brett Enterprises")
        y += 20

        siteLink := this.Gui.Add("Text", "x" x " y" y " c0066CC", "bykovbrett.net")
        siteLink.OnEvent("Click", (*) => Run("https://bykovbrett.net/"))
        y += 20

        emailLink := this.Gui.Add("Text", "x" x " y" y " c0066CC", "jamie@bykovbrett.net")
        emailLink.OnEvent("Click", (*) => Run("mailto:jamie@bykovbrett.net"))
        y += 30

        ; License section
        this.Gui.SetFont("Bold")
        this.Gui.Add("Text", "x" x " y" y, "License")
        this.Gui.SetFont("Norm")
        y += 22

        this.Gui.Add("Text", "x" x " y" y " w500", "Licensed under CC BY-NC-ND (Creative Commons")
        y += 18
        this.Gui.Add("Text", "x" x " y" y " w500", "Attribution-NonCommercial-NoDerivatives).")
        y += 28

        ; Support section with buttons
        coffeeBtn := this.Gui.Add("Button", "x" x " y" y " w140 h28", "Buy Me A Coffee")
        coffeeBtn.OnEvent("Click", (*) => Run("https://buymeacoffee.com/jamiebykovbrett"))

        shareBtn := this.Gui.Add("Button", "x" (x + 150) " y" y " w140 h28", "Share on GitHub")
        shareBtn.OnEvent("Click", (*) => Run("https://github.com/Netropolitan/AI-Text-Tools"))
    }

    /**
     * Uninstall the application
     */
    static Uninstall() {
        uninstallerPath := A_ScriptDir "\Uninstall.exe"

        if FileExist(uninstallerPath) {
            ; Close settings window first
            this.Close()
            ; Run the uninstaller wizard with admin rights
            try {
                Run('*RunAs "' uninstallerPath '"')
                ExitApp
            } catch as e {
                MsgBox("Could not start uninstaller: " e.Message, "Error", "IconX")
            }
        } else {
            ; Fallback to simple uninstall if wizard not found
            result := MsgBox("Are you sure you want to uninstall AI Text Tools?`n`nThis will:`n- Remove startup registry entry`n- Delete settings file`n- Close the application`n`nThe program files will remain and can be manually deleted.", "Uninstall AI Text Tools", "YesNo Icon!")

            if result = "Yes" {
                ; Remove startup entry
                try RegDelete("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", "AITextTools")

                ; Delete settings file
                try FileDelete(A_ScriptDir "\settings.ini")

                MsgBox("AI Text Tools has been uninstalled.`n`nYou can delete the program folder manually.", "Uninstall Complete", "Iconi")

                ; Exit the application
                ExitApp
            }
        }
    }

    /**
     * Build Disclaimer tab content
     */
    static BuildDisclaimerTab() {
        y := 40
        x := 20

        this.Gui.SetFont("Bold s12")
        this.Gui.Add("Text", "x" x " y" y " w500", "Disclaimer")
        this.Gui.SetFont("Norm s10")
        y += 30

        disclaimerText := "
        (
TERMS OF USE AND DISCLAIMER

Last updated: January 2026

By using AI Text Tools ("the Software"), you agree to be bound by these terms. If you do not agree, do not use the Software.

1. SOFTWARE PROVIDED "AS IS"
THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH YOU.

2. LIMITATION OF LIABILITY
IN NO EVENT SHALL THE AUTHORS, DEVELOPERS, COPYRIGHT HOLDERS, OR BYKOV-BRETT ENTERPRISES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

3. AI-GENERATED CONTENT
a) AI output may contain errors, inaccuracies, biases, or inappropriate material
b) You are solely responsible for reviewing, verifying, and editing all AI-generated content before use
c) The developers make no representations about the accuracy, reliability, or suitability of AI output
d) You assume all risk for any decisions or actions based on AI-generated content

4. DATA AND PRIVACY
a) API keys and credentials are stored locally on your device using Base64 encoding
b) You are responsible for keeping your API keys secure
c) Text you process is sent to your chosen AI provider (OpenAI, Anthropic, Google, or Ollama)
d) Each AI provider has their own privacy policy and terms of service
e) Anonymous usage analytics may be collected (can be disabled in Settings)
f) We do not store, access, or have visibility into the content you process

5. ACCEPTABLE USE
You agree NOT to use this Software to:
a) Generate content that is illegal, harmful, threatening, abusive, or harassing
b) Create content that infringes on intellectual property rights
c) Produce spam, malware, or deceptive content
d) Violate any applicable laws or regulations
e) Circumvent the terms of service of any AI provider

6. THIRD-PARTY SERVICES
a) This Software requires third-party AI services to function
b) You must comply with the terms of service of any AI provider you use
c) We are not responsible for the availability, pricing, or policies of third-party services
d) Changes to third-party APIs may affect Software functionality

7. INDEMNIFICATION
You agree to indemnify and hold harmless the developers, Bykov-Brett Enterprises, and their affiliates from any claims, damages, or expenses arising from your use of the Software or violation of these terms.

8. MODIFICATIONS
We reserve the right to modify these terms at any time. Continued use of the Software constitutes acceptance of modified terms.

9. GOVERNING LAW
These terms shall be governed by the laws of the United Kingdom.

© 2026 Bykov-Brett Enterprises. All rights reserved.

By using this Software, you acknowledge that you have read, understood, and agree to be bound by these terms.
        )"

        this.Gui.Add("Edit", "x" x " y" y " w510 h340 ReadOnly Multi", disclaimerText)
    }

    /**
     * Check for updates from GitHub (legacy - opens releases page)
     */
    static CheckForUpdates() {
        try {
            Run this.GitHubRepo "/releases"
            MsgBox("Opening GitHub releases page.`n`nCheck if a newer version than v" this.CurrentVersion " is available.", "Check for Updates", "Iconi")
        } catch as e {
            MsgBox("Could not open GitHub page.`n`nVisit: " this.GitHubRepo, "Check for Updates", "IconX")
        }
    }

    /**
     * Handle Check for Updates button click
     */
    static OnCheckForUpdates() {
        ; Update UI to show checking
        this.UpdateStatusText.Value := "Checking..."
        this.UpdateButton.Enabled := false

        ; Run check in background to avoid blocking UI
        SetTimer(() => this.DoUpdateCheck(), -1)
    }

    /**
     * Perform actual update check
     */
    static DoUpdateCheck() {
        result := UpdateManager.CheckForUpdates()

        if result.error != "" {
            ; Handle "no releases" case gracefully (not an error)
            if InStr(result.error, "No releases") {
                this.UpdateStatusText.Value := "No releases yet"
                this.UpdateStatusText.SetFont("c666666")
                this.UpdateButton.Text := "Check for Updates"
                this.UpdateButton.Enabled := true
                return
            }

            this.UpdateStatusText.Value := "Check failed"
            this.UpdateButton.Text := "Retry"
            this.UpdateButton.Enabled := true
            MsgBox("Could not check for updates:`n`n" . result.error, "Update Check", "Icon!")
            return
        }

        if result.available {
            this.UpdateAvailable := true
            this.UpdateStatusText.Value := "Update available: v" . result.version
            this.UpdateStatusText.SetFont("cGreen")
            this.UpdateButton.Text := "Download && Install"
            this.UpdateButton.OnEvent("Click", (*) => this.OnDownloadUpdate(), -1)  ; Remove old handler
            this.UpdateButton.OnEvent("Click", (*) => this.OnDownloadUpdate())
        } else {
            this.UpdateStatusText.Value := "Up to date"
            this.UpdateStatusText.SetFont("c666666")
            this.UpdateButton.Text := "Check for Updates"
        }

        this.UpdateButton.Enabled := true
    }

    /**
     * Handle Download & Install button click
     */
    static OnDownloadUpdate() {
        if !this.UpdateAvailable {
            this.OnCheckForUpdates()
            return
        }

        ; Confirm with user
        result := MsgBox("Download and install AI Text Tools v" . UpdateManager.LatestVersion . "?`n`nThe application will close and the installer will run.", "Update Available", "YesNo Iconi")

        if result != "Yes"
            return

        ; Update UI
        this.UpdateStatusText.Value := "Downloading..."
        this.UpdateButton.Enabled := false

        ; Download
        downloadResult := UpdateManager.DownloadUpdate()

        if !downloadResult.success {
            this.UpdateStatusText.Value := "Download failed"
            this.UpdateButton.Enabled := true
            MsgBox("Download failed:`n`n" . downloadResult.error, "Update Error", "IconX")
            return
        }

        this.UpdateInstallerPath := downloadResult.path
        this.UpdateStatusText.Value := "Installing..."

        ; Launch installer and exit
        UpdateManager.InstallUpdate(downloadResult.path)
    }

    /**
     * Handle Save button click
     */
    static OnSave() {
        ; Get form values
        submitted := this.Gui.Submit(false)  ; Don't hide

        ; Note: Default provider is now set via checkboxes in Providers/Local tabs

        ; Save spelling variant
        spellingVariant := submitted.SpellingVariant = "US English" ? "US" : "UK"
        AppConfig.Set("General", "SpellingVariant", spellingVariant)

        ; Save hotkeys and apply immediately
        currentQuickKey := HotkeyManager.CurrentQuickKey || "^+j"
        currentMenuKey := HotkeyManager.CurrentMenuKey || "^+k"

        if submitted.QuickActionKey != currentQuickKey
            HotkeyManager.UpdateBinding("QuickAction", submitted.QuickActionKey, AppConfig)

        if submitted.PromptMenuKey != currentMenuKey
            HotkeyManager.UpdateBinding("PromptMenu", submitted.PromptMenuKey, AppConfig)

        ; Handle startup options
        this.SetStartupEnabled(submitted.RunOnStartup)
        AppConfig.Set("General", "StartMinimized", submitted.StartMinimized ? "1" : "0")

        ; Save update and analytics settings
        AppConfig.Set("Updates", "AutoCheck", submitted.AutoCheckUpdates ? "1" : "0")
        AppConfig.Set("Updates", "Analytics", submitted.AnalyticsEnabled ? "1" : "0")

        ; Save provider settings (API keys to CredentialManager, models to INI)
        ProvidersTab.SaveAll()

        ; Save local/Ollama settings
        LocalTab.SaveAll()

        ; Save custom prompts (already saved on individual changes, but ensure)
        CustomPromptManager.Save(AppConfig)

        MsgBox("Settings saved.", "AI Text Tools", "Iconi")
    }

    /**
     * Set or remove startup registry entry
     */
    static SetStartupEnabled(enabled) {
        key := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
        if enabled {
            exePath := A_ScriptFullPath
            if !A_IsCompiled
                exePath := A_AhkPath ' "' A_ScriptFullPath '"'
            ; Add /startup flag so app knows it was auto-started (won't show settings)
            RegWrite('"' exePath '" /startup', "REG_SZ", key, "AITextTools")
        } else {
            try RegDelete(key, "AITextTools")
        }
    }

    /**
     * Close and destroy settings window
     */
    static Close() {
        if this.Gui {
            this.Gui.Destroy()
            this.Gui := ""
        }
    }

    /**
     * Check if settings window is visible
     * @returns {Boolean} True if window is open
     */
    static IsVisible() {
        return this.Gui != ""
    }
}
