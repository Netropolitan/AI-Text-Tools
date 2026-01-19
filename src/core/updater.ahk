#Requires AutoHotkey v2.0

/**
 * UpdateManager - Handles version checking, auto-updates, and usage analytics
 *
 * Features:
 * - GitHub Releases API for update checking
 * - Automatic monthly update check (1st of month at 2pm, or next online day)
 * - Anonymous usage analytics for active user counting
 */
class UpdateManager {
    static GitHubRepo := "Netropolitan/AI-Text-Tools"
    static GitHubAPI := "https://api.github.com/repos/" . UpdateManager.GitHubRepo . "/releases/latest"
    static CurrentVersion := "1.4.1"

    ; Analytics endpoint - Set to empty string "" to disable analytics
    static AnalyticsEndpoint := "https://brew.taila07ff3.ts.net/api/ping"

    ; Application identifier for multi-app analytics
    static AppName := "AI-Text-Tools"

    ; Cached update info
    static LatestVersion := ""
    static DownloadUrl := ""
    static ReleaseNotes := ""
    static LastCheckTime := 0

    /**
     * Initialize and run automatic monthly check if due
     * Call this from main.ahk on startup
     * @param {ConfigManager} config - The app config manager
     * @param {bool} isFirstLaunch - Whether this is the first time the app has launched
     */
    static InitializeAutoCheck(config, isFirstLaunch := false) {
        ; Check if auto-update is enabled (default: true)
        autoUpdateEnabled := config.Get("Updates", "AutoCheck", "1") = "1"
        if !autoUpdateEnabled
            return

        ; Get last auto-check date
        lastCheckStr := config.Get("Updates", "LastAutoCheck", "")

        ; Get current date/time
        currentYear := A_Year
        currentMonth := A_Mon
        currentDay := A_MDay
        currentHour := A_Hour

        ; Determine if we should check:
        ; - It's the 1st (or later) of the month
        ; - It's 2pm (14:00) or later
        ; - We haven't checked this month yet

        shouldCheck := false
        currentMonthKey := currentYear . "-" . Format("{:02}", currentMonth)

        if lastCheckStr = "" {
            ; Never checked before - check now
            shouldCheck := true
        } else {
            ; Parse last check (format: YYYY-MM)
            if lastCheckStr != currentMonthKey {
                ; Haven't checked this month
                if currentDay >= 1 {
                    if currentDay = 1 {
                        ; It's the 1st - only check if past 2pm
                        if currentHour >= 14
                            shouldCheck := true
                    } else {
                        ; Past the 1st - check now (user was offline on the 1st)
                        shouldCheck := true
                    }
                }
            }
        }

        if shouldCheck {
            ; Run check in background (don't block startup)
            SetTimer(() => this.DoAutoCheck(config), -5000)  ; 5 second delay
        }

        ; Also send analytics ping if enabled
        analyticsEnabled := config.Get("Updates", "Analytics", "1") = "1"
        if analyticsEnabled && this.AnalyticsEndpoint != "" {
            eventType := isFirstLaunch ? "install" : "startup"
            SetTimer(() => this.SendAnalyticsPing(config, eventType), -10000)  ; 10 second delay
        }
    }

    /**
     * Perform automatic background update check
     */
    static DoAutoCheck(config) {
        result := this.CheckForUpdates()

        ; Save that we checked this month
        currentMonthKey := A_Year . "-" . Format("{:02}", A_Mon)
        config.Set("Updates", "LastAutoCheck", currentMonthKey)

        ; If update available, notify user via tray
        if result.available {
            TrayTip("Update Available", "AI Text Tools v" . result.version . " is available. Open Settings to update.", 1)
        }
    }

    /**
     * Send anonymous analytics ping
     * Data sent: app_name, install_id, version, timestamp, os, event
     * @param {ConfigManager} config - The app config manager
     * @param {string} eventType - Event type: "install" for first launch, "startup" for subsequent launches
     */
    static SendAnalyticsPing(config, eventType := "startup") {
        if this.AnalyticsEndpoint = ""
            return

        try {
            ; Get or create anonymous install ID
            installId := config.Get("Updates", "InstallId", "")
            if installId = "" {
                installId := this.GenerateInstallId()
                config.Set("Updates", "InstallId", installId)
            }

            ; Build payload
            payload := '{'
            payload .= '"app_name":"' . this.AppName . '",'
            payload .= '"install_id":"' . installId . '",'
            payload .= '"version":"' . this.CurrentVersion . '",'
            payload .= '"timestamp":"' . FormatTime(, "yyyy-MM-ddTHH:mm:ssZ") . '",'
            payload .= '"os":"Windows",'
            payload .= '"event":"' . eventType . '"'
            payload .= '}'

            ; Send to analytics endpoint
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("POST", this.AnalyticsEndpoint, true)
            whr.SetRequestHeader("Content-Type", "application/json")
            whr.SetRequestHeader("User-Agent", "AI-Text-Tools/" . this.CurrentVersion)
            whr.SetTimeouts(5000, 5000, 5000, 5000)
            whr.Send(payload)
            whr.WaitForResponse(5)

            ; Silent - we don't care about the response
        } catch {
            ; Silent fail - analytics should never interrupt the user
        }
    }

    /**
     * Generate a unique anonymous install ID (UUID v4 format)
     */
    static GenerateInstallId() {
        chars := "0123456789abcdef"
        id := ""

        ; Generate UUID format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
        Loop 36 {
            if A_Index = 9 || A_Index = 14 || A_Index = 19 || A_Index = 24
                id .= "-"
            else if A_Index = 15
                id .= "4"  ; Version 4
            else if A_Index = 20
                id .= SubStr("89ab", Random(1, 4), 1)  ; Variant
            else
                id .= SubStr(chars, Random(1, 16), 1)
        }

        return id
    }

    /**
     * Get the current install ID (for display in About tab)
     */
    static GetInstallId(config) {
        return config.Get("Updates", "InstallId", "Not generated")
    }

    /**
     * Check for updates from GitHub
     * @returns {Object} {available: bool, version: string, error: string}
     */
    static CheckForUpdates() {
        try {
            ; Make request to GitHub API
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("GET", this.GitHubAPI, true)
            whr.SetRequestHeader("User-Agent", "AI-Text-Tools/" . this.CurrentVersion)
            whr.SetTimeouts(10000, 10000, 10000, 10000)
            whr.Send()
            whr.WaitForResponse(10)

            if whr.Status = 404 {
                return {available: false, version: "", error: "No releases found. Publish a release on GitHub first."}
            }
            if whr.Status != 200 {
                return {available: false, version: "", error: "GitHub API returned status " . whr.Status}
            }

            ; Parse JSON response
            response := whr.ResponseText
            data := JSON.Load(response)

            if !data || !data.Has("tag_name") {
                return {available: false, version: "", error: "Invalid response from GitHub"}
            }

            ; Extract version (remove 'v' prefix if present)
            latestVersion := data["tag_name"]
            if SubStr(latestVersion, 1, 1) = "v"
                latestVersion := SubStr(latestVersion, 2)

            this.LatestVersion := latestVersion
            this.LastCheckTime := A_TickCount

            ; Get release notes
            if data.Has("body")
                this.ReleaseNotes := data["body"]

            ; Find download URL for setup exe
            if data.Has("assets") {
                for asset in data["assets"] {
                    if asset.Has("name") && InStr(asset["name"], "Setup.exe") {
                        this.DownloadUrl := asset["browser_download_url"]
                        break
                    }
                }
                ; Fallback to first exe if no Setup found
                if this.DownloadUrl = "" {
                    for asset in data["assets"] {
                        if asset.Has("name") && InStr(asset["name"], ".exe") {
                            this.DownloadUrl := asset["browser_download_url"]
                            break
                        }
                    }
                }
            }

            ; Compare versions
            if this.CompareVersions(latestVersion, this.CurrentVersion) > 0 {
                return {available: true, version: latestVersion, error: ""}
            } else {
                return {available: false, version: latestVersion, error: ""}
            }

        } catch as e {
            return {available: false, version: "", error: "Check failed: " . e.Message}
        }
    }

    /**
     * Compare two version strings
     * @param {string} v1 - First version (e.g., "1.4.1")
     * @param {string} v2 - Second version (e.g., "1.3.0")
     * @returns {int} 1 if v1 > v2, -1 if v1 < v2, 0 if equal
     */
    static CompareVersions(v1, v2) {
        ; Strip any non-numeric suffixes (e.g., "-beta", "-rc1")
        v1 := RegExReplace(v1, "-.*$", "")
        v2 := RegExReplace(v2, "-.*$", "")

        parts1 := StrSplit(v1, ".")
        parts2 := StrSplit(v2, ".")

        ; Pad arrays to same length
        while parts1.Length < 3
            parts1.Push("0")
        while parts2.Length < 3
            parts2.Push("0")

        ; Compare each part
        Loop 3 {
            ; Extract only numeric portion from each part
            n1 := this.ParseVersionPart(parts1[A_Index])
            n2 := this.ParseVersionPart(parts2[A_Index])
            if n1 > n2
                return 1
            if n1 < n2
                return -1
        }

        return 0
    }

    /**
     * Parse a version part, extracting only the numeric portion
     * @param {string} part - Version part (e.g., "1", "4", "1-beta")
     * @returns {int} Numeric value, or 0 if not parseable
     */
    static ParseVersionPart(part) {
        ; Extract leading digits only
        if RegExMatch(part, "^(\d+)", &match)
            return Integer(match[1])
        return 0
    }

    /**
     * Download update to temp folder
     * @param {Function} progressCallback - Optional callback(percent, status)
     * @returns {Object} {success: bool, path: string, error: string}
     */
    static DownloadUpdate(progressCallback := "") {
        if this.DownloadUrl = "" {
            return {success: false, path: "", error: "No download URL available"}
        }

        try {
            ; Create temp path
            tempPath := A_Temp . "\AITextTools-Setup-" . this.LatestVersion . ".exe"

            ; Delete if exists
            if FileExist(tempPath)
                FileDelete(tempPath)

            if progressCallback
                progressCallback(0, "Connecting...")

            ; Download file
            Download(this.DownloadUrl, tempPath)

            if progressCallback
                progressCallback(100, "Download complete")

            if FileExist(tempPath) {
                return {success: true, path: tempPath, error: ""}
            } else {
                return {success: false, path: "", error: "Download failed - file not created"}
            }

        } catch as e {
            return {success: false, path: "", error: "Download failed: " . e.Message}
        }
    }

    /**
     * Install downloaded update
     * @param {string} installerPath - Path to downloaded installer
     */
    static InstallUpdate(installerPath) {
        if !FileExist(installerPath) {
            MsgBox("Installer not found at: " . installerPath, "Update Error", "IconX")
            return
        }

        ; Get current install directory to pass to installer
        installDir := ""
        if A_IsCompiled {
            installDir := A_ScriptDir
        }

        try {
            ; Launch installer with upgrade flag
            if installDir != "" {
                Run('"' . installerPath . '" /upgrade "' . installDir . '"')
            } else {
                Run('"' . installerPath . '" /upgrade')
            }

            ; Exit current application
            ExitApp
        } catch as e {
            MsgBox("Failed to launch installer: " . e.Message, "Update Error", "IconX")
        }
    }

    /**
     * Open releases page in browser
     */
    static OpenReleasesPage() {
        Run("https://github.com/" . this.GitHubRepo . "/releases")
    }
}
