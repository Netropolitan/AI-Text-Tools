#Requires AutoHotkey v2.0

/**
 * STTFactory - Creates Speech-to-Text provider instances from config
 *
 * Supports:
 * - whisper_local: Local whisper.cpp executable (default, fully offline)
 * - whisper: Remote Whisper-compatible server (advanced)
 */
class STTFactory {
    ; Engine display names for UI
    static EngineNames := Map(
        "whisper_local", "Whisper (Built-in)",
        "whisper", "Whisper Server (Advanced)"
    )

    ; Engine keys in display order
    static EngineKeys := ["whisper_local", "whisper"]

    /**
     * Create an STT provider from config
     * @param {ConfigManager} config - Configuration manager instance
     * @returns {Object} STT provider instance
     */
    static Create(config) {
        engine := config.Get("STT", "DefaultEngine", "whisper_local")

        switch engine {
            case "whisper_local":
                model := config.Get("STT_WhisperLocal", "Model", "ggml-tiny.en.bin")
                return STTWhisperLocal(model)

            case "whisper":
                serverUrl := config.Get("STT_Whisper", "ServerUrl", "")
                transcribePath := config.Get("STT_Whisper", "TranscribePath", "/v1/audio/transcriptions")
                model := config.Get("STT_Whisper", "Model", "whisper-1")
                return STTWhisper(serverUrl, transcribePath, model)

            default:
                ; Unknown engine - return whisper local as safe default
                model := config.Get("STT_WhisperLocal", "Model", "ggml-tiny.en.bin")
                return STTWhisperLocal(model)
        }
    }

    /**
     * Check if STT is configured
     * @param {ConfigManager} config
     * @returns {boolean}
     */
    static IsConfigured(config) {
        engine := config.Get("STT", "DefaultEngine", "whisper_local")

        switch engine {
            case "whisper_local":
                stt := STTWhisperLocal(config.Get("STT_WhisperLocal", "Model", "ggml-tiny.en.bin"))
                return stt.TestConnection().success

            case "whisper":
                serverUrl := config.Get("STT_Whisper", "ServerUrl", "")
                return serverUrl != ""

            default:
                return true
        }
    }
}
