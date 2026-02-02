#Requires AutoHotkey v2.0

/**
 * CredentialManager - API key storage using DPAPI encryption in INI file
 *
 * Uses Windows Data Protection API (DPAPI) for real cryptographic protection.
 * DPAPI encrypts data using the current Windows user's credentials - the
 * encrypted data can only be decrypted by the same user on the same machine.
 *
 * Includes automatic migration from legacy Base64 format (v1.6 and earlier).
 * Uses AppData folder for write permissions when installed to Program Files.
 */
class CredentialManager {
    static AppDataDir := A_AppData . "\AI Text Tools"
    static IniFile := A_AppData . "\AI Text Tools\settings.ini"
    static Section := "Credentials"

    /**
     * Store API key (DPAPI encrypted in INI file)
     * @param provider Provider name (openai, anthropic, gemini)
     * @param key API key value
     * @returns {success, error}
     */
    static Store(provider, key) {
        try {
            ; Ensure AppData directory exists
            if !DirExist(this.AppDataDir)
                DirCreate(this.AppDataDir)

            ; DPAPI encrypt the key
            encrypted := this.DPAPIEncrypt(key)
            if encrypted = ""
                throw Error("DPAPI encryption failed")

            IniWrite(encrypted, this.IniFile, this.Section, provider)
            return {success: true, error: ""}
        } catch as e {
            return {success: false, error: e.Message}
        }
    }

