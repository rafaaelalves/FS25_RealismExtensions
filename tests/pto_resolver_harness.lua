dofile("scripts/pto/PTOModel.lua")
dofile("scripts/pto/PTOProfiles.lua")
dofile("scripts/pto/PTOResolver.lua")

local M=RealismExtensionsPTOModel
local R=RealismExtensionsPTOResolver

local motor={
    minRpm=800,
    maxRpm=2200,
    getPtoMotorRpmRatio=function() return 4.0 end
}

local fiat={
    configFileName="/mods/fiat18090.xml",
    getName=function() return "Fiat 180-90 DT" end,
    getMotor=function() return motor end,
    getOutputPowerTakeOffs=function() return {rear={}} end,
    getAttachedImplements=function() return {} end
}

assert(R.vehicleHasOutputPto(fiat)==true)
local cap=R.resolveCapability(fiat)
assert(cap.source=="PROFILE")
assert(cap.modes[M.MODE.RPM_540]~=nil)
assert(cap.modes[M.MODE.RPM_1000]~=nil)
assert(cap.modes[M.MODE.RPM_540_ECO]==nil)

local johnDeere={
    configFileName="data/vehicles/johnDeere/series6R/series6RLarge.xml",
    getName=function() return "6R 155" end,
    getMotor=function() return motor end,
    getOutputPowerTakeOffs=function() return {rear={}} end,
    getAttachedImplements=function() return {} end
}
local jdCap=R.resolveCapability(johnDeere)
assert(jdCap.source=="PROFILE")
assert(jdCap.profileId=="john_deere_6r_155")
assert(jdCap.modes[M.MODE.RPM_540]~=nil)
assert(jdCap.modes[M.MODE.RPM_540_ECO]~=nil)
assert(jdCap.modes[M.MODE.RPM_1000]~=nil)
assert(jdCap.modes[M.MODE.RPM_1000_ECO]==nil)
assert(math.abs(
    jdCap.modes[M.MODE.RPM_540].effectiveMotorRatio-(1987/540)
)<0.000001)
assert(math.abs(
    jdCap.modes[M.MODE.RPM_540_ECO].effectiveMotorRatio-(1753/540)
)<0.000001)
assert(math.abs(
    jdCap.modes[M.MODE.RPM_1000].effectiveMotorRatio-2.0
)<0.000001)

local unknown={
    configFileName="/mods/unknownTractor.xml",
    getMotor=function() return motor end,
    getOutputPowerTakeOffs=function() return {rear={}} end,
    getAttachedImplements=function() return {} end
}
local fallback=R.resolveCapability(unknown)
assert(fallback.source=="NATIVE_FALLBACK")
assert(fallback.modes[M.MODE.RPM_540]~=nil)
assert(fallback.modes[M.MODE.RPM_1000]==nil)
assert(math.abs(fallback.modes[M.MODE.RPM_540].effectiveMotorRatio-4.0)<0.000001)

local chipperActive=false
local chipper={
    configFileName="/mods/hm10500KF.xml",
    spec_powerConsumer={ptoRpm=540},
    spec_powerTakeOffs={inputPowerTakeOffs={{}}},
    getIsPowerTakeOffActive=function() return chipperActive end,
    getIsTurnedOn=function() return chipperActive end,
    getAttachedImplements=function() return {} end
}
local mowerActive=false
local mower={
    configFileName="/mods/mower.xml",
    spec_powerConsumer={ptoRpm=540},
    spec_powerTakeOffs={inputPowerTakeOffs={{}}},
    getIsPowerTakeOffActive=function() return mowerActive end,
    getIsTurnedOn=function() return mowerActive end,
    getAttachedImplements=function() return {} end
}
local hydraulicPlowActive=true
local hydraulicPlow={
    configFileName="/mods/hydraulicPlow.xml",
    -- Generic power consumer + hoses/cables, but deliberately no input PTO
    -- and no ptoRpm. This must never become a PTO consumer.
    spec_powerConsumer={neededPower=85},
    spec_connectionHoses={hoses={{type="hydraulic"},{type="electric"}}},
    spec_plow={},
    getInputPowerTakeOffs=function() return {} end,
    getIsTurnedOn=function() return hydraulicPlowActive end,
    getAttachedImplements=function() return {} end
}

