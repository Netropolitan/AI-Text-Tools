#Requires AutoHotkey v2.0

/**
 * VoiceTab - Speech settings (STT + TTS configuration)
 *
 * Combined tab for Speech-to-Text and Text-to-Speech settings.
 * STT engines: Whisper (Built-in), Whisper Server (Advanced)
 * TTS engines: Edge TTS, Windows SAPI, Piper (Offline), TTS Server (Advanced)
 */
class VoiceTab {
    static Controls := Map()
    static Config := ""

    ; Track dynamic control groups for show/hide
    static STTGroups := Map()  ; engine key -> array of controls
    static TTSGroups := Map()  ; engine key -> array of controls

    /**
     * Build Voice tab content
     * @param {Gui} settingsGui - Parent GUI
     * @param {ConfigManager} config - Config manager
     */
    static Build(settingsGui, config) {
        this.Config := config
        this.STTGroups := Map()
        this.TTSGroups := Map()
        y := 50
        x := 20

        ; === STT Section ===
        settingsGui.SetFont("Bold s11")
        settingsGui.Add("Text", "x" . x . " y" . y . " w500", "Speech-to-Text (STT)")
        settingsGui.SetFont("Norm s10")
        y += 25

        ; STT Engine dropdown
        settingsGui.Add("Text", "x" . x . " y" . y, "Engine:")
        engineNames := []
        for key in STTFactory.EngineKeys
            engineNames.Push(STTFactory.EngineNames[key])
        sttEngineDropdown := settingsGui.Add("DropDownList", "x" . (x+90) . " y" . (y-3) . " w250", engineNames)
        this.Controls["sttEngine"] := sttEngineDropdown

        ; Select current engine
        currentEngine := config.Get("STT", "DefaultEngine", "whisper_local")
        engineIndex := 1
        for i, key in STTFactory.EngineKeys {
            if key = currentEngine {
                engineIndex := i
                break
            }
        }
        sttEngineDropdown.Choose(engineIndex)
        sttEngineDropdown.OnEvent("Change", (*) => this.OnSTTEngineChange())

        ; STT Status text (shared)
        sttStatus := settingsGui.Add("Text", "x" . (x+350) . " y" . y . " w180 c666666", "")
        this.Controls["sttStatus"] := sttStatus
        y += 32

        ; All STT engine panels start at this Y position (only one visible at a time)
        sttPanelY := y

        ; --- Whisper Local controls ---
        this.STTGroups["whisper_local"] := []

        ctrl := settingsGui.Add("Text", "x" . x . " y" . sttPanelY, "Model:")
        this.STTGroups["whisper_local"].Push(ctrl)

        sttLocalModel := config.Get("STT_WhisperLocal", "Model", "ggml-tiny.en.bin")
        sttLocalModelDropdown := settingsGui.Add("DropDownList", "x" . (x+90) . " y" . (sttPanelY-3) . " w250", [sttLocalModel])
        sttLocalModelDropdown.Choose(1)
        this.Controls["sttLocalModel"] := sttLocalModelDropdown
        this.STTGroups["whisper_local"].Push(sttLocalModelDropdown)

        ; --- Whisper Server controls (same starting Y, taller panel) ---
        sttServerY := sttPanelY
        this.STTGroups["whisper"] := []

        ctrl := settingsGui.Add("Text", "x" . x . " y" . sttServerY, "Server URL:")
        this.STTGroups["whisper"].Push(ctrl)

        sttUrl := config.Get("STT_Whisper", "ServerUrl", "")
        sttUrlEdit := settingsGui.Add("Edit", "x" . (x+90) . " y" . (sttServerY-3) . " w250", sttUrl)
        this.Controls["sttUrl"] := sttUrlEdit
        this.STTGroups["whisper"].Push(sttUrlEdit)
        sttServerY += 28

        ctrl := settingsGui.Add("Text", "x" . x . " y" . sttServerY, "API Path:")
        this.STTGroups["whisper"].Push(ctrl)

        sttPath := config.Get("STT_Whisper", "TranscribePath", "/v1/audio/transcriptions")
        sttPathEdit := settingsGui.Add("Edit", "x" . (x+90) . " y" . (sttServerY-3) . " w250", sttPath)
        this.Controls["sttPath"] := sttPathEdit
        this.STTGroups["whisper"].Push(sttPathEdit)
        sttServerY += 28

        sttConnectBtn := settingsGui.Add("Button", "x" . x . " y" . sttServerY . " w150 h26", "Connect && Load Models")
        sttConnectBtn.OnEvent("Click", (*) => this.ConnectSTTServer())
        this.STTGroups["whisper"].Push(sttConnectBtn)

        ctrl := settingsGui.Add("Text", "x" . (x+160) . " y" . (sttServerY+4), "Model:")
        this.STTGroups["whisper"].Push(ctrl)

        sttServerModel := config.Get("STT_Whisper", "Model", "whisper-1")
        sttServerModelDropdown := settingsGui.Add("DropDownList", "x" . (x+200) . " y" . sttServerY . " w140", sttServerModel ? [sttServerModel] : ["whisper-1"])
        if sttServerModel
            sttServerModelDropdown.Choose(1)
        this.Controls["sttServerModel"] := sttServerModelDropdown
        this.STTGroups["whisper"].Push(sttServerModelDropdown)

        ; Advance Y past the tallest STT panel (whisper server: 3 rows × 28px = 84px)
        y := sttPanelY + 90

        ; Separator
        settingsGui.Add("Text", "x" . x . " y" . y . " w520 0x10")
        y += 12

        ; === TTS Section ===
        settingsGui.SetFont("Bold s11")
        settingsGui.Add("Text", "x" . x . " y" . y . " w500", "Text-to-Speech (TTS)")
        settingsGui.SetFont("Norm s10")
        y += 25

        ; TTS Engine dropdown
        settingsGui.Add("Text", "x" . x . " y" . y, "Engine:")
        ttsNames := []
        for key in TTSFactory.EngineKeys
            ttsNames.Push(TTSFactory.EngineNames[key])
        ttsEngineDropdown := settingsGui.Add("DropDownList", "x" . (x+90) . " y" . (y-3) . " w250", ttsNames)
        this.Controls["ttsEngine"] := ttsEngineDropdown

        currentTTSEngine := config.Get("TTS", "DefaultEngine", "edge")
        ttsIndex := 1
        for i, key in TTSFactory.EngineKeys {
            if key = currentTTSEngine {
                ttsIndex := i
                break
            }
        }
        ttsEngineDropdown.Choose(ttsIndex)
        ttsEngineDropdown.OnEvent("Change", (*) => this.OnTTSEngineChange())

        ; TTS Status text (shared)
        ttsStatus := settingsGui.Add("Text", "x" . (x+350) . " y" . y . " w180 c666666", "")
        this.Controls["ttsStatus"] := ttsStatus
        y += 32

        ; All TTS engine panels start at this Y position (only one visible at a time)
        ttsPanelY := y

        ; --- Edge TTS controls (2 rows: voice, rate/volume) ---
        this.TTSGroups["edge"] := []

        ctrl := settingsGui.Add("Text", "x" . x . " y" . ttsPanelY, "Voice:")
        this.TTSGroups["edge"].Push(ctrl)

        currentEdgeVoice := config.Get("TTS_Edge", "Voice", "en-GB-SoniaNeural")
        edgeVoiceDropdown := settingsGui.Add("DropDownList", "x" . (x+90) . " y" . (ttsPanelY-3) . " w250", currentEdgeVoice ? [currentEdgeVoice] : ["(Fetch voices)"])
        if currentEdgeVoice
            edgeVoiceDropdown.Choose(1)
        this.Controls["edgeVoice"] := edgeVoiceDropdown
        this.TTSGroups["edge"].Push(edgeVoiceDropdown)

        edgeFetchBtn := settingsGui.Add("Button", "x" . (x+350) . " y" . (ttsPanelY-4) . " w100 h26", "Fetch Voices")
        edgeFetchBtn.OnEvent("Click", (*) => this.FetchEdgeVoices())
        this.TTSGroups["edge"].Push(edgeFetchBtn)

        edgeRow2Y := ttsPanelY + 30

        ctrl := settingsGui.Add("Text", "x" . x . " y" . edgeRow2Y, "Rate:")
        this.TTSGroups["edge"].Push(ctrl)

        edgeRate := config.Get("TTS_Edge", "Rate", "+0%")
        edgeRateEdit := settingsGui.Add("Edit", "x" . (x+90) . " y" . (edgeRow2Y-3) . " w80", edgeRate)
        this.Controls["edgeRate"] := edgeRateEdit
        this.TTSGroups["edge"].Push(edgeRateEdit)

        ctrl := settingsGui.Add("Text", "x" . (x+180) . " y" . edgeRow2Y, "Volume:")
        this.TTSGroups["edge"].Push(ctrl)

        edgeVolume := config.Get("TTS_Edge", "Volume", "+0%")
        edgeVolumeEdit := settingsGui.Add("Edit", "x" . (x+240) . " y" . (edgeRow2Y-3) . " w80", edgeVolume)
        this.Controls["edgeVolume"] := edgeVolumeEdit
        this.TTSGroups["edge"].Push(edgeVolumeEdit)

        edgeTestBtn := settingsGui.Add("Button", "x" . (x+350) . " y" . (edgeRow2Y-4) . " w100 h26", "Test Voice")
        edgeTestBtn.OnEvent("Click", (*) => this.TestEdgeVoice())
        this.TTSGroups["edge"].Push(edgeTestBtn)

        ; --- Windows SAPI controls (1 row, same starting Y) ---
        this.TTSGroups["windows"] := []

        ctrl := settingsGui.Add("Text", "x" . x . " y" . ttsPanelY, "Voice:")
        this.TTSGroups["windows"].Push(ctrl)

        sapiVoiceDropdown := settingsGui.Add("DropDownList", "x" . (x+90) . " y" . (ttsPanelY-3) . " w250", ["(Loading...)"])
        this.Controls["sapiVoice"] := sapiVoiceDropdown
        this.TTSGroups["windows"].Push(sapiVoiceDropdown)

        sapiTestBtn := settingsGui.Add("Button", "x" . (x+350) . " y" . (ttsPanelY-4) . " w100 h26", "Test Voice")
        sapiTestBtn.OnEvent("Click", (*) => this.TestSAPIVoice())
        this.TTSGroups["windows"].Push(sapiTestBtn)

        ; --- Piper controls (1 row, same starting Y) ---
        this.TTSGroups["piper"] := []

        ctrl := settingsGui.Add("Text", "x" . x . " y" . ttsPanelY, "Model:")
        this.TTSGroups["piper"].Push(ctrl)

        piperModel := config.Get("TTS_Piper", "Model", "")
        piperModelName := piperModel ? this.GetFileName(piperModel) : "(No model)"
        piperModelDropdown := settingsGui.Add("DropDownList", "x" . (x+90) . " y" . (ttsPanelY-3) . " w250", [piperModelName])
        if piperModelName != "(No model)"
            piperModelDropdown.Choose(1)
        this.Controls["piperModel"] := piperModelDropdown
        this.TTSGroups["piper"].Push(piperModelDropdown)

        piperDownloadBtn := settingsGui.Add("Button", "x" . (x+350) . " y" . (ttsPanelY-4) . " w100 h26", "Download Piper")
        piperDownloadBtn.OnEvent("Click", (*) => this.DownloadPiper())
        this.TTSGroups["piper"].Push(piperDownloadBtn)

        ; --- TTS Server controls (3 rows, same starting Y) ---
        ttsServerY := ttsPanelY
        this.TTSGroups["server"] := []

        ctrl := settingsGui.Add("Text", "x" . x . " y" . ttsServerY, "Server URL:")
        this.TTSGroups["server"].Push(ctrl)

        ttsUrl := config.Get("TTS_Server", "ServerUrl", "")
        ttsUrlEdit := settingsGui.Add("Edit", "x" . (x+90) . " y" . (ttsServerY-3) . " w250", ttsUrl)
        this.Controls["ttsUrl"] := ttsUrlEdit
        this.TTSGroups["server"].Push(ttsUrlEdit)
        ttsServerY += 28

        ctrl := settingsGui.Add("Text", "x" . x . " y" . ttsServerY, "API Path:")
        this.TTSGroups["server"].Push(ctrl)

        ttsPath := config.Get("TTS_Server", "TTSPath", "/v1/audio/speech")
        ttsPathEdit := settingsGui.Add("Edit", "x" . (x+90) . " y" . (ttsServerY-3) . " w250", ttsPath)
        this.Controls["ttsPath"] := ttsPathEdit
        this.TTSGroups["server"].Push(ttsPathEdit)
        ttsServerY += 28

        ttsConnectBtn := settingsGui.Add("Button", "x" . x . " y" . ttsServerY . " w150 h26", "Connect && Load Voices")
        ttsConnectBtn.OnEvent("Click", (*) => this.ConnectTTSServer())
        this.TTSGroups["server"].Push(ttsConnectBtn)

        ctrl := settingsGui.Add("Text", "x" . (x+160) . " y" . (ttsServerY+4), "Voice:")
        this.TTSGroups["server"].Push(ctrl)

        ttsServerVoice := config.Get("TTS_Server", "Voice", "")
        ttsServerVoiceDropdown := settingsGui.Add("DropDownList", "x" . (x+200) . " y" . ttsServerY . " w140", ttsServerVoice ? [ttsServerVoice] : ["(Connect to load)"])
        if ttsServerVoice
            ttsServerVoiceDropdown.Choose(1)
        this.Controls["ttsServerVoice"] := ttsServerVoiceDropdown
        ttsServerVoiceDropdown.OnEvent("Change", (*) => this.OnServerVoiceSelect())
        this.TTSGroups["server"].Push(ttsServerVoiceDropdown)

        ttsServerTestBtn := settingsGui.Add("Button", "x" . (x+350) . " y" . ttsServerY . " w90 h26", "Test Voice")
        ttsServerTestBtn.OnEvent("Click", (*) => this.TestServerVoice())
        this.TTSGroups["server"].Push(ttsServerTestBtn)

        ; Apply initial visibility
        this.OnSTTEngineChange()
        this.OnTTSEngineChange()

        ; Auto-load data based on current engine
        SetTimer(() => this.AutoLoadEngineData(), -500)
    }

