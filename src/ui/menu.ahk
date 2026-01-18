#Requires AutoHotkey v2.0

/**
 * PromptMenu - Styled popup menu for selecting prompts
 * Keyboard shortcuts, grouped sections, hover effects
 */
class PromptMenu {
    ; GUI reference
    static Gui := ""
    static HoverTimer := ""

    ; State
    static SelectedPrompt := ""
    static CapturedText := ""
    static DisplayInWindow := false  ; Toggle for popup vs auto-replace

    ; Menu items with shortcuts
    static MenuItems := []
    static TextControls := []  ; Store text controls for hover effects
    static LastHovered := ""   ; Track last hovered control

    /**
     * Show prompt selection menu
     * @param {string} capturedText - Text that was selected
     */
    static Show(capturedText) {
        ; Store captured text for use after selection
        this.CapturedText := capturedText
        this.SelectedPrompt := ""
        this.TextControls := []
        this.LastHovered := ""

        ; Close existing if open
        this.Close()

        ; Build menu items
        this.BuildMenuItems()

        ; Create GUI - borderless popup style
        this.Gui := Gui("+AlwaysOnTop -Caption +Border", "")
        this.Gui.BackColor := "FFFFFF"
        this.Gui.MarginX := 12
        this.Gui.MarginY := 10
        this.Gui.SetFont("s10", "Segoe UI")

        y := 10

        ; Add each menu item
        for item in this.MenuItems {
            if item.type = "separator" {
                ; Add separator line
                this.Gui.Add("Text", "x12 y" y " w260 h1 0x10")
                y += 10
            } else if item.type = "toggle" {
                ; Toggle option at bottom
                toggleText := this.DisplayInWindow ? "* - Display response in new window" : "_ - Display response in new window"
                toggleCtrl := this.Gui.Add("Text", "x12 y" y " w260 h22 c000000", toggleText)
                toggleCtrl.OnEvent("Click", (*) => this.ToggleDisplayMode())
                this.AddHoverEffect(toggleCtrl)
                y += 24
            } else {
                ; Add menu item with shortcut
                shortcutText := item.shortcut = "Space" ? "Space" : item.shortcut
                displayText := shortcutText " - " item.name

                ; Create clickable text
                txt := this.Gui.Add("Text", "x12 y" y " w260 h22 c000000", displayText)

                ; Store prompt ID in control for click handler
                txt.promptId := item.id
                txt.OnEvent("Click", (ctrl, *) => this.OnItemClick(ctrl.promptId))

                ; Add hover effect
                this.AddHoverEffect(txt)

                y += 24
            }
        }

        ; Separator before model selector
        this.Gui.Add("Text", "x12 y" y " w260 h1 0x10")
        y += 10

        ; Model selector - show current provider with friendly name
        currentProvider := AppConfig.Get("General", "DefaultProvider", "openai")
        providerDisplay := this.GetProviderDisplayName(currentProvider)
        modelText := "Provider: " . providerDisplay . " >"
        modelCtrl := this.Gui.Add("Text", "x12 y" y " w260 h22 c000000", modelText)
        modelCtrl.OnEvent("Click", (*) => this.ShowModelSubmenu())
        this.AddHoverEffect(modelCtrl)
        y += 24

        ; Separator before link
        this.Gui.Add("Text", "x12 y" y " w260 h1 0x10")
        y += 10

        ; Netropolitan Academy link
        linkCtrl := this.Gui.Add("Text", "x12 y" y " w260 h22 c000000", "Go to Netropolitan Academy")
        linkCtrl.OnEvent("Click", (*) => this.OpenNetropolitan())
        this.AddHoverEffect(linkCtrl)
        y += 26

        ; Handle escape key
        this.Gui.OnEvent("Escape", (*) => this.Close())
        this.Gui.OnEvent("Close", (*) => this.Close())

        ; Set up hotkeys for this menu
        this.SetupHotkeys()

        ; Calculate dimensions
        height := y + 10
        width := 285

        ; Position near cursor
        CoordMode "Mouse", "Screen"
        MouseGetPos &mouseX, &mouseY

        posX := mouseX + 10
        posY := mouseY - 50

        ; Get screen dimensions
        MonitorGetWorkArea(MonitorGetPrimary(), &workL, &workT, &workR, &workB)

        ; Adjust if would go off edges
        if (posX + width > workR)
            posX := workR - width - 20
        if (posY + height > workB)
            posY := workB - height - 20
        if (posY < workT)
            posY := workT + 20
        if (posX < workL)
            posX := workL + 20

        ; Show
        this.Gui.Show("w" width " h" height " x" posX " y" posY)

        ; Start hover detection
        this.StartHoverDetection()
    }

