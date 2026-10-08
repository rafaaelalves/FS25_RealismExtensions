RealismExtensionsPTOProfiles = RealismExtensionsPTOProfiles or {}
local Profiles = RealismExtensionsPTOProfiles
local Model = RealismExtensionsPTOModel

Profiles.VERSION = 1

-- Evidence-only catalog. Unknown tractors deliberately fall back to their
-- native GIANTS 540 ratio instead of guessing 1000/Economy capability from HP.
-- Official FS25 v1.24 Small Tractors: 25 shop families (base + official DLC).
-- Listed != equipped: uncertain factory packages remain separated from the
-- installed mechanism and have explicit pending status.
Profiles.SMALL_CATALOG = {
    "antonio_carraro_mach_4r",
    "antonio_carraro_tony_10900_ttr",
    "case_ih_farmall_c",
    "case_ih_vestrum",
    "claas_arion_400",
    "claas_arion_570_530",
    "deutz_fahr_6c_rvshift",
    "fendt_200_v_vario",
    "fendt_300_vario",
    "fendt_500_vario",
    "iseki_tjw",
    "jcb_fastrac_2000_4ws",
    "john_deere_3650",
    "john_deere_6m",
    "landini_rex4_gt",
    "lindner_lintrac_130",
    "massey_ferguson_5700_s",
    "mercedes_mb_trac_700_900",
    "mercedes_mb_trac_1000_1100",
    "new_holland_tk4_80_methane",
    "rigitrac_skh60",
    "same_virtus_135_rvshift",
    "zetor_crystal_16045",
    "zetor_forterra_hsx",
    "zetor_proxima_hs",
}
Profiles.PENDING_SMALL = {
    new_holland_tk4_80_methane =
        "TK4.80 diesel documents 540/540E and optional 540/1000; methane-powered FS25 machine's exact PTO gearbox needs confirmation"
}

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

-- FS25 v1.24 official shop: 26 Large Tractors entries, including tracked,
-- articulated and the unique Black Edition variant. The roster is not a
-- statement that a PTO gearbox is fitted to any particular configuration.
Profiles.LARGE_CATALOG = {
    "new_holland_t8000", "versatile_976", "ford_976_versatile",
    "versatile_1156", "ford_1156_versatile", "versatile_big_roy",
    "jcb_fastrac_8000_icon", "valtra_s", "massey_ferguson_9s",
    "versatile_mfwd", "new_holland_t8_genesis", "john_deere_7r",
    "john_deere_8r", "fendt_900_vario", "case_ih_magnum_afs",
    "fendt_1000_vario", "john_deere_8rt", "fendt_1100_vario_mt",
    "john_deere_9r_440_640", "john_deere_8rx",
    "versatile_deltatrack", "john_deere_9rx_490_640",
    "claas_xerion_12", "case_ih_steiger_715_785_black",
    "case_ih_steiger_715_785", "john_deere_9rx_710_830"
}
Profiles.PENDING_LARGE = {
    versatile_big_roy =
        "1977 prototype: no verified mechanical PTO shaft, ratio or FS25 installed output; no mode inferred"
}

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

