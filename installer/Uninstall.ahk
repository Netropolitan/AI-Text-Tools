#Requires AutoHotkey v2.0
#SingleInstance Force

; Compiler directives
;@Ahk2Exe-SetName AI Text Tools Uninstaller
;@Ahk2Exe-SetDescription AI Text Tools Uninstaller
;@Ahk2Exe-SetVersion 1.5.2
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Jamie Bykov-Brett

; Check for admin rights and elevate if needed
if !A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
        ExitApp
    } catch {
        MsgBox("This uninstaller requires administrator privileges.`n`nPlease right-click and select 'Run as administrator'.", "Administrator Required", "IconX")
        ExitApp
    }
}

; Global variables
global MainGui := ""
global CurrentStep := 1
global RemoveSettings := true
global RemoveShortcuts := true
global UninstallComplete := false

; Step controls
global Step1Controls := []
global Step2Controls := []
global Step3Controls := []
global ProgressBar := ""
global ProgressText := ""

; Installation path (detect from registry or script location)
global InstallPath := DetectInstallPath()

SetupUninstaller()

DetectInstallPath() {
    ; Try to get from registry first
    try {
        path := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AITextTools", "InstallLocation")
        if path && DirExist(path)
            return path
    }

    ; Fall back to script directory
    return A_ScriptDir
}

SetupUninstaller() {
    global MainGui

    ; Create main window
    MainGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", "Uninstall AI Text Tools")
    MainGui.SetFont("s10", "Segoe UI")
    MainGui.BackColor := "FFFFFF"

    ; Left sidebar (red theme for uninstall)
    MainGui.Add("Text", "x0 y0 w180 h350 BackgroundDC2626")

    ; Sidebar title
    MainGui.SetFont("Bold s14 cFFFFFF")
    MainGui.Add("Text", "x15 y20 w150 BackgroundTrans", "AI Text Tools")
    MainGui.SetFont("Norm s9 cFFFFFF")
    MainGui.Add("Text", "x15 y45 w150 BackgroundTrans", "Uninstall Wizard")

    ; Step indicators
    MainGui.SetFont("s10 cFFFFFF")
    MainGui.Add("Text", "x15 y100 w150 BackgroundTrans vSideStep1", "1. Confirm")
    MainGui.Add("Text", "x15 y130 w150 BackgroundTrans vSideStep2", "2. Options")
    MainGui.Add("Text", "x15 y160 w150 BackgroundTrans vSideStep3", "3. Uninstall")

    ; Reset font
    MainGui.SetFont("Norm s10 c000000", "Segoe UI")

    ; Build steps
    BuildStep1()
    BuildStep2()
    BuildStep3()

    ; Show step 1
    ShowStep1()
    HideStep2()
    HideStep3()

    ; Navigation buttons
    MainGui.Add("Button", "x200 y310 w80 h30 vBackBtn", "< Back").OnEvent("Click", OnBackBtn)
    MainGui.Add("Button", "x290 y310 w80 h30 vNextBtn", "Next >").OnEvent("Click", OnNextBtn)
    MainGui.Add("Button", "x420 y310 w80 h30 vCancelBtn", "Cancel").OnEvent("Click", OnCancelBtn)

    MainGui["BackBtn"].Enabled := false

    MainGui.OnEvent("Close", OnGuiClose)
    MainGui.OnEvent("Escape", OnGuiClose)

    MainGui.Show("w520 h350")
}

BuildStep1() {
    global MainGui, Step1Controls, InstallPath

    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w300 vStep1Title", "Uninstall AI Text Tools?")
    Step1Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")

    ctrl := MainGui.Add("Text", "x200 y70 w300 vStep1Desc", "This will remove AI Text Tools from your computer.`n`nInstall location:`n" InstallPath)
    Step1Controls.Push(ctrl)

    ctrl := MainGui.Add("Text", "x200 y180 w300 c666666 vStep1Note", "Click Next to choose uninstall options.")
    Step1Controls.Push(ctrl)
}

