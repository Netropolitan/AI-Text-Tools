#Requires AutoHotkey v2.0

/**
 * STTWhisper - Speech-to-Text provider using Whisper-compatible API
 *
 * Supports OpenAI Whisper API format and Kamino STT format.
 * Configurable transcribe endpoint path for different server implementations.
 *
 * OpenAI format: POST /v1/audio/transcriptions (multipart) -> {text}
 * Kamino format: POST /api/transcribe (multipart) -> {text, language, duration}
 */
class STTWhisper {
    ServerUrl := ""
    TranscribePath := "/v1/audio/transcriptions"
    Model := "whisper-1"
    ApiKey := ""

    /**
     * Constructor
     * @param {string} serverUrl - Base server URL (e.g., http://localhost:8000)
     * @param {string} transcribePath - API path for transcription endpoint
     * @param {string} model - Model name (default: whisper-1)
     * @param {string} apiKey - Optional API key for authenticated servers
     */
    __New(serverUrl := "", transcribePath := "", model := "", apiKey := "") {
        if serverUrl
            this.ServerUrl := serverUrl
        if transcribePath
            this.TranscribePath := transcribePath
        if model
            this.Model := model
        if apiKey
            this.ApiKey := apiKey
    }

    /**
     * Transcribe an audio file to text
     * @param {string} audioFilePath - Path to audio file (WAV, MP3, etc.)
     * @returns {success, text, error}
     */
    Transcribe(audioFilePath) {
        if !this.ServerUrl
            return {success: false, text: "", error: "STT server URL not configured"}

        if !FileExist(audioFilePath)
            return {success: false, text: "", error: "Audio file not found: " . audioFilePath}

        url := this.ServerUrl . this.TranscribePath

        try {
            ; Use curl for multipart file upload (built into Windows 10+)
            return this.TranscribeWithCurl(url, audioFilePath)
        } catch as e {
            return {success: false, text: "", error: "Transcription failed: " . e.Message}
        }
    }

    /**
     * Transcribe using curl for multipart form upload
     */
    TranscribeWithCurl(url, audioFilePath) {
        tempDir := A_Temp "\AITextTools"
        if !DirExist(tempDir)
            DirCreate(tempDir)

        responseFile := tempDir "\stt_response.json"
        doneFile := tempDir "\stt_done.txt"

        ; Clean up old files
        try FileDelete(responseFile)
        try FileDelete(doneFile)

        ; Build curl command for multipart upload
        curlCmd := 'C:\Windows\System32\curl.exe --silent --show-error --max-time 60 '

        ; Add auth header if API key is set
        if this.ApiKey
            curlCmd .= '-H "Authorization: Bearer ' . this.ApiKey . '" '

        ; Add file and model as multipart form data
        curlCmd .= '-F "file=@' . audioFilePath . '" '
        curlCmd .= '-F "model=' . this.Model . '" '
        curlCmd .= '-o "' . responseFile . '" '
        curlCmd .= '"' . url . '" && echo done > "' . doneFile . '"'

        ; Run via hidden cmd
        try {
            shell := ComObject("WScript.Shell")
            shell.Run('cmd.exe /c ' . curlCmd, 0, false)
        } catch as e {
            return {success: false, text: "", error: "Failed to start curl: " . e.Message}
        }

        ; Poll for completion - max 60 seconds
        maxWait := 60000
        startTime := A_TickCount
        while !FileExist(doneFile) && (A_TickCount - startTime < maxWait) {
            Sleep(200)
        }

        if !FileExist(doneFile) {
            return {success: false, text: "", error: "Transcription timed out after 60 seconds"}
        }

        if !FileExist(responseFile)
            return {success: false, text: "", error: "No response from STT server"}

        try {
            responseBody := FileRead(responseFile, "UTF-8-RAW")
        } catch as e {
            return {success: false, text: "", error: "Failed to read response: " . e.Message}
        }

        ; Clean up temp files
        try {
            FileDelete(responseFile)
            FileDelete(doneFile)
        }

        if responseBody = ""
            return {success: false, text: "", error: "Empty response from STT server"}

        ; Parse JSON response - both OpenAI and Kamino formats have a "text" field
        try {
            data := JSON.Load(responseBody)

            if data.Has("text") {
                return {success: true, text: data["text"], error: ""}
            } else if data.Has("error") {
                errMsg := IsObject(data["error"]) ? (data["error"].Has("message") ? data["error"]["message"] : String(data["error"])) : String(data["error"])
                return {success: false, text: "", error: errMsg}
            } else {
                return {success: false, text: "", error: "Unexpected response format"}
            }
        } catch as e {
            return {success: false, text: "", error: "Failed to parse response: " . SubStr(responseBody, 1, 200)}
        }
    }

    /**
     * Test connection to the STT server
     * @returns {success, error}
     */
    TestConnection() {
        if !this.ServerUrl
            return {success: false, error: "Server URL not configured"}

        ; Try a simple GET to the server root to check connectivity
        try {
            response := HttpClient.Get(this.ServerUrl, Map())
            if response.status >= 200 && response.status < 500
                return {success: true, error: ""}
            else if response.error
                return {success: false, error: "Cannot connect to " . this.ServerUrl . ": " . response.error}
            else
                return {success: false, error: "Server returned HTTP " . response.status}
        } catch as e {
            return {success: false, error: "Connection failed: " . e.Message}
        }
    }

    /**
     * Get available models from the server
     * Tries /v1/models endpoint; returns empty array if not available
     * @returns {Array} Array of model name strings
     */
    GetModels() {
        if !this.ServerUrl
            return []

        try {
            headers := Map()
            if this.ApiKey
                headers["Authorization"] := "Bearer " . this.ApiKey

            response := HttpClient.Get(this.ServerUrl . "/v1/models", headers)

            if response.status = 200 {
                data := JSON.Load(response.body)
                models := []
                if data.Has("data") {
                    for model in data["data"] {
                        if model.Has("id")
                            models.Push(model["id"])
                    }
                }
                return models
            }
        } catch {
            ; Server may not support /v1/models - that's OK
        }

        return []
    }
}
