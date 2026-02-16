#Requires AutoHotkey v2.0

/**
 * TTSFactory - Creates Text-to-Speech provider instances from config
 *
 * Supports:
 * - edge: Microsoft Edge TTS neural voices (default, free, requires internet)
 * - windows: Windows SAPI built-in voices (offline fallback)
 * - piper: Piper offline neural TTS (optional download)
 * - server: Remote TTS server (advanced)
 */
class TTSFactory {
    ; Engine display names for UI
    static EngineNames := Map(
        "edge", "Edge TTS (Natural Voices)",
        "windows", "Windows SAPI (Free)",
        "piper", "Piper (Offline)",
        "server", "TTS Server (Advanced)"
    )

    ; Engine keys in display order
    static EngineKeys := ["edge", "windows", "piper", "server"]

    /**
     * Create a TTS provider from config
     * @param {ConfigManager} config - Configuration manager instance
     * @returns {Object} TTS provider instance
     */
    static Create(config) {
        engine := config.Get("TTS", "DefaultEngine", "edge")

        switch engine {
            case "edge":
                voice := config.Get("TTS_Edge", "Voice", "en-GB-SoniaNeural")
                rate := config.Get("TTS_Edge", "Rate", "+0%")
                volume := config.Get("TTS_Edge", "Volume", "+0%")
                return TTSEdge(voice, rate, volume)

            case "piper":
                modelFile := config.Get("TTS_Piper", "Model", "")
                return TTSPiper(modelFile)

            case "server":
                serverUrl := config.Get("TTS_Server", "ServerUrl", "")
                ttsPath := config.Get("TTS_Server", "TTSPath", "/v1/audio/speech")
                voice := config.Get("TTS_Server", "Voice", "")
                return TTSServer(serverUrl, ttsPath, voice)

            default:
                ; "windows" or unknown - return TTSServer with no URL (uses SAPI fallback)
                return TTSServer("", "", "")
        }
    }

    /**
     * Check if a TTS engine is configured
     * @param {ConfigManager} config
     * @returns {boolean}
     */
    static IsConfigured(config) {
        engine := config.Get("TTS", "DefaultEngine", "edge")

        switch engine {
            case "edge":
                return true  ; Edge TTS always available (needs internet at runtime)

            case "piper":
                piper := TTSPiper(config.Get("TTS_Piper", "Model", ""))
                return FileExist(piper.GetExePath())

            case "server":
                serverUrl := config.Get("TTS_Server", "ServerUrl", "")
                return serverUrl != ""

            default:
                return true  ; Windows SAPI always available
        }
    }
}
