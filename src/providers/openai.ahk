#Requires AutoHotkey v2.0

/**
 * OpenAIProvider - Adapter for OpenAI Chat Completions API
 *
 * Endpoint: POST https://api.openai.com/v1/chat/completions
 * Auth: Authorization: Bearer {api_key}
 * Format: OpenAI standard (messages array with role/content)
 */
class OpenAIProvider extends ProviderBase {
    Name := "OpenAI"
    BaseUrl := "https://api.openai.com"
    DefaultModel := "gpt-4.1-nano"

    /**
     * Send completion request to OpenAI
     */
    Complete(systemPrompt, userPrompt, options := Map()) {
        apiKey := this.GetApiKey()
        if apiKey = ""
            return this.BuildResult(false, "", "OpenAI API key not configured")

        model := options.Has("model") ? options["model"] : this.DefaultModel
        maxTokens := options.Has("max_tokens") ? options["max_tokens"] : this.MaxTokens
        temperature := options.Has("temperature") ? options["temperature"] : this.Temperature

        ; Build messages array
        messages := []
        if systemPrompt != ""
            messages.Push({role: "system", content: systemPrompt})
        messages.Push({role: "user", content: userPrompt})

        ; Build request body (stream defaults to false, don't include it)
        body := {
            model: model,
            messages: messages,
            max_tokens: maxTokens,
            temperature: temperature
        }

        ; Build headers
        headers := Map(
            "Authorization", "Bearer " apiKey,
            "Content-Type", "application/json"
        )

        ; Make request
        url := this.BaseUrl "/v1/chat/completions"
        response := HttpClient.PostJSON(url, body, headers)

        if !response.success
            return this.BuildResult(false, "", response.error)

        ; Parse response
        try {
            content := response.data["choices"][1]["message"]["content"]
            usage := {
                prompt_tokens: response.data["usage"]["prompt_tokens"],
                completion_tokens: response.data["usage"]["completion_tokens"]
            }
            return this.BuildResult(true, content, "", usage)
        } catch as e {
            return this.BuildResult(false, "", "Failed to parse response: " e.Message)
        }
    }

    /**
     * Test connection by listing models
     */
    TestConnection() {
        apiKey := this.GetApiKey()
        if apiKey = ""
            return {success: false, error: "API key not configured"}

        headers := Map(
            "Authorization", "Bearer " apiKey
        )

        url := this.BaseUrl "/v1/models"
        response := HttpClient.Get(url, headers)

        if response.status = 200
            return {success: true, error: ""}
        else if response.status = 401
            return {success: false, error: "Invalid API key"}
        else
            return {success: false, error: "Connection failed: HTTP " response.status}
    }
}
