#Requires AutoHotkey v2.0

/**
 * TextSelection - Reliable text capture from any application
 * Addresses PITFALLS P1 (clipboard timing) and P2 (app-specific behavior)
 */
class TextSelection {
    ; Configuration
    static DefaultTimeout := 2        ; ClipWait timeout in seconds
    static MaxRetries := 3            ; Retry attempts
    static PostPasteDelay := 150      ; ms to wait after paste (increased for reliability)

    /**
     * Get currently selected text
     * Clears clipboard, sends Ctrl+C, waits for content
     * @returns {Object} {success: bool, text: string, error: string}
     */
    static GetSelectedText() {
        ; Save current clipboard contents
        savedClip := ClipboardAll()

        try {
            ; Clear clipboard before copy (P1 prevention)
            A_Clipboard := ""

            ; Send copy command
            Send "^c"

            ; Wait for clipboard with timeout
            if !ClipWait(this.DefaultTimeout) {
                ; Restore clipboard and return error
                A_Clipboard := savedClip
                return {success: false, text: "", error: "No text selected or copy failed"}
            }

            ; Get the text
            text := A_Clipboard

            ; Restore original clipboard
            A_Clipboard := savedClip
            Sleep 50  ; Allow clipboard restoration

            ; Validate we got something
            if (text = "") {
                return {success: false, text: "", error: "Selection was empty"}
            }

            return {success: true, text: text, error: ""}
        } catch as e {
            ; Restore clipboard on any error
            try {
                A_Clipboard := savedClip
            }
            return {success: false, text: "", error: "Error capturing text: " e.Message}
        }
    }

    /**
     * Get selected text with retry logic for unreliable apps
     * @param {number} maxRetries - Number of retry attempts
     * @returns {Object} {success: bool, text: string, error: string}
     */
    static GetSelectedTextWithRetry(maxRetries := 3) {
        Loop maxRetries {
            result := this.GetSelectedText()
            if result.success
                return result

            ; Wait before retry
            Sleep 100
        }

        return {success: false, text: "", error: "Failed to capture text after " maxRetries " attempts"}
    }

    /**
     * Replace selected text with new content
     * @param {string} newText - Text to paste
     * @returns {Object} {success: bool, error: string}
     */
    static ReplaceSelectedText(newText) {
        ; Save current clipboard
        savedClip := ClipboardAll()

        try {
            ; Set clipboard to new text
            A_Clipboard := newText

            ; Wait for clipboard to be ready
            if !ClipWait(this.DefaultTimeout) {
                A_Clipboard := savedClip
                return {success: false, error: "Failed to set clipboard"}
            }

            ; Paste
            Send "^v"
            Sleep this.PostPasteDelay  ; Critical: allow paste to complete (P1)

            ; Restore original clipboard (so user's copied content isn't lost)
            A_Clipboard := savedClip
            Sleep 50

            return {success: true, error: ""}
        } catch as e {
            try {
                A_Clipboard := savedClip
            }
            return {success: false, error: "Error replacing text: " e.Message}
        }
    }

    /**
     * Copy text to clipboard without affecting selection
     * @param {string} text - Text to place on clipboard
     * @returns {Object} {success: bool, error: string}
     */
    static CopyToClipboard(text) {
        try {
            A_Clipboard := text
            if !ClipWait(this.DefaultTimeout) {
                return {success: false, error: "Failed to set clipboard"}
            }
            return {success: true, error: ""}
        } catch as e {
            return {success: false, error: "Error copying to clipboard: " e.Message}
        }
    }
}