    ; ==================== Helpers ====================

    /**
     * Extract filename from full path
     */
    static GetFileName(path) {
        SplitPath(path, &name)
        return name
    }

    ; ==================== Engine Switching ====================

    /**
     * Show/hide STT controls based on selected engine
     */
    static OnSTTEngineChange() {
        try {
            dropdown := this.Controls["sttEngine"]
            selectedIndex := dropdown.Value
        } catch {
            return
        }

        if selectedIndex < 1
            return

        selectedKey := STTFactory.EngineKeys[selectedIndex]

        ; Hide all STT groups
        for key, controls in this.STTGroups {
            for ctrl in controls
                ctrl.Visible := false
        }

        ; Show selected group
        if this.STTGroups.Has(selectedKey) {
            for ctrl in this.STTGroups[selectedKey]
                ctrl.Visible := true
        }

        ; Update status
        this.UpdateSTTStatus(selectedKey)
    }

    /**
     * Show/hide TTS controls based on selected engine
     */
    static OnTTSEngineChange() {
        try {
            dropdown := this.Controls["ttsEngine"]
            selectedIndex := dropdown.Value
        } catch {
            return
        }

        if selectedIndex < 1
            return

        selectedKey := TTSFactory.EngineKeys[selectedIndex]

        ; Hide all TTS groups
        for key, controls in this.TTSGroups {
            for ctrl in controls
                ctrl.Visible := false
        }

        ; Show selected group
        if this.TTSGroups.Has(selectedKey) {
            for ctrl in this.TTSGroups[selectedKey]
                ctrl.Visible := true
        }

        ; Update status
        this.UpdateTTSStatus(selectedKey)
    }

