#Requires AutoHotkey v2.0

/**
 * CredentialManager - API key storage using Base64 encoding in INI file
 *
 * Simple and reliable approach - stores keys in settings.ini with Base64 encoding.
 * Not cryptographically secure, but prevents casual viewing.
 * Uses AppData folder for write permissions when installed to Program Files.
 */
class CredentialManager {
    static AppDataDir := A_AppData . "\AI Text Tools"
    static IniFile := A_AppData . "\AI Text Tools\settings.ini"
    static Section := "Credentials"

    /**
     * Store API key (Base64 encoded in INI file)
     * @param provider Provider name (openai, anthropic, gemini)
     * @param key API key value
     * @returns {success, error}
     */
    static Store(provider, key) {
        try {
            ; Ensure AppData directory exists
            if !DirExist(this.AppDataDir)
                DirCreate(this.AppDataDir)

            ; Base64 encode the key
            encoded := this.Base64Encode(key)
            IniWrite(encoded, this.IniFile, this.Section, provider)
            return {success: true, error: ""}
        } catch as e {
            return {success: false, error: e.Message}
        }
    }

    /**
     * Retrieve API key (Base64 decoded from INI file)
     * @param provider Provider name
     * @returns API key string or empty if not found
     */
    static Retrieve(provider) {
        try {
            encoded := IniRead(this.IniFile, this.Section, provider, "")
            if encoded = ""
                return ""
            return this.Base64Decode(encoded)
        } catch {
            return ""
        }
    }

    /**
     * Delete stored credential
     * @param provider Provider name
     * @returns {success, error}
     */
    static Delete(provider) {
        try {
            IniDelete(this.IniFile, this.Section, provider)
            return {success: true, error: ""}
        } catch as e {
            return {success: false, error: e.Message}
        }
    }

    /**
     * Check if credential exists
     * @param provider Provider name
     * @returns Boolean
     */
    static Exists(provider) {
        try {
            encoded := IniRead(this.IniFile, this.Section, provider, "")
            return encoded != ""
        } catch {
            return false
        }
    }

    /**
     * Get masked version of API key for display
     * Shows last 4 characters only
     * @param provider Provider name
     * @returns Masked string or empty
     */
    static GetMasked(provider) {
        key := this.Retrieve(provider)
        if !key
            return ""

        keyLen := StrLen(key)
        if keyLen > 4
            return "********" . SubStr(key, -4)
        else if keyLen > 0
            return "****"
        return ""
    }

    /**
     * Base64 encode a string
     */
    static Base64Encode(str) {
        if str = ""
            return ""

        ; Convert string to UTF-8 bytes
        buf := Buffer(StrPut(str, "UTF-8"))
        StrPut(str, buf, "UTF-8")
        size := buf.Size - 1  ; Exclude null terminator

        ; Calculate required output size
        outSize := 4 * ((size + 2) // 3) + 1

        ; Encode
        outBuf := Buffer(outSize)
        DllCall("crypt32\CryptBinaryToStringA",
            "Ptr", buf,
            "UInt", size,
            "UInt", 0x40000001,  ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
            "Ptr", outBuf,
            "UInt*", &outSize)

        return StrGet(outBuf, "CP0")
    }

    /**
     * Base64 decode a string
     */
    static Base64Decode(b64) {
        if b64 = ""
            return ""

        ; Calculate required buffer size
        size := 0
        DllCall("crypt32\CryptStringToBinaryA",
            "AStr", b64,
            "UInt", 0,
            "UInt", 0x1,  ; CRYPT_STRING_BASE64
            "Ptr", 0,
            "UInt*", &size,
            "Ptr", 0,
            "Ptr", 0)

        if size = 0
            return ""

        ; Decode
        buf := Buffer(size + 1)
        DllCall("crypt32\CryptStringToBinaryA",
            "AStr", b64,
            "UInt", 0,
            "UInt", 0x1,  ; CRYPT_STRING_BASE64
            "Ptr", buf,
            "UInt*", &size,
            "Ptr", 0,
            "Ptr", 0)

        return StrGet(buf, size, "UTF-8")
    }
}
