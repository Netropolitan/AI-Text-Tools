#Requires AutoHotkey v2.0

/**
 * CustomPromptManager - User-defined prompt storage with INI persistence
 *
 * Manages custom prompts created by users. Stores in INI file using
 * pipe-delimited format: id=name|category|system
 */
class CustomPromptManager {
    static CustomPrompts := Map()
    static ConfigSection := "CustomPrompts"

    /**
     * Load custom prompts from config
     * @param {ConfigManager} config - Config manager instance
     */
    static Load(config) {
        this.CustomPrompts := Map()

        ; Read all keys in CustomPrompts section
        ; Format: id=name|category|system
        section := config.GetSection(this.ConfigSection)

        for id, value in section {
            parts := StrSplit(value, "|", , 3)
            if parts.Length >= 3 {
                this.CustomPrompts[id] := {
                    id: id,
                    name: parts[1],
                    category: parts[2],
                    system: parts[3],
                    isCustom: true
                }
            }
        }
    }

    /**
     * Save all custom prompts to config
     * @param {ConfigManager} config - Config manager instance
     */
    static Save(config) {
        ; Write each custom prompt
        for id, prompt in this.CustomPrompts {
            value := prompt.name "|" prompt.category "|" prompt.system
            config.Set(this.ConfigSection, id, value)
        }
    }

    /**
     * Add new custom prompt
     * @param {string} id - Unique identifier (no spaces)
     * @param {string} name - Display name
     * @param {string} category - Category for grouping
     * @param {string} system - System prompt text
     */
    static Add(id, name, category, system) {
        if this.CustomPrompts.Has(id) || PromptManager.GetPrompt(id)
            throw Error("Prompt ID already exists: " id)

        this.CustomPrompts[id] := {
            id: id,
            name: name,
            category: category,
            system: system,
            isCustom: true
        }
    }

    /**
     * Update existing custom prompt
     * @param {string} id - Prompt identifier
     * @param {string} name - New display name
     * @param {string} category - New category
     * @param {string} system - New system prompt text
     */
    static Update(id, name, category, system) {
        if !this.CustomPrompts.Has(id)
            throw Error("Custom prompt not found: " id)

        this.CustomPrompts[id] := {
            id: id,
            name: name,
            category: category,
            system: system,
            isCustom: true
        }
    }

    /**
     * Delete custom prompt
     * @param {string} id - Prompt identifier
     * @param {ConfigManager} config - Config manager for persistence
     */
    static Delete(id, config) {
        if !this.CustomPrompts.Has(id)
            throw Error("Custom prompt not found: " id)

        this.CustomPrompts.Delete(id)
        config.Delete(this.ConfigSection, id)
    }

    /**
     * Get all prompts (default + custom) for display
     * @returns {Array} Array of prompt objects with isCustom flag
     */
    static GetAllPrompts() {
        result := []

        ; Add default prompts (marked as not editable)
        for id, prompt in PromptManager.GetAllPrompts() {
            result.Push({
                id: id,
                name: prompt.name,
                category: prompt.category,
                system: prompt.system,
                isCustom: false
            })
        }

        ; Add custom prompts
        for id, prompt in this.CustomPrompts {
            result.Push(prompt)
        }

        return result
    }

    /**
     * Get custom prompt by ID
     * @param {string} id - Prompt identifier
     * @returns {Object|""} Prompt object or empty string if not found
     */
    static Get(id) {
        return this.CustomPrompts.Has(id) ? this.CustomPrompts[id] : ""
    }
}