    /**
     * Update STT status indicator
     */
    static UpdateSTTStatus(engine) {
        try statusCtrl := this.Controls["sttStatus"]
        catch
            return

        switch engine {
            case "whisper_local":
                stt := STTWhisperLocal(this.Config.Get("STT_WhisperLocal", "Model", "ggml-tiny.en.bin"))
                test := stt.TestConnection()
                if test.success {
                    statusCtrl.Opt("c00AA00")
                    statusCtrl.Text := "Ready"
                } else {
                    statusCtrl.Opt("cCC0000")
                    statusCtrl.Text := "Not installed"
                }

            case "whisper":
                url := this.Config.Get("STT_Whisper", "ServerUrl", "")
                if url {
                    statusCtrl.Opt("c666666")
                    statusCtrl.Text := "Click Connect"
                } else {
                    statusCtrl.Opt("c888888")
                    statusCtrl.Text := "Enter server URL"
                }
        }
    }

    /**
     * Update TTS status indicator
     */
    static UpdateTTSStatus(engine) {
        try statusCtrl := this.Controls["ttsStatus"]
        catch
            return

        switch engine {
            case "edge":
                statusCtrl.Opt("c00AA00")
                statusCtrl.Text := "Internet required"

            case "windows":
                statusCtrl.Opt("c00AA00")
                statusCtrl.Text := "Built-in"

            case "piper":
                piper := TTSPiper()
                if FileExist(piper.GetExePath()) {
                    statusCtrl.Opt("c00AA00")
                    statusCtrl.Text := "Installed"
                } else {
                    statusCtrl.Opt("cCC8800")
                    statusCtrl.Text := "Not installed"
                }

            case "server":
                url := this.Config.Get("TTS_Server", "ServerUrl", "")
                if url {
                    statusCtrl.Opt("c666666")
                    statusCtrl.Text := "Click Connect"
                } else {
                    statusCtrl.Opt("c888888")
                    statusCtrl.Text := "Enter server URL"
                }
        }
    }

