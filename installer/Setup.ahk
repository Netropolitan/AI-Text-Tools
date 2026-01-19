#Requires AutoHotkey v2.0
#SingleInstance Force

; Compiler directives
;@Ahk2Exe-SetName AI Text Tools Setup
;@Ahk2Exe-SetDescription AI Text Tools Installer
;@Ahk2Exe-SetVersion 1.4.2
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Jamie Bykov-Brett

; Check for upgrade mode BEFORE admin elevation
global UpgradeMode := false
global UpgradePath := ""

for arg in A_Args {
    if arg = "/upgrade" || arg = "-upgrade" || arg = "--upgrade" {
        UpgradeMode := true
    } else if UpgradeMode && UpgradePath = "" && DirExist(arg) {
        ; Next argument after /upgrade is the install path
        UpgradePath := arg
    }
}

; Check for admin rights and elevate if needed (pass along upgrade args)
if !A_IsAdmin {
    try {
        cmdLine := '"' A_ScriptFullPath '"'
        if UpgradeMode {
            cmdLine .= ' /upgrade'
            if UpgradePath != ""
                cmdLine .= ' "' UpgradePath '"'
        }
        Run('*RunAs ' cmdLine)
        ExitApp
    } catch {
        MsgBox("This installer requires administrator privileges.`n`nPlease right-click and select 'Run as administrator'.", "Administrator Required", "IconX")
        ExitApp
    }
}

; Global variables
global MainGui := ""
global CurrentStep := 1
global InstallPath := "C:\Program Files\AI Text Tools"
global CreateDesktopShortcut := true
global CreateStartMenuShortcut := true
global LaunchAfterInstall := true
global RunOnStartup := false
global StartMinimized := false
global InstallComplete := false

; If upgrade mode with path, use that path
if UpgradeMode && UpgradePath != "" {
    InstallPath := UpgradePath
} else if UpgradeMode {
    ; Try to get existing install path from registry
    try {
        InstallPath := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AITextTools", "InstallLocation")
    }
}

; Step controls (will be populated)
global Step1Controls := []
global Step2Controls := []
global Step3Controls := []
global Step4Controls := []
global ProgressBar := ""
global ProgressText := ""

; Source directory (where files to install are located)
global SourceDir := A_IsCompiled ? A_ScriptDir : A_ScriptDir "\.."

; Handle upgrade mode or normal setup
if UpgradeMode {
    RunUpgrade()
} else {
    SetupInstaller()
}

/**
 * Run silent upgrade
 */
RunUpgrade() {
    global InstallPath, SourceDir, UpgradeMode, LaunchAfterInstall

    ; Force launch after upgrade
    LaunchAfterInstall := true

    ; Close running instances
    CloseRunningInstances()

    ; Create simple progress GUI
    upgradeGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox -SysMenu", "AI Text Tools Update")
    upgradeGui.SetFont("s10", "Segoe UI")
    upgradeGui.BackColor := "FFFFFF"

    upgradeGui.Add("Text", "x20 y20 w360", "Updating AI Text Tools...")
    progressBar := upgradeGui.Add("Progress", "x20 y50 w360 h25", 0)
    statusText := upgradeGui.Add("Text", "x20 y85 w360", "Preparing...")

    upgradeGui.Show("w400 h120")

    try {
        ; Step 1: Close running instances
        statusText.Value := "Closing running instances..."
        progressBar.Value := 20
        Sleep(500)

        ; Step 2: Copy files
        statusText.Value := "Updating application files..."
        progressBar.Value := 40

        if !DirExist(InstallPath) {
            DirCreate(InstallPath)
        }

        ; Copy main exe
        if FileExist(SourceDir "\AITextTools.exe") {
            FileCopy(SourceDir "\AITextTools.exe", InstallPath "\AITextTools.exe", true)
        }

        progressBar.Value := 60

        ; Copy uninstaller
        if FileExist(SourceDir "\Uninstall.exe") {
            FileCopy(SourceDir "\Uninstall.exe", InstallPath "\Uninstall.exe", true)
        }

        ; Copy icon
        if FileExist(SourceDir "\assets\icon.ico") {
            FileCopy(SourceDir "\assets\icon.ico", InstallPath "\icon.ico", true)
        } else if FileExist(SourceDir "\icon.ico") {
            FileCopy(SourceDir "\icon.ico", InstallPath "\icon.ico", true)
        }

        progressBar.Value := 80

        ; Step 3: Update registry version
        statusText.Value := "Updating registry..."
        regKey := "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AITextTools"
        try RegWrite("1.4.2", "REG_SZ", regKey, "DisplayVersion")

        progressBar.Value := 100
        statusText.Value := "Update complete!"
        Sleep(1000)

        upgradeGui.Destroy()

        ; Launch app
        exePath := InstallPath "\AITextTools.exe"
        if FileExist(exePath) {
            try Run('explorer.exe "' exePath '"')
        }

        ExitApp

    } catch as e {
        upgradeGui.Destroy()
        MsgBox("Update failed: " e.Message, "Update Error", "IconX")
        ExitApp
    }
}

