#Requires AutoHotkey v2.0

/**
 * ProviderBase - Abstract base class for AI provider adapters
 *
 * All providers implement:
 * - Complete(systemPrompt, userPrompt, options) -> {success, content, error, usage}
 * - GetModels() -> Array of model names (optional)
 * - TestConnection() -> {success, error}
 */
class ProviderBase {
    Name := "Base"
    BaseUrl := ""
    DefaultModel := ""
    MaxTokens := 4096
    Temperature := 0.7

    /**
     * Constructor - load settings from config
     * @param config ConfigManager instance
     * @param section INI section name (e.g., "Provider_OpenAI")
     */
    __New(config, section) {
        this.Config := config
        this.Section := section
        this.LoadSettings()
    }

    /**
     * Load provider-specific settings from config
     * Subclasses should override to load additional settings
     */
    LoadSettings() {
        this.BaseUrl := this.Config.Get(this.Section, "BaseUrl", this.BaseUrl)
        this.DefaultModel := this.Config.Get(this.Section, "DefaultModel", this.DefaultModel)
        this.MaxTokens := Integer(this.Config.Get(this.Section, "MaxTokens", this.MaxTokens))
        this.Temperature := Float(this.Config.Get(this.Section, "Temperature", this.Temperature))
    }

    /**
     * Send a completion request
     * @param systemPrompt System instructions
     * @param userPrompt User's input text
     * @param options Map with optional overrides: model, max_tokens, temperature
     * @returns {success, content, error, usage: {prompt_tokens, completion_tokens}}
     */
    Complete(systemPrompt, userPrompt, options := Map()) {
        throw Error("Complete() must be implemented by subclass")
    }

    /**
     * Test if the provider is configured and accessible
     * @returns {success, error}
     */
    TestConnection() {
        throw Error("TestConnection() must be implemented by subclass")
    }

    /**
     * Get the API key for this provider
     * Checks CredentialManager first, falls back to INI for legacy support
     * @returns API key string or empty
     */
    GetApiKey() {
        ; Derive provider name from section (e.g., "Provider_OpenAI" -> "openai")
        providerName := StrLower(StrReplace(this.Section, "Provider_", ""))

        ; Try CredentialManager first (secure storage)
        key := CredentialManager.Retrieve(providerName)
        if key
            return key

        ; Fall back to INI (legacy or development)
        return this.Config.Get(this.Section, "ApiKey", "")
    }

    /**
     * Build standard result object
     */
    BuildResult(success, content := "", error := "", usage := "") {
        ; Strip <think>...</think> blocks from reasoning models (e.g., DeepSeek R1, Qwen QwQ)
        if success && content != ""
            content := this.StripThinkTags(content)

        return {
            success: success,
            content: content,
            error: error,
            usage: usage ? usage : {prompt_tokens: 0, completion_tokens: 0}
        }
    }

    /**
     * Strip <think>...</think> reasoning blocks from model output
     * Many local models (DeepSeek, Qwen, etc.) emit chain-of-thought in these tags
     */
    StripThinkTags(text) {
        ; Remove complete <think>...</think> blocks (dotall: . matches newlines)
        text := RegExReplace(text, "s)<think>.*?</think>\s*", "")
        ; Handle unclosed <think> tag (truncated reasoning) - strip from <think> to end
        text := RegExReplace(text, "s)<think>.*$", "")
        return Trim(text)
    }
}