    /**
     * Auto-load engine data on tab open
     */
    static AutoLoadEngineData() {
        ; Load STT models for whisper local
        try {
            stt := STTWhisperLocal(this.Config.Get("STT_WhisperLocal", "Model", "ggml-tiny.en.bin"))
            models := stt.GetModels()
            if models.Length > 0 {
                modelDropdown := this.Controls["sttLocalModel"]
                modelDropdown.Delete()
                modelDropdown.Add(models)
                currentModel := this.Config.Get("STT_WhisperLocal", "Model", "ggml-tiny.en.bin")
                foundIdx := 0
                for i, m in models {
                    if m = currentModel {
                        foundIdx := i
                        break
                    }
                }
                modelDropdown.Choose(foundIdx > 0 ? foundIdx : 1)
            }
        }

        ; Load SAPI voices
        this.LoadSAPIVoices()

        ; Load Piper models
        this.LoadPiperModels()
    }

    ; ==================== Edge TTS ====================

    /**
     * Fetch Edge TTS voice list
     */
    static FetchEdgeVoices() {
        try {
            statusCtrl := this.Controls["ttsStatus"]
            voiceDropdown := this.Controls["edgeVoice"]
        } catch {
            return
        }

        statusCtrl.Opt("c666666")
        statusCtrl.Text := "Fetching voices..."

        voices := TTSEdge.FetchVoiceList("")

        try {
            voiceDropdown.Delete()

            if voices.Length > 0 {
                voiceNames := []
                for v in voices
                    voiceNames.Push(v.shortName)

                voiceDropdown.Add(voiceNames)

                ; Try to select current voice
                currentVoice := this.Config.Get("TTS_Edge", "Voice", "en-GB-SoniaNeural")
                foundIdx := 0
                for i, name in voiceNames {
                    if name = currentVoice {
                        foundIdx := i
                        break
                    }
                }
                voiceDropdown.Choose(foundIdx > 0 ? foundIdx : 1)

                statusCtrl.Opt("c00AA00")
                statusCtrl.Text := voices.Length . " voices loaded"
            } else {
                voiceDropdown.Add(["(No voices found)"])
                statusCtrl.Opt("cCC0000")
                statusCtrl.Text := "Failed to fetch voices"
            }
        } catch {
            ; Window closed
        }
    }

