#Requires AutoHotkey v2.0

/**
 * OllamaProvider - Adapter for Ollama API
 *
 * Supports both local (localhost:11434) and remote servers.
 * Uses native Ollama /api/chat endpoint (not OpenAI-compatible).
 *
 * Endpoint: POST {BaseUrl}/api/chat
 * Auth: None (local) or custom header if configured
 */
class OllamaProvider extends ProviderBase {
    Name := "Ollama"
    BaseUrl := "http://localhost:11434"
    DefaultModel := "llama3.2"

    /**
     * Send completion request to Ollama
     */
    Complete(systemPrompt, userPrompt, options := Map()) {
        ; Handle both Map and Object for options
        hasModel := (options is Map) ? options.Has("model") : options.HasOwnProp("model")
        hasTemp := (options is Map) ? options.Has("temperature") : options.HasOwnProp("temperature")
        model := hasModel ? options["model"] : this.DefaultModel
        temperature := hasTemp ? options["temperature"] : this.Temperature

        ; Build messages array using Maps for proper JSON serialization
        messages := []
        if systemPrompt != "" {
            sysMsg := Map("role", "system", "content", systemPrompt)
            messages.Push(sysMsg)
        }
        userMsg := Map("role", "user", "content", userPrompt)
        messages.Push(userMsg)

        ; Build options map
        opts := Map("temperature", temperature)
        hasMaxTokens := (options is Map) ? options.Has("max_tokens") : options.HasOwnProp("max_tokens")
        if hasMaxTokens
            opts["num_predict"] := options["max_tokens"]
        else if this.MaxTokens > 0
            opts["num_predict"] := this.MaxTokens

        ; Build JSON manually to ensure "stream":false is a proper boolean
        ; Escape content for JSON (handle quotes and newlines)
        escapeJson(str) {
            str := StrReplace(str, "\", "\\")
            str := StrReplace(str, '"', '\"')
            str := StrReplace(str, "`n", "\n")
            str := StrReplace(str, "`r", "\r")
            str := StrReplace(str, "`t", "\t")
            return str
        }

        ; Build messages array
        messagesJson := "["
        for i, msg in messages {
            if i > 1
                messagesJson .= ","
            messagesJson .= '{"role":"' . msg["role"] . '","content":"' . escapeJson(msg["content"]) . '"}'
        }
        messagesJson .= "]"

        ; Build complete JSON body - stream:false written literally as boolean
        bodyJson := '{"model":"' . escapeJson(model) . '","messages":' . messagesJson . ',"stream":false,"options":{"temperature":' . temperature . '}}'

        ; DEBUG: Show what we're sending (remove after fixing)
        ; MsgBox("Sending JSON:`n" . SubStr(bodyJson, 1, 500), "Debug")

        ; Headers
        headers := Map("Content-Type", "application/json")

        ; Make direct HTTP request to avoid any middleware issues
        url := this.BaseUrl "/api/chat"

        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("POST", url, true)
            whr.SetTimeouts(30000, 30000, 30000, 120000)
            whr.SetRequestHeader("Content-Type", "application/json")
            whr.Send(bodyJson)
            whr.WaitForResponse(120)

            status := whr.Status
            responseBody := whr.ResponseText
        } catch as e {
            return this.BuildResult(false, "", "Connection error: " . e.Message)
        }

        ; Handle response
        if status < 200 || status >= 300 {
            ; Try to get error message from response
            try {
                errData := JSON.Load(responseBody)
                errMsg := (errData is Map && errData.Has("error")) ? errData["error"] : "HTTP " . status
                return this.BuildResult(false, "", errMsg . " (Model: " . model . ")")
            } catch {
                return this.BuildResult(false, "", "HTTP " . status . ": " . SubStr(responseBody, 1, 200))
            }
        }

        ; Parse successful response (Ollama format)
        try {
            data := JSON.Load(responseBody)
            content := data["message"]["content"]
            usage := {
                prompt_tokens: data.Has("prompt_eval_count") ? data["prompt_eval_count"] : 0,
                completion_tokens: data.Has("eval_count") ? data["eval_count"] : 0
            }
            return this.BuildResult(true, content, "", usage)
        } catch as e {
            return this.BuildResult(false, "", "Failed to parse response: " e.Message)
        }
    }

    /**
     * Test connection by getting Ollama version or listing models
     */
    TestConnection() {
        ; Try to list models (simple GET request)
        url := this.BaseUrl "/api/tags"
        headers := Map()

        response := HttpClient.Get(url, headers)

        if response.status = 200
            return {success: true, error: ""}
        else if response.error
            return {success: false, error: "Cannot connect to Ollama at " this.BaseUrl}
        else
            return {success: false, error: "Ollama returned HTTP " response.status}
    }

    /**
     * Get list of available models
     * @returns Array of model names
     */
    GetModels() {
        url := this.BaseUrl "/api/tags"
        response := HttpClient.Get(url, Map())

        if response.status != 200
            return []

        try {
            data := JSON.Load(response.body)
            models := []
            for model in data["models"]
                models.Push(model["name"])
            return models
        } catch {
            return []
        }
    }
}