BuildStep2() {
    global MainGui, Step2Controls

    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w300 vStep2Title Hidden", "Uninstall Options")
    Step2Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")

    ctrl := MainGui.Add("Text", "x200 y70 w300 vStep2Desc Hidden", "Choose what to remove:")
    Step2Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y110 w300 vRemoveSettingsCheck Checked Hidden", "Remove settings (stored in AppData)")
    Step2Controls.Push(ctrl)

    ctrl := MainGui.Add("Checkbox", "x200 y140 w300 vRemoveShortcutsCheck Checked Hidden", "Remove desktop and Start Menu shortcuts")
    Step2Controls.Push(ctrl)

    ctrl := MainGui.Add("Text", "x200 y190 w300 c666666 vStep2Note Hidden", "Note: API keys stored in Windows Credential Manager`nwill not be removed automatically.")
    Step2Controls.Push(ctrl)
}

BuildStep3() {
    global MainGui, Step3Controls, ProgressBar, ProgressText

    MainGui.SetFont("Bold s14")
    ctrl := MainGui.Add("Text", "x200 y30 w300 vStep3Title Hidden", "Uninstalling")
    Step3Controls.Push(ctrl)
    MainGui.SetFont("Norm s10")

    ctrl := MainGui.Add("Text", "x200 y70 w300 vStep3Desc Hidden", "Please wait while AI Text Tools is being removed...")
    Step3Controls.Push(ctrl)

    ProgressBar := MainGui.Add("Progress", "x200 y120 w300 h25 vProgressBar Hidden cDC2626", 0)
    Step3Controls.Push(ProgressBar)

    ProgressText := MainGui.Add("Text", "x200 y155 w300 vProgressText Hidden", "Preparing...")
    Step3Controls.Push(ProgressText)
}

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

OnBackBtn(ctrl, info) {
    global CurrentStep
    if CurrentStep > 1 {
        CurrentStep--
        UpdateStep()
    }
}

OnNextBtn(ctrl, info) {
    global CurrentStep, MainGui, RemoveSettings, RemoveShortcuts

    if CurrentStep = 2 {
        ; Save options
        RemoveSettings := MainGui["RemoveSettingsCheck"].Value
        RemoveShortcuts := MainGui["RemoveShortcutsCheck"].Value
        CurrentStep++
        UpdateStep()
        StartUninstall()
        return
    }

    if CurrentStep < 3 {
        CurrentStep++
        UpdateStep()
    }
}

OnCancelBtn(ctrl, info) {
    CancelUninstall()
}

OnGuiClose(gui) {
    CancelUninstall()
}

CancelUninstall() {
    global MainGui, UninstallComplete

    ; If uninstall is complete, just exit without confirmation
    if UninstallComplete {
        ; Run the cleanup batch if it exists
        batchPath := A_Temp "\uninstall_cleanup.bat"
        if FileExist(batchPath) {
            try Run(batchPath, , "Hide")
        }
        ExitApp
    }

    MainGui.Opt("-AlwaysOnTop")
    result := MsgBox("Are you sure you want to cancel?", "Uninstall AI Text Tools", "YesNo Icon? Owner" MainGui.Hwnd)
    if result = "Yes" {
        ExitApp
    }
    MainGui.Opt("+AlwaysOnTop")
}

UpdateStep() {
    global CurrentStep, MainGui

    HideStep1()
    HideStep2()
    HideStep3()

    switch CurrentStep {
        case 1: ShowStep1()
        case 2: ShowStep2()
        case 3: ShowStep3()
    }

    MainGui["SideStep1"].SetFont(CurrentStep = 1 ? "Bold" : "Norm")
    MainGui["SideStep2"].SetFont(CurrentStep = 2 ? "Bold" : "Norm")
    MainGui["SideStep3"].SetFont(CurrentStep = 3 ? "Bold" : "Norm")

    MainGui["BackBtn"].Enabled := (CurrentStep > 1 && CurrentStep < 3)
    MainGui["NextBtn"].Enabled := (CurrentStep < 3)

    if CurrentStep = 2
        MainGui["NextBtn"].Text := "Uninstall"
    else
        MainGui["NextBtn"].Text := "Next >"
}

