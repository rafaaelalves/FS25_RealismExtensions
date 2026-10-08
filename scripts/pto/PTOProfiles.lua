RealismExtensionsPTOProfiles = RealismExtensionsPTOProfiles or {}
local Profiles = RealismExtensionsPTOProfiles
local Model = RealismExtensionsPTOModel

Profiles.VERSION = 1

-- Evidence-only catalog. Unknown tractors deliberately fall back to their
-- native GIANTS 540 ratio instead of guessing 1000/Economy capability from HP.
-- Medium tractor store category inventory as of FS25 1.24 (base + DLC).
-- The set is separate from installed capabilities: catalog coverage does NOT
-- enable a feature. Some vehicles are still source- or package-ambiguous.
Profiles.MEDIUM_CATALOG = {
    "agco_white_8010", "case_ih_puma_afs", "challenger_mt600",
    "deutz_agrostar_831", "deutz_6230_ttv", "deutz_7_ttv_hd",
    "deutz_8_ttv", "fendt_700_gen7", "fiat_160_90",
    "jcb_fastrac_4000_icon", "john_deere_6r_145_185",
    "john_deere_6r_230_250", "kubota_m8", "massey_ferguson_7s",
    "mccormick_x8", "mercedes_mb_trac_1100_1500",
    "mercedes_mb_trac_1300_1800", "mercedes_unimog_1800_2400",
    "mercedes_unimog_527_535", "new_holland_t7_lwb",
    "steyr_absolut_cvt", "valtra_t", "versatile_nemesis",
    "zetor_crystal_hd"
}

-- In the unresolved series below, no mode is unlocked from mere identity.
-- DLC agricultural PTO installation depends on options and cannot be
-- established from an in-game label alone.
Profiles.PENDING_MEDIUM = {
    mercedes_unimog_1800_2400 = "PTO option/package and exact FS25 configuration not verified",
    mercedes_unimog_527_535 = "PTO option/package and exact FS25 configuration not verified"
}

local function modes(spec)
    local result = {}
    for _, row in ipairs(spec) do
        local mode = Model.normalizeMode(row[1])
        result[mode] = row[2] ~= nil and { engineRpm = row[2] } or {}
    end
    return result
end

local function tractor(id, tokens, spec, source, note)
    return {
        id = id, tokens = tokens, modes = modes(spec),
        evidenceUrl = source, evidenceNote = note
    }
end

