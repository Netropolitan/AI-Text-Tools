#Requires AutoHotkey v2.0

/**
 * TTSEdge - Text-to-Speech using Microsoft Edge Read Aloud (free, no API key)
 *
 * Connects to Microsoft's speech synthesis service via WebSocket using PowerShell.
 * Produces high-quality neural voices. Requires internet connection.
 *
 * Protocol: WebSocket to wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1
 * Audio format: audio-24khz-48kbitrate-mono-mp3
 */
class TTSEdge {
    Voice := "en-GB-SoniaNeural"
    Rate := "+0%"
    Volume := "+0%"

    static VoiceListUrl := "https://speech.platform.bing.com/consumer/speech/api/v1/voicelist?trustedclienttoken=6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    static TrustedClientToken := "6A5AA1D4EAFF4E9FB37E23D68491D6F4"

    /**
     * Constructor
     * @param {string} voice - Voice name (e.g., en-GB-SoniaNeural)
     * @param {string} rate - Speech rate (e.g., +0%, +50%, -30%)
     * @param {string} volume - Volume (e.g., +0%, +50%)
     */
    __New(voice := "", rate := "", volume := "") {
        if voice
            this.Voice := voice
        if rate
            this.Rate := rate
        if volume
            this.Volume := volume
    }

    /**
     * Speak text using Edge TTS
     * @param {string} text - Text to speak
     * @param {string} voice - Optional voice override
     * @returns {success, error}
     */
    Speak(text, voice := "") {
        if !voice
            voice := this.Voice

        if !text || text = ""
            return {success: false, error: "No text to speak"}

        tempDir := A_Temp "\AITextTools"
        if !DirExist(tempDir)
            DirCreate(tempDir)

        audioFile := tempDir "\edge_tts_output.mp3"
        doneFile := tempDir "\edge_tts_done.txt"
        errorFile := tempDir "\edge_tts_error.txt"

        ; Clean up old files
        try FileDelete(audioFile)
        try FileDelete(doneFile)
        try FileDelete(errorFile)

        ; Build SSML
        ssml := this.BuildSSML(text, voice)

        ; Build PowerShell script for WebSocket communication
        psScript := this.BuildPowerShellScript(ssml, audioFile, doneFile, errorFile)

        ; Encode script as Base64 for PowerShell -EncodedCommand
        encoded := this.EncodeBase64(psScript)

        ; Run PowerShell hidden
        try {
            shell := ComObject("WScript.Shell")
            shell.Run('powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand ' . encoded, 0, false)
        } catch as e {
            return {success: false, error: "Failed to start PowerShell: " . e.Message}
        }

        ; Poll for completion - max 30 seconds
        maxWait := 30000
        startTime := A_TickCount
        while !FileExist(doneFile) && !FileExist(errorFile) && (A_TickCount - startTime < maxWait) {
            Sleep(200)
        }

        ; Check for error
        if FileExist(errorFile) {
            try {
                errText := Trim(FileRead(errorFile, "UTF-8"))
                FileDelete(errorFile)
                if errText
                    return {success: false, error: "Edge TTS error: " . SubStr(errText, 1, 300)}
            }
        }

        if !FileExist(doneFile)
            return {success: false, error: "Edge TTS timed out after 30 seconds"}

        ; Clean up done file
        try FileDelete(doneFile)

        if !FileExist(audioFile)
            return {success: false, error: "No audio produced by Edge TTS"}

        ; Play the MP3 using MCI
        return this.PlayAudioFile(audioFile)
    }

    /**
     * Build SSML for the given text
     */
    BuildSSML(text, voice) {
        ; Escape XML special characters in text
        text := StrReplace(text, "&", "&amp;")
        text := StrReplace(text, "<", "&lt;")
        text := StrReplace(text, ">", "&gt;")
        text := StrReplace(text, '"', "&quot;")

        ssml := '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">'
        ssml .= '<voice name="' . voice . '">'
        ssml .= '<prosody rate="' . this.Rate . '" volume="' . this.Volume . '">'
        ssml .= text
        ssml .= '</prosody></voice></speak>'
        return ssml
    }

