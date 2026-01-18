#Requires AutoHotkey v2.0

/**
 * ThemeManager - Dark/light theme support
 *
 * Manages application theme with light and dark color schemes.
 * Theme preference persists via ConfigManager.
 */
class ThemeManager {
    static CurrentTheme := "light"

    static Themes := Map(
        "light", {
            bgColor: "FFFFFF",
            textColor: "000000",
            accentColor: "0066CC",
            headerColor: "666666",
            borderColor: "CCCCCC"
        },
        "dark", {
            bgColor: "1E1E1E",
            textColor: "FFFFFF",
            accentColor: "4FC3F7",
            headerColor: "AAAAAA",
            borderColor: "444444"
        }
    )

    /**
     * Load theme from config
     * @param {ConfigManager} config - Config manager instance
     */
    static Load(config) {
        this.CurrentTheme := StrLower(config.Get("General", "Theme", "light"))
        if !this.Themes.Has(this.CurrentTheme)
            this.CurrentTheme := "light"
    }

    /**
     * Apply theme to a GUI
     * @param {Gui} gui - GUI to apply theme to
     */
    static Apply(gui) {
        theme := this.Themes[this.CurrentTheme]
        gui.BackColor := theme.bgColor

        ; Note: AHK v2 has limited runtime style changes
        ; Full theme support may require recreating controls
    }

    /**
     * Get current theme colors
     * @returns {Object} Theme color object
     */
    static GetColors() {
        return this.Themes[this.CurrentTheme]
    }

    /**
     * Get current theme name
     * @returns {string} "light" or "dark"
     */
    static GetTheme() {
        return this.CurrentTheme
    }

    /**
     * Set theme
     * @param {string} themeName - "light" or "dark"
     * @param {ConfigManager} config - Config manager for persistence
     */
    static SetTheme(themeName, config) {
        themeName := StrLower(themeName)
        if this.Themes.Has(themeName) {
            this.CurrentTheme := themeName
            config.Set("General", "Theme", themeName)
        }
    }

    /**
     * Check if dark theme is active
     * @returns {Boolean} True if dark theme
     */
    static IsDark() {
        return this.CurrentTheme = "dark"
    }
}