    /**
     * Track text control for hover effects
     */
    static AddHoverEffect(ctrl) {
        this.TextControls.Push(ctrl)
    }

    /**
     * Start hover detection timer
     */
    static StartHoverDetection() {
        this.HoverTimer := ObjBindMethod(this, "CheckHover")
        SetTimer this.HoverTimer, 30
    }

    /**
     * Stop hover detection timer
     */
    static StopHoverDetection() {
        if this.HoverTimer {
            SetTimer this.HoverTimer, 0
            this.HoverTimer := ""
        }
    }

    /**
     * Check mouse position and update hover states
     */
    static CheckHover() {
        if !this.Gui
            return

        try {
            ; Get GUI position
            this.Gui.GetPos(&winX, &winY, &winW, &winH)

            ; Get mouse position in screen coordinates
            CoordMode "Mouse", "Screen"
            MouseGetPos &mx, &my

            ; Convert to client coordinates
            clientX := mx - winX
            clientY := my - winY

            ; Check if mouse is inside window
            if (clientX < 0 || clientY < 0 || clientX > winW || clientY > winH) {
                ; Mouse outside window - reset all
                if this.LastHovered {
                    this.LastHovered.Opt("c000000 BackgroundFFFFFF")
                    this.LastHovered := ""
                }

                ; Close menu if user clicks outside
                if GetKeyState("LButton", "P") {
                    this.Close()
                }
                return
            }

            ; Find which control mouse is over
            hoveredCtrl := ""
            for ctrl in this.TextControls {
                ctrl.GetPos(&cx, &cy, &cw, &ch)

                if (clientX >= cx && clientX <= cx + cw && clientY >= cy && clientY <= cy + ch) {
                    hoveredCtrl := ctrl
                    break
                }
            }

            ; Update hover states
            if (hoveredCtrl != this.LastHovered) {
                ; Remove highlight from previous
                if this.LastHovered {
                    this.LastHovered.Opt("c000000 BackgroundFFFFFF")
                }

                ; Add highlight to current
                if hoveredCtrl {
                    hoveredCtrl.Opt("cFFFFFF Background404040")
                }

                this.LastHovered := hoveredCtrl
            }
        }
    }

    /**
     * Toggle display mode between popup and auto-replace
     */
    static ToggleDisplayMode() {
        this.DisplayInWindow := !this.DisplayInWindow
        ; Refresh menu to show updated toggle state
        text := this.CapturedText
        this.Close()
        this.Show(text)
    }

    /**
     * Open Netropolitan Academy website
     */
    static OpenNetropolitan() {
        this.Close()
        Run "https://netropolitan.xyz/"
    }

