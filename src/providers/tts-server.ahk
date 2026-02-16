#Requires AutoHotkey v2.0

/**
 * TTSServer - Text-to-Speech provider using server API
 *
 * Supports multiple TTS server formats:
 * - Kamino format: POST /api/kamino/tts with {text, voice} -> {audio: "<base64_mp3>"}
 * - OpenAI format: POST /v1/audio/speech with {input, voice, model} -> raw audio bytes
 *
 * Configurable endpoint path for different server implementations.
 * Falls back to Windows SAPI for users without a TTS server.
 */
class TTSServer {
    ServerUrl := ""
    TTSPath := "/v1/audio/speech"
    Voice := "irish_female"
    Model := "tts-1"
    ApiKey := ""

    ; Kamino voice list (used as fallback when server has no voice listing endpoint)
    static KaminoVoices := ["irish_female", "irish_male", "british_female", "british_male", "american_female", "american_male"]

    /**
     * Constructor
     * @param {string} serverUrl - Base server URL
     * @param {string} ttsPath - API path for TTS endpoint
     * @param {string} voice - Voice name (default: irish_female)
     * @param {string} apiKey - Optional API key
     */
    __New(serverUrl := "", ttsPath := "", voice := "", apiKey := "") {
        if serverUrl
            this.ServerUrl := serverUrl
        if ttsPath
            this.TTSPath := ttsPath
        if voice
            this.Voice := voice
        if apiKey
            this.ApiKey := apiKey
    }

    /**
     * Speak text using the TTS server
     * @param {string} text - Text to speak
     * @param {string} voice - Optional voice override
     * @returns {success, error}
     */
    Speak(text, voice := "") {
        if !voice
            voice := this.Voice

        if !this.ServerUrl
            return this.SpeakWithSAPI(text)

        url := this.ServerUrl . this.TTSPath

        ; Detect format based on path
        if InStr(this.TTSPath, "kamino")
            return this.SpeakKamino(url, text, voice)
        else
            return this.SpeakOpenAI(url, text, voice)
    }

    /**
     * Speak using Kamino TTS format
     * Sends {text, voice} JSON, receives {audio: "<base64_mp3>"}
     */
    SpeakKamino(url, text, voice) {
        headers := Map("Content-Type", "application/json")
        if this.ApiKey
            headers["Authorization"] := "Bearer " . this.ApiKey

        body := Map("text", text, "voice", voice)

        response := HttpClient.PostJSON(url, body, headers)

        if !response.success
            return {success: false, error: "TTS request failed: " . response.error}

        ; Extract base64 audio from response
        data := response.data
        if !data.Has("audio")
            return {success: false, error: "No audio in response"}

        base64Audio := data["audio"]

        ; Decode base64 and play MP3
        return this.PlayBase64Audio(base64Audio)
    }

