extends Node
## Applies the player's saved language (falls back to the OS locale) and
## persists changes. Translations live in res://localization/translations.csv.

signal language_changed(locale: String)

const SETTINGS_PATH := "user://settings.cfg"

## Locale code -> native display name, for a future language picker.
const LANGUAGES := {
	"en": "English",
	"az": "Azərbaycanca",
	"tr": "Türkçe",
	"ru": "Русский",
	"uk": "Українська",
	"de": "Deutsch",
	"fr": "Français",
	"es": "Español",
	"it": "Italiano",
	"pt_BR": "Português (Brasil)",
	"pl": "Polski",
	"ja": "日本語",
	"zh_CN": "简体中文",
	"kk": "Қазақша",
	"ka": "ქართული",
	"ar": "العربية",
}

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved: String = config.get_value("general", "language", "")
		if LANGUAGES.has(saved):
			TranslationServer.set_locale(saved)

func set_language(locale: String) -> void:
	if not LANGUAGES.has(locale):
		push_warning("Unsupported language: %s" % locale)
		return
	TranslationServer.set_locale(locale)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("general", "language", locale)
	config.save(SETTINGS_PATH)
	language_changed.emit(locale)
