#Requires AutoHotkey v2.0

/**
 * ResponsePopup - Display AI response with copy/replace actions
 * Positioned near cursor, dismissable with Escape
 */
class ResponsePopup {
    ; GUI reference
    static Gui := ""
    static ContentEdit := ""

    ; Popup dimensions
    static Width := 500
    static Height := 400

    /**
     * Show response popup
     * @param {string} content - AI response text
     * @param {string} promptName - Name of prompt used
     * @param {string} providerName - Name of provider used
     */
    static Show(content, promptName := "", providerName := "") {
        ; Close existing if open
        this.Close()

        ; Create GUI
        this.Gui := Gui("+AlwaysOnTop -MinimizeBox", "AI Response")
        this.Gui.SetFont("s10", "Segoe UI")

        ; Header with prompt and provider info
        headerText := promptName
        if providerName
            headerText .= " · " providerName

        this.Gui.Add("Text", "w" (this.Width - 40) " c666666", headerText)

        ; Content area (multi-line edit for now, Markdown in Phase 4 polish)
        this.ContentEdit := this.Gui.Add("Edit", "w" (this.Width - 40) " h" (this.Height - 140) " ReadOnly Multi VScroll", content)

        ; Button row
        btnWidth := 100
        btnGap := 10
        btnY := this.Height - 70

        copyBtn := this.Gui.Add("Button", "x20 y" btnY " w" btnWidth, "Copy")
        copyBtn.OnEvent("Click", (*) => this.OnCopy())

        replaceBtn := this.Gui.Add("Button", "x" (20 + btnWidth + btnGap) " y" btnY " w" btnWidth, "Replace")
        replaceBtn.OnEvent("Click", (*) => this.OnReplace())

        closeBtn := this.Gui.Add("Button", "x" (20 + 2*(btnWidth + btnGap)) " y" btnY " w" btnWidth, "Close")
        closeBtn.OnEvent("Click", (*) => this.Close())

        ; Handle Escape key to close
        this.Gui.OnEvent("Escape", (*) => this.Close())
        this.Gui.OnEvent("Close", (*) => this.Close())

        ; Position near cursor
        CoordMode "Mouse", "Screen"
        MouseGetPos &mouseX, &mouseY

        ; Adjust position to stay on screen
        posX := mouseX + 20
        posY := mouseY + 20

        ; Get screen dimensions
        MonitorGetWorkArea(MonitorGetPrimary(), &workL, &workT, &workR, &workB)

        ; Adjust if would go off right edge
        if (posX + this.Width > workR)
            posX := workR - this.Width - 20

        ; Adjust if would go off bottom
        if (posY + this.Height > workB)
            posY := workB - this.Height - 20

        ; Show
        this.Gui.Show("w" this.Width " h" this.Height " x" posX " y" posY)
    }

    /**
     * Close the popup
     */
    static Close() {
        if this.Gui {
            this.Gui.Destroy()
            this.Gui := ""
        }
    }

    /**
     * Copy button handler
     */
    static OnCopy() {
        Orchestrator.CopyResponse()
        this.Close()
    }

    /**
     * Replace button handler
     */
    static OnReplace() {
        this.Close()  ; Close first so focus returns to original app
        Sleep 100     ; Brief delay for focus to return
        Orchestrator.ReplaceWithResponse()
    }

    /**
     * Check if popup is currently visible
     * @returns {bool}
     */
    static IsVisible() {
        return this.Gui != ""
    }
}

/**
 * AskAIPopup - Interactive Q&A popup for quick AI questions
 * Features input box, generate button, and response display
 */
class AskAIPopup {
    ; GUI references
    static Gui := ""
    static InputEdit := ""
    static ResponseEdit := ""
    static GenerateBtn := ""
    static StatusText := ""

    ; Popup dimensions
    static Width := 550
    static Height := 500

    ; State
    static IsProcessing := false