    /**
     * Speak using OpenAI TTS format
     * Sends {input, voice, model} JSON, receives raw audio bytes
     */
    SpeakOpenAI(url, text, voice) {
        ; Use curl for binary response handling
        tempDir := A_Temp "\AITextTools"
        if !DirExist(tempDir)
            DirCreate(tempDir)

        audioFile := tempDir "\tts_output.mp3"
        requestFile := tempDir "\tts_request.json"
        doneFile := tempDir "\tts_done.txt"

        ; Clean up old files
        try FileDelete(audioFile)
        try FileDelete(requestFile)
        try FileDelete(doneFile)

        ; Build request JSON
        requestJson := '{"input":"' . this.EscapeJson(text) . '","voice":"' . this.EscapeJson(voice) . '","model":"' . this.EscapeJson(this.Model) . '"}'

        ; Write request body
        try {
            f := FileOpen(requestFile, "w", "UTF-8-RAW")
            f.Write(requestJson)
            f.Close()
        } catch as e {
            return {success: false, error: "Failed to write request: " . e.Message}
        }

        ; Build curl command
        curlCmd := 'C:\Windows\System32\curl.exe --silent --show-error --max-time 30 '
        curlCmd .= '-H "Content-Type: application/json" '
        if this.ApiKey
            curlCmd .= '-H "Authorization: Bearer ' . this.ApiKey . '" '
        curlCmd .= '-d @"' . requestFile . '" '
        curlCmd .= '-o "' . audioFile . '" '
        curlCmd .= '"' . url . '" && echo done > "' . doneFile . '"'

        try {
            shell := ComObject("WScript.Shell")
            shell.Run('cmd.exe /c ' . curlCmd, 0, false)
        } catch as e {
            return {success: false, error: "Failed to start curl: " . e.Message}
        }

        ; Poll for completion
        maxWait := 30000
        startTime := A_TickCount
        while !FileExist(doneFile) && (A_TickCount - startTime < maxWait) {
            Sleep(200)
        }

        ; Clean up request files
        try {
            FileDelete(requestFile)
            FileDelete(doneFile)
        }

        if !FileExist(audioFile)
            return {success: false, error: "No audio response from TTS server"}

        return this.PlayAudioFile(audioFile)
    }

    /**
     * Decode base64 audio and play as MP3
     */
    PlayBase64Audio(base64String) {
        tempDir := A_Temp "\AITextTools"
        if !DirExist(tempDir)
            DirCreate(tempDir)

        audioFile := tempDir "\tts_output.mp3"

        ; Decode base64 to binary file using certutil
        tempB64 := tempDir "\tts_b64.txt"
        try FileDelete(tempB64)
        try FileDelete(audioFile)

        ; Write base64 string to file
        try {
            f := FileOpen(tempB64, "w", "UTF-8-RAW")
            f.Write(base64String)
            f.Close()
        } catch as e {
            return {success: false, error: "Failed to write base64 data: " . e.Message}
        }

        ; Use certutil to decode base64 -> binary
        doneFile := tempDir "\tts_decode_done.txt"
        try FileDelete(doneFile)

        decodeCmd := 'certutil -decode "' . tempB64 . '" "' . audioFile . '" >nul 2>&1 && echo done > "' . doneFile . '"'

        try {
            shell := ComObject("WScript.Shell")
            shell.Run('cmd.exe /c ' . decodeCmd, 0, false)
        } catch as e {
            return {success: false, error: "Failed to decode audio: " . e.Message}
        }

        ; Wait for decode
        maxWait := 5000
        startTime := A_TickCount
        while !FileExist(doneFile) && (A_TickCount - startTime < maxWait) {
            Sleep(100)
        }

        ; Clean up temp files
        try {
            FileDelete(tempB64)
            FileDelete(doneFile)
        }

        if !FileExist(audioFile)
            return {success: false, error: "Failed to decode base64 audio"}

        return this.PlayAudioFile(audioFile)
    }

    /**
     * Play an MP3 file using mciSendString
     */
    PlayAudioFile(filePath) {
        try {
            ; Close any previously playing audio
            DllCall("winmm\mciSendStringW", "Str", "close tts_audio", "Ptr", 0, "UInt", 0, "Ptr", 0)

            ; Open the audio file
            result := DllCall("winmm\mciSendStringW", "Str", 'open "' . filePath . '" alias tts_audio', "Ptr", 0, "UInt", 0, "Ptr", 0)
            if result != 0
                return {success: false, error: "Failed to open audio file (MCI error " . result . ")"}

            ; Play the audio
            result := DllCall("winmm\mciSendStringW", "Str", "play tts_audio", "Ptr", 0, "UInt", 0, "Ptr", 0)
            if result != 0 {
                DllCall("winmm\mciSendStringW", "Str", "close tts_audio", "Ptr", 0, "UInt", 0, "Ptr", 0)
                return {success: false, error: "Failed to play audio (MCI error " . result . ")"}
            }

            ; Wait for playback to finish (poll status)
            buf := Buffer(256, 0)
            Loop {
                DllCall("winmm\mciSendStringW", "Str", "status tts_audio mode", "Ptr", buf.Ptr, "UInt", 128, "Ptr", 0)
                mode := StrGet(buf.Ptr, "UTF-16")
                if mode != "playing"
                    break
                Sleep(100)
            }

            ; Close when done
            DllCall("winmm\mciSendStringW", "Str", "close tts_audio", "Ptr", 0, "UInt", 0, "Ptr", 0)

            return {success: true, error: ""}
        } catch as e {
            try DllCall("winmm\mciSendStringW", "Str", "close tts_audio", "Ptr", 0, "UInt", 0, "Ptr", 0)
            return {success: false, error: "Audio playback error: " . e.Message}
        }
    }