Profiles.TRACTORS = {
    -- Existing original profiles, unchanged in physical scope.
    tractor("fiat_180_90", {"180-90", "180_90", "18090"},
        {{"540"}, {"1000"}},
        "https://www.tractordata.com/farm-tractors/002/0/2/2021-fiat-180-90.html",
        "Fiat 180-90 540/1000 gearbox verified; engine RPM intentionally not copied from the 160-90."),
    tractor("john_deere_6r_155", {"6r 155", "6r_155", "6r155"},
        {{"540",1987}, {"540E",1753}, {"1000",2000}},
        "https://www.deere.asia/ko/tractors/6r-series-tractors/6145r-tractor/",
        "Retains original proven 6R 155 variant values. Alternative factory 540E/1000/1000E is not assumed."),

    -- Medium list (24 store families; 22 evidence-backed, two held pending).
    -- Several families have mutually exclusive factory PTO packages. We
    -- expose only conservative factory/common configurations here; future
    -- upgrades will select explicit package IDs, never accumulate all choices.
    tractor("agco_white_8010_8510", {"white 8510","agco 8510","agco white 8510"},
        {{"540",1990},{"1000",2100}},
        "https://www.tractordata.com/farm-tractors/002/3/8/2384-agco-white-8510.html",
        "Specific 8510: 540 and 1000."),
    tractor("agco_white_8010_8610_8810", {"white 8610","white 8710","white 8810","agco 8610","agco 8710","agco 8810"},
        {{"1000",2100}},
        "https://www.tractordata.com/farm-tractors/002/3/8/2385-agco-white-8610.html",
        "1000-only confirmed for 8610 and 8710; 8810 exact model requires follow-up."),
    tractor("agco_white_8010", {"white 8010","agco white 8010","white8010"},
        {{"1000"}},
        "https://www.tractordata.com/farm-tractors/002/3/8/2386-agco-white-8710.html",
        "Series fallback: 1000 common to documented 8510/8610/8710; 540 not inferred."),
    tractor("case_ih_puma_afs", {"puma 260","puma afs","puma260","puma series"},
        {{"1000"}},
        "https://assets.cnhindustrial.com/caseih/NAFTA/NAFTAASSETS/Products/Tractors/AFS-Connect-Puma/AFS_Puma_Spec_Sheet_CIH23020701_pages%20%281%29.pdf",
        "Alternative factory PTO packs: 540/1000, 540E/1000, 1000/1000E. Only shared 1000 is guaranteed."),
    tractor("challenger_mt635", {"mt635","mt 635"},
        {{"540",1991},{"1000",2091}},
        "https://www.tractordata.com/farm-tractors/003/8/2/3827-challenger-mt635.html",
        "Exact MT635 tested 540/1000 engine speeds."),
    tractor("challenger_mt600", {"mt645","mt655","mt665","mt600 series","mt600series"},
        {{"540"},{"1000"}},
        "https://farmingsimulator.wiki.gg/wiki/Challenger_MT600_Series",
        "MT600 540/1000 gearbox; model-dependent engine RPM intentionally not copied from MT635."),
    tractor("deutz_agrostar_831", {"agrostar 8.31","agrostar8.31","agrostar_831"},
        {{"1000"}},
        "https://www.tractordata.com/farm-tractors/002/1/2/2122-deutz-fahr-831.html",
        "Rear PTO listed as 1000 only."),
    tractor("deutz_6230_ttv", {"6230 ttv","6230ttv"},
        {{"540E"},{"1000"},{"1000E"}},
        "https://www.deutz-fahr.com/en-ea/tractors/series-6",
        "6190–6230 TTV HD rear PTO 540E/1000/1000E; no 540."),
    tractor("deutz_7_ttv_hd", {"7250 ttv","7250ttv","series 7 ttv hd","7 ttv hd"},
        {{"540E"},{"1000"},{"1000E"}},
        "https://www.deutz-fahr.com/en-eu/tractors/7250-ttv-warrior",
        "Rear 540E/1000/1000E."),
    tractor("deutz_8_ttv", {"8280 ttv","8280ttv","series 8 ttv"},
        {{"540E"},{"1000"},{"1000E"}},
        "https://www.deutz-fahr.com/media/308.8517.7.4-1_Serie_8_Stage_V_PT.pdf",
        "Factory rear PTO 540E/1000/1000E."),
    tractor("fendt_700_gen7",
        {"700 vario","700vario","722 vario","724 vario","726 vario","728 vario","series700"},
        {{"540",1618},{"540E",1283},{"1000",1649},{"1000E",1308}},
        "https://www.fendt.com/int/geneva-assets/article/150214/905890-fendt700variogen7-2201-td-en-web-v2.pdf",
        "Gen7 700 series exact engine RPM for four rear ratios."),
    tractor("fiat_160_90", {"160-90","160_90","16090"},
        {{"540",1950},{"1000",2074}},
        "https://pruefberichte.dlg.org/filestorage/FIAT_160-90_Nr976_1985-englisch.pdf",
        "Official DLG mechanical test: 540@1950 and 1000@2074."),
    tractor("jcb_fastrac_4000_icon",
        {"fastrac 4160","fastrac 4190","fastrac 4220","fastrac 4000","4000 icon"},
        {{"540"},{"540E"},{"1000"},{"1000E"}},
        "https://www.jcb.com/globalassets/digizuite/53520-29846-fastrac-4000-8000-series-e-spec-fr-fr-issue-1-lr/",
        "4000 iCON brochure, four rear PTO modes."),
    tractor("john_deere_6r_145",
        {"6r 145","6r_145","6r145"},
        {{"540",1967},{"540E",1753},{"1000",2000}},
        "https://www.deere.ca/en/tractors/row-crop-tractors/row-crop-6-family/6145r-tractor/",
        "John Deere 6R 145 specific factory PTO engine-speed specification."),
    tractor("john_deere_6r_145_185",
        {"6r 165","6r_165","6r165","6r 175","6r_175","6r175","6r 185","6r_185","6r185"},
        {{"540"},{"540E"},{"1000"}},
        "https://www.deere.ca/en/tractors/row-crop-tractors/row-crop-6-family/6145r-tractor/",
        "6R family factory 540/540E/1000 selection; engine RPM not copied from 6R 145 to other variants."),
    tractor("john_deere_6r_230_250",
        {"6r 230","6r_230","6r230","6r 250","6r_250","6r250"},
        {{"540E",1761},{"1000",1950},{"1000E",1756}},
        "https://www.deere.ca/en/tractors/utility-tractors/6-family-utility-tractors/6250r/",
        "Factory base 540E/1000/1000E; alternative 540/540E/1000 is not silently fitted."),
    tractor("kubota_m8", {"kubota m8","kubota_m8","m8-181","m8-201","m8 181","m8 201"},
        {{"540"},{"540E"},{"1000"},{"1000E"}},
        "https://www.kubotausa.com/docs/default-source/brochure-sheets/2024-full-product-line-brochure.pdf",
        "M8-181 and M8-201 four rear PTO ratios; engine RPM per gear not published in cited product-line sheet."),
    tractor("massey_ferguson_7s",
        {"mf 7s","mf7s","massey ferguson 7s","7s.155","7s.165","7s.180","7s.190","7s.210"},
        {{"540"},{"1000"}},
        "https://www.masseyferguson.com/content/dam/public/masseyfergusonglobal/markets/en_au/assets/product-brochures/tractors/mf-7s/240622_MF_7S_Brochure.pdf",
        "Gearbox and trim-dependent four-speed options exist, but transmission is not identified by FS25 profile."),
    tractor("mccormick_x8", {"x8 vt-drive","x8 vt drive","x8.627","x8.631","x8 627","x8 631"},
        {{"540E"},{"1000"},{"1000E"}},
        "https://www.mccormick.it/wp-content/uploads/2024/02/X8-2024-Brochure-_02.02.2024-1.pdf",
        "Three electronically selected modes in contemporary X8 brochure."),
    tractor("mercedes_mb_trac_1100_1500",
        {"mb-trac 1100","mb-trac 1300","mb-trac 1500","mb trac 1100","mb trac 1300","mb trac 1500"},
        {{"540"},{"1000"}},
        "https://www.tractorbook.de/traktoren/mercedes-benz/mb-trac-1100-1300-1500-1976-1987/technische-daten/",
        "Traditional rear 540/1000, no economy gearbox."),
    tractor("mercedes_mb_trac_1300_1800",
        {"mb-trac 1400","mb-trac 1600","mb-trac 1800","mb trac 1400","mb trac 1600","mb trac 1800"},
        {{"540"},{"1000"}},
        "https://www.tractordata.com/farm-tractors/002/9/4/2947-mercedes-benz-trac-1800.html",
        "Traditional 540/1000; game series naming depends on DLC vehicle identity."),
    tractor("new_holland_t7_lwb",
        {"t7.260","t7 260","t7.270","t7 270","t7 lwb","t7lwb","t7 plm"},
        {{"540",1931},{"540E",1598},{"1000",1912},{"1000E",1583}},
        "https://www.berchtold.com/equipment/new-equipment/new-holland/new-holland-ag/tractors-and-telehandlers/T7-with-PLM-Intelligence/T7-260/",
        "T7.260 PLM four modes with published PTO engine rpm."),
    tractor("steyr_absolut_cvt",
        {"absolut cvt","absolut_cvt","absolutcvt"},
        {{"540",1931},{"540E",1598},{"1000",1912},{"1000E",1583}},
        "https://www.steyr.ro/en/agricultural/2/absolut-cvt",
        "Four speeds standard in some markets; alternative two-speed package must not be silently combined."),
    tractor("valtra_t",
        {"valtra t series","valtra t-series","valtra_t","t145 valtra","t155 valtra","t175 valtra","t195 valtra","t215 valtra","t235 valtra","t255 valtra"},
        {{"540",1890},{"1000",1897}},
        "https://www.valtra.com/content/dam/Brands/Valtra/en/Products/Brochures/2021/Valtra-t5-series-tractor-brochure-en-screen-2021.pdf",
        "540/1000 standard; 540E optional, absent until factory package can be resolved."),
    tractor("versatile_nemesis_175_210",
        {"nemesis 175","nemesis 195","nemesis 210","nemesis175","nemesis195","nemesis210"},
        {{"540"},{"540E"},{"1000"},{"1000E"}},
        "https://www.versatile-ag.com/NA/downloads/brochure/Versatile-Brochure-Nemesis.pdf",
        "175/195/210 rear 540/540E/1000/1000E."),
    tractor("versatile_nemesis_235_255",
        {"nemesis 235","nemesis 255","nemesis235","nemesis255"},
        {{"540E"},{"1000"},{"1000E"}},
        "https://www.versatile-ag.com/NA/downloads/brochure/Versatile-Brochure-Nemesis.pdf",
        "235/255 do not list regular 540 as standard."),
    tractor("versatile_nemesis",
        {"versatile nemesis","nemesis series"},
        {{"540E"},{"1000"},{"1000E"}},
        "https://www.versatile-ag.com/NA/downloads/brochure/Versatile-Brochure-Nemesis.pdf",
        "Common conservative series denominator; model-specific package is preferred."),
    tractor("zetor_crystal_hd",
        {"crystal hd","crystal_hd","crystalhd170"},
        {{"540"},{"540E"},{"1000"},{"1000E"}},
        "https://www.zetor.com/zetor-crystal-technical-parameters",
        "Crystal HD170 standard four-speed PTO.")
}