    /**
     * Test Edge TTS voice
     */
    static TestEdgeVoice() {
        try {
            voiceDropdown := this.Controls["edgeVoice"]
            rateEdit := this.Controls["edgeRate"]
            volumeEdit := this.Controls["edgeVolume"]
        } catch {
            return
        }

        voice := voiceDropdown.Text
        if !voice || voice = "(Fetch voices)" || voice = "(No voices found)" {
            ToolTip("Select a voice first")
            SetTimer(() => ToolTip(), -2000)
            return
        }

        tts := TTSEdge(voice, rateEdit.Value, volumeEdit.Value)

        ToolTip("Testing voice: " . voice)
        result := tts.Speak("Hello, this is a test of the Edge text to speech system.")
        ToolTip()

        if !result.success
            MsgBox("Voice test failed:`n`n" . result.error, "Test Voice", "Icon!")
    }

    ; ==================== Windows SAPI ====================

    /**
     * Load Windows SAPI voices
     */
    static LoadSAPIVoices() {
        try {
            voiceDropdown := this.Controls["sapiVoice"]
        } catch {
            return
        }

        tts := TTSServer()
        voices := tts.GetSAPIVoices()

        try {
            voiceDropdown.Delete()

            if voices.Length > 0 {
                voiceDropdown.Add(voices)
                currentVoice := this.Config.Get("TTS_Server", "Voice", "")
                foundIndex := 0
                for i, v in voices {
                    if v = currentVoice {
                        foundIndex := i
                        break
                    }
                }
                voiceDropdown.Choose(foundIndex > 0 ? foundIndex : 1)
            } else {
                voiceDropdown.Add(["(No voices available)"])
            }
        } catch {
            ; Window closed
        }
    }

