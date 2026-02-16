#Requires AutoHotkey v2.0

/**
 * STTWhisperLocal - Speech-to-Text using local whisper.cpp executable
 *
 * Runs whisper-cli.exe as a subprocess for fully offline transcription.
 * Requires whisper-cli.exe and a ggml model file in the bin/ directory.
 *
 * Usage: Run scripts/download-deps.ps1 to fetch the required files.
 */
class STTWhisperLocal {
    ModelFile := "ggml-tiny.en.bin"
    BinDir := ""

    /**
     * Constructor
     * @param {string} modelFile - Model filename (e.g., ggml-tiny.en.bin)
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
     * Get full path to whisper-cli.exe
     */
    GetExePath() {
        return this.BinDir "\whisper-cli.exe"
    }

    /**
     * Get full path to model file
     */
    GetModelPath() {
        return this.BinDir "\" this.ModelFile
    }

    /**
     * Transcribe an audio file to text
     * @param {string} audioFilePath - Path to audio file (WAV format preferred)
     * @returns {success, text, error}
     */
    Transcribe(audioFilePath) {
        exePath := this.GetExePath()
        modelPath := this.GetModelPath()

        if !FileExist(exePath)
            return {success: false, text: "", error: "whisper-cli.exe not found. Run scripts\download-deps.ps1 to download."}

        if !FileExist(modelPath)
            return {success: false, text: "", error: "Model file not found: " . this.ModelFile . ". Run scripts\download-deps.ps1 to download."}

        if !FileExist(audioFilePath)
            return {success: false, text: "", error: "Audio file not found: " . audioFilePath}

        try {
            return this.TranscribeWithWhisper(exePath, modelPath, audioFilePath)
        } catch as e {
            return {success: false, text: "", error: "Transcription failed: " . e.Message}
        }
    }

    /**
     * Run whisper-cli.exe and read output
     */
    TranscribeWithWhisper(exePath, modelPath, audioFilePath) {
        tempDir := A_Temp "\AITextTools"
        if !DirExist(tempDir)
            DirCreate(tempDir)

        doneFile := tempDir "\whisper_done.txt"
        errorFile := tempDir "\whisper_error.txt"

        ; Clean up old files
        try FileDelete(doneFile)
        try FileDelete(errorFile)

        ; whisper-cli outputs to <input>.txt when using --output-txt
        ; We'll use --output-file to control the output location
        outputBase := tempDir "\whisper_output"
        outputTxt := outputBase ".txt"
        try FileDelete(outputTxt)

        ; Build command
        ; --no-prints suppresses progress output
        ; --output-txt writes transcription to .txt file
        ; --output-file sets the base output path (without extension)
        cmd := '"' . exePath . '"'
        cmd .= ' -m "' . modelPath . '"'
        cmd .= ' -f "' . audioFilePath . '"'
        cmd .= ' --output-txt'
        cmd .= ' --output-file "' . outputBase . '"'
        cmd .= ' --no-prints'

        ; Wrap in cmd to capture errors and signal completion
        fullCmd := 'cmd.exe /c (' . cmd . ' 2>"' . errorFile . '" && echo done > "' . doneFile . '")'

        ; Run hidden
        try {
            shell := ComObject("WScript.Shell")
            shell.Run(fullCmd, 0, false)
        } catch as e {
            return {success: false, text: "", error: "Failed to start whisper-cli: " . e.Message}
        }

        ; Poll for completion - max 120 seconds (large files can take time)
        maxWait := 120000
        startTime := A_TickCount
        while !FileExist(doneFile) && (A_TickCount - startTime < maxWait) {
            Sleep(200)
        }

        if !FileExist(doneFile) {
            ; Check for error output
            if FileExist(errorFile) {
                try {
                    errText := Trim(FileRead(errorFile, "UTF-8"))
                    if errText
                        return {success: false, text: "", error: "Whisper error: " . SubStr(errText, 1, 300)}
                }
            }
            return {success: false, text: "", error: "Transcription timed out after 120 seconds"}
        }

        ; Read output text
        if !FileExist(outputTxt)
            return {success: false, text: "", error: "No transcription output produced"}

        try {
            transcription := Trim(FileRead(outputTxt, "UTF-8"))
        } catch as e {
            return {success: false, text: "", error: "Failed to read output: " . e.Message}
        }

        ; Clean up temp files
        try {
            FileDelete(doneFile)
            FileDelete(errorFile)
            FileDelete(outputTxt)
        }

        if transcription = ""
            return {success: false, text: "", error: "Empty transcription result"}

        return {success: true, text: transcription, error: ""}
    }

    /**
     * Test if whisper-cli.exe and model are available
     * @returns {success, error}
     */
    TestConnection() {
        exePath := this.GetExePath()
        modelPath := this.GetModelPath()

        if !FileExist(exePath)
            return {success: false, error: "whisper-cli.exe not found in bin/"}

        if !FileExist(modelPath)
            return {success: false, error: "Model not found: " . this.ModelFile}

        return {success: true, error: ""}
    }

    /**
     * Get available models by scanning bin/ directory for ggml-*.bin files
     * @returns {Array} Array of model filename strings
     */
    GetModels() {
        models := []
        pattern := this.BinDir "\ggml-*.bin"

        Loop Files pattern {
            models.Push(A_LoopFileName)
        }

        ; If no models found, return the configured one as placeholder
        if models.Length = 0
            models.Push(this.ModelFile)

        return models
    }
}