    /**
     * Show Ask AI popup
     * @param {string} initialText - Pre-fill input with selected text
     */
    static Show(initialText := "") {
        ; Close existing if open
        this.Close()

        ; Create GUI
        this.Gui := Gui("+AlwaysOnTop -MinimizeBox", "Ask AI")
        this.Gui.SetFont("s10", "Segoe UI")

        y := 15

        ; Input label
        this.Gui.Add("Text", "x20 y" y " w" (this.Width - 40) " c666666", "Your question:")
        y += 22

        ; Input text area
        this.InputEdit := this.Gui.Add("Edit", "x20 y" y " w" (this.Width - 40) " h80 Multi", initialText)
        y += 90

        ; Generate button
        this.GenerateBtn := this.Gui.Add("Button", "x20 y" y " w100 h30", "Generate")
        this.GenerateBtn.OnEvent("Click", (*) => this.OnGenerate())

        ; Status text (shows processing state)
        this.StatusText := this.Gui.Add("Text", "x130 y" (y + 5) " w200 c666666", "")
        y += 45

        ; Response label
        this.Gui.Add("Text", "x20 y" y " w" (this.Width - 40) " c666666", "Response:")
        y += 22

        ; Response display area
        responseHeight := this.Height - y - 70
        this.ResponseEdit := this.Gui.Add("Edit", "x20 y" y " w" (this.Width - 40) " h" responseHeight " ReadOnly Multi VScroll", "")
        y += responseHeight + 15

        ; Bottom button row
        btnWidth := 70
        btnGap := 8

        copyBtn := this.Gui.Add("Button", "x20 y" y " w" btnWidth, "Copy")
        copyBtn.OnEvent("Click", (*) => this.OnCopy())

        insertBtn := this.Gui.Add("Button", "x" (20 + btnWidth + btnGap) " y" y " w" btnWidth, "Insert")
        insertBtn.OnEvent("Click", (*) => this.OnInsert())

        clearBtn := this.Gui.Add("Button", "x" (20 + 2*(btnWidth + btnGap)) " y" y " w" btnWidth, "Clear")
        clearBtn.OnEvent("Click", (*) => this.OnClear())

        closeBtn := this.Gui.Add("Button", "x" (this.Width - 20 - btnWidth) " y" y " w" btnWidth, "Close")
        closeBtn.OnEvent("Click", (*) => this.Close())

        ; Handle Escape and Enter keys
        this.Gui.OnEvent("Escape", (*) => this.Close())
        this.Gui.OnEvent("Close", (*) => this.Close())

        ; Position near cursor
        CoordMode "Mouse", "Screen"
        MouseGetPos &mouseX, &mouseY

        posX := mouseX + 20
        posY := mouseY - 100

        ; Get screen dimensions
        MonitorGetWorkArea(MonitorGetPrimary(), &workL, &workT, &workR, &workB)

        ; Adjust to stay on screen
        if (posX + this.Width > workR)
            posX := workR - this.Width - 20
        if (posY + this.Height > workB)
            posY := workB - this.Height - 20
        if (posY < workT)
            posY := workT + 20

        ; Show
        this.Gui.Show("w" this.Width " h" this.Height " x" posX " y" posY)

        ; Focus on input
        this.InputEdit.Focus()
    }

    /**
     * Generate button handler - send question to AI
     */
    static OnGenerate() {
        if this.IsProcessing
            return

        question := this.InputEdit.Value
        if !question || Trim(question) = "" {
            this.StatusText.Value := "Please enter a question"
            return
        }

        ; Check provider
        if !Orchestrator.Provider {
            this.StatusText.Value := "No AI provider configured"
            return
        }

        ; Set processing state
        this.IsProcessing := true
        this.GenerateBtn.Opt("+Disabled")
        this.StatusText.Value := "Processing..."
        this.ResponseEdit.Value := ""

        ; Show wait cursor
        Orchestrator.ShowSpinner()

        ; Get Ask AI prompt
        prompt := PromptManager.GetPrompt("ask-ai")
        if !prompt {
            prompt := {
                id: "ask-ai",
                system: "You are a helpful AI assistant. Answer the user's question directly and concisely."
            }
        }

        ; Call AI
        result := Orchestrator.Provider.Complete(prompt.system, question, Map())

        ; Hide wait cursor
        Orchestrator.HideSpinner()

        ; Reset processing state
        this.IsProcessing := false
        this.GenerateBtn.Opt("-Disabled")

        if result.success {
            this.ResponseEdit.Value := result.content
            this.StatusText.Value := ""
        } else {
            this.StatusText.Value := "Error"
            this.ResponseEdit.Value := "Error: " . result.error
        }
    }

    /**
     * Copy response to clipboard
     */
    static OnCopy() {
        response := this.ResponseEdit.Value
        if response && response != "" {
            A_Clipboard := response
            this.StatusText.Value := "Copied!"
            SetTimer (*) => (this.StatusText ? this.StatusText.Value := "" : ""), -2000
        }
    }

    /**
     * Insert response at original cursor position
     */
    static OnInsert() {
        response := this.ResponseEdit.Value
        if response && response != "" {
            this.Close()
            Sleep 100  ; Brief delay for focus to return
            TextSelection.ReplaceSelectedText(response)
        }
    }

    /**
     * Clear input and response
     */
    static OnClear() {
        this.InputEdit.Value := ""
        this.ResponseEdit.Value := ""
        this.StatusText.Value := ""
        this.InputEdit.Focus()
    }

    /**
     * Close the popup
     */
    static Close() {
        if this.IsProcessing {
            Orchestrator.HideSpinner()
            this.IsProcessing := false
        }
        if this.Gui {
            this.Gui.Destroy()
            this.Gui := ""
        }
    }

    /**
     * Check if popup is visible
     */
    static IsVisible() {
        return this.Gui != ""
    }
}