    /**
     * Test SAPI voice
     */
    static TestSAPIVoice() {
        try {
            voiceDropdown := this.Controls["sapiVoice"]
        } catch {
            return
        }

        voice := voiceDropdown.Text
        if !voice || voice = "(No voices available)" || voice = "(Loading...)" {
            ToolTip("No voice available")
            SetTimer(() => ToolTip(), -2000)
            return
        }

        ToolTip("Testing voice: " . voice)
        tts := TTSServer()
        result := tts.SpeakWithSAPI("Hello, this is a test of the Windows text to speech system.")
        ToolTip()

        if !result.success
            MsgBox("Voice test failed:`n`n" . result.error, "Test Voice", "Icon!")
    }

    ; ==================== Piper ====================

    /**
     * Load available Piper models
     */
    static LoadPiperModels() {
        try {
            modelDropdown := this.Controls["piperModel"]
        } catch {
            return
        }

        piper := TTSPiper()
        voices := piper.GetVoices()

        try {
            modelDropdown.Delete()

            if voices.Length > 0 {
                names := []
                for v in voices
                    names.Push(this.GetFileName(v))
                modelDropdown.Add(names)

                currentModel := this.Config.Get("TTS_Piper", "Model", "")
                if currentModel {
                    currentName := this.GetFileName(currentModel)
                    foundIdx := 0
                    for i, n in names {
                        if n = currentName {
                            foundIdx := i
                            break
                        }
                    }
                    modelDropdown.Choose(foundIdx > 0 ? foundIdx : 1)
                } else if names.Length > 0 {
                    modelDropdown.Choose(1)
                }
            } else {
                modelDropdown.Add(["(No models found)"])
            }
        } catch {
            ; Window closed
        }
    }