local unknownInputPto={
    configFileName="/mods/unknownPtoImplement.xml",
    spec_powerTakeOffs={inputPowerTakeOffs={{}}},
    getAttachedImplements=function() return {} end
}

fiat.getAttachedImplements=function()
    return {{object=hydraulicPlow}}
end
local req=R.collectRequirements(fiat)
assert(req.hasPtoConsumer==false)
assert(req.requiredRpm==nil)
assert(req.knownCount==0)
assert(req.unknownCount==0)

-- A real input PTO without an RPM remains a PTO consumer, but requirement
-- family is intentionally unknown rather than guessed.
fiat.getAttachedImplements=function()
    return {{object=unknownInputPto}}
end
req=R.collectRequirements(fiat)
assert(req.hasPtoConsumer==true)
assert(req.requiredRpm==nil)
assert(req.knownCount==0)
assert(req.unknownCount==1)
assert(req.items[1].source=="INPUT_PTO")

fiat.getAttachedImplements=function()
    return {{object=chipper}}
end
req=R.collectRequirements(fiat)
assert(req.hasPtoConsumer==true)
assert(req.requiredRpm==1000)
assert(req.conflict==false)
assert(req.primary.source=="PROFILE")

fiat.getAttachedImplements=function()
    return {{object=chipper},{object=mower}}
end
req=R.collectRequirements(fiat)
assert(req.conflict==true)
assert(req.requiredRpm==nil)

-- Turned-on hydraulic/electrical tools with a generic PowerConsumer must not
-- be mistaken for PTO engagement.
fiat.getAttachedImplements=function()
    return {{object=hydraulicPlow}}
end
fiat.getIsPowerTakeOffActive=function() return false end
local engaged,source=R.isPtoEngaged(fiat)
assert(engaged==false)
assert(source=="NO_ACTIVE_CONSUMER")

-- Tractor PowerTakeOffs itself reports false; active state lives on the
-- attached PTO-consuming implement specialization.
fiat.getAttachedImplements=function()
    return {{object=chipper}}
end
engaged,source=R.isPtoEngaged(fiat)
assert(engaged==false)
assert(source=="NO_ACTIVE_CONSUMER")

chipperActive=true
engaged,source=R.isPtoEngaged(fiat)
assert(engaged==true)
assert(source=="IMPLEMENT_PTO_ACTIVE")

-- Fallback: a modded PTO consumer can expose only TurnOnVehicle state.
chipper.getIsPowerTakeOffActive=nil
engaged,source=R.isPtoEngaged(fiat)
assert(engaged==true)
assert(source=="IMPLEMENT_TURNED_ON")

chipperActive=false
engaged,source=R.isPtoEngaged(fiat)
assert(engaged==false)
assert(source=="NO_ACTIVE_CONSUMER")