    /**
     * Build the PowerShell script that handles WebSocket communication
     *
     * Uses file-based approach: writes SSML to temp file, PowerShell reads it.
     * This avoids all string escaping issues between AHK and PowerShell.
     */
    BuildPowerShellScript(ssml, audioFile, doneFile, errorFile) {
        ; Write SSML to a temp file so PowerShell can read it (avoids escaping nightmares)
        tempDir := A_Temp "\AITextTools"
        ssmlFile := tempDir "\edge_tts_ssml.txt"
        try FileDelete(ssmlFile)
        try {
            f := FileOpen(ssmlFile, "w", "UTF-8-RAW")
            f.Write(ssml)
            f.Close()
        }

        ; Escape file paths for PowerShell single-quoted strings
        ssmlFilePs := StrReplace(ssmlFile, "'", "''")
        audioFilePs := StrReplace(audioFile, "'", "''")
        doneFilePs := StrReplace(doneFile, "'", "''")
        errorFilePs := StrReplace(errorFile, "'", "''")

        ; Build PowerShell script using line-by-line concatenation
        ; Each line uses `n for newlines in the final script
        LF := "`n"
        ps := ""
        ps .= "try {" . LF
        ps .= "$token = '6A5AA1D4EAFF4E9FB37E23D68491D6F4'" . LF
        ps .= "$connId = [guid]::NewGuid().ToString('N')" . LF
        ps .= '$uri = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=$token&ConnectionId=$connId"' . LF
        ps .= "$ws = New-Object System.Net.WebSockets.ClientWebSocket" . LF
        ps .= "$ws.Options.SetRequestHeader('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')" . LF
        ps .= "$ws.Options.SetRequestHeader('Origin', 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold')" . LF
        ps .= "$ct = New-Object System.Threading.CancellationToken($false)" . LF
        ps .= "$ws.ConnectAsync([Uri]$uri, $ct).Wait()" . LF

        ; Audio config message
        ps .= '$configMsg = "Content-Type:application/json; charset=utf-8`r`nPath:speech.config`r`n`r`n{""context"":{""synthesis"":{""audio"":{""metadataoptions"":{""sentenceBoundaryEnabled"":""false"",""wordBoundaryEnabled"":""false""},""outputFormat"":""audio-24khz-48kbitrate-mono-mp3""}}}}"' . LF
        ps .= "$configBytes = [System.Text.Encoding]::UTF8.GetBytes($configMsg)" . LF
        ps .= "$segment = New-Object System.ArraySegment[byte] @(,$configBytes)" . LF
        ps .= "$ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()" . LF

        ; Read SSML from temp file and send
        ps .= "$ssmlContent = [System.IO.File]::ReadAllText('" . ssmlFilePs . "')" . LF
        ps .= "$requestId = [guid]::NewGuid().ToString('N')" . LF
        ps .= "$date = [DateTime]::UtcNow.ToString('ddd MMM dd yyyy HH:mm:ss') + ' GMT+0000 (Coordinated Universal Time)'" . LF
        ps .= '$ssmlMsg = "X-RequestId:$requestId`r`nContent-Type:application/ssml+xml`r`nX-Timestamp:$date`r`nPath:ssml`r`n`r`n" + $ssmlContent' . LF
        ps .= "$ssmlBytes = [System.Text.Encoding]::UTF8.GetBytes($ssmlMsg)" . LF
        ps .= "$segment = New-Object System.ArraySegment[byte] @(,$ssmlBytes)" . LF
        ps .= "$ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()" . LF

        ; Receive audio data loop
        ps .= "$audioData = New-Object System.Collections.Generic.List[byte]" . LF
        ps .= "$buffer = New-Object byte[] 8192" . LF
        ps .= "while ($true) {" . LF
        ps .= "  $segment = New-Object System.ArraySegment[byte] @(,$buffer)" . LF
        ps .= "  $result = $ws.ReceiveAsync($segment, $ct).GetAwaiter().GetResult()" . LF
        ps .= "  if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { break }" . LF
        ps .= "  if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Binary) {" . LF
        ps .= "    $received = $buffer[0..($result.Count - 1)]" . LF
        ps .= "    if ($result.Count -gt 2) {" . LF
        ps .= "      $headerLen = [BitConverter]::ToUInt16([byte[]]@($received[1], $received[0]), 0)" . LF
        ps .= "      if ($headerLen -lt $result.Count) {" . LF
        ps .= "        $audioBytes = $received[($headerLen + 2)..($result.Count - 1)]" . LF
        ps .= "        $audioData.AddRange([byte[]]$audioBytes)" . LF
        ps .= "      }" . LF
        ps .= "    }" . LF
        ps .= "  }" . LF
        ps .= "  if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Text) {" . LF
        ps .= "    $txt = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)" . LF
        ps .= "    if ($txt -match 'Path:turn.end') { break }" . LF
        ps .= "  }" . LF
        ps .= "}" . LF

        ; Close websocket and write output
        ps .= "$ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, '', $ct).Wait()" . LF
        ps .= "if ($audioData.Count -gt 0) {" . LF
        ps .= "  [System.IO.File]::WriteAllBytes('" . audioFilePs . "', $audioData.ToArray())" . LF
        ps .= "  'done' | Out-File -FilePath '" . doneFilePs . "' -Encoding utf8" . LF
        ps .= "} else {" . LF
        ps .= "  'No audio data received' | Out-File -FilePath '" . errorFilePs . "' -Encoding utf8" . LF
        ps .= "}" . LF
        ps .= "} catch {" . LF
        ps .= "  $_.Exception.Message | Out-File -FilePath '" . errorFilePs . "' -Encoding utf8" . LF
        ps .= "}"

        return ps
    }

