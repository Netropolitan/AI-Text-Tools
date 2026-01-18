#Requires AutoHotkey v2.0

/**
 * HotkeyManager - Global hotkey registration and management
 */
class HotkeyManager {
    ; Default hotkey bindings
    static DefaultQuickAction := "^+j"   ; Ctrl+Shift+J
    static DefaultPromptMenu := "^+k"    ; Ctrl+Shift+K

    ; Registered callbacks
    static QuickActionCallback := ""
    static PromptMenuCallback := ""

    ; Track if hotkeys are registered
    static IsRegistered := false

    ; Store current bindings for unregister
    static CurrentQuickKey := ""
    static CurrentMenuKey := ""

    /**
     * Initialize hotkeys with callbacks
     * @param {Func} quickActionFn - Called on Ctrl+Shift+J
     * @param {Func} promptMenuFn - Called on Ctrl+Shift+K
     * @param {ConfigManager} config - Optional config for custom bindings
     */
    static Initialize(quickActionFn, promptMenuFn, config := "") {
        this.QuickActionCallback := quickActionFn
        this.PromptMenuCallback := promptMenuFn

        ; Get hotkey bindings from config or use defaults
        quickKey := this.DefaultQuickAction
        menuKey := this.DefaultPromptMenu

        if config {
            customQuick := config.Get("Hotkeys", "QuickAction", "")
            customMenu := config.Get("Hotkeys", "PromptMenu", "")
            if customQuick
                quickKey := customQuick
            if customMenu
                menuKey := customMenu
        }

        ; Register hotkeys
        this.Register(quickKey, menuKey)
    }

    /**
     * Register hotkeys with the system
     * @param {string} quickKey - Hotkey for quick action
     * @param {string} menuKey - Hotkey for prompt menu
     */
    static Register(quickKey, menuKey) {
        ; Unregister existing if any
        if this.IsRegistered
            this.Unregister()

        try {
            ; Register quick action hotkey
            Hotkey quickKey, (*) => this.OnQuickAction(), "On"

            ; Register prompt menu hotkey
            Hotkey menuKey, (*) => this.OnPromptMenu(), "On"

            ; Store current bindings for later unregister
            this.CurrentQuickKey := quickKey
            this.CurrentMenuKey := menuKey

            this.IsRegistered := true
        } catch as e {
            throw Error("Failed to register hotkeys: " e.Message)
        }
    }

    /**
     * Unregister all hotkeys
     */
    static Unregister() {
        try {
            if this.CurrentQuickKey
                Hotkey this.CurrentQuickKey, "Off"
            if this.CurrentMenuKey
                Hotkey this.CurrentMenuKey, "Off"
        }
        this.IsRegistered := false
        this.CurrentQuickKey := ""
        this.CurrentMenuKey := ""
    }

    /**
     * Quick action handler (Ctrl+Shift+J)
     */
    static OnQuickAction() {
        if this.QuickActionCallback
            this.QuickActionCallback.Call()
    }

    /**
     * Prompt menu handler (Ctrl+Shift+K)
     */
    static OnPromptMenu() {
        if this.PromptMenuCallback
            this.PromptMenuCallback.Call()
    }

    /**
     * Update hotkey binding at runtime
     * @param {string} which - "QuickAction" or "PromptMenu"
     * @param {string} newKey - New hotkey string
     * @param {ConfigManager} config - Optional config to persist to
     */
    static UpdateBinding(which, newKey, config := "") {
        ; Validate hotkey
        if !newKey
            throw Error("Hotkey cannot be empty")

        ; Get current keys
        quickKey := this.CurrentQuickKey || this.DefaultQuickAction
        menuKey := this.CurrentMenuKey || this.DefaultPromptMenu

        ; Update the appropriate one
        if which = "QuickAction"
            quickKey := newKey
        else if which = "PromptMenu"
            menuKey := newKey
        else
            throw Error("Unknown hotkey: " which)

        ; Re-register both
        this.Register(quickKey, menuKey)

        ; Persist if config provided
        if config {
            config.Set("Hotkeys", which, newKey)
        }
    }
}