    /**
     * Build the menu items array
     */
    static BuildMenuItems() {
        this.MenuItems := []

        ; Writing group
        this.MenuItems.Push({type: "item", shortcut: "1", name: "Fix spelling && grammar", id: "fix-spelling"})
        this.MenuItems.Push({type: "item", shortcut: "2", name: "Rewrite for clarity", id: "rewrite-clarity"})
        this.MenuItems.Push({type: "item", shortcut: "3", name: "Make shorter", id: "make-shorter"})
        this.MenuItems.Push({type: "item", shortcut: "4", name: "Make longer", id: "make-longer"})
        this.MenuItems.Push({type: "item", shortcut: "5", name: "Change Tone - Professional", id: "tone-professional"})
        this.MenuItems.Push({type: "item", shortcut: "6", name: "Simplify language", id: "simplify"})
        this.MenuItems.Push({type: "item", shortcut: "7", name: "Humanify language", id: "humanify"})

        this.MenuItems.Push({type: "separator"})

        ; Analysis group
        this.MenuItems.Push({type: "item", shortcut: "8", name: "Proofread", id: "proofread"})
        this.MenuItems.Push({type: "item", shortcut: "9", name: "Summarise", id: "summarise"})
        this.MenuItems.Push({type: "item", shortcut: "0", name: "Explain this", id: "explain"})
        this.MenuItems.Push({type: "item", shortcut: "a", name: "Find action items", id: "action-items"})

        this.MenuItems.Push({type: "separator"})

        ; Creative
        this.MenuItems.Push({type: "item", shortcut: "Space", name: "Continue writing", id: "continue-writing"})

        this.MenuItems.Push({type: "separator"})

        ; Legal group
        this.MenuItems.Push({type: "item", shortcut: "b", name: "Convert to legalese", id: "to-legalese"})
        this.MenuItems.Push({type: "item", shortcut: "c", name: "Translate from legalese", id: "from-legalese"})

        this.MenuItems.Push({type: "separator"})

        ; Code group
        this.MenuItems.Push({type: "item", shortcut: "d", name: "Optimise code", id: "code-optimise"})

        this.MenuItems.Push({type: "separator"})

        ; Ask AI - interactive Q&A
        this.MenuItems.Push({type: "item", shortcut: "e", name: "Ask AI", id: "ask-ai"})

        this.MenuItems.Push({type: "separator"})

        ; Toggle option
        this.MenuItems.Push({type: "toggle"})
    }

    /**
     * Set up keyboard shortcuts while menu is open
     */
    static SetupHotkeys() {
        ; Number keys
        Hotkey "1", (*) => this.OnShortcut("1"), "On"
        Hotkey "2", (*) => this.OnShortcut("2"), "On"
        Hotkey "3", (*) => this.OnShortcut("3"), "On"
        Hotkey "4", (*) => this.OnShortcut("4"), "On"
        Hotkey "5", (*) => this.OnShortcut("5"), "On"
        Hotkey "6", (*) => this.OnShortcut("6"), "On"
        Hotkey "7", (*) => this.OnShortcut("7"), "On"
        Hotkey "8", (*) => this.OnShortcut("8"), "On"
        Hotkey "9", (*) => this.OnShortcut("9"), "On"
        Hotkey "0", (*) => this.OnShortcut("0"), "On"

        ; Letter keys
        Hotkey "a", (*) => this.OnShortcut("a"), "On"
        Hotkey "b", (*) => this.OnShortcut("b"), "On"
        Hotkey "c", (*) => this.OnShortcut("c"), "On"
        Hotkey "d", (*) => this.OnShortcut("d"), "On"
        Hotkey "e", (*) => this.OnShortcut("e"), "On"

        ; Space key
        Hotkey "Space", (*) => this.OnShortcut("Space"), "On"

        ; Underscore/asterisk for toggle
        Hotkey "_", (*) => this.ToggleDisplayMode(), "On"
        Hotkey "+8", (*) => this.ToggleDisplayMode(), "On"  ; Shift+8 = *
    }

    /**
     * Remove keyboard shortcuts
     */
    static RemoveHotkeys() {
        try {
            Hotkey "1", "Off"
            Hotkey "2", "Off"
            Hotkey "3", "Off"
            Hotkey "4", "Off"
            Hotkey "5", "Off"
            Hotkey "6", "Off"
            Hotkey "7", "Off"
            Hotkey "8", "Off"
            Hotkey "9", "Off"
            Hotkey "0", "Off"
            Hotkey "a", "Off"
            Hotkey "b", "Off"
            Hotkey "c", "Off"
            Hotkey "d", "Off"
            Hotkey "e", "Off"
            Hotkey "Space", "Off"
            Hotkey "_", "Off"
            Hotkey "+8", "Off"
        }
    }

