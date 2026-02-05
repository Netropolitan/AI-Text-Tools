#Requires AutoHotkey v2.0

/**
 * OllamaProvider - Adapter for Ollama API
 *
 * Supports both local (localhost:11434) and remote servers.
 * Uses native Ollama /api/chat endpoint (not OpenAI-compatible).
 *
 * Uses curl.exe (built into Windows 10/11) for reliable long-running requests.
 * Falls back to WinHTTP if curl is unavailable.
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

        ; Build JSON body
        bodyJson := this.BuildRequestJson(systemPrompt, userPrompt, model, temperature, options)
        url := this.BaseUrl "/api/chat"

        ; Try curl first (more reliable for long requests), fall back to WinHTTP
        if this.HasCurl()
            return this.CompleteWithCurl(url, bodyJson, model)
        else
            return this.CompleteWithWinHttp(url, bodyJson, model)
    }

    /**
     * Build JSON request body
     */
    BuildRequestJson(systemPrompt, userPrompt, model, temperature, options) {
        ; Escape content for JSON
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
        if systemPrompt != ""
            messagesJson .= '{"role":"system","content":"' . escapeJson(systemPrompt) . '"},'
        messagesJson .= '{"role":"user","content":"' . escapeJson(userPrompt) . '"}'
        messagesJson .= "]"

        ; Build complete JSON body - stream:false as literal boolean
        return '{"model":"' . escapeJson(model) . '","messages":' . messagesJson . ',"stream":false,"options":{"temperature":' . temperature . '}}'
    }

    /**
     * Check if curl.exe is available (built into Windows 10 1803+)
     */
    HasCurl() {
        return FileExist("C:\Windows\System32\curl.exe")
    }

    /**
     * Make request using curl.exe - reliable for long-running LLM requests
     */
    CompleteWithCurl(url, bodyJson, model) {
        ; Write JSON to temp file (avoids command line escaping issues)
        tempDir := A_Temp "\AITextTools"
        if !DirExist(tempDir)
            DirCreate(tempDir)

        requestFile := tempDir "\ollama_request.json"
        responseFile := tempDir "\ollama_response.json"

        ; Clean up old response file
        try FileDelete(responseFile)

        ; Write request body (UTF-8 without BOM - important for curl)
        try {
            f := FileOpen(requestFile, "w", "UTF-8-RAW")
            f.Write(bodyJson)
            f.Close()
        } catch as e {
            return this.BuildResult(false, "", "Failed to write request: " . e.Message)
        }

        ; Build curl command with a done marker file so we know when it's finished
        ; --max-time 300 = 5 minute timeout for LLM inference
        ; --silent = no progress output
        ; --show-error = show errors
        ; -o = output response to file
        doneFile := tempDir "\ollama_done.txt"
        try FileDelete(doneFile)

        ; Use a batch approach: run curl, then create done file
        curlCmd := 'C:\Windows\System32\curl.exe --silent --show-error --max-time 300 '
            . '-H "Content-Type: application/json" '
            . '-d @"' . requestFile . '" '
            . '-o "' . responseFile . '" '
            . '"' . url . '" && echo done > "' . doneFile . '"'

        ; Run via cmd /c in hidden window
        try {
            shell := ComObject("WScript.Shell")
            shell.Run('cmd.exe /c ' . curlCmd, 0, false)  ; 0=hidden, false=don't wait
        } catch as e {
            return this.BuildResult(false, "", "Failed to start curl: " . e.Message)
        }

        ; Poll for completion (check for done file) - max 5 minutes
        maxWait := 300000  ; 5 minutes in ms
        startTime := A_TickCount
        while !FileExist(doneFile) && (A_TickCount - startTime < maxWait) {
            Sleep(200)
        }

        ; Check if we timed out
        if !FileExist(doneFile) {
            try FileDelete(requestFile)
            return this.BuildResult(false, "", "Request timed out after 5 minutes")
        }

        ; Read response
        if !FileExist(responseFile)
            return this.BuildResult(false, "", "No response from Ollama server - check URL and that Ollama is running")

        try {
            responseBody := FileRead(responseFile, "UTF-8-RAW")
        } catch as e {
            return this.BuildResult(false, "", "Failed to read response: " . e.Message)
        }

        ; Clean up temp files
        try {
            FileDelete(requestFile)
            FileDelete(responseFile)
            FileDelete(doneFile)
        }

        ; Check if response is empty
        if responseBody = ""
            return this.BuildResult(false, "", "Empty response from Ollama server")

        ; Try to parse as JSON - if it has an error field, it's an error response
        try {
            data := JSON.Load(responseBody)

            ; Check for error in response
            if data.Has("error") {
                return this.BuildResult(false, "", data["error"] . " (Model: " . model . ")")
            }

            ; Success - extract content
            content := data["message"]["content"]
            usage := {
                prompt_tokens: data.Has("prompt_eval_count") ? data["prompt_eval_count"] : 0,
                completion_tokens: data.Has("eval_count") ? data["eval_count"] : 0
            }
            return this.BuildResult(true, content, "", usage)
        } catch as e {
            ; Not valid JSON - probably an error message from curl or server
            return this.BuildResult(false, "", "Invalid response: " . SubStr(responseBody, 1, 200))
        }
    }

    /**
     * Make request using WinHTTP - fallback for systems without curl
     */
    CompleteWithWinHttp(url, bodyJson, model) {
        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.SetTimeouts(30000, 30000, 60000, 300000)  ; 5 min receive timeout
            whr.Open("POST", url, false)  ; synchronous
            whr.SetRequestHeader("Content-Type", "application/json")
            whr.Send(bodyJson)

            status := whr.Status
            responseBody := whr.ResponseText
        } catch as e {
            return this.BuildResult(false, "", "Connection error: " . e.Message)
        }

        if status < 200 || status >= 300 {
            try {
                errData := JSON.Load(responseBody)
                errMsg := (errData is Map && errData.Has("error")) ? errData["error"] : "HTTP " . status
                return this.BuildResult(false, "", errMsg . " (Model: " . model . ")")
            } catch {
                return this.BuildResult(false, "", "HTTP " . status . ": " . SubStr(responseBody, 1, 200))
            }
        }

        return this.ParseOllamaResponse(responseBody, model)
    }

    /**
     * Parse Ollama API response
     */
    ParseOllamaResponse(responseBody, model) {
        try {
            data := JSON.Load(responseBody)
            content := data["message"]["content"]
            usage := {
                prompt_tokens: data.Has("prompt_eval_count") ? data["prompt_eval_count"] : 0,
                completion_tokens: data.Has("eval_count") ? data["eval_count"] : 0
            }
            return this.BuildResult(true, content, "", usage)
        } catch as e {
            return this.BuildResult(false, "", "Failed to parse response: " . e.Message)
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
