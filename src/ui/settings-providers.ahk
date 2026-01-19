#Requires AutoHotkey v2.0

/**
 * ProvidersTab - Provider configuration UI for Settings window
 *
 * Displays configuration for all 4 providers:
 * - OpenAI, Anthropic, Gemini: API key, model selection
 * - Ollama: URL field, model selection
 *
 * Features:
 * - API keys masked with show/hide toggle
 * - Test Connection button per provider
 * - Status indicators (green/red)
 * - Secure storage via CredentialManager
 */
class ProvidersTab {
    static Controls := Map()
    static Config := ""
    static DefaultCheckboxes := Map()  ; Track all default checkboxes for mutual exclusion

    /**
     * Build Providers tab content
     * @param settingsGui The parent Gui object
     * @param config ConfigManager instance
     */
    static Build(settingsGui, config) {
        this.Config := config
        y := 50  ; Starting Y position within tab

        ; OpenAI section - models populated from API
        y := this.BuildProviderSection(settingsGui, "OpenAI", "openai", y, {
            hasApiKey: true,
            apiKeyUrl: "https://platform.openai.com/api-keys"
        })

        ; Anthropic section - models populated from API
        y := this.BuildProviderSection(settingsGui, "Anthropic", "anthropic", y, {
            hasApiKey: true,
            apiKeyUrl: "https://console.anthropic.com/settings/keys"
        })

        ; Gemini section - models populated from API
        y := this.BuildProviderSection(settingsGui, "Google Gemini", "gemini", y, {
            hasApiKey: true,
            apiKeyUrl: "https://aistudio.google.com/apikey"
        })
    }

    /**
     * Build a provider configuration section
     */
    static BuildProviderSection(gui, displayName, providerName, startY, options) {
        y := startY
        x := 20

        ; Provider header with status indicator
        statusColor := this.GetStatusColor(providerName)
        statusCtrl := gui.Add("Text", "x" . x . " y" . y . " w16 h16 c" . statusColor, Chr(0x25CF))  ; Bullet character
        this.Controls[providerName . "_status"] := statusCtrl

        gui.SetFont("Bold")
        gui.Add("Text", "x" . (x+22) . " y" . y . " w200", displayName)
        gui.SetFont("Norm")
        y += 28

        ; API Key field (for OpenAI, Anthropic, Gemini)
        if options.hasApiKey {
            gui.Add("Text", "x" . x . " y" . y, "API Key:")

            ; Check if key exists - show placeholder, not masked value
            hasKey := CredentialManager.Exists(providerName)
            placeholder := hasKey ? "(key stored - enter new to replace)" : ""
            keyEdit := gui.Add("Edit", "x" . (x+80) . " y" . (y-3) . " w300 Password", placeholder)
            this.Controls[providerName . "_key"] := keyEdit
            this.Controls[providerName . "_haskey"] := hasKey

            ; Show/Hide toggle button
            showBtn := gui.Add("Button", "x" . (x+390) . " y" . (y-4) . " w50 h24", "Show")
            showBtn.OnEvent("Click", this.MakeToggleHandler(providerName))
            this.Controls[providerName . "_showbtn"] := showBtn
            this.Controls[providerName . "_keyvisible"] := false

            ; Delete button
            delBtn := gui.Add("Button", "x" . (x+445) . " y" . (y-4) . " w50 h24", "Delete")
            delBtn.OnEvent("Click", this.MakeDeleteHandler(providerName))
            y += 30
        }

        ; URL field (for Ollama)
        if options.HasOwnProp("hasUrl") && options.hasUrl {
            gui.Add("Text", "x" . x . " y" . y, "URL:")
            section := "Provider_Ollama"
            urlVal := this.Config.Get(section, "BaseUrl", options.defaultUrl)
            urlEdit := gui.Add("Edit", "x" . (x+80) . " y" . (y-3) . " w300", urlVal)
            this.Controls[providerName . "_url"] := urlEdit
            y += 30
        }

        ; Model dropdown - starts empty, populated after Test Connection
        gui.Add("Text", "x" . x . " y" . y, "Model:")
        section := "Provider_" . this.GetSectionName(providerName)
        currentModel := this.Config.Get(section, "DefaultModel", "")

        ; Create dropdown with just the saved model (if any) or placeholder
        initialModels := currentModel ? [currentModel] : ["(Test connection to load)"]
        modelCtrl := gui.Add("DropDownList", "x" . (x+80) . " y" . (y-3) . " w200", initialModels)
        modelCtrl.Choose(1)
        this.Controls[providerName . "_model"] := modelCtrl
        y += 30

        ; Test connection button
        testBtn := gui.Add("Button", "x" . x . " y" . y . " w110 h26", "Test Connection")
        testBtn.OnEvent("Click", this.MakeTestHandler(providerName))

        ; Default checkbox
        currentDefault := this.Config.Get("General", "DefaultProvider", "openai")
        isDefault := (providerName = currentDefault)
        defaultCheck := gui.Add("Checkbox", "x" . (x+130) . " y" . (y+4), "Default")
        defaultCheck.Value := isDefault
        defaultCheck.OnEvent("Click", this.MakeDefaultHandler(providerName))
        this.Controls[providerName . "_default"] := defaultCheck
        this.DefaultCheckboxes[providerName] := defaultCheck

        ; Get API Key link
        if options.HasOwnProp("apiKeyUrl") && options.apiKeyUrl {
            apiKeyLink := gui.Add("Text", "x" . (x+210) . " y" . (y+4) . " c0066CC", "Get API Key")
            apiKeyLink.OnEvent("Click", this.MakeApiKeyLinkHandler(options.apiKeyUrl))
        }
        y += 38

        ; Horizontal separator line
        gui.Add("Text", "x" . x . " y" . y . " w520 0x10")  ; SS_ETCHEDHORZ style
        y += 12

        return y
    }

