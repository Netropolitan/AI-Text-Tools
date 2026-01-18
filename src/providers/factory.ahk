#Requires AutoHotkey v2.0

/**
 * ProviderFactory - Creates provider instances based on configuration
 *
 * Provides single entry point for creating any provider adapter.
 * Reads DefaultProvider from config to select which provider to use.
 */
class ProviderFactory {
    static Providers := Map(
        "openai", OpenAIProvider,
        "anthropic", AnthropicProvider,
        "gemini", GeminiProvider,
        "ollama", OllamaProvider
    )

    /**
     * Create a provider instance
     * @param name Provider name (openai, anthropic, gemini, ollama) - case insensitive
     * @param config ConfigManager instance
     * @returns Provider instance or throws error
     */
    static Create(name, config) {
        name := StrLower(name)

        if !this.Providers.Has(name)
            throw Error("Unknown provider: " name ". Available: " this.GetAvailableString())

        ; Determine config section
        sectionMap := Map(
            "openai", "Provider_OpenAI",
            "anthropic", "Provider_Anthropic",
            "gemini", "Provider_Gemini",
            "ollama", "Provider_Ollama"
        )

        section := sectionMap[name]
        providerClass := this.Providers[name]

        return providerClass(config, section)
    }

    /**
     * Create the default provider from config
     * @param config ConfigManager instance
     * @returns Provider instance
     */
    static CreateDefault(config) {
        defaultName := config.Get("General", "DefaultProvider", "openai")
        return this.Create(defaultName, config)
    }

    /**
     * Get list of available provider names
     * @returns Array of provider names
     */
    static GetAvailable() {
        result := []
        for name, _ in this.Providers
            result.Push(name)
        return result
    }

    /**
     * Get available providers as comma-separated string
     */
    static GetAvailableString() {
        names := this.GetAvailable()
        if names.Length = 0
            return ""
        result := names[1]
        Loop names.Length - 1
            result .= ", " names[A_Index + 1]
        return result
    }

    /**
     * Test if a provider is configured (has API key or is Ollama)
     * Checks CredentialManager first, then falls back to INI
     * @param name Provider name
     * @param config ConfigManager instance
     * @returns Boolean
     */
    static IsConfigured(name, config) {
        name := StrLower(name)

        if name = "ollama"
            return true  ; Ollama doesn't require API key

        sectionMap := Map(
            "openai", "Provider_OpenAI",
            "anthropic", "Provider_Anthropic",
            "gemini", "Provider_Gemini"
        )

        if !sectionMap.Has(name)
            return false

        ; Check CredentialManager first (secure storage)
        if CredentialManager.Exists(name)
            return true

        ; Fall back to INI check (legacy)
        section := sectionMap[name]
        apiKey := config.Get(section, "ApiKey", "")
        return apiKey != ""
    }

    /**
     * Get status of all providers
     * @param config ConfigManager instance
     * @returns Map of provider name => {configured, error}
     */
    static GetStatus(config) {
        status := Map()
        for name, _ in this.Providers {
            try {
                provider := this.Create(name, config)
                testResult := provider.TestConnection()
                status[name] := {configured: testResult.success, error: testResult.error}
            } catch as e {
                status[name] := {configured: false, error: e.Message}
            }
        }
        return status
    }
}
