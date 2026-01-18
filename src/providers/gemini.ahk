#Requires AutoHotkey v2.0

/**
 * GeminiProvider - Adapter for Google Gemini API
 *
 * Endpoint: POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
 * Auth: x-goog-api-key header
 *
 * Key differences from OpenAI:
 * - Model name goes in URL path, not request body
 * - Completely different structure: contents with parts arrays
 * - System prompt: system_instruction.parts (NOT in contents)
 * - Uses maxOutputTokens not max_tokens
 * - Response: candidates[0].content.parts[0].text
 */
class GeminiProvider extends ProviderBase {
    Name := "Gemini"
    BaseUrl := "https://generativelanguage.googleapis.com/v1beta"
    DefaultModel := "gemini-2.5-flash"

    /**
     * Send completion request to Gemini
     */
    Complete(systemPrompt, userPrompt, options := Map()) {
        apiKey := this.GetApiKey()
        if apiKey = ""
            return this.BuildResult(false, "", "Gemini API key not configured")

        model := options.Has("model") ? options["model"] : this.DefaultModel
        maxTokens := options.Has("max_tokens") ? options["max_tokens"] : this.MaxTokens
        temperature := options.Has("temperature") ? options["temperature"] : this.Temperature

        ; Build request body - completely different structure from OpenAI
        body := {
            contents: [
                {
                    parts: [
                        {text: userPrompt}
                    ]
                }
            ],
            generationConfig: {
                temperature: temperature,
                maxOutputTokens: maxTokens
            }
        }

        ; Add system instruction if provided (separate field with parts)
        if systemPrompt != "" {
            body.system_instruction := {
                parts: [
                    {text: systemPrompt}
                ]
            }
        }

        ; Build headers
        headers := Map(
            "x-goog-api-key", apiKey,
            "Content-Type", "application/json"
        )

        ; Make request - NOTE: model in URL path
        url := this.BaseUrl "/models/" model ":generateContent"
        response := HttpClient.PostJSON(url, body, headers)

        if !response.success {
            ; Gemini-specific error handling
            if response.status = 400
                return this.BuildResult(false, "", "Invalid request: " response.error)
            if response.status = 403
                return this.BuildResult(false, "", "Invalid Gemini API key or API not enabled")
            if response.status = 429
                return this.BuildResult(false, "", "Rate limit exceeded. Please wait and try again.")
            return this.BuildResult(false, "", response.error)
        }

        ; Parse response - NOTE: candidates[0].content.parts[0].text
        ; AHK v2 arrays are 1-indexed
        try {
            content := response.data["candidates"][1]["content"]["parts"][1]["text"]
            ; Gemini usage format (may not always be present)
            promptTokens := 0
            completionTokens := 0
            if response.data.Has("usageMetadata") {
                usageData := response.data["usageMetadata"]
                if usageData.Has("promptTokenCount")
                    promptTokens := usageData["promptTokenCount"]
                if usageData.Has("candidatesTokenCount")
                    completionTokens := usageData["candidatesTokenCount"]
            }
            usage := {
                prompt_tokens: promptTokens,
                completion_tokens: completionTokens
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
            "x-goog-api-key", apiKey
        )

        ; List models endpoint
        url := this.BaseUrl "/models"
        response := HttpClient.Get(url, headers)

        if response.status = 200
            return {success: true, error: ""}
        else if response.status = 403
            return {success: false, error: "Invalid API key or API not enabled"}
        else
            return {success: false, error: "Connection failed: HTTP " response.status}
    }
}