    /**
     * Get INI section name from provider name
     */
    static GetSectionName(providerName) {
        sectionMap := Map(
            "openai", "OpenAI",
            "anthropic", "Anthropic",
            "gemini", "Gemini",
            "ollama", "Ollama"
        )
        return sectionMap.Has(providerName) ? sectionMap[providerName] : providerName
    }

    /**
     * Get status indicator color based on configuration
     */
    static GetStatusColor(providerName) {
        if ProviderFactory.IsConfigured(providerName, this.Config)
            return "00AA00"  ; Green
        return "CC0000"  ; Red
    }

    /**
     * Build pipe-separated model list for DropDownList
     */
    static BuildModelList(models) {
        result := []
        for model in models
            result.Push(model)
        return result
    }

    /**
     * Select the current model in dropdown
     */
    static SelectModel(ctrl, currentModel, models) {
        for i, model in models {
            if model = currentModel {
                ctrl.Choose(i)
                return
            }
        }
        ctrl.Choose(1)  ; Default to first if not found
    }

    /**
     * Create toggle handler for API key visibility
     */
    static MakeToggleHandler(providerName) {
        return (*) => this.ToggleKeyVisibility(providerName)
    }

    /**
     * Create delete handler for API key
     */
    static MakeDeleteHandler(providerName) {
        return (*) => this.DeleteApiKey(providerName)
    }

    /**
     * Create default checkbox handler
     */
    static MakeDefaultHandler(providerName) {
        return (*) => this.SetAsDefault(providerName)
    }

    /**
     * Create API key link handler
     */
    static MakeApiKeyLinkHandler(url) {
        return (*) => Run(url)
    }

    /**
     * Set a provider as the default, unchecking all others
     */
    static SetAsDefault(providerName) {
        ; Check if user is trying to uncheck the currently selected default
        currentDefault := this.Config.Get("General", "DefaultProvider", "openai")
        clickedCheckbox := this.DefaultCheckboxes.Has(providerName) ? this.DefaultCheckboxes[providerName] : ""

        if clickedCheckbox && clickedCheckbox.Value = 0 && providerName = currentDefault {
            ; User unchecked the current default - force it back on (must have a default)
            clickedCheckbox.Value := 1
            ToolTip("Must have a default provider")
            SetTimer () => ToolTip(), -2000
            return
        }

        ; Uncheck all other provider default checkboxes
        for name, checkbox in this.DefaultCheckboxes {
            if name != providerName
                checkbox.Value := 0
        }

        ; Also uncheck Ollama's default checkbox if it exists
        if LocalTab.Controls.Has("default") {
            LocalTab.Controls["default"].Value := 0
        }

        ; Ensure this one is checked
        if this.DefaultCheckboxes.Has(providerName)
            this.DefaultCheckboxes[providerName].Value := 1

        ; Save to config
        this.Config.Set("General", "DefaultProvider", providerName)

        ; Refresh orchestrator to use new provider
        Orchestrator.RefreshProvider()

        ; Show confirmation
        ToolTip("Default provider: " . providerName)
        SetTimer () => ToolTip(), -2000
    }