    /**
     * Fallback: Speak using Windows SAPI
     */
    SpeakWithSAPI(text) {
        try {
            spVoice := ComObject("SAPI.SpVoice")
            spVoice.Speak(text, 1)  ; 1 = SVSFlagsAsync
            return {success: true, error: ""}
        } catch as e {
            return {success: false, error: "SAPI speech failed: " . e.Message}
        }
    }

    /**
     * Stop any currently playing audio
     */
    Stop() {
        try {
            DllCall("winmm\mciSendStringW", "Str", "close tts_audio", "Ptr", 0, "UInt", 0, "Ptr", 0)
        }
    }

    /**
     * Test connection to the TTS server
     * @returns {success, error}
     */
    TestConnection() {
        if !this.ServerUrl
            return {success: false, error: "Server URL not configured"}

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
     * Fetch available voices from the server
     * Falls back to Kamino voice list if server has no voice endpoint
     * @returns {Array} Array of voice name strings
     */
    FetchVoices() {
        if !this.ServerUrl
            return this.GetSAPIVoices()

        ; Try common voice listing endpoints
        voiceEndpoints := ["/v1/voices", "/api/voices", "/voices"]

        headers := Map()
        if this.ApiKey
            headers["Authorization"] := "Bearer " . this.ApiKey

        for endpoint in voiceEndpoints {
            try {
                response := HttpClient.Get(this.ServerUrl . endpoint, headers)
                if response.status = 200 {
                    data := JSON.Load(response.body)
                    voices := []

                    ; Handle array response
                    if data is Array {
                        for voice in data {
                            if IsObject(voice) && voice.Has("name")
                                voices.Push(voice["name"])
                            else if !IsObject(voice)
                                voices.Push(String(voice))
                        }
                    }
                    ; Handle {voices: [...]} response
                    else if data.Has("voices") {
                        for voice in data["voices"] {
                            if IsObject(voice) && voice.Has("name")
                                voices.Push(voice["name"])
                            else if !IsObject(voice)
                                voices.Push(String(voice))
                        }
                    }

                    if voices.Length > 0
                        return voices
                }
            } catch {
                ; Try next endpoint
            }
        }

        ; Fallback: if server is reachable, provide Kamino voice list
        try {
            response := HttpClient.Get(this.ServerUrl, Map())
            if response.status >= 200 && response.status < 500
                return TTSServer.KaminoVoices.Clone()
        } catch {
            ; Server not reachable
        }

        return []
    }

    /**
     * Get Windows SAPI voices
     * @returns {Array} Array of SAPI voice names
     */
    GetSAPIVoices() {
        voices := []
        try {
            spVoice := ComObject("SAPI.SpVoice")
            voiceTokens := spVoice.GetVoices()
            Loop voiceTokens.Count {
                token := voiceTokens.Item(A_Index - 1)
                voices.Push(token.GetDescription())
            }
        } catch {
            ; SAPI not available
        }
        return voices
    }

    /**
     * Escape string for JSON
     */
    EscapeJson(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, '"', '\"')
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`t", "\t")
        return str
    }
}