local function largeTractor(id, tokens, spec, source, note)
    local entry = tractor(id, tokens, spec, source, note)
    -- Crucial for high-horsepower tractors: a documented optional factory PTO
    -- is NOT necessarily fitted to the individual FS25 vehicle.
    -- Require native, instantiated PTO output before exposing the gearbox.
    entry.requiresOutputPto = true
    return entry
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

    -- Small shop catalog: conservative, source-backed gears; individual
    -- exact engine RPM measurements precede generic family aliases.
    tractor("antonio_carraro_mach_4r", {"mach 4r", "mach4r", "mach_4r"},
        {{"540"}, {"540E"}},
        "https://liveecpaperdmp.blob.core.windows.net/cms/Catalogs/21078/21078/eivSob/pekass-ac-mach-a4-ok.pdf",
        "MACH 4R rear 540/540E only; no 1000."),
    tractor("antonio_carraro_tony_10900_ttr", {"tony 10900 ttr", "tony10900ttr", "tony_10900_ttr", "ttr 10900"},
        {{"540"}, {"540E"}},
        "https://www.antoniocarraro.it/sfogliabili/depliant%20MOBILE/TTR100/TTR_7800_10900_2016_EN/files/assets/common/downloads/TTR%207800_10900%20ing%2001_2016%20.pdf",
        "TTR 10900 standard rear 540/540E, not other TONY versions."),
    tractor("case_ih_farmall_c", {"farmall c series", "farmall c", "farmall_100c", "farmall_110c", "farmall_120c"},
        {{"540"}, {"1000"}},
        "https://www.caseih.com/en/asiapacific/products/tractors/farmall-series/farmall-c",
        "540/1000 conservative: 540E available with alternate factory package."),
    tractor("case_ih_vestrum", {"vestrum series", "vestrum 110", "vestrum 120", "vestrum 130", "vestrum 140", "vestrum_"},
        {{"540"}, {"540E"}, {"1000"}},
        "https://www.caseih.com/en-gb/europe/products/tractors/vestrum-series",
        "Standard 540/540E/1000; alternate factory 540E/1000/1000E."),
    tractor("claas_arion_470", {"arion 470", "arion470"},
        {{"540",1920}, {"540E",1560}, {"1000",1964}},
        "https://www.claas.com/caas/v1/media/870548/data/f9ddbb10b95c32b542bddd0ce299e9c6",
        "Exact 470 DLG/profi shaft ratios; other ARION 400 models cannot inherit engine speed."),
    tractor("claas_arion_400", {"arion 410", "arion 420", "arion 430", "arion 440", "arion 450", "arion 460", "arion 400", "arion400", "arion 470-410"},
        {{"540"}, {"540E"}, {"1000"}},
        "https://www.claas.com/caas/v1/media/870548/data/f9ddbb10b95c32b542bddd0ce299e9c6",
        "400 family mode set only; exact engine speeds only known for 470."),
    tractor("claas_arion_570", {"arion 570", "arion570"},
        {{"540"}, {"540E"}, {"1000"}, {"1000E"}},
        "https://www.claas.com/en-tw/press/press-releases/2025-02-11-arion-570",
        "Exact ARION 570 CMATIC standard four-speed; not automatically fitted to smaller variants."),
    tractor("claas_arion_570_530", {"arion 560", "arion 550", "arion 540", "arion 530", "arion 570-530"},
        {{"540"}, {"1000"}},
        "https://www.tractordata.com/farm-tractors/006/5/8/6583-claas-arion-530.html",
        "Historical ARION 530 540/1000 base, optional four-speed. Conservative common modes for newer 530-560 until game factory package identified."),
    tractor("deutz_fahr_6c_rvshift", {"6c rvshift", "6c rv", "deutz fahr 6c", "deutz-fahr 6c"},
        {{"540"}, {"540E"}, {"1000"}},
        "https://www.deutz-fahr.com/media/article_11765_308.9003.3.4-0_Serie_6_C_EN.pdf",
        "RVShift 540/540E/1000; PowerShift alternative four-speed separate."),
    tractor("fendt_200_v_vario", {"200 v vario", "200vvario", "200 v/f/p vario", "200 vfp vario", "fendt 200 v"},
        {{"540"}, {"540E"}, {"1000"}},
        "https://www.fendt.com/pt/tratores/fendt-200-vfp-vario",
        "V/F/P narrow tractor 540/540E/1000 rear; front drive separate."),
    tractor("fendt_300_vario", {"300 vario", "300vario", "310 vario", "311 vario", "312 vario", "313 vario", "314 vario"},
        {{"540"}, {"540E"}, {"1000"}},
        "https://api.fendt.com/techdata/GB/en/1153083/Fendt-300-Vario",
        "540/540E/1000 standard; 540E/1000/1000E optional alternative."),
    tractor("fendt_500_vario", {"500 vario", "500vario", "512 vario", "513 vario", "514 vario", "515 vario", "516 vario"},
        {{"540"}, {"540E"}, {"1000"}},
        "https://api.fendt.com/techdata/AU/en/1153083/Fendt-500-Vario",
        "FS25-era 500 generation standard three PTO speeds; Gen4 four-speed not automatically inherited."),
    tractor("iseki_tjw", {"iseki tjw", "tjw1233", "tjw 123", "tjw123", "t japan w", "tjw3"},
        {{"540"}, {"540E"}, {"1000"}},
        "https://tym.world/en-ko/products/tractors/iseki/tjw1233",
        "TJW1233 standard 540/540E/1000; other Japanese shaft options are distinct."),
    tractor("jcb_fastrac_2000_4ws", {"fastrac 2000 4ws", "fastrac 2000", "fastrac 2155", "fastrac 2170", "jcb 2155", "jcb 2170"},
        {{"540"}, {"1000"}},
        "https://www.koneviesti.fi/en/konedata/traktorit/jcb/jcb-fastrac-2155-2170",
        "JCB Fastrac 2000 classic 540/1000, not newer 4000."),
    tractor("john_deere_3650", {"john deere 3650", "johndeere3650", "3650 deere", "jd 3650"},
        {{"540",2178}, {"1000",2172}},
        "https://www.tractordata.com/farm-tractors/005/0/0/5000-john-deere-3650.html",
        "Historical 3650 540@2178 and 1000@2172 engine rpm."),
    tractor("john_deere_6m_105", {"6m 105", "6m105", "6m_105"},
        {{"540",1977}, {"1000",1972}},
        "https://www.deere.ca/en/tractors/utility-tractors/6-family-utility-tractors/6m-105-tractor/",
        "Exact 6M 105 540@1977 and 1000@1972 engine rpm."),
    tractor("john_deere_6m", {"6m series", "series6m", "6m 95", "6m 110", "6m 115", "6m 120", "6m 125", "6m 130", "6m 135", "6m_"},
        {{"540"}, {"1000"}},
        "https://www.deere.com/assets/pdfs/region-4/industries/government-and-military-sales/contracts/price-pages/agricultural/Tractors_6000s_WITH%20ALDI_05Nov2025.pdf",
        "6M family standard 540/1000 factory; economy optional; exact RPM varies by engine."),
    tractor("landini_rex4_gt", {"rex 4 gt", "rex4 gt", "rex4gt", "rex 4gt", "rex4-gt"},
        {{"540"}, {"540E"}},
        "https://landini-tractors.com/pt/pt/produtos/rex4-cab.html",
        "REX4 GT standard 540/540E; 540/1000 and four-speed other factory packs."),
    tractor("lindner_lintrac_130", {"lintrac 130", "lintrac130", "lintrac_130"},
        {{"540"}, {"1000"}},
        "https://pimcore.lindner-traktoren.at/en/tractors-transporters/lintrac/lintrac-130",
        "Real 540/750/1000/1400; 750 and 1400 unsupported shaft families; not economy."),
    tractor("massey_ferguson_5700_s", {"mf 5700 s", "mf5700s", "5700 s", "5700s", "mf 5710 s", "mf 5711 s", "mf 5712 s", "mf 5713 s"},
        {{"540"}, {"540E"}},
        "https://www.corkfarmmachinery.ie/wp-content/uploads/2022/03/ENGLISH_A-A-16457_MF-5700_S_158542.pdf",
        "MF 5700 S standard 540/540E; optional 1000 not assumed."),
    tractor("mercedes_mb_trac_700", {"mb-trac 700", "mb trac 700", "mbtrac700", "mb-trac 700-900"},
        {{"540",2165}, {"1000",2196}},
        "https://pruefberichte.dlg.org/filestorage/Mercedes-Benz-MB_TRAC_700_Nr1185-700-1989-englisch.pdf",
        "MB-trac 700 DLG test specific 540@2165 and 1000@2196."),
    tractor("mercedes_mb_trac_700_900", {"mb-trac 800", "mb-trac 900", "mb trac 800", "mb trac 900", "mbtrac800", "mbtrac900"},
        {{"540"}, {"1000"}},
        "https://www.koneviesti.fi/en/konedata/traktorit/mb-trac-unimog/mb-trac-700-1000",
        "MB-trac 800/900 540/1000; not 700 exact engine speeds."),
    tractor("mercedes_mb_trac_1000_1100", {"mb-trac 1000", "mb-trac 1100", "mb trac 1000", "mb trac 1100", "mbtrac1000", "mbtrac1100", "mb-trac 1000-1100"},
        {{"540"}, {"1000"}},
        "https://www.koneviesti.fi/en/konedata/traktorit/mb-trac-unimog/mb-trac-700-1100",
        "MB-trac small 1000/1100 rear PTO 540/1000."),
    tractor("rigitrac_skh60", {"rigitrac skh60", "rigitrac skh 60", "skh 60", "skh60"},
        {{"540"}, {"1000"}},
        "https://www.rigitrac.com/produkte/rigitrac-skh-60/rt-skh-60-technische-informationen/",
        "Manufacturer front and rear 540 or 1000; distinct outputs."),
    tractor("same_virtus_135_rvshift", {"virtus 135 rvshift", "virtus 135 rv shift", "virtus 125 rvshift", "same virtus", "virtus 135"},
        {{"540"}, {"540E"}, {"1000"}},
        "https://pi.product-bank.com/same-virtus-135-rvshift-row-crop-tractor",
        "RVShift 540/540E/1000, not four-mode PowerShift alternative."),
    tractor("zetor_crystal_16045", {"crystal 16045", "zetor 16045", "crystal16045", "16045"},
        {{"540",1900}, {"1000",2200}},
        "https://www.tractordata.com/farm-tractors/001/7/3/1733-zetor-16045.html",
        "Historical Zetor 16045 540@1900 and 1000@2200."),
    tractor("zetor_forterra_hsx", {"forterra hsx", "forterra_hsx", "forterrahsx"},
        {{"540"}, {"540E"}, {"1000"}, {"1000E"}},
        "https://www.zetor.com/zetor-forterra-technical-parameters",
        "Forterra HSX standard four-speed gearbox; ground-speed alternative separate."),
    tractor("zetor_proxima_hs", {"proxima hs", "proxima_hs", "proximahs"},
        {{"540"}},
        "https://www.zetor.com/zetor-proxima-technical-parameters",
        "Alternative 540/1000 and 540/540E mutually exclusive; common 540 only."),

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
        "Crystal HD170 standard four-speed PTO."),
    -- Large shop: source-backed mechanical rear gears, never a union of all
    -- mutually exclusive factory PTO packages.
    -- EVERY large entry requires a real GIANTS rear output (see PTOResolver).
    largeTractor("new_holland_t8000",
        {"t8000 series","t8000series","t8030","t8040","t8050","t8060","t8070"},
        {{"1000"}},
        "https://www.tractordata.com/farm-tractors/006/3/2/6323-new-holland-t8050.html",
        "T8050 standard rear 1000; optional 540/1000 shaft is not assumed."),
    largeTractor("ford_976_versatile",
        {"ford 976 versatile","ford versatile 976","ford 976"},
        {{"1000"}},
        "https://www.tractordata.com/farm-tractors/010/1/4/10148-ford-976.html",
        "Rear 1000 PTO only with PowerShift transmission; physical output mandatory."),
    largeTractor("versatile_976",
        {"versatile 976","versatile976"},
        {{"1000"}},
        "https://www.tractordata.com/farm-tractors/001/3/6/1361-versatile-976.html",
        "Rear 1000 only on PowerShift transmission; physical output mandatory."),
    largeTractor("ford_1156_versatile",
        {"ford 1156 versatile","ford versatile 1156","ford 1156"},
        {{"1000"}},
        "https://www.tractordata.com/farm-tractors/001/3/6/1363-versatile-1156.html",
        "Ford-badged Versatile 1156 historical 1000 output; in-game installation unverified."),
    largeTractor("versatile_1156",
        {"versatile 1156","versatile1156"},
        {{"1000"}},
        "https://www.tractordata.com/farm-tractors/001/3/6/1363-versatile-1156.html",
        "Versatile 1156 rear PTO listed 1000."),
    largeTractor("jcb_fastrac_8000_icon",
        {"fastrac 8290","fastrac 8330","fastrac 8000","8000 icon"},
        {{"540E"},{"1000"}},
        "https://www.jcb.com/globalassets/digizuite/53520-29846-fastrac-4000-8000-series-e-spec-fr-fr-issue-1-lr/",
        "Fastrac 8000 rear has 540E/1000; do not copy 4000's four speeds."),
    largeTractor("valtra_s",
        {"valtra s series","valtra s-series","s286","s316","s346","s376","s396","s416"},
        {{"540E",1577},{"1000",1882}},
        "https://www.valtra.com/content/dam/Brands/Valtra/en/Products/Brochures/2023/Valtra-S6-brochure-en-2023-screen.pdf",
        "S6 factory 540E/1000; alternative 1000E/1000 exists but is mutually exclusive."),
    largeTractor("massey_ferguson_9s",
        {"massey ferguson 9s","mf 9s","mf9s","9s.285","9s.310","9s.340","9s.370","9s.400","9s.425"},
        {{"540E"},{"1000"}},
        "https://www.masseyferguson.com/en_gb/product/tractors/mf-9s.html",
        "Factory 540E/1000; alternative 1000/1000E PTO set, not additional."),
    largeTractor("versatile_mfwd",
        {"versatile mfwd","versatilemfwd","versatile 275","versatile 295","versatile 315","versatile 335","versatile 365"},
        {{"1000"}},
        "https://www.versatile-ag.com/na/pages/product_mfwd.php",
        "1000 standard across 275-365; optional 540/1000 on 275-315."),
    largeTractor("new_holland_t8_genesis",
        {"t8 genesis","t8genesis","t8.350","t8.380","t8.410","t8.435","t8 350","t8 380","t8 410","t8 435"},
        {{"1000"}},
        "https://assets.cnhindustrial.com/nhag/nar/en-us/assets/pdf/agricultural-tractors/t8-plm-spec-sheet-us-en.pdf",
        "T8 PLM/Genesis rear PTO; 1000 conservative across sizes/options."),
    largeTractor("john_deere_7r",
        {"7r series","series7r","7r 210","7r 230","7r 250","7r 270","7r 290","7r 310","7r 330","7r 350"},
        {{"1000"}},
        "https://www.deere.com/assets/pdfs/region-1/products/tractors/7R_Brochure.pdf",
        "1000 standard; source 1950 engine rpm belongs to earlier 7R generation and is not copied."),
    largeTractor("john_deere_8rt",
        {"8rt series","series8rt","8rt 310","8rt 340","8rt 370","8rt 410"},
        {{"1000"}},
        "https://www.deere.com/assets/pdfs/region-4/industries/government-and-military-sales/contracts/price-pages/agricultural/A2_6000-8000_20210203.pdf",
        "8RT rear 1000 native; 8R family engine target is NOT assumed for track variant."),
    largeTractor("john_deere_8rx_340",
        {"8rx 340"},
        {{"1000",1995}},
        "https://www.deere.com/en/tractors/row-crop-tractors/row-crop-8-family/8rx-340-tractor/",
        "Exact 8RX 340: standard 1000 at 1995 engine rpm."),
    largeTractor("john_deere_8rx",
        {"8rx series","series8rx","8rx 310","8rx 370","8rx 410"},
        {{"1000"}},
        "https://www.deere.com/en/tractors/row-crop-tractors/row-crop-8-family/8rx-340-tractor/",
        "8RX family rear 1000, but exact shaft/engine ratios require model confirmation."),
    largeTractor("john_deere_8r_250",
        {"8r 250"},
        {{"1000",1995}},
        "https://www.deere.com/en-us/products-and-solutions/tractors/row-crop-4wd-tractors/8r-250-tractor-odexmvjx",
        "Exact 8R 250: rear 1000@1995."),
    largeTractor("john_deere_8r",
        {"8r series","series8r","8r 280","8r 310","8r 340","8r 370","8r 410","8r 230"},
        {{"1000"}},
        "https://www.deere.com/en-us/products-and-solutions/tractors/row-crop-4wd-tractors/8r-250-tractor-odexmvjx",
        "8R family factory 1000; engine RPM not copied unverified across variants."),
    largeTractor("fendt_900_vario",
        {"fendt 900 vario","900 vario","900vario","930 vario","933 vario","936 vario","939 vario","942 vario","series900"},
        {{"540E"},{"1000"}},
        "https://www.fendt.com/nl/geneva-assets/article/126276/700249-fendt900vario-2101-td-en.pdf",
        "Gen6 standard 540E/1000. 1000/1000E optional package, not combined."),
    largeTractor("case_ih_magnum_afs",
        {"magnum afs","afs connect magnum","magnum 310","magnum 340","magnum 380","magnum 400","magnum 250","magnum 280"},
        {{"1000",1803}},
        "https://www.caseih.com/en-gb/europe/products/tractors/magnum-afs-connect/magnum",
        "Heavy-duty rear 1000@1803; alternative dual 540/1000 requires its own PTO set."),
    largeTractor("fendt_1000_vario",
        {"1000 vario","1000vario","1038 vario","1042 vario","1046 vario","1050 vario"},
        {{"1000"},{"1000E"}},
        "https://api.fendt.com/techdata/BR/pt/1161054/Fendt%201000%20Vario%20Gen3",
        "FS25-era Gen3 optionally fitted 1000/1000E/1300; 1300 unsupported by four-mode controller."),
    largeTractor("fendt_1100_vario_mt",
        {"1100 vario mt","1100variomt","1151 vario mt","1156 vario mt","1162 vario mt","1167 vario mt"},
        {{"1000"},{"1000E"}},
        "https://api.fendt.com/techdata/GB/en/1152877/Fendt-1100-Vario-MT",
        "Optional 1000/1000E rear. Do not advertise PTO unless shaft truly fitted."),
    largeTractor("john_deere_9r_440_640",
        {"9r 440","9r 490","9r 540","9r 590","9r 640","9r series","series9r"},
        {{"1000"}},
        "https://www.deere.ca/en/tractors/4wd-track-tractors/9r-590/",
        "9R 440-640 1000 rear; actual installed output required (optional installations)."),
    largeTractor("versatile_deltatrack",
        {"deltatrack","delta track","versatile 530dt","versatile 570dt","versatile 620dt"},
        {{"1000"}},
        "https://www.versatile-ag.com/NA/pages/product_dt.php",
        "Rear PTO is a factory OPTION, not inherent to DeltaTrack; verify actual output."),
    largeTractor("john_deere_9rx_710_830",
        {"9rx 710","9rx 770","9rx 830","9rx710","9rx770","9rx830"},
        {{"1000"}},
        "https://www.deere.com/en-us/products-and-solutions/tractors/row-crop-4wd-tractors/9rx-830-tractor-otkymfjx",
        "High-horsepower 9RX 710-830 1000 rpm; 540 and economy not presumed."),
    largeTractor("john_deere_9rx_490_640",
        {"9rx 490","9rx 540","9rx 590","9rx 640","9rx series","series9rx"},
        {{"1000"}},
        "https://www.deere.ca/en/tractors/4wd-track-tractors/9rx-590/",
        "9RX 490-640 native independent 1000 rpm; no economy gearbox declared."),
    largeTractor("claas_xerion_12",
        {"xerion 12","xerion12","12.590","12.650"},
        {{"1000",1500}},
        "https://www.claas.com/caas/v1/media/1328946/data/738cb304d52f63b9be6f3d4eb853b7c9",
        "XERION 12 1000 PTO at 1500 engine RPM; actual native output required."),
    largeTractor("case_ih_steiger_715_785_black",
        {"steiger 715-785 quadtrac black","steiger 715 black","steiger 785 black","quadtrac black edition","steiger black edition"},
        {{"1000"}},
        "https://online.flippingbook.com/view/341953633",
        "Special Black Edition uses Steiger 715/785 PTO family; hardware fit is optional."),
    largeTractor("case_ih_steiger_715_785",
        {"steiger 715","steiger 785","steiger series","steiger715","steiger785","quadtrac 715","quadtrac 785"},
        {{"1000"}},
        "https://online.flippingbook.com/view/341953633",
        "Steiger/Quadtrac PTO listed at 1000; package fit verified at runtime.")
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