/**
 * Close any running instances of AI Text Tools
 */
CloseRunningInstances() {
    ; Try to close gracefully first
    if WinExist("ahk_exe AITextTools.exe") {
        try {
            WinClose("ahk_exe AITextTools.exe")
            Sleep(1000)
        }
    }

    ; Force kill if still running
    try RunWait('taskkill /F /IM "AITextTools.exe"',, "Hide")
    Sleep(500)
}

SetupInstaller() {
    global MainGui, InstallPath

    ; Create main window
    MainGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", "AI Text Tools Setup")
    MainGui.SetFont("s10", "Segoe UI")
    MainGui.BackColor := "FFFFFF"

    ; Left sidebar (blue)
    MainGui.Add("Text", "x0 y0 w180 h400 Background2563EB")

    ; Sidebar title
    MainGui.SetFont("Bold s14 cFFFFFF")
    MainGui.Add("Text", "x15 y20 w150 BackgroundTrans", "AI Text Tools")
    MainGui.SetFont("Bold s9 cFFFFFF")
    MainGui.Add("Text", "x15 y42 w150 BackgroundTrans", "Bykov-Brett Enterprises")
    MainGui.SetFont("Norm s9 cFFFFFF")
    MainGui.Add("Text", "x15 y58 w150 BackgroundTrans", "Setup Wizard")

    ; Step indicators on sidebar
    MainGui.SetFont("s10 cFFFFFF")
    MainGui.Add("Text", "x15 y100 w150 BackgroundTrans vSideStep1", "1. Welcome")
    MainGui.Add("Text", "x15 y130 w150 BackgroundTrans vSideStep2", "2. Location")
    MainGui.Add("Text", "x15 y160 w150 BackgroundTrans vSideStep3", "3. Options")
    MainGui.Add("Text", "x15 y190 w150 BackgroundTrans vSideStep4", "4. Install")

    ; Reset font for main content
    MainGui.SetFont("Norm s10 c000000", "Segoe UI")

    ; Build all steps (initially hidden except step 1)
    BuildStep1()
    BuildStep2()
    BuildStep3()
    BuildStep4()

    ; Show step 1, hide others
    ShowStep1()
    HideStep2()
    HideStep3()
    HideStep4()

    ; Navigation buttons (always visible)
    MainGui.Add("Button", "x200 y360 w80 h30 vBackBtn", "< Back").OnEvent("Click", OnBackBtn)
    MainGui.Add("Button", "x290 y360 w80 h30 vNextBtn", "Next >").OnEvent("Click", OnNextBtn)
    MainGui.Add("Button", "x450 y360 w80 h30 vCancelBtn", "Cancel").OnEvent("Click", OnCancelBtn)

    ; Disable back button on first step
    MainGui["BackBtn"].Enabled := false

    ; Event handlers
    MainGui.OnEvent("Close", OnGuiClose)
    MainGui.OnEvent("Escape", OnGuiClose)

    ; Show window
    MainGui.Show("w550 h400")
}

; === STEP BUILDERS ===

BuildStep1() {
    global MainGui, Step1Controls

    ; Welcome step
    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w330 vStep1Title", "Welcome to AI Text Tools")
    Step1Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")

    ctrl := MainGui.Add("Text", "x200 y70 w330 vStep1Desc", "This wizard will install AI Text Tools on your computer.`n`nAI Text Tools provides AI-powered text transformation using hotkeys. Select text anywhere and press a hotkey to transform it using AI.`n`nFeatures:`n- Multiple AI providers (OpenAI, Anthropic, Gemini, Ollama)`n- Customizable hotkeys`n- Custom prompts`n- System tray integration")
    Step1Controls.Push(ctrl)

    ctrl := MainGui.Add("Text", "x200 y280 w330 vStep1Footer", "Click Next to continue.")
    Step1Controls.Push(ctrl)
}