StartUninstall() {
    global MainGui, ProgressBar, ProgressText, InstallPath, RemoveSettings, RemoveShortcuts
    global UninstallComplete

    MainGui["BackBtn"].Enabled := false
    MainGui["NextBtn"].Enabled := false
    MainGui["CancelBtn"].Enabled := false

    try {
        ; Close running instance first
        ProgressText.Value := "Closing AI Text Tools..."
        ProgressBar.Value := 10
        Sleep(200)

        ; Try to close any running instance
        DetectHiddenWindows(true)
        try {
            if WinExist("AI Text Tools Settings") {
                PostMessage(0x0010)  ; WM_CLOSE to last found window
                Sleep(500)
            }
        }

        ; Remove startup registry entry
        ProgressText.Value := "Removing startup entry..."
        ProgressBar.Value := 20
        Sleep(200)
        try RegDelete("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", "AITextTools")

        ; Remove shortcuts
        if RemoveShortcuts {
            ProgressText.Value := "Removing shortcuts..."
            ProgressBar.Value := 35
            Sleep(200)

            ; Desktop shortcut
            try FileDelete(A_Desktop "\AI Text Tools.lnk")

            ; Start Menu shortcuts
            startMenuFolder := A_Programs "\AI Text Tools"
            if DirExist(startMenuFolder) {
                try DirDelete(startMenuFolder, true)
            }
        }

        ; Remove settings from AppData
        if RemoveSettings {
            ProgressText.Value := "Removing settings..."
            ProgressBar.Value := 50
            Sleep(200)

            appDataDir := A_AppData "\AI Text Tools"
            if DirExist(appDataDir) {
                try DirDelete(appDataDir, true)
            }
        }

        ; Remove Add/Remove Programs entry
        ProgressText.Value := "Removing registry entries..."
        ProgressBar.Value := 65
        Sleep(200)
        try RegDeleteKey("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AITextTools")

        ; Remove program files
        ProgressText.Value := "Removing program files..."
        ProgressBar.Value := 80
        Sleep(200)

        ; Schedule deletion of install folder (can't delete while running)
        if InstallPath && DirExist(InstallPath) {
            ; Create a batch file to delete after exit
            batchPath := A_Temp "\uninstall_cleanup.bat"
            batchContent := "@echo off`r`n"
            batchContent .= "timeout /t 2 /nobreak >nul`r`n"
            batchContent .= 'rd /s /q "' InstallPath '"`r`n'
            batchContent .= 'del "%~f0"`r`n'
            try FileDelete(batchPath)
            FileAppend(batchContent, batchPath)
        }

        ; Complete
        ProgressText.Value := "Uninstall complete!"
        ProgressBar.Value := 100
        Sleep(500)

        ; Mark uninstall as complete
        UninstallComplete := true

        MainGui["Step3Title"].Value := "Uninstall Complete"
        MainGui["Step3Desc"].Value := "AI Text Tools has been removed from your computer.`n`nThe program folder will be deleted when you close this window."

        MainGui["CancelBtn"].Text := "Finish"
        MainGui["CancelBtn"].Enabled := true

    } catch as e {
        MainGui.Opt("-AlwaysOnTop")
        MsgBox("Uninstall encountered an error: " e.Message, "Uninstall AI Text Tools", "IconX Owner" MainGui.Hwnd)
        MainGui.Opt("+AlwaysOnTop")
        MainGui["CancelBtn"].Enabled := true
    }
}

OnFinish(ctrl, info) {
    global InstallPath

    ; Run the cleanup batch
    batchPath := A_Temp "\uninstall_cleanup.bat"
    if FileExist(batchPath) {
        Run(batchPath, , "Hide")
    }

    ExitApp
}

RegDeleteKey(key) {
    ; Delete a registry key and all its values
    try {
        RegDelete(key)
    }
    ; Use RunWait with reg.exe as fallback
    try {
        RunWait('reg delete "' key '" /f', , "Hide")
    }
}
