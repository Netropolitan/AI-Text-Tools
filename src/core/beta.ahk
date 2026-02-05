#Requires AutoHotkey v2.0

/**
 * BetaManager - Handles beta tester registration and API proxying
 *
 * Features:
 * - Beta code validation via server
 * - OpenAI request proxying through server (API key stays server-side)
 * - Usage tracking and limit enforcement
 */
class BetaManager {
    static ServerEndpoint := "https://brew.taila07ff3.ts.net/api/aitexttools/beta"
    static Config := ""

    /**
     * Initialize with config manager
     * @param {ConfigManager} config
     */
    static Init(config) {
        this.Config := config
    }

    /**
     * Check if user has active beta access
     * @returns {bool}
     */
    static HasBetaAccess() {
        if !this.Config
            return false
        token := this.Config.Get("Beta", "Token", "")
        return token != ""
    }

    /**
     * Get beta token
     * @returns {string}
     */
    static GetToken() {
        if !this.Config
            return ""
        return this.Config.Get("Beta", "Token", "")
    }

    /**
     * Get beta email
     * @returns {string}
     */
    static GetEmail() {
        if !this.Config
            return ""
        return this.Config.Get("Beta", "Email", "")
    }

    /**
     * Get remaining uses
     * @returns {int}
     */
    static GetUsesRemaining() {
        if !this.Config
            return 0
        val := this.Config.Get("Beta", "UsesRemaining", "0")
        return (val = "") ? 0 : Integer(val)
    }

    /**
     * Register as beta tester
     * @param {string} code - Beta tester code
     * @param {string} email - Email address
     * @returns {Object} {success: bool, message: string, uses_remaining: int}
     */
    static Register(code, email) {
        try {
            ; Build request payload
            payload := '{'
            payload .= '"code":"' . this.EscapeJson(code) . '",'
            payload .= '"email":"' . this.EscapeJson(email) . '"'
            payload .= '}'

            ; Send registration request
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("POST", this.ServerEndpoint . "/register", true)
            whr.SetRequestHeader("Content-Type", "application/json")
            whr.SetRequestHeader("User-Agent", "AI-Text-Tools/" . UpdateManager.CurrentVersion)
            whr.SetTimeouts(10000, 10000, 10000, 30000)
            whr.Send(payload)
            whr.WaitForResponse(30)

            ; Parse response
            response := JSON.Load(whr.ResponseText)

            ; Extract token from response (server may use different field names)
            ; Token value could be null from JSON, so check for both empty and non-string
            token := ""
            if response.Has("beta_token") && response["beta_token"] != "" && !IsObject(response["beta_token"])
                token := String(response["beta_token"])
            else if response.Has("token") && response["token"] != "" && !IsObject(response["token"])
                token := String(response["token"])

            if token != "" {
                ; Got a valid token - save it and activate
                this.Config.Set("Beta", "Token", token)
                this.Config.Set("Beta", "Email", email)

                ; Get uses remaining - check response first, fall back to status endpoint
                usesRemaining := 0
                if response.Has("uses_remaining") && response["uses_remaining"] != "" && !IsObject(response["uses_remaining"]) {
                    try usesRemaining := Integer(response["uses_remaining"])
                }

                if usesRemaining = 0 {
                    ; Response didn't have valid uses_remaining, check status endpoint
                    status := this.CheckStatus()
                    if status.success
                        usesRemaining := status.uses_remaining
                }

                this.Config.Set("Beta", "UsesRemaining", String(usesRemaining))

                ; Refresh provider to switch to BetaProvider
                try Orchestrator.RefreshProvider()

                return {
                    success: true,
                    message: "Beta access activated! You have " . usesRemaining . " credits.",
                    uses_remaining: usesRemaining
                }
            } else {
                ; No token in response - check if we have one stored locally
                existingToken := this.GetToken()
                if existingToken != "" {
                    this.Config.Set("Beta", "Email", email)
                    status := this.CheckStatus()
                    if status.success {
                        this.Config.Set("Beta", "UsesRemaining", String(status.uses_remaining))
                        try Orchestrator.RefreshProvider()
                        return {
                            success: true,
                            message: "Beta access activated! You have " . status.uses_remaining . " credits.",
                            uses_remaining: status.uses_remaining
                        }
                    }
                }
                ; Genuine error - no token anywhere
                errorMsg := response.Has("error") ? response["error"] : "Registration failed"
                return {success: false, message: errorMsg, uses_remaining: 0}
            }

        } catch as e {
            return {success: false, message: "Connection error: " . e.Message, uses_remaining: 0}
        }
    }