BuildStep2() {
    global MainGui, Step2Controls, InstallPath

    ; Location step
    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w330 vStep2Title Hidden", "Choose Install Location")
    Step2Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")

    ctrl := MainGui.Add("Text", "x200 y70 w330 vStep2Desc Hidden", "Select where AI Text Tools should be installed:")
    Step2Controls.Push(ctrl)

    ctrl := MainGui.Add("Edit", "x200 y110 w250 vInstallPathEdit Hidden", InstallPath)
    Step2Controls.Push(ctrl)

    ctrl := MainGui.Add("Button", "x460 y109 w70 h24 vBrowseBtn Hidden", "Browse...")
    ctrl.OnEvent("Click", OnBrowse)
    Step2Controls.Push(ctrl)

    ctrl := MainGui.Add("Text", "x200 y150 w330 c666666 vStep2Note Hidden", "Note: The application will be installed in this folder.`nSettings are stored in AppData and won't be affected.")
    Step2Controls.Push(ctrl)
}

BuildStep3() {
    global MainGui, Step3Controls, CreateDesktopShortcut, CreateStartMenuShortcut, LaunchAfterInstall

    ; Options step
    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w330 vStep3Title Hidden", "Installation Options")
    Step3Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")

    ctrl := MainGui.Add("Text", "x200 y70 w330 vStep3Desc Hidden", "Choose additional options:")
    Step3Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y100 w330 vDesktopShortcut Checked Hidden", "Create desktop shortcut")
    Step3Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y125 w330 vStartMenuShortcut Checked Hidden", "Create Start Menu shortcut")
    Step3Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y150 w330 vRunOnStartup Hidden", "Run on Windows startup")
    Step3Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y175 w330 vStartMinimized Hidden", "Start minimized to system tray")
    Step3Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y200 w330 vLaunchAfter Checked Hidden", "Launch AI Text Tools after installation")
    Step3Controls.Push(ctrl)

    ctrl := MainGui.Add("Text", "x200 y240 w330 c666666 vStep3Note Hidden", "You can change these settings later from the application.")
    Step3Controls.Push(ctrl)
}

BuildStep4() {
    global MainGui, Step4Controls, ProgressBar, ProgressText

    ; Install step
    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w330 vStep4Title Hidden", "Installing")
    Step4Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")

    ctrl := MainGui.Add("Text", "x200 y70 w330 vStep4Desc Hidden", "Please wait while AI Text Tools is being installed...")
    Step4Controls.Push(ctrl)

    ProgressBar := MainGui.Add("Progress", "x200 y120 w330 h25 vProgressBar Hidden", 0)
    Step4Controls.Push(ProgressBar)

    ProgressText := MainGui.Add("Text", "x200 y155 w330 vProgressText Hidden", "Preparing...")
    Step4Controls.Push(ProgressText)
}

; === SHOW/HIDE FUNCTIONS ===

ShowStep1() {
    global Step1Controls
    for ctrl in Step1Controls
        ctrl.Visible := true
}

HideStep1() {
    global Step1Controls
    for ctrl in Step1Controls
        ctrl.Visible := false
}

ShowStep2() {
    global Step2Controls
    for ctrl in Step2Controls
        ctrl.Visible := true
}

HideStep2() {
    global Step2Controls
    for ctrl in Step2Controls
        ctrl.Visible := false
}

ShowStep3() {
    global Step3Controls
    for ctrl in Step3Controls
        ctrl.Visible := true
}

HideStep3() {
    global Step3Controls
    for ctrl in Step3Controls
        ctrl.Visible := false
}

ShowStep4() {
    global Step4Controls
    for ctrl in Step4Controls
        ctrl.Visible := true
}

HideStep4() {
    global Step4Controls
    for ctrl in Step4Controls
        ctrl.Visible := false
}

; === NAVIGATION ===

OnBackBtn(ctrl, info) {
    global CurrentStep
    if CurrentStep > 1 {
        CurrentStep--
        UpdateStep()
    }
}

OnNextBtn(ctrl, info) {
    global CurrentStep, MainGui, InstallPath

    if CurrentStep = 2 {
        ; Validate and save install path
        InstallPath := MainGui["InstallPathEdit"].Value
        if InstallPath = "" {
            MainGui.Opt("-AlwaysOnTop")
            MsgBox("Please enter an installation path.", "AI Text Tools Setup", "Icon! Owner" MainGui.Hwnd)
            MainGui.Opt("+AlwaysOnTop")
            return
        }
    }

    if CurrentStep = 3 {
        ; Save options and start installation
        SaveOptions()
        CurrentStep++
        UpdateStep()
        StartInstallation()
        return
    }

    if CurrentStep < 4 {
        CurrentStep++
        UpdateStep()
    }
}

OnCancelBtn(ctrl, info) {
    CancelInstall()
}

OnGuiClose(gui) {
    CancelInstall()
}