    /**
     * Delete API key for a provider
     */
    static DeleteApiKey(providerName) {
        result := MsgBox("Are you sure you want to delete the API key for " . providerName . "?", "Delete API Key", "YesNo Icon!")
        if result = "Yes" {
            CredentialManager.Delete(providerName)

            ; Clear the field and update status
            if this.Controls.Has(providerName . "_key") {
                keyCtrl := this.Controls[providerName . "_key"]
                keyCtrl.Value := ""
            }

            this.UpdateStatus(providerName, false)
            ToolTip("API key deleted")
            SetTimer () => ToolTip(), -2000
        }
    }

    /**
     * Toggle API key visibility in the edit field
     */
    static ToggleKeyVisibility(providerName) {
        if !this.Controls.Has(providerName . "_key")
            return

        keyCtrl := this.Controls[providerName . "_key"]
        showBtn := this.Controls[providerName . "_showbtn"]
        isVisible := this.Controls[providerName . "_keyvisible"]

        currentValue := keyCtrl.Value

        if isVisible {
            ; Hide - add Password style
            keyCtrl.Opt("+Password")
            showBtn.Text := "Show"
            this.Controls[providerName . "_keyvisible"] := false
        } else {
            ; Show - remove Password style
            keyCtrl.Opt("-Password")
            showBtn.Text := "Hide"
            this.Controls[providerName . "_keyvisible"] := true
        }

        ; Restore the value (changing Password style can clear it)
        keyCtrl.Value := currentValue
    }

    /**
     * Create test connection handler for provider
     */
    static MakeTestHandler(providerName) {
        return (*) => this.TestConnection(providerName)
    }

    /**
     * Test connection for a provider
     */
    static TestConnection(providerName) {
        try {
            ; Save current settings first so test uses latest values
            this.SaveProviderSettings(providerName)

            ; Create provider and test
            provider := ProviderFactory.Create(providerName, this.Config)
            result := provider.TestConnection()

            if result.success {
                MsgBox("Connection successful!`n`nProvider: " . providerName, "Test Connection", "Icon!")
                this.UpdateStatus(providerName, true)

                ; Fetch and populate models after successful connection
                this.FetchModels(providerName)
            } else {
                MsgBox("Connection failed:`n`n" . result.error, "Test Connection", "IconX")
                this.UpdateStatus(providerName, false)
            }
        } catch as e {
            MsgBox("Error: " . e.Message, "Test Connection", "IconX")
            this.UpdateStatus(providerName, false)
        }
    }

    /**
     * Fetch available models from provider API
     */
    static FetchModels(providerName) {
        if !this.Controls.Has(providerName . "_model")
            return

        try {
            modelCtrl := this.Controls[providerName . "_model"]
            currentModel := modelCtrl.Text
            if currentModel = "(Test connection to load)"
                currentModel := ""

            ; Get API key
            apiKey := CredentialManager.Retrieve(providerName)
            if !apiKey
                return

            models := []

            if providerName = "openai" {
                ; Fetch OpenAI models from API
                headers := Map("Authorization", "Bearer " . apiKey)
                response := HttpClient.Get("https://api.openai.com/v1/models", headers)

                if response.status = 200 {
                    data := JSON.Load(response.body)
                    if data.Has("data") {
                        for model in data["data"] {
                            modelId := model["id"]
                            ; Filter to GPT chat models only
                            if InStr(modelId, "gpt-") && !InStr(modelId, "instruct") && !InStr(modelId, "realtime") && !InStr(modelId, "audio")
                                models.Push(modelId)
                        }
                    }
                }
            } else if providerName = "anthropic" {
                ; Fetch Anthropic models from API
                headers := Map(
                    "x-api-key", apiKey,
                    "anthropic-version", "2023-06-01"
                )
                response := HttpClient.Get("https://api.anthropic.com/v1/models", headers)

                if response.status = 200 {
                    data := JSON.Load(response.body)
                    if data.Has("data") {
                        for model in data["data"] {
                            modelId := model["id"]
                            models.Push(modelId)
                        }
                    }
                }
            } else if providerName = "gemini" {
                ; Fetch Gemini models from API (use v1beta for latest models)
                response := HttpClient.Get("https://generativelanguage.googleapis.com/v1beta/models?key=" . apiKey, Map())

                if response.status = 200 {
                    data := JSON.Load(response.body)
                    if data.Has("models") {
                        for model in data["models"] {
                            modelName := model["name"]
                            ; Extract just the model ID (remove "models/" prefix)
                            if InStr(modelName, "models/")
                                modelName := SubStr(modelName, 8)
                            ; Filter to generative models
                            if InStr(modelName, "gemini")
                                models.Push(modelName)
                        }
                    }
                }
            }

            ; Update dropdown
            modelCtrl.Delete()

            if models.Length > 0 {
                ; Sort models
                models := this.SortModels(models)
                modelCtrl.Add(models)

                ; Re-select current model if it exists, otherwise select first
                foundIndex := 0
                for i, m in models {
                    if m = currentModel {
                        foundIndex := i
                        break
                    }
                }
                if foundIndex > 0
                    modelCtrl.Choose(foundIndex)
                else
                    modelCtrl.Choose(1)

                ToolTip("Found " . models.Length . " models")
                SetTimer () => ToolTip(), -2000
            } else {
                ; No models found - leave dropdown empty
                ToolTip("No models found")
                SetTimer () => ToolTip(), -2000
            }
        } catch as e {
            ; On error, clear dropdown
            modelCtrl.Delete()
            ToolTip("Error fetching models")
            SetTimer () => ToolTip(), -2000
        }
    }

