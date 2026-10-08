# FS25 1.24 — Small tractor PTO evidence ledger (2026-10-08)

Inventory scope: [official FS25 small tractor shop](https://farmingsimulator.wiki.gg/wiki/Full_Tractor_List/Farming_Simulator_25), base game, updates and official DLC. **25 store families**, not community ModHub tractors.

- **24 shop families** with source-backed rear PTO mode candidates.
- **1 pending**: New Holland TK4.80 **Methane Power**. The manufacturer publishes [TK4.80 diesel PTO 540/540E and optional 540/1000](https://assets.cnhindustrial.com/nhag/apac/en/assets/pdf/agriculture-tractors/tk4-brochure-apac-en.pdf), but identical mechanical rear PTO configuration has not been verified for the *methane-powered FS25 variant*. No speculative profile is installed.
- **28 concrete profile records**: 24 shop families split into independent entries when exact engine data exist for ARION 470, 6M 105 and MB-trac 700. A source URL and gearbox note live alongside each runtime profile; only speed mode keys and optional model-specific engine RPM affect gameplay.

## Equipment manufacturer / technical references

| FS25 shop model or family | Candidate rear PTO gearbox | Engineering source / variant qualifier |
|---|---|---|
| antonio carraro mach 4r | 540, 540E | [Technical reference](https://liveecpaperdmp.blob.core.windows.net/cms/Catalogs/21078/21078/eivSob/pekass-ac-mach-a4-ok.pdf). MACH 4R rear 540/540E only; no 1000. |
| antonio carraro tony 10900 ttr | 540, 540E | [Technical reference](https://www.antoniocarraro.it/sfogliabili/depliant%20MOBILE/TTR100/TTR_7800_10900_2016_EN/files/assets/common/downloads/TTR%207800_10900%20ing%2001_2016%20.pdf). TTR 10900 standard rear 540/540E, not other TONY versions. |
| case ih farmall c | 540, 1000 | [Technical reference](https://www.caseih.com/en/asiapacific/products/tractors/farmall-series/farmall-c). 540/1000 conservative: 540E available with alternate factory package. |
| case ih vestrum | 540, 540E, 1000 | [Technical reference](https://www.caseih.com/en-gb/europe/products/tractors/vestrum-series). Standard 540/540E/1000; alternate factory 540E/1000/1000E. |
| claas arion 400 | 540, 540E, 1000 | [Technical reference](https://www.claas.com/caas/v1/media/870548/data/f9ddbb10b95c32b542bddd0ce299e9c6). 400 family mode set only; exact engine speeds only known for 470. |
| claas arion 570 530 | 540, 540E, 1000, 1000E | [Technical reference](https://www.claas.com/en-tw/press/press-releases/2025-02-11-arion-570). 570 CMATIC four-speed standard; lower series variants need game configuration check. |
| deutz fahr 6c rvshift | 540, 540E, 1000 | [Technical reference](https://www.deutz-fahr.com/media/article_11765_308.9003.3.4-0_Serie_6_C_EN.pdf). RVShift 540/540E/1000; PowerShift alternative four-speed separate. |
| fendt 200 v vario | 540, 540E, 1000 | [Technical reference](https://www.fendt.com/pt/tratores/fendt-200-vfp-vario). V/F/P narrow tractor 540/540E/1000 rear; front drive separate. |
| fendt 300 vario | 540, 540E, 1000 | [Technical reference](https://api.fendt.com/techdata/GB/en/1153083/Fendt-300-Vario). 540/540E/1000 standard; 540E/1000/1000E optional alternative. |
| fendt 500 vario | 540, 540E, 1000 | [Technical reference](https://api.fendt.com/techdata/AU/en/1153083/Fendt-500-Vario). FS25-era 500 generation standard three PTO speeds; Gen4 four-speed not automatically inherited. |
| iseki tjw | 540, 540E, 1000 | [Technical reference](https://tym.world/en-ko/products/tractors/iseki/tjw1233). TJW1233 standard 540/540E/1000; other Japanese shaft options are distinct. |
| jcb fastrac 2000 4ws | 540, 1000 | [Technical reference](https://www.koneviesti.fi/en/konedata/traktorit/jcb/jcb-fastrac-2155-2170). JCB Fastrac 2000 classic 540/1000, not newer 4000. |
| john deere 3650 | 540@2178, 1000@2172 | [Technical reference](https://www.tractordata.com/farm-tractors/005/0/0/5000-john-deere-3650.html). Historical 3650 540@2178 and 1000@2172 engine rpm. |
| john deere 6m | 540, 1000 | [Technical reference](https://www.deere.com/assets/pdfs/region-4/industries/government-and-military-sales/contracts/price-pages/agricultural/Tractors_6000s_WITH%20ALDI_05Nov2025.pdf). 6M family standard 540/1000 factory; economy optional; exact RPM varies by engine. |
| landini rex4 gt | 540, 540E | [Technical reference](https://landini-tractors.com/pt/pt/produtos/rex4-cab.html). REX4 GT standard 540/540E; 540/1000 and four-speed other factory packs. |
| lindner lintrac 130 | 540, 1000 | [Technical reference](https://pimcore.lindner-traktoren.at/en/tractors-transporters/lintrac/lintrac-130). Real 540/750/1000/1400; 750 and 1400 unsupported shaft families; not economy. |
| massey ferguson 5700 s | 540, 540E | [Technical reference](https://www.corkfarmmachinery.ie/wp-content/uploads/2022/03/ENGLISH_A-A-16457_MF-5700_S_158542.pdf). MF 5700 S standard 540/540E; optional 1000 not assumed. |
| mercedes mb trac 700 900 | 540, 1000 | [Technical reference](https://www.koneviesti.fi/en/konedata/traktorit/mb-trac-unimog/mb-trac-700-1000). MB-trac 800/900 540/1000; not 700 exact engine speeds. |
| mercedes mb trac 1000 1100 | 540, 1000 | [Technical reference](https://www.koneviesti.fi/en/konedata/traktorit/mb-trac-unimog/mb-trac-700-1100). MB-trac small 1000/1100 rear PTO 540/1000. |
| new holland tk4 80 methane | PENDING | [CNH TK4 family](https://assets.cnhindustrial.com/nhag/apac/en/assets/pdf/agriculture-tractors/tk4-brochure-apac-en.pdf). Methane-specific factory gearbox unverified. |
| rigitrac skh60 | 540, 1000 | [Technical reference](https://www.rigitrac.com/produkte/rigitrac-skh-60/rt-skh-60-technische-informationen/). Manufacturer front and rear 540 or 1000; distinct outputs. |
| same virtus 135 rvshift | 540, 540E, 1000 | [Technical reference](https://pi.product-bank.com/same-virtus-135-rvshift-row-crop-tractor). RVShift 540/540E/1000, not four-mode PowerShift alternative. |
| zetor crystal 16045 | 540@1900, 1000@2200 | [Technical reference](https://www.tractordata.com/farm-tractors/001/7/3/1733-zetor-16045.html). Historical Zetor 16045 540@1900 and 1000@2200. |
| zetor forterra hsx | 540, 540E, 1000, 1000E | [Technical reference](https://www.zetor.com/zetor-forterra-technical-parameters). Forterra HSX standard four-speed gearbox; ground-speed alternative separate. |
| zetor proxima hs | 540 | [Technical reference](https://www.zetor.com/zetor-proxima-technical-parameters). Alternative 540/1000 and 540/540E mutually exclusive; common 540 only. |

### Exact per-tractor engine-to-shaft ratios

- John Deere 3650: 540@2178 engine rpm, 1000@2172. [Historical TractorData](https://www.tractordata.com/farm-tractors/005/0/0/5000-john-deere-3650.html).
- Zetor Crystal 16045: 540@1900, 1000@2200. [TractorData](https://www.tractordata.com/farm-tractors/001/7/3/1733-zetor-16045.html).
- John Deere 6M 105: 540@1977, 1000@1972. [Official John Deere specifications](https://www.deere.ca/en/tractors/utility-tractors/6-family-utility-tractors/6m-105-tractor/).
- CLAAS ARION 470: 540@1920, 540E@1560, 1000@1964. [Independent DLG/profi test hosted by CLAAS](https://www.claas.com/caas/v1/media/870548/data/f9ddbb10b95c32b542bddd0ce299e9c6).
- MB-trac 700: 540@2165, 1000@2196. [DLG 1989 factory specimen test](https://pruefberichte.dlg.org/filestorage/Mercedes-Benz-MB_TRAC_700_Nr1185-700-1989-englisch.pdf).
- Massey Ferguson MF 5700 S: 540E@1560, 540/1000@1960 reported in [manufacturer brochure](https://www.corkfarmmachinery.ie/wp-content/uploads/2022/03/ENGLISH_A-A-16457_MF-5700_S_158542.pdf). As the 1000 gearbox is an option, only 540/540E are active in generic profile; exact numeric targets have not been applied to all trims.

### Configuration accuracy, unsupported gears and upgrades

- **Mutually exclusive gearboxes:** Zetor PROXIMA HS real options 540/1000 **or** 540/540E ([Zetor](https://www.zetor.com/zetor-proxima-technical-parameters)); default profile is **540 only**, the intersection until selected installed hardware can be inferred. Case Farmall C, Case Vestrum, Landini REX4, Fendt 300/500, JD 6M and MF5700S also require a future explicit gearbox-package resolver.
- **Distinct nominal speeds:** Lindner Lintrac 130 rear PTO modes are **540/750/1000/1400** ([manufacturer](https://pimcore.lindner-traktoren.at/en/tractors-transporters/lintrac/lintrac-130)). We expose 540/1000 only. 750 and 1400 are physically distinct shaft RPMs and **must not** be incorrectly represented as 540E/1000E.
- **Front PTO independence:** Rigitrac SKH60 is 540 or 1000 rpm at *front and rear*, mechanically separate shaft positions ([Rigitrac](https://www.rigitrac.com/produkte/rigitrac-skh-60/rt-skh-60-technische-informationen/)). Future package identity must include shaft location, transmission and spline, not just nominal rpm.
- **New Holland methane variant:** baseline factory evidence not enough to assert gearbox; no additional rear gear unlocked.
- **Unverified exact RPM:** standard `PTOModel.resolveMotorRatio` fallback remains an approximation when only available modes are verified. No other model gets the tested 6M 105, Arion 470 or MB-trac 700 ratios.
- **Future per-tractor upgrades (no gameplay in scope):** keep family/base PTO spec immutable; future package stored as installed hardware per vehicle and revised on workshop transactions. RE owns package/selection and RC reads only current selected effective ratio. No shop, save schema, price, PTO retrofits or 750/1400 network changes now.
- **Performance:** profile table consulted only on resolver/load events, no new per-frame queries.
- **Validation:** the `pto_resolver_harness` asserts 25/25 shop IDs, 28 source-backed model profiles, exact target ratios for five models, the absent methane profile, and no cross-category collisions with Fendt 700, JD 7R/8RX.

### Claas ARION 570 vs 530–560

[CLAAS manufacturer release](https://www.claas.com/en-tw/press/press-releases/2025-02-11-arion-570) proves all 540/540E/1000/1000E gears on the 570 CMATIC, but not the same factory gearbox on lesser ARION 530–560. [Historical ARION 530 specification](https://www.tractordata.com/farm-tractors/006/5/8/6583-claas-arion-530.html) distinguishes 540/1000 base and optional four-speed. Only 570 now defaults to four speeds; other variants conservatively keep 540/1000 until the actual FS25-installed package is known.