    /**
     * Check beta status (uses remaining, active state)
     * @returns {Object} {success: bool, is_active: bool, uses_remaining: int, uses_total: int}
     */
    static CheckStatus() {
        token := this.GetToken()
        if token = ""
            return {success: false, is_active: false, uses_remaining: 0, uses_total: 0}

        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("GET", this.ServerEndpoint . "/status?token=" . token, true)
            whr.SetRequestHeader("User-Agent", "AI-Text-Tools/" . UpdateManager.CurrentVersion)
            whr.SetTimeouts(10000, 10000, 10000, 30000)
            whr.Send()
            whr.WaitForResponse(30)

            if whr.Status = 200 {
                response := JSON.Load(whr.ResponseText)
                if response.Has("success") && response["success"] {
                    ; Update local cache
                    this.Config.Set("Beta", "UsesRemaining", String(response["uses_remaining"]))

                    return {
                        success: true,
                        is_active: response["is_active"],
                        uses_remaining: response["uses_remaining"],
                        uses_total: response["uses_total"]
                    }
                }
            }

            return {success: false, is_active: false, uses_remaining: 0, uses_total: 0}

        } catch {
            return {success: false, is_active: false, uses_remaining: 0, uses_total: 0}
        }
    }

    /**
     * Proxy an OpenAI request through the server
     * @param {Array} messages - Chat messages array [{role, content}, ...]
     * @returns {Object} {success: bool, content: string, error: string, uses_remaining: int}
     */
    static ProxyRequest(messages) {
        token := this.GetToken()
        if token = ""
            return {success: false, content: "", error: "No beta token", uses_remaining: 0}

        try {
            ; Build messages JSON
            messagesJson := "["
            for i, msg in messages {
                if i > 1
                    messagesJson .= ","
                messagesJson .= '{"role":"' . msg.role . '","content":"' . this.EscapeJson(msg.content) . '"}'
            }
            messagesJson .= "]"

            ; Build request payload
            payload := '{'
            payload .= '"beta_token":"' . token . '",'
            payload .= '"messages":' . messagesJson
            payload .= '}'

            ; Send proxy request
            whr := ComObject("WinHttp.WinHttpRequest.5.1")
            whr.Open("POST", this.ServerEndpoint . "/proxy", true)
            whr.SetRequestHeader("Content-Type", "application/json")
            whr.SetRequestHeader("User-Agent", "AI-Text-Tools/" . UpdateManager.CurrentVersion)
            whr.SetTimeouts(30000, 30000, 30000, 120000)  ; Longer timeout for AI responses
            whr.Send(payload)
            whr.WaitForResponse(120)

            response := JSON.Load(whr.ResponseText)

            if whr.Status = 200 && response.Has("success") && response["success"] {
                ; Update local uses count
                if response.Has("uses_remaining")
                    this.Config.Set("Beta", "UsesRemaining", String(response["uses_remaining"]))

                return {
                    success: true,
                    content: response["content"],
                    error: "",
                    uses_remaining: response["uses_remaining"]
                }
            } else if whr.Status = 429 {
                ; Uses exhausted
                this.Config.Set("Beta", "UsesRemaining", "0")
                return {
                    success: false,
                    content: "",
                    error: "Beta usage limit reached. Please get your own API key (see README).",
                    uses_remaining: 0
                }
            } else if whr.Status = 403 {
                ; Deactivated
                return {
                    success: false,
                    content: "",
                    error: "Beta access has been revoked.",
                    uses_remaining: 0
                }
            } else if whr.Status = 401 {
                ; Invalid token
                this.ClearBetaAccess()
                return {
                    success: false,
                    content: "",
                    error: "Invalid beta token. Please re-register.",
                    uses_remaining: 0
                }
            } else {
                errorMsg := response.Has("error") ? response["error"] : "Request failed"
                return {success: false, content: "", error: errorMsg, uses_remaining: 0}
            }

        } catch as e {
            return {success: false, content: "", error: "Connection error: " . e.Message, uses_remaining: 0}
        }
    }

    /**
     * Clear beta access (logout)
     */
    static ClearBetaAccess() {
        if this.Config {
            this.Config.Set("Beta", "Token", "")
            this.Config.Set("Beta", "Email", "")
            this.Config.Set("Beta", "UsesRemaining", "0")
        }
    }

    /**
     * Escape string for JSON
     * @param {string} str
     * @returns {string}
     */
    static EscapeJson(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, '"', '\"')
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`t", "\t")
        return str
    }

    /**
     * Show beta tester registration popup
     * @returns {bool} True if registered successfully
     */
    static ShowRegistrationPopup() {
        ; Create popup GUI
        popup := Gui("+AlwaysOnTop -MinimizeBox", "Beta Tester Registration")
        popup.SetFont("s10", "Segoe UI")

        popup.Add("Text", "x20 y20 w300", "Enter your beta tester code and email to activate free OpenAI credit on AI Text Tools.")

        popup.Add("Text", "x20 y60", "Beta Code:")
        codeEdit := popup.Add("Edit", "x100 y57 w220 vBetaCode Password")

        popup.Add("Text", "x20 y95", "Email:")
        emailEdit := popup.Add("Edit", "x100 y92 w220 vEmail")

        statusText := popup.Add("Text", "x20 y130 w300 c666666", "")

        registerBtn := popup.Add("Button", "x100 y160 w100 h30 Default", "Activate")
        cancelBtn := popup.Add("Button", "x210 y160 w100 h30", "Cancel")

        ; Result variable
        result := false

        ; Event handlers
        registerBtn.OnEvent("Click", (*) => this.DoRegister(popup, codeEdit, emailEdit, statusText, &result))
        cancelBtn.OnEvent("Click", (*) => popup.Destroy())
        popup.OnEvent("Close", (*) => popup.Destroy())
        popup.OnEvent("Escape", (*) => popup.Destroy())

        ; Show and wait
        popup.Show("w340 h210")

        ; Wait for popup to close
        WinWaitClose(popup)

        return result
    }

    /**
     * Handle registration button click
     */
    static DoRegister(popup, codeEdit, emailEdit, statusText, &result) {
        code := codeEdit.Value
        email := emailEdit.Value

        if code = "" {
            statusText.Value := "Please enter a beta code."
            return
        }

        if email = "" || !InStr(email, "@") {
            statusText.Value := "Please enter a valid email."
            return
        }

        statusText.Value := "Registering..."

        ; Attempt registration
        regResult := this.Register(code, email)

        if regResult.success {
            result := true
            popup.Destroy()
            MsgBox(regResult.message, "Beta Access Activated", "Iconi")
        } else {
            statusText.Value := regResult.message
        }
    }
}