CancelInstall() {
    global MainGui, InstallComplete

    ; If installation is complete, just exit without confirmation
    if InstallComplete {
        ExitApp
    }

    MainGui.Opt("-AlwaysOnTop")
    result := MsgBox("Are you sure you want to cancel the installation?", "AI Text Tools Setup", "YesNo Icon? Owner" MainGui.Hwnd)
    if result = "Yes" {
        ExitApp
    }
    MainGui.Opt("+AlwaysOnTop")
}

UpdateStep() {
    global CurrentStep, MainGui

    ; Hide all steps
    HideStep1()
    HideStep2()
    HideStep3()
    HideStep4()

    ; Show current step
    switch CurrentStep {
        case 1: ShowStep1()
        case 2: ShowStep2()
        case 3: ShowStep3()
        case 4: ShowStep4()
    }

    ; Update sidebar highlighting
    MainGui["SideStep1"].SetFont(CurrentStep = 1 ? "Bold" : "Norm")
    MainGui["SideStep2"].SetFont(CurrentStep = 2 ? "Bold" : "Norm")
    MainGui["SideStep3"].SetFont(CurrentStep = 3 ? "Bold" : "Norm")
    MainGui["SideStep4"].SetFont(CurrentStep = 4 ? "Bold" : "Norm")

    ; Update button states
    MainGui["BackBtn"].Enabled := (CurrentStep > 1 && CurrentStep < 4)
    MainGui["NextBtn"].Enabled := (CurrentStep < 4)

    if CurrentStep = 3
        MainGui["NextBtn"].Text := "Install"
    else
        MainGui["NextBtn"].Text := "Next >"
}

OnBrowse(ctrl, info) {
    global MainGui, InstallPath
    folder := DirSelect("*" InstallPath, 3, "Select installation folder")
    if folder {
        MainGui["InstallPathEdit"].Value := folder
    }
}

SaveOptions() {
    global MainGui, CreateDesktopShortcut, CreateStartMenuShortcut, LaunchAfterInstall
    global RunOnStartup, StartMinimized
    CreateDesktopShortcut := MainGui["DesktopShortcut"].Value
    CreateStartMenuShortcut := MainGui["StartMenuShortcut"].Value
    RunOnStartup := MainGui["RunOnStartup"].Value
    StartMinimized := MainGui["StartMinimized"].Value
    LaunchAfterInstall := MainGui["LaunchAfter"].Value
}

; === INSTALLATION ===

