#Requires AutoHotkey v2.0

/**
 * ConfigManager - INI-based configuration management
 *
 * Provides read/write access to settings with default value support.
 * Stores settings in AppData to avoid permission issues in Program Files.
 * Creates settings.ini from settings.default.ini on first run.
 */
class ConfigManager {
    FilePath := ""
    DefaultPath := ""
    AppDataDir := ""

    __New() {
        ; Use AppData for settings (writable even when installed to Program Files)
        this.AppDataDir := A_AppData "\AI Text Tools"
        this.FilePath := this.AppDataDir "\settings.ini"
        this.DefaultPath := A_ScriptDir "\settings.default.ini"

        ; Create AppData directory if it doesn't exist
        if !DirExist(this.AppDataDir)
            DirCreate(this.AppDataDir)

        ; Create settings.ini from default if doesn't exist
        if !FileExist(this.FilePath) {
            if FileExist(this.DefaultPath) {
                FileCopy(this.DefaultPath, this.FilePath)
            } else if FileExist(A_ScriptDir "\settings.ini") {
                ; Migration: copy from old location if exists
                FileCopy(A_ScriptDir "\settings.ini", this.FilePath)
            }
        }
    }

    /**
     * Read a config value with optional default
     * @param section INI section name
     * @param key Key name within section
     * @param defaultValue Value to return if key doesn't exist
     * @returns The config value or default
     */
    Get(section, key, defaultValue := "") {
        return IniRead(this.FilePath, section, key, defaultValue)
    }

    /**
     * Write a config value
     * @param section INI section name
     * @param key Key name within section
     * @param value Value to write
     */
    Set(section, key, value) {
        IniWrite(value, this.FilePath, section, key)
    }

    /**
     * Read all keys in a section as Map
     * @param section INI section name
     * @returns Map of key => value pairs
     */
    GetSection(section) {
        result := Map()
        try {
            content := IniRead(this.FilePath, section)
            for line in StrSplit(content, "`n", "`r") {
                if InStr(line, "=") {
                    parts := StrSplit(line, "=", , 2)
                    result[Trim(parts[1])] := parts.Length > 1 ? Trim(parts[2]) : ""
                }
            }
        }
        return result
    }

    /**
     * Delete a key from config
     * @param section INI section name
     * @param key Key to delete
     */
    Delete(section, key) {
        IniDelete(this.FilePath, section, key)
    }

    /**
     * Check if a key exists
     * @param section INI section name
     * @param key Key name
     * @returns true if key exists with non-empty value
     */
    Has(section, key) {
        val := this.Get(section, key, Chr(0))  ; Use null char as sentinel
        return val != Chr(0) && val != ""
    }

    /**
     * Get the AppData directory path
     * @returns Path to the AppData settings directory
     */
    GetAppDataDir() {
        return this.AppDataDir
    }
}