    /**
     * Handle keyboard shortcut press
     */
    static OnShortcut(key) {
        ; Find matching item
        for item in this.MenuItems {
            if item.type = "item" && item.shortcut = key {
                this.ExecutePrompt(item.id)
                return
            }
        }
    }

    /**
     * Handle item click
     */
    static OnItemClick(promptId) {
        this.ExecutePrompt(promptId)
    }

    /**
     * Execute the selected prompt
     */
    static ExecutePrompt(promptId) {
        ; Get the prompt
        prompt := PromptManager.GetPrompt(promptId)
        if !prompt
            return

        this.SelectedPrompt := prompt

        ; Store captured text before closing
        capturedText := this.CapturedText

        this.Close()

        ; Brief delay for GUI to close
        Sleep 50

        ; Ask AI shows special interactive popup
        if promptId = "ask-ai" {
            AskAIPopup.Show(capturedText)
        } else if this.DisplayInWindow {
            ; Show response in popup window
            Orchestrator.ExecuteWithPromptAndText(this.SelectedPrompt, capturedText)
        } else {
            ; Auto-replace text (like Ctrl+Shift+J)
            Orchestrator.ExecuteQuickReplaceWithPromptAndText(this.SelectedPrompt, capturedText)
        }
    }

    /**
     * Close the menu
     */
    static Close() {
        this.StopHoverDetection()
        this.RemoveHotkeys()
        if this.Gui {
            this.Gui.Destroy()
            this.Gui := ""
        }
        this.TextControls := []
        this.LastHovered := ""
    }

    /**
     * Check if menu is visible
     * @returns {bool}
     */
    static IsVisible() {
        return this.Gui != ""
    }

    /**
     * Get current model for a provider
     */
    static GetCurrentModel(providerName) {
        sectionMap := Map(
            "openai", "Provider_OpenAI",
            "anthropic", "Provider_Anthropic",
            "gemini", "Provider_Gemini",
            "ollama", "Provider_Ollama"
        )
        section := sectionMap.Has(providerName) ? sectionMap[providerName] : "Provider_OpenAI"
        return AppConfig.Get(section, "DefaultModel", "default")
    }

    /**
     * Get friendly display name for provider
     */
    static GetProviderDisplayName(providerId) {
        displayNames := Map(
            "openai", "ChatGPT",
            "anthropic", "Claude",
            "gemini", "Gemini",
            "ollama", "Ollama"
        )
        return displayNames.Has(providerId) ? displayNames[providerId] : providerId
    }