    /**
     * Retrieve API key (DPAPI decrypted from INI file)
     * Includes automatic migration from legacy Base64 format
     * @param provider Provider name
     * @returns API key string or empty if not found
     */
    static Retrieve(provider) {
        try {
            encoded := IniRead(this.IniFile, this.Section, provider, "")
            if encoded = ""
                return ""

            ; Try DPAPI decrypt first (v1.7+ format)
            decrypted := this.DPAPIDecrypt(encoded)
            if decrypted != ""
                return decrypted

            ; DPAPI failed - try legacy Base64 decode (v1.6 and earlier)
            legacyDecrypted := this.Base64Decode(encoded)
            if legacyDecrypted != "" {
                ; Successfully decoded legacy format - migrate to DPAPI
                this.Store(provider, legacyDecrypted)
                return legacyDecrypted
            }

            ; Both failed - data is corrupted or invalid
            return ""
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
     * Encrypt string using Windows DPAPI (CryptProtectData)
     * Returns Base64-encoded encrypted data for storage in INI
     * @param plainText String to encrypt
     * @returns Base64-encoded encrypted data, or empty on failure
     */
    static DPAPIEncrypt(plainText) {
        if plainText = ""
            return ""

        try {
            ; Convert string to UTF-8 bytes
            utf8Buf := Buffer(StrPut(plainText, "UTF-8"))
            StrPut(plainText, utf8Buf, "UTF-8")
            utf8Size := utf8Buf.Size - 1  ; Exclude null terminator

            ; Prepare DATA_BLOB structures
            ; typedef struct _DATA_BLOB { DWORD cbData; BYTE *pbData; } DATA_BLOB;
            dataIn := Buffer(A_PtrSize * 2)
            NumPut("UInt", utf8Size, dataIn, 0)
            NumPut("Ptr", utf8Buf.Ptr, dataIn, A_PtrSize)

            dataOut := Buffer(A_PtrSize * 2)
            NumPut("UInt", 0, dataOut, 0)
            NumPut("Ptr", 0, dataOut, A_PtrSize)

            ; Call CryptProtectData
            ; BOOL CryptProtectData(DATA_BLOB *pDataIn, LPCWSTR szDataDescr,
            ;   DATA_BLOB *pOptionalEntropy, PVOID pvReserved,
            ;   CRYPTPROTECT_PROMPTSTRUCT *pPromptStruct, DWORD dwFlags, DATA_BLOB *pDataOut)
            result := DllCall("crypt32\CryptProtectData",
                "Ptr", dataIn,           ; pDataIn
                "Ptr", 0,                 ; szDataDescr (NULL)
                "Ptr", 0,                 ; pOptionalEntropy (NULL)
                "Ptr", 0,                 ; pvReserved
                "Ptr", 0,                 ; pPromptStruct (NULL)
                "UInt", 0,                ; dwFlags
                "Ptr", dataOut,           ; pDataOut
                "Int")

            if !result
                return ""

            ; Extract encrypted data
            encryptedSize := NumGet(dataOut, 0, "UInt")
            encryptedPtr := NumGet(dataOut, A_PtrSize, "Ptr")

            if encryptedSize = 0 || encryptedPtr = 0
                return ""

            ; Copy encrypted data to our buffer
            encryptedBuf := Buffer(encryptedSize)
            DllCall("RtlMoveMemory", "Ptr", encryptedBuf.Ptr, "Ptr", encryptedPtr, "UInt", encryptedSize)

            ; Free the memory allocated by CryptProtectData
            DllCall("LocalFree", "Ptr", encryptedPtr)

            ; Base64 encode for INI storage
            outSize := 4 * ((encryptedSize + 2) // 3) + 1
            outBuf := Buffer(outSize)
            DllCall("crypt32\CryptBinaryToStringA",
                "Ptr", encryptedBuf,
                "UInt", encryptedSize,
                "UInt", 0x40000001,  ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
                "Ptr", outBuf,
                "UInt*", &outSize)

            return StrGet(outBuf, "CP0")
        } catch {
            return ""
        }
    }

    /**
     * Decrypt string using Windows DPAPI (CryptUnprotectData)
     * @param encryptedB64 Base64-encoded encrypted data
     * @returns Decrypted string, or empty on failure
     */
    static DPAPIDecrypt(encryptedB64) {
        if encryptedB64 = ""
            return ""

        try {
            ; Base64 decode first
            size := 0
            DllCall("crypt32\CryptStringToBinaryA",
                "AStr", encryptedB64,
                "UInt", 0,
                "UInt", 0x1,  ; CRYPT_STRING_BASE64
                "Ptr", 0,
                "UInt*", &size,
                "Ptr", 0,
                "Ptr", 0)

            if size = 0
                return ""

            encryptedBuf := Buffer(size)
            DllCall("crypt32\CryptStringToBinaryA",
                "AStr", encryptedB64,
                "UInt", 0,
                "UInt", 0x1,  ; CRYPT_STRING_BASE64
                "Ptr", encryptedBuf,
                "UInt*", &size,
                "Ptr", 0,
                "Ptr", 0)

            ; Prepare DATA_BLOB structures
            dataIn := Buffer(A_PtrSize * 2)
            NumPut("UInt", size, dataIn, 0)
            NumPut("Ptr", encryptedBuf.Ptr, dataIn, A_PtrSize)

            dataOut := Buffer(A_PtrSize * 2)
            NumPut("UInt", 0, dataOut, 0)
            NumPut("Ptr", 0, dataOut, A_PtrSize)

            ; Call CryptUnprotectData
            result := DllCall("crypt32\CryptUnprotectData",
                "Ptr", dataIn,           ; pDataIn
                "Ptr", 0,                 ; ppszDataDescr (NULL)
                "Ptr", 0,                 ; pOptionalEntropy (NULL)
                "Ptr", 0,                 ; pvReserved
                "Ptr", 0,                 ; pPromptStruct (NULL)
                "UInt", 0,                ; dwFlags
                "Ptr", dataOut,           ; pDataOut
                "Int")

            if !result
                return ""

            ; Extract decrypted data
            decryptedSize := NumGet(dataOut, 0, "UInt")
            decryptedPtr := NumGet(dataOut, A_PtrSize, "Ptr")

            if decryptedSize = 0 || decryptedPtr = 0
                return ""

            ; Convert to string (UTF-8)
            decrypted := StrGet(decryptedPtr, decryptedSize, "UTF-8")

            ; Free the memory allocated by CryptUnprotectData
            DllCall("LocalFree", "Ptr", decryptedPtr)

            return decrypted
        } catch {
            return ""
        }
    }

    /**
     * Base64 decode a string (for legacy v1.6 migration)
     */
    static Base64Decode(b64) {
        if b64 = ""
            return ""

        try {
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
        } catch {
            return ""
        }
    }
}
