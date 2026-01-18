/**
 * TrayManager - System tray integration
 *
 * Manages the system tray icon and menu for AI Text Tools.
 * Provides Settings and Exit menu items.
 */

class TrayManager {
    /**
     * Initialize system tray
     * Sets up menu items and default action
     */
    static Initialize() {
        ; Clear default menu
        A_TrayMenu.Delete()

        ; Add menu items
        A_TrayMenu.Add("Settings", (*) => this.OnSettings())
        A_TrayMenu.Add()  ; Separator
        A_TrayMenu.Add("Exit", (*) => ExitApp())

        ; Set default action (double-click opens Settings)
        A_TrayMenu.Default := "Settings"

        ; Set tooltip
        A_IconTip := "AI Text Tools"
    }

    /**
     * Handle Settings menu click
     */
    static OnSettings() {
        SettingsWindow.Show()
    }
}