    /**
     * Show provider selection submenu (simplified - just provider names)
     */
    static ShowModelSubmenu() {
        ; Close main menu first
        capturedText := this.CapturedText
        this.Close()

        ; Store submenu reference for click-outside detection
        this.SubGui := Gui("+AlwaysOnTop -Caption +Border", "")
        this.SubGui.BackColor := "FFFFFF"
        this.SubGui.MarginX := 12
        this.SubGui.MarginY := 10
        this.SubGui.SetFont("s10", "Segoe UI")
        this.SubGuiControls := []
        this.SubGuiCapturedText := capturedText

        y := 10

        ; Title
        this.SubGui.SetFont("Bold")
        this.SubGui.Add("Text", "x12 y" y " w180", "Select Provider")
        this.SubGui.SetFont("Norm")
        y += 28

        ; Define providers with friendly names
        providers := [
            {display: "ChatGPT", id: "openai"},
            {display: "Claude", id: "anthropic"},
            {display: "Gemini", id: "gemini"},
            {display: "Ollama", id: "ollama"}
        ]

        currentProvider := AppConfig.Get("General", "DefaultProvider", "openai")

        for provider in providers {
            ; Check if provider is configured (has API key or is Ollama)
            isConfigured := (provider.id = "ollama") || CredentialManager.Exists(provider.id)

            ; Determine display style
            isActive := (provider.id = currentProvider)
            prefix := isActive ? ">> " : "    "
            textColor := isConfigured ? "000000" : "999999"
            suffix := isConfigured ? "" : " (no key)"

            providerCtrl := this.SubGui.Add("Text", "x12 y" y " w180 h24 c" . textColor, prefix . provider.display . suffix)

            if isConfigured {
                providerCtrl.providerId := provider.id
                providerCtrl.OnEvent("Click", (ctrl, *) => PromptMenu.SelectProvider(ctrl.providerId))
                this.SubGuiControls.Push(providerCtrl)
            }
            y += 26
        }

        y += 6

        ; Separator
        this.SubGui.Add("Text", "x12 y" y " w180 h1 0x10")
        y += 10

        ; Cancel
        cancelCtrl := this.SubGui.Add("Text", "x12 y" y " w180 h22 c000000 Center", "Cancel")
        cancelCtrl.OnEvent("Click", (*) => PromptMenu.CloseSubmenuAndReturn())
        this.SubGuiControls.Push(cancelCtrl)
        y += 26

        ; Handle escape
        this.SubGui.OnEvent("Escape", (*) => this.CloseSubmenuAndReturn())
        this.SubGui.OnEvent("Close", (*) => this.CloseSubmenuAndReturn())

        ; Position near cursor
        CoordMode "Mouse", "Screen"
        MouseGetPos &mouseX, &mouseY
        height := y + 10
        width := 205

        MonitorGetWorkArea(MonitorGetPrimary(), &workL, &workT, &workR, &workB)
        posX := mouseX + 10
        posY := mouseY - 50
        if (posX + width > workR)
            posX := workR - width - 20
        if (posY + height > workB)
            posY := workB - height - 20
        if (posY < workT)
            posY := workT + 20

        this.SubGui.Show("w" width " h" height " x" posX " y" posY)

        ; Start click-outside detection for submenu
        this.StartSubmenuClickDetection()
    }

    /**
     * Start click-outside detection for submenu
     */
    static StartSubmenuClickDetection() {
        this.SubGuiTimer := ObjBindMethod(this, "CheckSubmenuClick")
        SetTimer this.SubGuiTimer, 30
    }

    /**
     * Stop submenu click detection
     */
    static StopSubmenuClickDetection() {
        if this.HasOwnProp("SubGuiTimer") && this.SubGuiTimer {
            SetTimer this.SubGuiTimer, 0
            this.SubGuiTimer := ""
        }
    }

    /**
     * Check for clicks outside submenu
     */
    static CheckSubmenuClick() {
        if !this.HasOwnProp("SubGui") || !this.SubGui
            return

        try {
            this.SubGui.GetPos(&winX, &winY, &winW, &winH)
            CoordMode "Mouse", "Screen"
            MouseGetPos &mx, &my

            clientX := mx - winX
            clientY := my - winY

            ; If mouse outside and clicking, close submenu
            if (clientX < 0 || clientY < 0 || clientX > winW || clientY > winH) {
                if GetKeyState("LButton", "P") {
                    this.CloseSubmenuOnly()
                }
            }
        }
    }

    /**
     * Select a provider from submenu
     */
    static SelectProvider(providerId) {
        ; Save selection
        AppConfig.Set("General", "DefaultProvider", providerId)

        ; Refresh orchestrator
        Orchestrator.RefreshProvider()

        ; Close submenu and reopen main menu
        this.CloseSubmenuAndReturn()
    }

    /**
     * Close submenu and return to main menu
     */
    static CloseSubmenuAndReturn() {
        capturedText := this.HasOwnProp("SubGuiCapturedText") ? this.SubGuiCapturedText : ""
        this.StopSubmenuClickDetection()
        if this.HasOwnProp("SubGui") && this.SubGui {
            this.SubGui.Destroy()
            this.SubGui := ""
        }
        this.SubGuiControls := []
        if capturedText
            this.Show(capturedText)
    }

    /**
     * Close submenu only (clicked outside - don't return to main menu)
     */
    static CloseSubmenuOnly() {
        this.StopSubmenuClickDetection()
        if this.HasOwnProp("SubGui") && this.SubGui {
            this.SubGui.Destroy()
            this.SubGui := ""
        }
        this.SubGuiControls := []
    }
}
