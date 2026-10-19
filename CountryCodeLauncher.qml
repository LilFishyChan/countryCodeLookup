import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string pluginId: "countryCodeLookup"
    property string trigger: "+"
    property string language: "eng"
    property string copyFormat: "name"
    property bool fuzzyMatching: true

    property bool dataReady: false
    property var countries: []

    readonly property string fallbackLanguage: "eng"
    readonly property int maxResults: 50
    readonly property int maxFuzzyResults: 10
    readonly property int manyCodesThreshold: 4
    readonly property int maxExtras: 4

    signal itemsChanged

    // localized UI strings (DMS language); English is the source text
    function tr(term) {
        if (typeof I18n !== "undefined")
            return I18n.trFor(pluginId, term);
        return term;
    }

    // ------------------------------------------------------------------ data

    function pluginBaseDir() {
        if (pluginService && typeof pluginService.getPluginPath === "function") {
            var p = pluginService.getPluginPath(pluginId);
            if (p && p.length > 0)
                return p;
        }
        if (pluginService && pluginService.pluginDirectory)
            return pluginService.pluginDirectory + "/" + pluginId;
        return "";
    }

    // All dial codes that reach this country. A country either has one code
    // (root + suffix, e.g. +86) or a shared root with sub-codes (e.g. +1 767).
    // Suffixes longer than 3 digits are junk in the source data and dropped.
    function countryCodes(country) {
        var r = String(country.r || "");
        var out = [];
        if (Array.isArray(country.s)) {
            for (var i = 0; i < country.s.length; i++) {
                var s = country.s[i];
                if (s && s.length <= 3) {
                    var code = r + s;
                    if (out.indexOf(code) === -1)
                        out.push(code);
                }
            }
        }
        if (out.length === 0 && r.length > 0)
            out.push(r);
        return out;
    }

    // The code shown for a country that owns many sub-codes (e.g. the +1 area
    // code list) collapses to the root; otherwise the first code is used.
    function primaryCode(country, codes) {
        if (codes.length === 0)
            return "";
        if (codes.length > manyCodesThreshold)
            return String(country.r || codes[0]);
        return codes[0];
    }

    // NANP-style codes are shown in the conventional "+1 767" form.
    function formatCode(code) {
        if (code.length > 1 && code.charAt(0) === "1")
            return "+1 " + code.substring(1);
        return "+" + code;
    }

    function applyData(raw) {
        if (dataReady || !raw)
            return;
        try {
            var obj = JSON.parse(raw);
            if (!obj || !Array.isArray(obj.countries))
                return;
            var list = obj.countries;
            for (var i = 0; i < list.length; i++) {
                list[i]._codes = countryCodes(list[i]);
                list[i]._primary = primaryCode(list[i], list[i]._codes);
            }
            countries = list;
            dataReady = true;
        } catch (e) {
            console.log("[CountryCode] Failed to parse data:", e);
        }
    }

    property FileView dataFile: FileView {
        blockLoading: true
        blockWrites: true
        path: ""

        onLoaded: root.applyData(text())
        onLoadFailed: err => console.log("[CountryCode] Could not load dial code data:", err)
    }

    property Connections serviceConn: Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId !== root.pluginId)
                return;
            root.loadSettings();
            if (root.pluginService && typeof root.pluginService.requestLauncherUpdate === "function")
                root.pluginService.requestLauncherUpdate(root.pluginId);
            root.itemsChanged();
        }
    }

    Component.onCompleted: {
        if (!pluginService)
            return;
        loadSettings();
        var base = pluginBaseDir();
        if (base.length > 0)
            dataFile.path = base + "/data/country_codes.json";
        // blockLoading makes the content available immediately
        if (typeof dataFile.text === "function")
            applyData(dataFile.text());
    }

    function loadSettings() {
        trigger = pluginService.loadPluginData(pluginId, "trigger", "+");
        language = pluginService.loadPluginData(pluginId, "language", fallbackLanguage);
        copyFormat = pluginService.loadPluginData(pluginId, "copyFormat", "name");
        fuzzyMatching = pluginService.loadPluginData(pluginId, "fuzzyMatching", true);
    }

    // -------------------------------------------------------------- matching

    function normalize(text) {
        if (!text)
            return "";
        return String(text).replace(/\D/g, "");
    }

    function localizedName(country) {
        // Dependent territories carry an annotated name, e.g. "Hong Kong (China)".
        if (country.a) {
            if (country.a[language])
                return country.a[language];
            if (country.a[fallbackLanguage])
                return country.a[fallbackLanguage];
        }
        var names = country.n || {};
        if (names[language])
            return names[language];
        if (names[fallbackLanguage])
            return names[fallbackLanguage];
        for (var k in names) {
            if (names[k])
                return names[k];
        }
        return "Unknown";
    }

    // Every name a country is known by (all languages + annotated), for search.
    function nameValues(country) {
        var out = [];
        var names = country.n || {};
        for (var k in names) {
            if (names[k] && out.indexOf(names[k]) === -1)
                out.push(names[k]);
        }
        var ann = country.a || {};
        for (var k2 in ann) {
            if (ann[k2] && out.indexOf(ann[k2]) === -1)
                out.push(ann[k2]);
        }
        return out;
    }

    // rank: 3 exact, 2 prefix completion, 1 query is a longer number starting
    //       with the code, -1 fuzzy (code merely contains the digits).
    // Matches against every code the country owns, so +1268 and +1 268 both
    // find Antigua and +1829 finds the Dominican Republic too.
    function rankCountry(q, codes) {
        var rank = 0;
        var code = "";
        for (var i = 0; i < codes.length; i++) {
            var c = codes[i];
            if (c === q) {
                return {rank: 3, code: c};
            }
            if (c.indexOf(q) === 0) {
                if (rank < 2) {
                    rank = 2;
                    code = c;
                }
            } else if (c.length >= 2 && q.length > c.length && q.indexOf(c) === 0) {
                if (rank < 1) {
                    rank = 1;
                    code = c;
                }
            }
        }
        if (rank > 0)
            return {rank: rank, code: code};

        if (fuzzyMatching && q.length > 0 && codes.length <= manyCodesThreshold) {
            for (var j = 0; j < codes.length; j++) {
                var fc = codes[j];
                if (fc.indexOf(q) > 0 && fc.length <= q.length + 2)
                    return {rank: -1, code: fc};
            }
        }
        return {rank: 0, code: ""};
    }

    function findMatches(query) {
        var q = normalize(query);
        if (q.length === 0)
            return [];

        var exact = [], prefix = [], full = [], fuzzy = [], roots = [];

        for (var i = 0; i < countries.length; i++) {
            var c = countries[i];
            var codes = c._codes || [];
            if (codes.length === 0)
                continue;
            var res = rankCountry(q, codes);
            if (res.rank === 3)
                exact.push({c: c, code: res.code});
            else if (res.rank === 2)
                prefix.push({c: c, code: res.code});
            else if (res.rank === 1)
                full.push({c: c, code: res.code});
            else if (res.rank === -1)
                fuzzy.push({c: c, code: res.code});
        }

        if (exact.length === 0 && prefix.length === 0 && full.length === 0) {
            for (var j = 0; j < countries.length; j++) {
                var r = String(countries[j].r || "");
                if (r.length > 0 && (r === q || (q.length > r.length && q.indexOf(r) === 0)))
                    roots.push({c: countries[j], code: r});
            }
        }

        var strong = exact.length + prefix.length + full.length + roots.length;
        // Only add fuzzy hits when there are not already plenty of strong ones,
        // so "+1" stays focused on the actual +1 codes.
        if (strong >= 15)
            return exact.concat(prefix, full, roots);

        return exact.concat(prefix, full, roots, fuzzy.slice(0, maxFuzzyResults));
    }

    function makeItem(match, query) {
        var c = match.c;
        var name = localizedName(c);
        var english = (c.a && c.a.eng) ? c.a.eng : ((c.n && c.n.eng) ? c.n.eng : "");

        // Countries with a big sub-code list collapse to their root (+1),
        // everything else shows the exact code that was matched (+1 767).
        var displayRaw = (c._codes.length > manyCodesThreshold) ? c._primary : match.code;
        if (!displayRaw)
            displayRaw = c._primary || "";

        // A sub-code was matched when the user typed more than the shared root.
        var qn = normalize(query);
        var root = String(c.r || "");
        var matchedSub = !!match.code && match.code !== displayRaw && qn.length > root.length;

        var others = [];
        if (c._codes.length > 1) {
            for (var i = 0; i < c._codes.length; i++) {
                var code = c._codes[i];
                if (code !== displayRaw && code.length >= 3)
                    others.push(code);
            }
        }
        if (matchedSub) {
            var mi = others.indexOf(match.code);
            if (mi > 0) {
                others.splice(mi, 1);
                others.unshift(match.code);
            } else if (mi === -1) {
                others.unshift(match.code);
            }
        }

        var extrasTotal = others.length;
        var shownCodes = others.slice(0, maxExtras);
        var shown = [];
        for (var k = 0; k < shownCodes.length; k++)
            shown.push(formatCode(shownCodes[k]));

        var comment = formatCode(displayRaw);
        if (english && english !== name)
            comment += " · " + english;

        if (shown.length > 0) {
            var list = shown.join(", ");
            if (extrasTotal > shown.length)
                comment += " · " + tr("%1 (+%2 more)").arg(list).arg(extrasTotal - shown.length);
            else
                comment += " · " + list;
        }

        var keywords = [formatCode(displayRaw), displayRaw, english, query];
        return {
            name: name,
            icon: c.f ? ("unicode:" + c.f) : "material:public",
            comment: comment,
            action: "copy:" + name,
            displayName: name,
            dialCode: displayRaw,
            categories: ["Country Codes"],
            keywords: keywords
        };
    }

    function hintItem() {
        return {
            name: tr("Type a country dial code or name"),
            icon: "material:public",
            comment: tr("e.g. +86, +1 767, or search \"China\" / \"中国\""),
            action: "none",
            categories: ["Country Codes"]
        };
    }

    // Country-name search: matches any translated name (and the annotated
    // names of dependent territories), so "China", "中国" or "chine" all work.
    // The name that actually matched is the one displayed. Enter copies the code.
    function bestNameMatch(country, q) {
        var vals = nameValues(country);
        var best = 0;
        var bestName = "";
        var preferred = [];
        if (country.n && country.n[language]) preferred.push(country.n[language]);
        if (country.a && country.a[language]) preferred.push(country.a[language]);
        if (country.n && country.n[fallbackLanguage]) preferred.push(country.n[fallbackLanguage]);
        if (country.a && country.a[fallbackLanguage]) preferred.push(country.a[fallbackLanguage]);

        for (var j = 0; j < vals.length; j++) {
            var low = vals[j].toLowerCase();
            var score = 0;
            if (low === q)
                score = 3;
            else if (low.indexOf(q) === 0)
                score = 2;
            else if (low.indexOf(q) > 0)
                score = 1;
            if (score > best) {
                best = score;
                bestName = vals[j];
            } else if (score === best && score > 0 && bestName !== "" &&
                       preferred.indexOf(vals[j]) !== -1 && preferred.indexOf(bestName) === -1) {
                bestName = vals[j];
            }
        }
        return {score: best, name: bestName};
    }

    function makeNameItem(country, matchedName, query) {
        var name = matchedName || localizedName(country);
        var english = (country.a && country.a.eng) ? country.a.eng : ((country.n && country.n.eng) ? country.n.eng : "");
        var comment = formatCode(country._primary || "");
        if (english && english !== name)
            comment += " · " + english;

        var keywords = nameValues(country);
        if (query && keywords.indexOf(query) === -1)
            keywords.push(query);

        return {
            name: name,
            icon: country.f ? ("unicode:" + country.f) : "material:public",
            comment: comment,
            action: "copycode:" + (country._primary || ""),
            displayName: name,
            dialCode: country._primary || "",
            categories: ["Country Codes"],
            keywords: keywords
        };
    }

    function getNameItems(text) {
        var q = String(text).trim().toLowerCase();
        if (q.length === 0)
            return [];

        var exact = [], prefix = [], contains = [];
        for (var i = 0; i < countries.length; i++) {
            var res = bestNameMatch(countries[i], q);
            if (res.score === 0)
                continue;
            var hit = {country: countries[i], name: res.name};
            if (res.score === 3)
                exact.push(hit);
            else if (res.score === 2)
                prefix.push(hit);
            else
                contains.push(hit);
        }

        var ordered = exact.concat(prefix, contains);
        var items = [];
        var limit = Math.min(ordered.length, maxResults);
        for (var k = 0; k < limit; k++) {
            var item = makeNameItem(ordered[k].country, ordered[k].name, q);
            item._preScored = 5000 - k;
            items.push(item);
        }
        return items;
    }

    // ------------------------------------------------------------ interface

    function getItems(query) {
        if (!dataReady)
            return [];
        if (!query)
            return [hintItem()];

        var text = String(query).trim();
        if (normalize(text).length === 0) {
            // just the trigger / punctuation -> hint; otherwise search by name
            if (/^[+\s]*$/.test(text))
                return [hintItem()];
            return getNameItems(text);
        }

        var matches = findMatches(query);
        if (matches.length === 0)
            return [];

        var items = [];
        var q = normalize(query);
        var limit = Math.min(matches.length, maxResults);
        for (var i = 0; i < limit; i++) {
            var item = makeItem(matches[i], q);
            // keep launcher order: exact -> prefix -> full number -> root -> fuzzy
            item._preScored = 5000 - i;
            items.push(item);
        }
        return items;
    }

    function executeItem(item) {
        if (!item || !item.action)
            return;
        if (item.action.indexOf("copycode:") === 0) {
            // name search -> copy the dial code
            var c = item.action.substring("copycode:".length);
            if (c)
                copyToClipboard(formatCode(c));
            return;
        }
        if (item.action.indexOf("copy:") !== 0)
            return;
        var name = item.displayName || item.action.substring(5);
        var code = item.dialCode || "";
        copyToClipboard(formatCopy(name, code));
    }

    function formatCopy(name, code) {
        switch (copyFormat) {
        case "name_code":
            return code ? (name + " (" + formatCode(code) + ")") : name;
        case "code_name":
            return code ? (formatCode(code) + " " + name) : name;
        default:
            return name;
        }
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["dms", "cl", "copy", text]);
        showToast(tr("Copied: %1").arg(text));
    }

    function showToast(message) {
        if (typeof ToastService !== "undefined")
            ToastService.showInfo(tr("Country Code"), message);
    }

    onTriggerChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData(pluginId, "trigger", trigger);
    }
}