StartInstallation() {
    global MainGui, ProgressBar, ProgressText, InstallPath, SourceDir
    global CreateDesktopShortcut, CreateStartMenuShortcut, LaunchAfterInstall
    global RunOnStartup, StartMinimized
    global InstallComplete

    ; Disable buttons during installation
    MainGui["BackBtn"].Enabled := false
    MainGui["NextBtn"].Enabled := false
    MainGui["CancelBtn"].Enabled := false

    try {
        ; Step 1: Create installation directory
        ProgressText.Value := "Creating installation folder..."
        ProgressBar.Value := 10
        Sleep(200)

        if !DirExist(InstallPath) {
            DirCreate(InstallPath)
        }

        ; Step 2: Copy main executable
        ProgressText.Value := "Copying application files..."
        ProgressBar.Value := 30
        Sleep(200)

        ; Copy the main exe (standalone - no AutoHotkey required)
        if FileExist(SourceDir "\AITextTools.exe") {
            FileCopy(SourceDir "\AITextTools.exe", InstallPath "\AITextTools.exe", true)
        } else {
            throw Error("AITextTools.exe not found in installation package")
        }

        ; Step 3: Copy supporting files
        ProgressText.Value := "Copying configuration files..."
        ProgressBar.Value := 50
        Sleep(200)

        ; Copy settings.default.ini (check multiple locations)
        if FileExist(SourceDir "\settings.default.ini") {
            FileCopy(SourceDir "\settings.default.ini", InstallPath "\settings.default.ini", true)
        } else if FileExist(SourceDir "\src\settings.default.ini") {
            FileCopy(SourceDir "\src\settings.default.ini", InstallPath "\settings.default.ini", true)
        }

        ; Copy icon if exists
        if FileExist(SourceDir "\icon.ico") {
            FileCopy(SourceDir "\icon.ico", InstallPath "\icon.ico", true)
        } else if FileExist(SourceDir "\assets\icon.ico") {
            FileCopy(SourceDir "\assets\icon.ico", InstallPath "\icon.ico", true)
        }

        ; Copy uninstaller
        if FileExist(SourceDir "\Uninstall.exe") {
            FileCopy(SourceDir "\Uninstall.exe", InstallPath "\Uninstall.exe", true)
        } else {
            throw Error("Uninstall.exe not found in installation package")
        }

        ; Step 4: Create shortcuts
        ProgressText.Value := "Creating shortcuts..."
        ProgressBar.Value := 70
        Sleep(200)

        exePath := InstallPath "\AITextTools.exe"
        iconPath := FileExist(InstallPath "\icon.ico") ? InstallPath "\icon.ico" : exePath

        if CreateDesktopShortcut {
            CreateShortcut(A_Desktop "\AI Text Tools.lnk", exePath, InstallPath, iconPath)
        }

        if CreateStartMenuShortcut {
            startMenuFolder := A_Programs "\AI Text Tools"
            if !DirExist(startMenuFolder)
                DirCreate(startMenuFolder)
            CreateShortcut(startMenuFolder "\AI Text Tools.lnk", exePath, InstallPath, iconPath)
            ; Add uninstaller shortcut to start menu
            if FileExist(InstallPath "\Uninstall.exe") {
                CreateShortcut(startMenuFolder "\Uninstall AI Text Tools.lnk", InstallPath "\Uninstall.exe", InstallPath, InstallPath "\Uninstall.exe")
            }
        }

        ; Step 5: Create registry entries
        ProgressText.Value := "Creating registry entries..."
        ProgressBar.Value := 85
        Sleep(200)

        ; Add to Add/Remove Programs
        regKey := "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AITextTools"
        RegWrite("AI Text Tools", "REG_SZ", regKey, "DisplayName")
        RegWrite(InstallPath "\Uninstall.exe", "REG_SZ", regKey, "UninstallString")
        RegWrite(iconPath, "REG_SZ", regKey, "DisplayIcon")
        RegWrite("Jamie Bykov-Brett", "REG_SZ", regKey, "Publisher")
        RegWrite("1.4.2", "REG_SZ", regKey, "DisplayVersion")
        RegWrite(InstallPath, "REG_SZ", regKey, "InstallLocation")

        ; Apply startup settings
        ProgressText.Value := "Applying settings..."
        ProgressBar.Value := 90
        Sleep(200)

        ; Create AppData settings folder and write settings
        appDataDir := A_AppData "\AI Text Tools"
        if !DirExist(appDataDir)
            DirCreate(appDataDir)
        settingsFile := appDataDir "\settings.ini"

        ; Write startup settings
        IniWrite(StartMinimized ? "1" : "0", settingsFile, "General", "StartMinimized")
        IniWrite("0", settingsFile, "General", "FirstLaunch")

        ; Add to Windows startup if requested (with /startup flag to suppress settings window)
        if RunOnStartup {
            startupKey := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
            RegWrite('"' exePath '" /startup', "REG_SZ", startupKey, "AITextTools")
        }

        ; Step 6: Complete
        ProgressText.Value := "Installation complete!"
        ProgressBar.Value := 100
        Sleep(500)

        ; Mark installation as complete
        InstallComplete := true

        ; Update UI for completion
        MainGui["Step4Title"].Value := "Installation Complete"
        MainGui["Step4Desc"].Value := "AI Text Tools has been successfully installed.`n`nYou can now use the application by pressing Ctrl+Shift+J on selected text."

        ; Enable cancel button as "Finish"
        MainGui["CancelBtn"].Text := "Finish"
        MainGui["CancelBtn"].Enabled := true

        ; Launch app if requested (with delay to allow installer to close)
        if LaunchAfterInstall {
            ; Use a timer to launch after a short delay
            SetTimer () => LaunchApp(exePath), -2000
        }

    } catch as e {
        MainGui.Opt("-AlwaysOnTop")
        MsgBox("Installation failed: " e.Message "`n`nPlease try running the installer as administrator.", "AI Text Tools Setup", "IconX Owner" MainGui.Hwnd)
        MainGui.Opt("+AlwaysOnTop")
        MainGui["CancelBtn"].Enabled := true
    }
}

OnFinish(ctrl, info) {
    ExitApp
}

LaunchApp(exePath) {
    ; Use explorer.exe to launch as normal user (not admin)
    try Run('explorer.exe "' exePath '"')
}

CreateShortcut(shortcutPath, targetPath, workingDir, iconPath) {
    try {
        shell := ComObject("WScript.Shell")
        shortcut := shell.CreateShortcut(shortcutPath)
        shortcut.TargetPath := targetPath
        shortcut.WorkingDirectory := workingDir
        shortcut.IconLocation := iconPath
        shortcut.Description := "AI-powered text transformation"
        shortcut.Save()
    } catch as e {
        ; Silent fail for shortcuts
    }
}
