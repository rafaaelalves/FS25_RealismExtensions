-- Research-only geometric representability screen for the MAIN heightmap.
-- Tests the wheel's oriented CONTACT RECTANGLE against one coarse vertex's
-- Voronoi/square support cell. This is NOT a native 0.125m wheel-surface
-- query, does not infer permanent terrain ownership, and NEVER writes height.
-- A plausible result is only a research candidate; collision, origin,
-- quantization, external edits, persistence and recovery remain separate gates.
RealismExtensionsTerrainMainFootprintGate =
    RealismExtensionsTerrainMainFootprintGate or {}
local Gate=RealismExtensionsTerrainMainFootprintGate
Gate.VERSION=1

local function finite(x)
    return type(x)=="number" and x==x
        and x~=math.huge and x~=-math.huge
end

local function outcome(state,reason,overlap,unit,footprintArea)
    local ratio=0
    if finite(unit) and unit>0 and finite(overlap) then
        ratio=math.max(0,math.min(1,overlap/(unit*unit)))
    end
    return {
        state=state,reason=reason,coverage01=ratio,
        overlappedAreaM2=math.max(0,overlap or 0),
        footprintAreaM2=math.max(0,footprintArea or 0),
        doesNotWrite=true,authorizesMainWrite=false
    }
end

-- Clip a convex polygon against one axis-aligned half-plane.
-- Vertices are {x,z}; an empty polygon means no supported area.
local function clip(poly,axis,bound,keepAbove)
    local result={}
    if #poly==0 then return result end
    local last=poly[#poly]
    local function inside(p)
        if keepAbove then return p[axis]>=bound end
        return p[axis]<=bound
    end
    local lastInside=inside(last)
    for _,now in ipairs(poly) do
        local nowInside=inside(now)
        if nowInside~=lastInside then
            local d=now[axis]-last[axis]
            if math.abs(d)>1e-12 then
                local t=(bound-last[axis])/d
                result[#result+1]={
                    last[1]+t*(now[1]-last[1]),
                    last[2]+t*(now[2]-last[2])
                }
            end
        end
        if nowInside then result[#result+1]=now end
        last,lastInside=now,nowInside
    end
    return result
end

local function area(poly)
    if #poly<3 then return 0 end
    local twice=0
    local prev=poly[#poly]
    for _,p in ipairs(poly) do
        twice=twice+prev[1]*p[2]-p[1]*prev[2]
        prev=p
    end
    return math.abs(twice)*0.5
end

-- Direction is wheel travel orientation (not yaw inferred from vehicle root).
-- Width and length are actual RE footprint-model estimates. As a deliberate
-- conservative screen we use only one sampled contact rectangle: we do NOT
-- concatenate sequential samples or sum overlapping 0.20m source cells into
-- a fictitious wider 1m track.
function Gate.evaluate(o)
    if type(o)~="table" then
        return outcome("GEOMETRY_UNKNOWN","MISSING_CONTEXT",0,nil,0)
    end
    local u=tonumber(o.unitM)
    if not finite(u) or u<=0 then
        return outcome("GEOMETRY_UNKNOWN","MAIN_UNIT_UNAVAILABLE",0,nil,0)
    end
    local fields={"vertexX","vertexZ","contactX","contactZ",
        "supportWidthM","footprintLengthM","dirX","dirZ"}
    for _,field in ipairs(fields) do
        if not finite(o[field]) then
            return outcome("GEOMETRY_UNKNOWN","MISSING_"..field,0,u,0)
        end
    end
    local w,len=o.supportWidthM,o.footprintLengthM
    if w<=0 or len<=0 or w>12*u or len>12*u then
        return outcome("GEOMETRY_UNKNOWN","INVALID_CONTACT_DIMENSIONS",0,u,0)
    end
    if o.footprintAvailable~=true or o.isCrawler==true then
        return outcome("GEOMETRY_UNKNOWN","UNVERIFIED_CONTACT_TOPOLOGY",0,u,0)
    end
    local dx,dz=o.dirX,o.dirZ
    local norm=math.sqrt(dx*dx+dz*dz)
    if not finite(norm) or norm<1e-6 then
        return outcome("GEOMETRY_UNKNOWN","TRAVEL_ORIENTATION_UNKNOWN",0,u,w*len)
    end
    dx,dz=dx/norm,dz/norm
    local nx,nz=-dz,dx
    local hx,hz=dx*len*0.5,dz*len*0.5
    local wx,wz=nx*w*0.5,nz*w*0.5
    local x,z=o.contactX,o.contactZ
    local poly={
        {x-hx-wx,z-hz-wz},
        {x+hx-wx,z+hz-wz},
        {x+hx+wx,z+hz+wz},
        {x-hx+wx,z-hz+wz}
    }
    local minX,maxX=o.vertexX-u*0.5,o.vertexX+u*0.5
    local minZ,maxZ=o.vertexZ-u*0.5,o.vertexZ+u*0.5
    poly=clip(poly,1,minX,true)
    poly=clip(poly,1,maxX,false)
    poly=clip(poly,2,minZ,true)
    poly=clip(poly,2,maxZ,false)
    local overlap=area(poly)
    local covered=math.min(1,overlap/(u*u))
    -- Deliberately conservative *research* threshold, not a proven
    -- terrain kernel/collision envelope. It must never grant write access.
    local minimum=tonumber(o.minCellCoverage01)
    if not finite(minimum) or minimum<0.5 or minimum>1 then
        minimum=0.75
    end
    if w<0.75*u or len<0.75*u then
        return outcome("FINE_ONLY_OR_UNREPRESENTABLE",
            "CONTACT_NARROWER_THAN_MAIN_SUPPORT",overlap,u,w*len)
    end
    if covered+1e-9<minimum then
        return outcome("FINE_ONLY_OR_UNREPRESENTABLE",
            "INSUFFICIENT_MAIN_CELL_COVERAGE",overlap,u,w*len)
    end
    return outcome("MAIN_RESEARCH_CANDIDATE",
        "FOOTPRINT_ONLY_OTHER_GATES_UNVERIFIED",overlap,u,w*len)
end

return Gate
