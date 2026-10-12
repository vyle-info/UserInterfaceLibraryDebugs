local ObsidianTypes = require("./UserInterfaceLibrary/source/Library.d")

return {
    Library = (require("./UserInterfaceLibrary/source/Library") :: any) :: ObsidianTypes.Library,
    Types = ObsidianTypes,
    ConfigManager = require("./UserInterfaceLibrary/addons/ConfigManager"),
    ThemeManager = require("./UserInterfaceLibrary/addons/ThemeManager")
}