    /**
     * Sort models with preferred ones first
     */
    static SortModels(models) {
        ; Preferred order prefixes
        preferred := ["gpt-4.1", "gpt-4o", "gpt-4-turbo", "gpt-4", "gpt-3.5", "claude-opus", "claude-sonnet", "gemini-2", "gemini-1"]
        sorted := []
        remaining := []

        ; First pass: add preferred models in order
        for prefix in preferred {
            for model in models {
                if InStr(model, prefix) && !this.ArrayContains(sorted, model)
                    sorted.Push(model)
            }
        }

        ; Second pass: add remaining models
        for model in models {
            if !this.ArrayContains(sorted, model)
                sorted.Push(model)
        }

        return sorted
    }

    /**
     * Check if array contains value
     */
    static ArrayContains(arr, value) {
        for item in arr {
            if item = value
                return true
        }
        return false
    }

    /**
     * Update status indicator color
     */
    static UpdateStatus(providerName, success) {
        try {
            if this.Controls.Has(providerName . "_status") {
                statusCtrl := this.Controls[providerName . "_status"]
                if success
                    statusCtrl.Opt("c00AA00")  ; Green
                else
                    statusCtrl.Opt("cCC0000")  ; Red
                statusCtrl.Redraw()
            }
        } catch {
            ; Control may have been destroyed if settings window was closed
        }
    }

    /**
     * Save settings for a single provider
     */
    static SaveProviderSettings(providerName) {
        section := "Provider_" . this.GetSectionName(providerName)

        ; Save API key to Credential Manager (if new key entered)
        if this.Controls.Has(providerName . "_key") {
            keyCtrl := this.Controls[providerName . "_key"]
            keyValue := keyCtrl.Value
            ; Only save if:
            ; - Value exists
            ; - Not the placeholder text
            ; - Doesn't contain parentheses (placeholder indicator)
            ; - Looks like an API key (reasonable length, no spaces)
            if keyValue && !InStr(keyValue, "(") && !InStr(keyValue, " ") && StrLen(keyValue) > 10 {
                CredentialManager.Store(providerName, keyValue)
                ; Auto-set this provider as default when API key is added
                this.Config.Set("General", "DefaultProvider", providerName)
            }
        }

        ; Save URL (Ollama only)
        if this.Controls.Has(providerName . "_url") {
            urlCtrl := this.Controls[providerName . "_url"]
            this.Config.Set(section, "BaseUrl", urlCtrl.Value)
        }

        ; Save model selection (but not if it's the placeholder text)
        if this.Controls.Has(providerName . "_model") {
            modelCtrl := this.Controls[providerName . "_model"]
            modelText := modelCtrl.Text
            if modelText && !InStr(modelText, "(")  ; Don't save placeholder text
                this.Config.Set(section, "DefaultModel", modelText)
        }
    }

    /**
     * Save all provider settings
     */
    static SaveAll() {
        for providerName in ["openai", "anthropic", "gemini"] {
            this.SaveProviderSettings(providerName)
        }
    }

    /**
     * Refresh all status indicators
     */
    static RefreshStatus() {
        for providerName in ["openai", "anthropic", "gemini"] {
            isConfigured := ProviderFactory.IsConfigured(providerName, this.Config)
            this.UpdateStatus(providerName, isConfigured)
        }
    }
}

/**
 * LocalTab - Local/Ollama server configuration
 *
 * Dedicated tab for connecting to Ollama servers (local or remote)
 * Features:
 * - Server URL configuration
 * - Connect & fetch available models
 * - Model selection dropdown (simplified from list)
 * - Default checkbox
 * - Connection status indicator
 */
class LocalTab {
    static Controls := Map()
    static Config := ""
    static Models := []