-- Only requirements that FS25 data cannot represent reliably belong here.
-- Ordinary implements continue to use their native powerConsumer.ptoRpm.
Profiles.IMPLEMENTS = {
    {
        id = "heizohack_hm10_500",
        tokens = { "hm10500", "hm10-500", "hm10_500", "hm 10-500" },
        shaftRpm = 1000
    }
}

local function lower(v)
    return string.lower(tostring(v or ""))
end

local function basename(path)
    path = lower(path):gsub("\\", "/")
    return path:match("([^/]+)$") or path
end

local function identityBlob(object)
    if object == nil then return "" end

    local parts = {
        lower(object.configFileName),
        lower(object.configFileNameClean),
        lower(object.typeName)
    }

    if type(object.getName) == "function" then
        local ok, value = pcall(object.getName, object)
        if ok then parts[#parts + 1] = lower(value) end
    end

    if type(object.getFullName) == "function" then
        local ok, value = pcall(object.getFullName, object)
        if ok then parts[#parts + 1] = lower(value) end
    end

    parts[#parts + 1] = basename(object.configFileName)
    return table.concat(parts, " ")
end

local function matches(entry, blob)
    for _, token in ipairs(entry.tokens or {}) do
        token = lower(token)
        if token ~= "" and string.find(blob, token, 1, true) ~= nil then
            return true
        end
    end
    return false
end

function Profiles.findTractor(object)
    local blob = identityBlob(object)
    for _, entry in ipairs(Profiles.TRACTORS) do
        if matches(entry, blob) then return entry end
    end
    return nil
end

function Profiles.findImplement(object)
    local blob = identityBlob(object)
    for _, entry in ipairs(Profiles.IMPLEMENTS) do
        if matches(entry, blob) then return entry end
    end
    return nil
end

function Profiles.getIdentityBlob(object)
    return identityBlob(object)
end

return Profiles