    /**
     * Encode string as UTF-16LE Base64 for PowerShell -EncodedCommand
     */
    EncodeBase64(str) {
        ; Convert string to UTF-16LE bytes, then Base64 encode
        ; Using COM ADODB.Stream + MSXML2.DOMDocument
        stream := ComObject("ADODB.Stream")
        stream.Type := 2  ; text
        stream.Charset := "UTF-16LE"
        stream.Open()
        stream.WriteText(str)

        ; Convert to binary
        stream.Position := 0
        stream.Type := 1  ; binary
        ; Skip BOM (2 bytes)
        stream.Position := 2
        bytes := stream.Read()
        stream.Close()

        ; Base64 encode using MSXML2
        dom := ComObject("MSXML2.DOMDocument.6.0")
        el := dom.createElement("b64")
        el.DataType := "bin.base64"
        el.nodeTypedValue := bytes
        encoded := StrReplace(StrReplace(el.text, "`n", ""), "`r", "")

        return encoded
    }

    /**
     * Play an MP3 file using MCI (mpegvideo device type)
     */
    PlayAudioFile(filePath) {
        try {
            ; Close any previously playing audio
            DllCall("winmm\mciSendStringW", "Str", "close edge_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)

            ; Open with mpegvideo type for MP3 support
            result := DllCall("winmm\mciSendStringW", "Str", 'open "' . filePath . '" type mpegvideo alias edge_tts', "Ptr", 0, "UInt", 0, "Ptr", 0)
            if result != 0
                return {success: false, error: "Failed to open audio file (MCI error " . result . ")"}

            ; Play the audio
            result := DllCall("winmm\mciSendStringW", "Str", "play edge_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)
            if result != 0 {
                DllCall("winmm\mciSendStringW", "Str", "close edge_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)
                return {success: false, error: "Failed to play audio (MCI error " . result . ")"}
            }

            ; Wait for playback to finish
            buf := Buffer(256, 0)
            Loop {
                DllCall("winmm\mciSendStringW", "Str", "status edge_tts mode", "Ptr", buf.Ptr, "UInt", 128, "Ptr", 0)
                mode := StrGet(buf.Ptr, "UTF-16")
                if mode != "playing"
                    break
                Sleep(100)
            }

            ; Close when done
            DllCall("winmm\mciSendStringW", "Str", "close edge_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)

            return {success: true, error: ""}
        } catch as e {
            try DllCall("winmm\mciSendStringW", "Str", "close edge_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)
            return {success: false, error: "Audio playback error: " . e.Message}
        }
    }

    /**
     * Pause playback
     */
    Pause() {
        DllCall("winmm\mciSendStringW", "Str", "pause edge_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)
    }

    /**
     * Resume playback
     */
    Resume() {
        DllCall("winmm\mciSendStringW", "Str", "resume edge_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)
    }

    /**
     * Stop playback
     */
    Stop() {
        try {
            DllCall("winmm\mciSendStringW", "Str", "close edge_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)
        }
    }

    /**
     * Check if audio is still playing
     * @returns {boolean}
     */
    IsFinished() {
        buf := Buffer(256, 0)
        DllCall("winmm\mciSendStringW", "Str", "status edge_tts mode", "Ptr", buf.Ptr, "UInt", 128, "Ptr", 0)
        mode := StrGet(buf.Ptr, "UTF-16")
        return mode != "playing"
    }

    /**
     * Fetch available voice list from Microsoft
     * @param {string} locale - Filter by locale (e.g., "en-GB", "en-US", "" for all)
     * @returns {Array} Array of voice objects {name, shortName, locale, gender}
     */
    static FetchVoiceList(locale := "") {
        voices := []

        try {
            ; Use curl for the HTTP request (built into Windows 10+)
            tempDir := A_Temp "\AITextTools"
            if !DirExist(tempDir)
                DirCreate(tempDir)

            responseFile := tempDir "\edge_voices.json"
            doneFile := tempDir "\edge_voices_done.txt"

            try FileDelete(responseFile)
            try FileDelete(doneFile)

            curlCmd := 'C:\Windows\System32\curl.exe --silent --show-error --max-time 15 '
            curlCmd .= '-o "' . responseFile . '" '
            curlCmd .= '"' . TTSEdge.VoiceListUrl . '" && echo done > "' . doneFile . '"'

            shell := ComObject("WScript.Shell")
            shell.Run('cmd.exe /c ' . curlCmd, 0, false)

            ; Wait for completion
            maxWait := 15000
            startTime := A_TickCount
            while !FileExist(doneFile) && (A_TickCount - startTime < maxWait) {
                Sleep(200)
            }

            if !FileExist(doneFile) || !FileExist(responseFile)
                return voices

            responseBody := FileRead(responseFile, "UTF-8-RAW")

            try {
                FileDelete(responseFile)
                FileDelete(doneFile)
            }

            if responseBody = ""
                return voices

            data := JSON.Load(responseBody)

            if !(data is Array)
                return voices

            for voiceObj in data {
                if !IsObject(voiceObj)
                    continue

                voiceLocale := voiceObj.Has("Locale") ? voiceObj["Locale"] : ""
                voiceName := voiceObj.Has("ShortName") ? voiceObj["ShortName"] : ""
                voiceFriendly := voiceObj.Has("FriendlyName") ? voiceObj["FriendlyName"] : voiceName
                voiceGender := voiceObj.Has("Gender") ? voiceObj["Gender"] : ""

                ; Filter by locale if specified
                if locale && voiceLocale {
                    if !InStr(voiceLocale, locale)
                        continue
                }

                if voiceName
                    voices.Push({name: voiceFriendly, shortName: voiceName, locale: voiceLocale, gender: voiceGender})
            }
        } catch {
            ; Return empty on error
        }

        return voices
    }

    /**
     * Test connection to Edge TTS service
     * @returns {success, error}
     */
    TestConnection() {
        voices := TTSEdge.FetchVoiceList("en")
        if voices.Length > 0
            return {success: true, error: ""}
        return {success: false, error: "Could not reach Edge TTS service. Check internet connection."}
    }
}