    /**
     * Build Local tab content
     */
    static Build(settingsGui, config) {
        this.Config := config
        y := 50
        x := 20

        ; Header
        settingsGui.SetFont("Bold s11")
        settingsGui.Add("Text", "x" . x . " y" . y . " w500", "Local AI Server (Ollama)")
        settingsGui.SetFont("Norm s10")
        y += 30

        ; Description
        settingsGui.Add("Text", "x" . x . " y" . y . " w500 c666666", "Connect to an Ollama server running on your local machine or network.")
        y += 35

        ; Server URL section
        settingsGui.SetFont("Bold")
        settingsGui.Add("Text", "x" . x . " y" . y, "Server URL")
        settingsGui.SetFont("Norm")
        y += 25

        ; URL input (masked by default)
        section := "Provider_Ollama"
        currentUrl := config.Get(section, "BaseUrl", "http://localhost:11434")
        urlEdit := settingsGui.Add("Edit", "x" . x . " y" . y . " w300 Password", currentUrl)
        this.Controls["url"] := urlEdit
        this.Controls["urlVisible"] := false

        ; Show URL checkbox
        showUrlCheck := settingsGui.Add("Checkbox", "x" . (x+310) . " y" . (y+2), "Show")
        showUrlCheck.OnEvent("Click", (*) => this.ToggleUrlVisibility(urlEdit, showUrlCheck))
        this.Controls["showUrl"] := showUrlCheck

        ; Connect button
        connectBtn := settingsGui.Add("Button", "x" . (x+380) . " y" . (y-2) . " w80 h26", "Connect")
        connectBtn.OnEvent("Click", (*) => this.ConnectToServer())
        y += 40

        ; Status indicator
        statusText := settingsGui.Add("Text", "x" . x . " y" . y . " w400 c666666", "Status: Not connected")
        this.Controls["status"] := statusText
        y += 35

        ; Selected Model section
        settingsGui.SetFont("Bold")
        settingsGui.Add("Text", "x" . x . " y" . y, "Model")
        settingsGui.SetFont("Norm")
        y += 25

        ; Model dropdown (populated when connected)
        currentModel := config.Get(section, "DefaultModel", "")
        modelDropdown := settingsGui.Add("DropDownList", "x" . x . " y" . y . " w300", currentModel ? [currentModel] : ["(Connect to load models)"])
        if currentModel
            modelDropdown.Choose(1)
        this.Controls["modelDropdown"] := modelDropdown
        modelDropdown.OnEvent("Change", (*) => this.OnModelSelect())

        ; Refresh models button
        refreshBtn := settingsGui.Add("Button", "x" . (x+310) . " y" . (y-2) . " w80 h26", "Refresh")
        refreshBtn.OnEvent("Click", (*) => this.ConnectToServer())
        y += 40

        ; Default checkbox
        currentDefault := config.Get("General", "DefaultProvider", "openai")
        isDefault := (currentDefault = "ollama")
        defaultCheck := settingsGui.Add("Checkbox", "x" . x . " y" . y, "Default")
        defaultCheck.Value := isDefault
        defaultCheck.OnEvent("Click", (*) => this.SetAsDefault())
        this.Controls["default"] := defaultCheck
        y += 35

        ; Tips
        settingsGui.Add("Text", "x" . x . " y" . y . " w500 c888888", "Tip: Click 'Connect' to fetch available models from your server.")

        ; Auto-connect if URL is configured (try to connect automatically on tab load)
        SetTimer () => this.ConnectToServer(), -500
    }

    /**
     * Toggle URL visibility between masked and visible
     */
    static ToggleUrlVisibility(urlEdit, checkbox) {
        currentValue := urlEdit.Value
        if checkbox.Value {
            ; Show URL - recreate without Password style
            urlEdit.Opt("-Password")
        } else {
            ; Hide URL - add Password style
            urlEdit.Opt("+Password")
        }
        urlEdit.Value := currentValue
    }

