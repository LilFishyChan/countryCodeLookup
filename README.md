# Country Code Lookup — DMS launcher plugin

A DankMaterialShell (DMS) launcher plugin that recognises international phone
dial codes. Type a dial code in the launcher (default trigger `+`) and the
matching country appears as a result you can copy.

## Installation

```bash
# clone into the DMS plugins directory
git clone <this-repo-url> ~/.config/DankMaterialShell/plugins/countryCodeLookup
```

Then open **Settings → Plugins**, scan, and enable **Country Code Lookup**.

## Usage

1. Open the launcher (`Ctrl+Space` or the launcher button).
2. Type the trigger followed by a dial code. Matching is "smart":
   - `+86` → China (exact)
   - `+8` → **+81** Japan, **+82** South Korea, **+86** China, **+886** Taiwan … (prefix completion)
   - `+1` → **+1** United States / Canada, **+1 268** Antigua, **+1 767** Dominica, **+1 787** Puerto Rico … — the extra digits are shown for every shared code, not just +1
   - `+1268` and `+1 268` → Antigua and Barbuda
   - `+1829` → Dominican Republic (its other codes `+1 809`, `+1 849` are shown as hints)
   - `+44` → United Kingdom, Guernsey, Isle of Man, Jersey (a code shared by several countries)
   - `+8613800138000` → China (a pasted full number matches its calling code)
   - `+8` also lists fuzzy hits such as `+48` Poland, `+58` Venezuela, `+98` Iran (when Fuzzy Matching is on)
3. Press Enter on a result to copy the country name to the clipboard.

When only the trigger (`+`) is typed, a short hint is shown.

### Search by country name

Type a country name instead of a code — no trigger needed — and the result
shows the dial code; pressing Enter copies the dial code.

- `China` / `中国` → `+86`
- `japan` / `日本` → `+81`
- `中国` also lists `中国 香港` (+852), `中国 澳门` (+853), `中国 台湾` (+886)
- `korea` → `+82` South Korea, `+850` North Korea

Name matching is case-insensitive and matches against every translated name, so
you can search `China`, `中国`, `chine`, `japan` or `日本` regardless of the
display language. Dependent territories can be found by their sovereign too
(`kingdom` lists the UK territories, `美国` lists the US ones).

### Shared codes

Matching is done against **every** dial code a country owns, so both the short
form and the extended form work (`+1268` = `+1 268`). When a country only has
one base code but several sub-codes (the +1 area-code list), the item shows the
base code (`+1`) and lists a few sub-codes as a hint; when the country has
distinct short codes (`+1 809 / +1 829 / +1 849`), the matched one is shown and
the others are listed too.

### Dependent territories

Dependent territories are labelled with the state they belong to, in every
language:

| Code | Chinese | English |
|------|---------|---------|
| +852 | 中国 香港 | Hong Kong (China) |
| +853 | 中国 澳门 | Macau (China) |
| +886 | 中国 台湾 | Taiwan (China) |
| +1787 | 美国 波多黎各 | Puerto Rico (United States) |
| +299 | 丹麦 格陵兰 | Greenland (Denmark) |
| +687 | 法国 新喀里多尼亚 | New Caledonia (France) |
| +690 | 新西兰 托克劳 | Tokelau (New Zealand) |

Names that already indicate the metropole (`美属维尔京群岛`, `法属波利尼西亚`,
`French Southern and Antarctic Lands`) are left as-is. Disputed or observer
entities (Western Sahara, Palestine, Kosovo) are not annotated.


### How matching is ranked

1. **Exact** — `+86`
2. **Prefix** — codes that start with what you typed (`+8` → `+8x`)
3. **Full number** — a longer number is matched against its leading calling code
4. **Root** — fallback to the shared country code (`+1202` → `+1`)
5. **Fuzzy** — codes that merely contain the digits (`+8` → `+x8`, e.g. `+48`). Fuzzy results are only added when there are fewer than 15 stronger matches, so `+1` stays focused on the real +1 codes.

## Settings

Open **Settings → Plugins → Country Code Lookup**:

| Setting | Default | Description |
|---------|---------|-------------|
| Language | English | Language for country names. Missing translations fall back to English. |
| Copy Format | Country name | `China` / `China (+86)` / `+86 China` |
| Fuzzy Matching | on | Also suggest codes that contain the typed digits; exact/prefix always come first. |
| Trigger | `+` | Prefix typed before the dial code. |
| Always Active | off | Run the lookup on every search instead of only after the trigger. |


## Data

`data/country_codes.json` contains 247 territories with their calling codes
(`root` + `suffixes`), a flag emoji and country names in 27 languages.

- Country names come from RestCountries v3.1 data (26 languages).
- English names come from the canonical upstream `mledoze/countries` dataset.
- A few gaps in the source were filled from the same upstream (and one manual
  entry for Indonesian), so every language is complete.
- Dependent territories are annotated with the state they belong to
  (see above).

The file is stored in a readable, formatter-friendly layout (objects expanded,
arrays kept on one line when they fit).

## Files

- `plugin.json` — manifest (`type: launcher`, `trigger: +`)
- `CountryCodeLauncher.qml` — launcher provider (`getItems` / `executeItem`)
- `CountryCodeSettings.qml` — settings UI
- `translations/zh.json` — Chinese translation of the UI strings (English is the source)
- `data/country_codes.json` — dial codes and translated country names

## Development

### Translations

The settings UI and the launcher hint are translated through DMS's `I18n`
service. Add a `translations/<locale>.json` file (for example `de.json`) with
the shape `{ "English source": { "English source": "translation" } }` and wrap
new strings with `I18n.trFor("countryCodeLookup", "English source")`. The
`zh.json` file is a complete example.

## License

MIT — see `LICENSE`.

