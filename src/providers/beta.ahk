#Requires AutoHotkey v2.0

/**
 * BetaProvider - Proxy provider for beta testers
 *
 * Routes OpenAI requests through the server, where the actual
 * API key is stored securely. Uses gpt-4.1-nano model only.
 */
class BetaProvider extends ProviderBase {
    Name := "OpenAI (Beta)"
    BaseUrl := "https://brew.taila07ff3.ts.net/api/aitexttools/beta"

    /**
     * Complete a prompt using the beta proxy
     * @param {string} systemPrompt - System instruction
     * @param {string} userContent - User's text
     * @param {Map} options - Additional options (ignored for beta)
     * @returns {Object} {success: bool, content: string, error: string}
     */
    Complete(systemPrompt, userContent, options := Map()) {
        ; Build messages array
        messages := []
        messages.Push({role: "system", content: systemPrompt})
        messages.Push({role: "user", content: userContent})

        ; Use BetaManager to proxy the request
        result := BetaManager.ProxyRequest(messages)

        if result.success {
            return {
                success: true,
                content: result.content,
                error: ""
            }
        } else {
            ; Check for specific error conditions
            if InStr(result.error, "usage limit") {
                ; Show popup directing to get own API key
                MsgBox("Your beta access has reached its usage limit.`n`nTo continue using AI Text Tools, please get your own API key. See the README for instructions on how to get a free or paid API key from OpenAI, Anthropic, or Google.", "Beta Access Exhausted", "Icon!")
            }

            return {
                success: false,
                content: "",
                error: result.error
            }
        }
    }

    /**
     * Test connection by checking beta status
     * @returns {Object} {success: bool, error: string}
     */
    TestConnection() {
        if !BetaManager.HasBetaAccess() {
            return {success: false, error: "No beta token configured"}
        }

        status := BetaManager.CheckStatus()

        if status.success && status.is_active {
            return {
                success: true,
                error: "",
                uses_remaining: status.uses_remaining
            }
        } else if status.success && !status.is_active {
            return {success: false, error: "Beta access has been deactivated"}
        } else {
            return {success: false, error: "Could not verify beta status"}
        }
    }

    /**
     * Get available models (only gpt-4.1-nano for beta)
     * @returns {Array} Array of model names
     */
    GetModels() {
        return ["gpt-4.1-nano (Beta)"]
    }
}