    /**
     * Open Piper download page
     */
    static DownloadPiper() {
        try Run("https://github.com/rhasspy/piper/releases")
        MsgBox("Download piper_windows_amd64.zip and extract piper.exe to the bin\ folder.`n`nThen download a voice model (.onnx + .onnx.json) from:`nhttps://github.com/rhasspy/piper/blob/master/VOICES.md`n`nPlace model files in bin\piper-models\", "Download Piper", "Iconi")
    }

    ; ==================== TTS Server ====================

    /**
     * Connect to TTS server and fetch voices
     */
    static ConnectTTSServer() {
        try {
            urlCtrl := this.Controls["ttsUrl"]
            statusCtrl := this.Controls["ttsStatus"]
            voiceDropdown := this.Controls["ttsServerVoice"]
            pathCtrl := this.Controls["ttsPath"]
            serverUrl := urlCtrl.Value
            ttsPath := pathCtrl.Value
        } catch {
            return
        }

        if !serverUrl {
            try {
                statusCtrl.Opt("cCC0000")
                statusCtrl.Text := "Enter a server URL"
            }
            return
        }

        try statusCtrl.Text := "Connecting..."

        this.Config.Set("TTS_Server", "ServerUrl", serverUrl)
        this.Config.Set("TTS_Server", "TTSPath", ttsPath)

        tts := TTSServer(serverUrl, ttsPath)
        testResult := tts.TestConnection()

        if !testResult.success {
            try {
                statusCtrl.Opt("cCC0000")
                statusCtrl.Text := testResult.error
            }
            return
        }

        voices := tts.FetchVoices()

        try {
            voiceDropdown.Delete()

            if voices.Length > 0 {
                voiceDropdown.Add(voices)
                currentVoice := this.Config.Get("TTS_Server", "Voice", "")
                foundIndex := 0
                for i, v in voices {
                    if v = currentVoice {
                        foundIndex := i
                        break
                    }
                }
                voiceDropdown.Choose(foundIndex > 0 ? foundIndex : 1)
                statusCtrl.Opt("c00AA00")
                statusCtrl.Text := "Connected - " . voices.Length . " voices"
            } else {
                statusCtrl.Opt("cCC8800")
                statusCtrl.Text := "Connected, no voices found"
            }
        } catch {
            ; Window closed
        }
    }

    /**
     * Handle server voice selection
     */
    static OnServerVoiceSelect() {
        voiceDropdown := this.Controls["ttsServerVoice"]
        if voiceDropdown.Value > 0
            this.Config.Set("TTS_Server", "Voice", voiceDropdown.Text)
    }

    /**
     * Test the selected server voice
     */
    static TestServerVoice() {
        try {
            voiceDropdown := this.Controls["ttsServerVoice"]
            urlCtrl := this.Controls["ttsUrl"]
            pathCtrl := this.Controls["ttsPath"]
        } catch {
            return
        }

        voice := voiceDropdown.Text
        if !voice || voice = "(Connect to load)" {
            ToolTip("Select a voice first")
            SetTimer(() => ToolTip(), -2000)
            return
        }

        tts := TTSServer(urlCtrl.Value, pathCtrl.Value, voice)

        ToolTip("Testing voice: " . voice)
        result := tts.Speak("Hello, this is a test of the text to speech system.")
        ToolTip()

        if !result.success
            MsgBox("Voice test failed:`n`n" . result.error, "Test Voice", "Icon!")
    }

    ; ==================== STT Server ====================

    /**
     * Connect to STT server and fetch models
     */
    static ConnectSTTServer() {
        try {
            urlCtrl := this.Controls["sttUrl"]
            statusCtrl := this.Controls["sttStatus"]
            modelDropdown := this.Controls["sttServerModel"]
            pathCtrl := this.Controls["sttPath"]
            serverUrl := urlCtrl.Value
            transcribePath := pathCtrl.Value
        } catch {
            return
        }

        if !serverUrl {
            try {
                statusCtrl.Opt("cCC0000")
                statusCtrl.Text := "Enter a server URL"
            }
            return
        }

        try statusCtrl.Text := "Connecting..."

        this.Config.Set("STT_Whisper", "ServerUrl", serverUrl)
        this.Config.Set("STT_Whisper", "TranscribePath", transcribePath)

        stt := STTWhisper(serverUrl, transcribePath)
        testResult := stt.TestConnection()

        if !testResult.success {
            try {
                statusCtrl.Opt("cCC0000")
                statusCtrl.Text := testResult.error
            }
            return
        }

        models := stt.GetModels()

        try {
            modelDropdown.Delete()

            if models.Length > 0 {
                modelDropdown.Add(models)
                currentModel := this.Config.Get("STT_Whisper", "Model", "whisper-1")
                foundIndex := 0
                for i, m in models {
                    if m = currentModel {
                        foundIndex := i
                        break
                    }
                }
                modelDropdown.Choose(foundIndex > 0 ? foundIndex : 1)
                statusCtrl.Opt("c00AA00")
                statusCtrl.Text := "Connected - " . models.Length . " models"
            } else {
                modelDropdown.Add(["whisper-1"])
                modelDropdown.Choose(1)
                statusCtrl.Opt("c00AA00")
                statusCtrl.Text := "Connected"
            }
        } catch {
            ; Window closed
        }
    }

    ; ==================== Save ====================

    /**
     * Save all speech settings
     */
    static SaveAll() {
        ; Save STT engine selection
        if this.Controls.Has("sttEngine") {
            sttIdx := this.Controls["sttEngine"].Value
            if sttIdx > 0
                this.Config.Set("STT", "DefaultEngine", STTFactory.EngineKeys[sttIdx])
        }

        ; Save STT Whisper Local settings
        if this.Controls.Has("sttLocalModel") {
            modelDropdown := this.Controls["sttLocalModel"]
            if modelDropdown.Value > 0
                this.Config.Set("STT_WhisperLocal", "Model", modelDropdown.Text)
        }

        ; Save STT Whisper Server settings
        if this.Controls.Has("sttUrl")
            this.Config.Set("STT_Whisper", "ServerUrl", this.Controls["sttUrl"].Value)
        if this.Controls.Has("sttPath")
            this.Config.Set("STT_Whisper", "TranscribePath", this.Controls["sttPath"].Value)
        if this.Controls.Has("sttServerModel") {
            modelDropdown := this.Controls["sttServerModel"]
            if modelDropdown.Value > 0
                this.Config.Set("STT_Whisper", "Model", modelDropdown.Text)
        }

        ; Save TTS engine selection
        if this.Controls.Has("ttsEngine") {
            ttsIdx := this.Controls["ttsEngine"].Value
            if ttsIdx > 0
                this.Config.Set("TTS", "DefaultEngine", TTSFactory.EngineKeys[ttsIdx])
        }

        ; Save Edge TTS settings
        if this.Controls.Has("edgeVoice") {
            voiceDropdown := this.Controls["edgeVoice"]
            if voiceDropdown.Value > 0 {
                voiceText := voiceDropdown.Text
                if voiceText != "(Fetch voices)" && voiceText != "(No voices found)"
                    this.Config.Set("TTS_Edge", "Voice", voiceText)
            }
        }
        if this.Controls.Has("edgeRate")
            this.Config.Set("TTS_Edge", "Rate", this.Controls["edgeRate"].Value)
        if this.Controls.Has("edgeVolume")
            this.Config.Set("TTS_Edge", "Volume", this.Controls["edgeVolume"].Value)

        ; Save SAPI voice (stored in TTS_Server.Voice for backwards compat when engine=windows)
        if this.Controls.Has("sapiVoice") {
            voiceDropdown := this.Controls["sapiVoice"]
            if voiceDropdown.Value > 0 {
                voiceText := voiceDropdown.Text
                if voiceText != "(No voices available)" && voiceText != "(Loading...)"
                    this.Config.Set("TTS_Windows", "Voice", voiceText)
            }
        }

        ; Save Piper settings
        if this.Controls.Has("piperModel") {
            modelDropdown := this.Controls["piperModel"]
            if modelDropdown.Value > 0 {
                modelText := modelDropdown.Text
                if modelText != "(No models found)" {
                    ; Reconstruct full path
                    piper := TTSPiper()
                    voices := piper.GetVoices()
                    for v in voices {
                        if InStr(v, modelText) {
                            this.Config.Set("TTS_Piper", "Model", v)
                            break
                        }
                    }
                }
            }
        }

        ; Save TTS Server settings
        if this.Controls.Has("ttsUrl")
            this.Config.Set("TTS_Server", "ServerUrl", this.Controls["ttsUrl"].Value)
        if this.Controls.Has("ttsPath")
            this.Config.Set("TTS_Server", "TTSPath", this.Controls["ttsPath"].Value)
        if this.Controls.Has("ttsServerVoice") {
            voiceDropdown := this.Controls["ttsServerVoice"]
            if voiceDropdown.Value > 0 {
                voiceText := voiceDropdown.Text
                if voiceText != "(Connect to load)"
                    this.Config.Set("TTS_Server", "Voice", voiceText)
            }
        }
    }
}
