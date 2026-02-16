#Requires AutoHotkey v2.0

/**
 * TTSPiper - Text-to-Speech using Piper (offline neural TTS)
 *
 * Runs piper.exe as a subprocess for fully offline speech synthesis.
 * Requires piper.exe and a .onnx voice model file.
 * Piper binaries are NOT bundled - download from settings via "Download Piper" button.
 *
 * https://github.com/rhasspy/piper
 */
class TTSPiper {
    ModelFile := ""
    BinDir := ""

    /**
     * Constructor
     * @param {string} modelFile - Full path to .onnx model file
     */
    __New(modelFile := "") {
        if modelFile
            this.ModelFile := modelFile

        ; Resolve bin/ directory (works for both source and compiled layouts)
        if A_IsCompiled
            this.BinDir := A_ScriptDir "\bin"
        else
            this.BinDir := A_ScriptDir "\..\bin"
    }

    /**
     * Get full path to piper.exe
     */
    GetExePath() {
        return this.BinDir "\piper.exe"
    }

    /**
     * Speak text using Piper TTS
     * @param {string} text - Text to speak
     * @returns {success, error}
     */
    Speak(text, voice := "") {
        exePath := this.GetExePath()

        if !FileExist(exePath)
            return {success: false, error: "piper.exe not found. Download Piper from Settings > Voice."}

        if !this.ModelFile || !FileExist(this.ModelFile)
            return {success: false, error: "No Piper voice model selected. Download a model from Settings > Voice."}

        if !text || text = ""
            return {success: false, error: "No text to speak"}

        tempDir := A_Temp "\AITextTools"
        if !DirExist(tempDir)
            DirCreate(tempDir)

        audioFile := tempDir "\piper_output.wav"
        doneFile := tempDir "\piper_done.txt"
        errorFile := tempDir "\piper_error.txt"
        inputFile := tempDir "\piper_input.txt"

        ; Clean up old files
        try FileDelete(audioFile)
        try FileDelete(doneFile)
        try FileDelete(errorFile)
        try FileDelete(inputFile)

        ; Write text to input file (avoids shell escaping issues)
        try {
            f := FileOpen(inputFile, "w", "UTF-8-RAW")
            f.Write(text)
            f.Close()
        } catch as e {
            return {success: false, error: "Failed to write input: " . e.Message}
        }

        ; Build command - pipe input text to piper
        cmd := 'type "' . inputFile . '" | "' . exePath . '"'
        cmd .= ' --model "' . this.ModelFile . '"'
        cmd .= ' --output_file "' . audioFile . '"'

        fullCmd := 'cmd.exe /c (' . cmd . ' 2>"' . errorFile . '" && echo done > "' . doneFile . '")'

        ; Run hidden
        try {
            shell := ComObject("WScript.Shell")
            shell.Run(fullCmd, 0, false)
        } catch as e {
            return {success: false, error: "Failed to start Piper: " . e.Message}
        }

        ; Poll for completion - max 30 seconds
        maxWait := 30000
        startTime := A_TickCount
        while !FileExist(doneFile) && !FileExist(errorFile) && (A_TickCount - startTime < maxWait) {
            Sleep(200)
        }

        ; Clean up input file
        try FileDelete(inputFile)

        ; Check for error
        if FileExist(errorFile) {
            try {
                errText := Trim(FileRead(errorFile, "UTF-8"))
                FileDelete(errorFile)
                ; Piper outputs progress to stderr, only report actual errors
                if errText && InStr(errText, "Error")
                    return {success: false, error: "Piper error: " . SubStr(errText, 1, 300)}
            }
        }

        if !FileExist(doneFile) && !FileExist(audioFile)
            return {success: false, error: "Piper TTS timed out after 30 seconds"}

        try FileDelete(doneFile)
        try FileDelete(errorFile)

        if !FileExist(audioFile)
            return {success: false, error: "No audio produced by Piper"}

        ; Play the WAV using MCI
        return this.PlayAudioFile(audioFile)
    }

    /**
     * Play a WAV file using MCI
     */
    PlayAudioFile(filePath) {
        try {
            DllCall("winmm\mciSendStringW", "Str", "close piper_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)

            result := DllCall("winmm\mciSendStringW", "Str", 'open "' . filePath . '" alias piper_tts', "Ptr", 0, "UInt", 0, "Ptr", 0)
            if result != 0
                return {success: false, error: "Failed to open audio (MCI error " . result . ")"}

            result := DllCall("winmm\mciSendStringW", "Str", "play piper_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)
            if result != 0 {
                DllCall("winmm\mciSendStringW", "Str", "close piper_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)
                return {success: false, error: "Failed to play audio (MCI error " . result . ")"}
            }

            buf := Buffer(256, 0)
            Loop {
                DllCall("winmm\mciSendStringW", "Str", "status piper_tts mode", "Ptr", buf.Ptr, "UInt", 128, "Ptr", 0)
                mode := StrGet(buf.Ptr, "UTF-16")
                if mode != "playing"
                    break
                Sleep(100)
            }

            DllCall("winmm\mciSendStringW", "Str", "close piper_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)
            return {success: true, error: ""}
        } catch as e {
            try DllCall("winmm\mciSendStringW", "Str", "close piper_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)
            return {success: false, error: "Audio playback error: " . e.Message}
        }
    }

    /**
     * Stop playback
     */
    Stop() {
        try {
            DllCall("winmm\mciSendStringW", "Str", "close piper_tts", "Ptr", 0, "UInt", 0, "Ptr", 0)
        }
    }

    /**
     * Get available voice models by scanning for .onnx files
     * @returns {Array} Array of model filenames
     */
    GetVoices() {
        voices := []

        ; Scan bin/ and bin/piper-models/ for .onnx files
        dirs := [this.BinDir, this.BinDir "\piper-models"]

        for dir in dirs {
            if DirExist(dir) {
                Loop Files dir "\*.onnx" {
                    voices.Push(A_LoopFileFullPath)
                }
            }
        }

        return voices
    }

    /**
     * Test if piper.exe is available
     * @returns {success, error}
     */
    TestConnection() {
        if !FileExist(this.GetExePath())
            return {success: false, error: "piper.exe not found. Use 'Download Piper' in settings."}

        if !this.ModelFile || !FileExist(this.ModelFile)
            return {success: false, error: "No voice model found. Download a model in settings."}

        return {success: true, error: ""}
    }
}