-- Every current medium tractor store family must be recorded, even if
-- its exact PTO hardware still requires factory/configuration evidence.
local P=RealismExtensionsPTOProfiles
assert(#P.MEDIUM_CATALOG==24)
local ids={}
for _,p in ipairs(P.TRACTORS) do
    assert(ids[p.id]==nil,"duplicate PTO profile "..p.id)
    assert(type(p.evidenceUrl)=="string" and p.evidenceUrl:find("https://",1,true)==1)
    ids[p.id]=true
end
local coverage={
    agco_white_8010={"AGCO White 8010", "agco_white_8010"},
    case_ih_puma_afs={"Puma 260", "case_ih_puma_afs"},
    challenger_mt600={"Challenger MT635", "challenger_mt600"},
    deutz_agrostar_831={"AgroStar 8.31", "deutz_agrostar_831"},
    deutz_6230_ttv={"6230 TTV", "deutz_6230_ttv"},
    deutz_7_ttv_hd={"7250 TTV", "deutz_7_ttv_hd"},
    deutz_8_ttv={"8280 TTV", "deutz_8_ttv"},
    fendt_700_gen7={"Fendt 728 Vario", "fendt_700_gen7"},
    fiat_160_90={"Fiat 160-90 DT", "fiat_160_90"},
    jcb_fastrac_4000_icon={"Fastrac 4220", "jcb_fastrac_4000_icon"},
    john_deere_6r_145_185={"6R 145", "john_deere_6r_145_185"},
    john_deere_6r_230_250={"6R 230", "john_deere_6r_230_250"},
    kubota_m8={"Kubota M8-181", "kubota_m8"},
    massey_ferguson_7s={"MF 7S.190", "massey_ferguson_7s"},
    mccormick_x8={"X8 VT-Drive", "mccormick_x8"},
    mercedes_mb_trac_1100_1500={"MB-trac 1500", "mercedes_mb_trac_1100_1500"},
    mercedes_mb_trac_1300_1800={"MB-trac 1800", "mercedes_mb_trac_1300_1800"},
    mercedes_unimog_1800_2400=nil,
    mercedes_unimog_527_535=nil,
    new_holland_t7_lwb={"T7.260", "new_holland_t7_lwb"},
    steyr_absolut_cvt={"Absolut CVT", "steyr_absolut_cvt"},
    valtra_t={"Valtra T Series", "valtra_t"},
    versatile_nemesis={"Versatile Nemesis", "versatile_nemesis"},
    zetor_crystal_hd={"Crystal HD 170", "zetor_crystal_hd"}
}
for _,id in ipairs(P.MEDIUM_CATALOG) do
    assert(coverage[id]~=nil or P.PENDING_MEDIUM[id]~=nil, "medium family undocumented: "..id)
    if coverage[id] then
        local label,profileId=table.unpack(coverage[id])
        local found=P.findTractor({configFileName="/vehicles/sample.xml",getName=function() return label end})
        assert(found~=nil and found.id==profileId,
            "medium profile identity failed: "..id.." / "..label.." / "..tostring(found and found.id))
    end
end
local function claim(label, expected, unexpected)
    local p=P.findTractor({configFileName="/vehicles/sample.xml",getName=function() return label end})
    assert(p~=nil, "missing profile "..label)
    local cap=R.resolveCapability({configFileName="/vehicles/sample.xml",getName=function() return label end,getMotor=function() return motor end})
    for _,m in ipairs(expected) do assert(cap.modes[M.normalizeMode(m)]~=nil,label.." missing "..m) end
    for _,m in ipairs(unexpected or {}) do assert(cap.modes[M.normalizeMode(m)]==nil,label.." must not offer "..m) end
end
claim("Fendt 728 Vario",{"540","540E","1000","1000E"})
claim("8280 TTV",{"540E","1000","1000E"},{"540"})
claim("6R 250",{"540E","1000","1000E"},{"540"})
claim("AgroStar 8.31",{"1000"},{"540"})
claim("Versatile Nemesis 255",{"540E","1000","1000E"},{"540"})
claim("MF 7S.155",{"540","1000"},{"540E","1000E"})
claim("Valtra T Series",{"540","1000"},{"540E","1000E"})
claim("Fiat 160-90 DT",{"540","1000"},{"540E","1000E"})
assert(P.findTractor({getName=function() return "6R 155" end}).id=="john_deere_6r_155")
assert(P.findTractor({getName=function() return "Fiat 180-90 DT" end}).id=="fiat_180_90")
assert(P.findTractor({getName=function() return "Unimog U 535" end})==nil)

print("pto_resolver_harness: OK")
