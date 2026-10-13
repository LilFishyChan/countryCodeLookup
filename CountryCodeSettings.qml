import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "countryCodeLookup"

    // Localized UI text (DMS language); English is the source string.
    function tr(term) {
        if (typeof I18n !== "undefined")
            return I18n.trFor(pluginId, term);
        return term;
    }

    readonly property var languageOptions: [
        { label: "English", value: "eng" },
        { label: "中文 (Chinese)", value: "zho" },
        { label: "日本語 (Japanese)", value: "jpn" },
        { label: "한국어 (Korean)", value: "kor" },
        { label: "العربية (Arabic)", value: "ara" },
        { label: "Brezhoneg (Breton)", value: "bre" },
        { label: "Čeština (Czech)", value: "ces" },
        { label: "Cymraeg (Welsh)", value: "cym" },
        { label: "Deutsch (German)", value: "deu" },
        { label: "Eesti (Estonian)", value: "est" },
        { label: "Suomi (Finnish)", value: "fin" },
        { label: "Français (French)", value: "fra" },
        { label: "Hrvatski (Croatian)", value: "hrv" },
        { label: "Magyar (Hungarian)", value: "hun" },
        { label: "Bahasa Indonesia (Indonesian)", value: "ind" },
        { label: "Italiano (Italian)", value: "ita" },
        { label: "Nederlands (Dutch)", value: "nld" },
        { label: "فارسی (Persian)", value: "per" },
        { label: "Polski (Polish)", value: "pol" },
        { label: "Português (Portuguese)", value: "por" },
        { label: "Русский (Russian)", value: "rus" },
        { label: "Slovenčina (Slovak)", value: "slk" },
        { label: "Español (Spanish)", value: "spa" },
        { label: "Српски (Serbian)", value: "srp" },
        { label: "Svenska (Swedish)", value: "swe" },
        { label: "Türkçe (Turkish)", value: "tur" },
        { label: "اردو (Urdu)", value: "urd" }
    ]

    StyledText {
        width: parent.width
        text: root.tr("Country Code Lookup")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: root.tr("Type a phone dial code (e.g. +86) or a country name (e.g. China / 中国) in the launcher. Selecting a result copies it.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    SelectionSetting {
        id: languageSetting
        settingKey: "language"
        label: root.tr("Language")
        description: root.tr("Language used for the country names. Defaults to English; missing translations fall back to English.")
        defaultValue: "eng"
        options: root.languageOptions
    }

    SelectionSetting {
        id: copyFormatSetting
        settingKey: "copyFormat"
        label: root.tr("Copy Format")
        description: copyFormatSetting.value === "name_code"
            ? root.tr("Pressing Enter copies e.g. \"China (+86)\"")
            : copyFormatSetting.value === "code_name"
            ? root.tr("Pressing Enter copies e.g. \"+86 China\"")
            : root.tr("Pressing Enter copies just the country name, e.g. \"China\"")
        defaultValue: "name"
        options: [
            { label: root.tr("Country name"), value: "name" },
            { label: root.tr("Name (code)"), value: "name_code" },
            { label: root.tr("Code Name"), value: "code_name" }
        ]
    }

    ToggleSetting {
        id: fuzzyToggle
        settingKey: "fuzzyMatching"
        label: root.tr("Fuzzy Matching")
        description: fuzzyToggle.value
            ? root.tr("Also suggest codes that merely contain the typed digits (+8 → +48, +58, +98 …). Exact and prefix matches always come first.")
            : root.tr("Only suggest codes that start with the typed digits (+8 → +86, +81, +880 …).")
        defaultValue: true
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StringSetting {
        id: triggerSetting
        visible: !alwaysActiveToggle.value
        settingKey: "trigger"
        label: root.tr("Trigger")
        description: root.tr("Prefix typed before the dial code to activate the lookup (e.g. +, cc)")
        placeholder: "+"
        defaultValue: "+"
    }

    ToggleSetting {
        id: alwaysActiveToggle
        settingKey: "noTrigger"
        label: root.tr("Always Active")
        description: alwaysActiveToggle.value
            ? root.tr("The lookup runs on every search. Typing a phone number such as +86 still works.")
            : root.tr("Only activate after the trigger above is typed (default: +).")
        defaultValue: false
        onValueChanged: {
            if (!alwaysActiveToggle.isInitialized)
                return;
            if (value)
                root.saveValue("trigger", "");
            else
                root.saveValue("trigger", triggerSetting.value || "+");
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: root.tr("Examples")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXS
        leftPadding: Theme.spacingM
        bottomPadding: Theme.spacingL

        Repeater {
            model: [
                "+86      →  China",
                "+8       →  +81 Japan, +82 …, +86 China, +886 Taiwan …",
                "+1       →  +1 United States / Canada, +1 268 Antigua, +1 767 Dominica …",
                "+1268    →  Antigua and Barbuda   (= +1 268)",
                "China    →  China  +86",
                "中国      →  China +86, 中国 香港 +852, 中国 台湾 +886",
                "+44      →  United Kingdom, Guernsey, Isle of Man, Jersey …",
                "+8       →  also fuzzy: +48 Poland, +58 Venezuela, +98 Iran …"
            ]

            StyledText {
                required property string modelData
                text: "• " + modelData
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
