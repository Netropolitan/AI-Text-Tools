#Requires AutoHotkey v2.0

/**
 * PromptsTab - Prompts tab content for settings window
 *
 * Provides CRUD interface for custom prompts. Default prompts
 * are displayed but protected from edit/delete.
 */
class PromptsTab {
    static PromptList := ""
    static PreviewEdit := ""
    static SelectedPrompt := ""
    static Config := ""

    /**
     * Build Prompts tab content
     * @param {Gui} settingsGui - Parent settings GUI
     * @param {ConfigManager} config - Config manager instance
     */
    static Build(settingsGui, config) {
        this.Config := config

        ; Load custom prompts
        CustomPromptManager.Load(config)

        ; Prompt list label
        settingsGui.Add("Text", "x20 y40", "Prompts:")

        ; ListView for prompts
        this.PromptList := settingsGui.Add("ListView", "x20 y65 w400 h300 -Multi", ["Name", "Category", "Type"])
        this.PromptList.OnEvent("DoubleClick", (*) => this.OnEdit())
        this.PromptList.OnEvent("ItemSelect", (*) => this.OnSelect())

        ; Populate list
        this.RefreshList()

        ; Buttons
        addBtn := settingsGui.Add("Button", "x430 y65 w100", "Add")
        addBtn.OnEvent("Click", (*) => this.OnAdd())

        editBtn := settingsGui.Add("Button", "x430 y100 w100", "Edit")
        editBtn.OnEvent("Click", (*) => this.OnEdit())

        deleteBtn := settingsGui.Add("Button", "x430 y135 w100", "Delete")
        deleteBtn.OnEvent("Click", (*) => this.OnDelete())

        ; Preview area
        settingsGui.Add("Text", "x20 y375", "System Prompt Preview:")
        this.PreviewEdit := settingsGui.Add("Edit", "x20 y395 w510 h50 ReadOnly Multi")
    }

    /**
     * Refresh the prompts ListView
     */
    static RefreshList() {
        this.PromptList.Delete()

        prompts := CustomPromptManager.GetAllPrompts()
        for prompt in prompts {
            typeStr := prompt.isCustom ? "Custom" : "Default"
            this.PromptList.Add(, prompt.name, prompt.category, typeStr)
        }

        ; Adjust column widths
        this.PromptList.ModifyCol(1, 200)
        this.PromptList.ModifyCol(2, 100)
        this.PromptList.ModifyCol(3, 80)
    }

    /**
     * Handle selection change
     */
    static OnSelect() {
        row := this.PromptList.GetNext()
        if !row
            return

        ; Find the prompt
        prompts := CustomPromptManager.GetAllPrompts()
        if row <= prompts.Length {
            this.SelectedPrompt := prompts[row]
            this.PreviewEdit.Value := this.SelectedPrompt.system
        }
    }

    /**
     * Handle Add button click
     */
    static OnAdd() {
        this.ShowPromptEditor("")
    }

    /**
     * Handle Edit button click
     */
    static OnEdit() {
        if !this.SelectedPrompt
            return

        if !this.SelectedPrompt.isCustom {
            MsgBox("Default prompts cannot be edited.", "AI Text Tools", "Icon!")
            return
        }

        this.ShowPromptEditor(this.SelectedPrompt.id)
    }

    /**
     * Handle Delete button click
     */
    static OnDelete() {
        if !this.SelectedPrompt
            return

        if !this.SelectedPrompt.isCustom {
            MsgBox("Default prompts cannot be deleted.", "AI Text Tools", "Icon!")
            return
        }

        result := MsgBox("Delete prompt '" this.SelectedPrompt.name "'?", "Confirm Delete", "YesNo Icon?")
        if result = "Yes" {
            CustomPromptManager.Delete(this.SelectedPrompt.id, this.Config)
            this.SelectedPrompt := ""
            this.PreviewEdit.Value := ""
            this.RefreshList()
        }
    }

    /**
     * Show prompt editor dialog
     * @param {string} promptId - Empty for new, ID for edit
     */
    static ShowPromptEditor(promptId) {
        ; Create editor dialog (owned by settings window)
        editor := Gui("+Owner" SettingsWindow.Gui.Hwnd, promptId ? "Edit Prompt" : "Add Prompt")
        editor.SetFont("s10", "Segoe UI")

        ; Disable parent window to simulate modal behavior
        SettingsWindow.Gui.Opt("+Disabled")

        ; Get existing values if editing
        existing := promptId ? CustomPromptManager.Get(promptId) : ""

        ; ID field
        editor.Add("Text", , "ID (unique, no spaces):")
        idEdit := editor.Add("Edit", "w300", existing ? existing.id : "")
        if existing
            idEdit.Opt("+Disabled")  ; Can't change ID

        ; Name field
        editor.Add("Text", , "Name:")
        nameEdit := editor.Add("Edit", "w300", existing ? existing.name : "")

        ; Category dropdown
        editor.Add("Text", , "Category:")
        categories := ["Writing", "Analysis", "Creative", "Legal", "Email", "Social", "Code", "Custom"]
        catEdit := editor.Add("DropDownList", "w300", categories)
        if existing {
            ; Select matching category
            for i, cat in categories {
                if cat = existing.category {
                    catEdit.Choose(i)
                    break
                }
            }
        } else {
            catEdit.Choose(8)  ; Default to Custom
        }

        ; System prompt field
        editor.Add("Text", , "System Prompt:")
        sysEdit := editor.Add("Edit", "w300 h100 Multi", existing ? existing.system : "")

        ; Save button
        saveBtn := editor.Add("Button", "w100", "Save")
        saveBtn.OnEvent("Click", (*) => this.SavePrompt(editor, idEdit, nameEdit, catEdit, sysEdit, promptId))

        ; Cancel button
        cancelBtn := editor.Add("Button", "x+10 w100", "Cancel")
        cancelBtn.OnEvent("Click", (*) => this.CloseEditor(editor))

        editor.OnEvent("Escape", (*) => this.CloseEditor(editor))
        editor.OnEvent("Close", (*) => this.CloseEditor(editor))
        editor.Show()
    }

    /**
     * Close editor and re-enable parent window
     */
    static CloseEditor(editor) {
        SettingsWindow.Gui.Opt("-Disabled")
        editor.Destroy()
    }

    /**
     * Save prompt from editor dialog
     */
    static SavePrompt(editor, idEdit, nameEdit, catEdit, sysEdit, existingId) {
        id := Trim(idEdit.Value)
        name := Trim(nameEdit.Value)
        category := catEdit.Text
        system := sysEdit.Value

        ; Validate
        if !id || !name || !system {
            MsgBox("All fields are required.", "Validation Error", "IconX")
            return
        }

        if !existingId && RegExMatch(id, "\s") {
            MsgBox("ID cannot contain spaces.", "Validation Error", "IconX")
            return
        }

        try {
            if existingId
                CustomPromptManager.Update(id, name, category, system)
            else
                CustomPromptManager.Add(id, name, category, system)

            CustomPromptManager.Save(this.Config)
            this.RefreshList()
            this.CloseEditor(editor)
        } catch as e {
            MsgBox("Error: " e.Message, "Save Failed", "IconX")
        }
    }
}
