#Requires AutoHotkey v2.0

/**
 * AnthropicProvider - Adapter for Anthropic Claude Messages API
 *
 * Endpoint: POST https://api.anthropic.com/v1/messages
 * Auth: x-api-key header (NOT Bearer token)
 *
 * Key differences from OpenAI:
 * - System prompt is separate "system" field, NOT in messages array
 * - max_tokens is REQUIRED
 * - Requires anthropic-version header
 * - Response format: content[0].text
 */
class AnthropicProvider extends ProviderBase {
    Name := "Anthropic"
    BaseUrl := "https://api.anthropic.com"
    DefaultModel := "claude-sonnet-4-20250514"
    AnthropicVersion := "2023-06-01"

    /**
     * Send completion request to Anthropic
     */
    Complete(systemPrompt, userPrompt, options := Map()) {
        apiKey := this.GetApiKey()
        if apiKey = ""
            return this.BuildResult(false, "", "Anthropic API key not configured")

        model := options.Has("model") ? options["model"] : this.DefaultModel
        maxTokens := options.Has("max_tokens") ? options["max_tokens"] : this.MaxTokens
        temperature := options.Has("temperature") ? options["temperature"] : this.Temperature

        ; Build messages array (NO system message - it's separate)
        messages := []
        messages.Push({role: "user", content: userPrompt})

        ; Build request body - NOTE: system is SEPARATE field
        body := {
            model: model,
            max_tokens: maxTokens,  ; REQUIRED for Anthropic
            messages: messages,
            temperature: temperature
        }

        ; Add system prompt as separate field (NOT in messages)
        if systemPrompt != ""
            body.system := systemPrompt

        ; Build headers - NOTE: x-api-key, NOT Bearer
        headers := Map(
            "x-api-key", apiKey,
            "anthropic-version", this.AnthropicVersion,
            "Content-Type", "application/json"
        )

        ; Make request
        url := this.BaseUrl "/v1/messages"
        response := HttpClient.PostJSON(url, body, headers)

        if !response.success {
            ; Anthropic-specific error handling
            if response.status = 401
                return this.BuildResult(false, "", "Invalid Anthropic API key")
            if response.status = 429
                return this.BuildResult(false, "", "Rate limit exceeded. Please wait and try again.")
            if response.status = 400
                return this.BuildResult(false, "", "Bad request: " response.error)
            return this.BuildResult(false, "", response.error)
        }

        ; Parse response - NOTE: content[0].text format
        try {
            ; Anthropic returns content as array with type/text objects
            ; AHK v2 arrays are 1-indexed
            content := response.data["content"][1]["text"]
            usage := {
                prompt_tokens: response.data["usage"]["input_tokens"],
                completion_tokens: response.data["usage"]["output_tokens"]
            }
            return this.BuildResult(true, content, "", usage)
        } catch as e {
            return this.BuildResult(false, "", "Failed to parse response: " e.Message)
        }
    }

    /**
     * Test connection with minimal request
     * Anthropic doesn't have a simple /models endpoint, so we send a minimal completion
     */
    TestConnection() {
        apiKey := this.GetApiKey()
        if apiKey = ""
            return {success: false, error: "API key not configured"}

        ; Minimal valid request to test auth
        body := {
            model: this.DefaultModel,
            max_tokens: 10,
            messages: [{role: "user", content: "Hi"}]
        }

        headers := Map(
            "x-api-key", apiKey,
            "anthropic-version", this.AnthropicVersion,
            "Content-Type", "application/json"
        )

        url := this.BaseUrl "/v1/messages"
        response := HttpClient.PostJSON(url, body, headers)

        if response.success
            return {success: true, error: ""}
        else if response.status = 401
            return {success: false, error: "Invalid API key"}
        else if response.status = 400
            return {success: false, error: "Configuration error: " response.error}
        else
            return {success: false, error: "Connection failed: " response.error}
    }
}