    /**
     * Connect to Ollama server and fetch models
     */
    static ConnectToServer() {
        ; Get controls - may be destroyed if window closed
        try {
            urlCtrl := this.Controls["url"]
            statusCtrl := this.Controls["status"]
            modelDropdown := this.Controls["modelDropdown"]
            baseUrl := urlCtrl.Value
            statusCtrl.Text := "Status: Connecting..."
        } catch {
            return  ; Window was closed
        }

        try {
            ; Fetch models from Ollama API
            url := baseUrl . "/api/tags"
            response := HttpClient.Get(url, Map())

            if response.status = 200 {
                data := JSON.Load(response.body)

                if data.Has("models") && data["models"].Length > 0 {
                    this.Models := []
                    modelNames := []

                    for model in data["models"] {
                        this.Models.Push(model["name"])
                        modelNames.Push(model["name"])
                    }

                    ; Get current saved model
                    currentModel := this.Config.Get("Provider_Ollama", "DefaultModel", "")
                    foundIndex := 0

                    ; Check if current model exists in list
                    if currentModel {
                        for i, m in modelNames {
                            if m = currentModel {
                                foundIndex := i
                                break
                            }
                        }
                    }

                    ; Update dropdown - wrap in try-catch in case window closed
                    try {
                        modelDropdown.Delete()
                        modelDropdown.Add(modelNames)

                        ; Select saved model or first available
                        if foundIndex > 0 {
                            modelDropdown.Choose(foundIndex)
                        } else if modelNames.Length > 0 {
                            modelDropdown.Choose(1)
                            this.Config.Set("Provider_Ollama", "DefaultModel", modelNames[1])
                        }

                        statusCtrl.Opt("c00AA00")  ; Green
                        statusCtrl.Text := "Status: Connected - " . this.Models.Length . " models available"
                    } catch {
                        ; Window was closed during operation
                    }

                    ; Save URL on successful connection
                    this.Config.Set("Provider_Ollama", "BaseUrl", baseUrl)
                } else {
                    try {
                        statusCtrl.Opt("cCC8800")  ; Orange
                        statusCtrl.Text := "Status: Connected but no models found. Run: ollama pull llama3.2"
                    } catch {
                        ; Window was closed
                    }
                }
            } else {
                try {
                    statusCtrl.Opt("cCC0000")  ; Red
                    statusCtrl.Text := "Status: Failed to connect (HTTP " . response.status . ")"
                } catch {
                    ; Window was closed
                }
            }
        } catch as e {
            try {
                statusCtrl.Opt("cCC0000")  ; Red
                statusCtrl.Text := "Status: Connection error - " . e.Message
            } catch {
                ; Window was closed
            }
        }
    }

    /**
     * Handle model selection from dropdown
     */
    static OnModelSelect() {
        modelDropdown := this.Controls["modelDropdown"]

        if modelDropdown.Value > 0 {
            selectedModel := modelDropdown.Text
            this.Config.Set("Provider_Ollama", "DefaultModel", selectedModel)

            ToolTip("Model: " . selectedModel)
            SetTimer () => ToolTip(), -1500
        }
    }

    /**
     * Set Ollama as the default provider, unchecking all others
     */
    static SetAsDefault() {
        ; Check if user is trying to uncheck the currently selected default
        currentDefault := this.Config.Get("General", "DefaultProvider", "openai")
        clickedCheckbox := this.Controls.Has("default") ? this.Controls["default"] : ""

        if clickedCheckbox && clickedCheckbox.Value = 0 && currentDefault = "ollama" {
            ; User unchecked the current default - force it back on (must have a default)
            clickedCheckbox.Value := 1
            ToolTip("Must have a default provider")
            SetTimer () => ToolTip(), -2000
            return
        }

        ; Uncheck all cloud provider default checkboxes
        for name, checkbox in ProvidersTab.DefaultCheckboxes {
            checkbox.Value := 0
        }

        ; Ensure Ollama's checkbox is checked
        if this.Controls.Has("default")
            this.Controls["default"].Value := 1

        ; Save to config
        this.Config.Set("General", "DefaultProvider", "ollama")

        ; Refresh orchestrator to use new provider
        Orchestrator.RefreshProvider()

        ; Show confirmation
        ToolTip("Default provider: Ollama")
        SetTimer () => ToolTip(), -2000
    }

    /**
     * Save Local tab settings
     */
    static SaveAll() {
        section := "Provider_Ollama"

        if this.Controls.Has("url") {
            this.Config.Set(section, "BaseUrl", this.Controls["url"].Value)
        }

        if this.Controls.Has("modelDropdown") {
            modelDropdown := this.Controls["modelDropdown"]
            if modelDropdown.Value > 0
                this.Config.Set(section, "DefaultModel", modelDropdown.Text)
        }
    }
}
