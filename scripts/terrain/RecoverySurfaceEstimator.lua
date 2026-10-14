RealismExtensionsRecoverySurfaceEstimator =
    RealismExtensionsRecoverySurfaceEstimator or {}
local Estimator = RealismExtensionsRecoverySurfaceEstimator

Estimator.VERSION = 1
Estimator.DEFAULTS = {
    minBoundaryInliers = 4,
    minOutlierThresholdM = 0.005,
    madMultiplier = 3.0
}

local function validNumber(v)
    return type(v) == "number"
        and v == v
        and v ~= math.huge
        and v ~= -math.huge
end

local function median(values)
    if #values == 0 then return nil end
    local copy = {}
    for i,v in ipairs(values) do copy[i]=v end
    table.sort(copy)
    local n=#copy
    if n%2==1 then return copy[(n+1)/2] end
    return (copy[n/2]+copy[n/2+1])*0.5
end

local function fitPlane(samples)
    if type(samples)~="table" or #samples<3 then return nil end

    local sx,sz,sy=0,0,0
    local n=0
    for _,s in ipairs(samples) do
        if validNumber(s.dx) and validNumber(s.dz) and validNumber(s.y) then
            sx=sx+s.dx
            sz=sz+s.dz
            sy=sy+s.y
            n=n+1
        end
    end
    if n<3 then return nil end

    local mx,mz,my=sx/n,sz/n,sy/n
    local xx,zz,xz,xy,zy=0,0,0,0,0
    for _,s in ipairs(samples) do
        if validNumber(s.dx) and validNumber(s.dz) and validNumber(s.y) then
            local x,z,y=s.dx-mx,s.dz-mz,s.y-my
            xx=xx+x*x
            zz=zz+z*z
            xz=xz+x*z
            xy=xy+x*y
            zy=zy+z*y
        end
    end

    local det=xx*zz-xz*xz
    if math.abs(det)<1e-10 then return nil end

    local ax=(xy*zz-zy*xz)/det
    local az=(zy*xx-xy*xz)/det
    local c=my-ax*mx-az*mz
    return {c=c,ax=ax,az=az}
end

local function planeY(plane,dx,dz)
    return plane.c+plane.ax*dx+plane.az*dz
end

local function boundarySamples(samples)
    local out={}
    for i,s in ipairs(samples or {}) do
        if s.boundary==true or (s.boundary==nil and i>1) then
            if validNumber(s.dx) and validNumber(s.dz)
                and validNumber(s.y) then
                out[#out+1]=s
            end
        end
    end
    return out
end

function Estimator.fitReferencePlane(samples,options)
    options=options or {}
    local boundary=boundarySamples(samples)
    local first=fitPlane(boundary)
    if first==nil then return nil,"insufficient boundary geometry" end

    local residuals={}
    for _,s in ipairs(boundary) do
        residuals[#residuals+1]=
            s.y-planeY(first,s.dx,s.dz)
    end

    local med=median(residuals) or 0
    local deviations={}
    for _,r in ipairs(residuals) do
        deviations[#deviations+1]=math.abs(r-med)
    end
    local mad=median(deviations) or 0
    local threshold=math.max(
        tonumber(options.minOutlierThresholdM)
            or Estimator.DEFAULTS.minOutlierThresholdM,
        mad*(tonumber(options.madMultiplier)
            or Estimator.DEFAULTS.madMultiplier)
    )

    local inliers={}
    for _,s in ipairs(boundary) do
        local r=s.y-planeY(first,s.dx,s.dz)
        if math.abs(r-med)<=threshold then
            inliers[#inliers+1]=s
        end
    end

    local minInliers=math.max(
        3,
        math.floor(tonumber(options.minBoundaryInliers)
            or Estimator.DEFAULTS.minBoundaryInliers)
    )
    local final=first
    if #inliers>=minInliers and #inliers<#boundary then
        final=fitPlane(inliers) or first
    else
        inliers=boundary
    end

    final.boundarySamples=#boundary
    final.boundaryInliers=#inliers
    final.inlierRatio=#boundary>0 and #inliers/#boundary or 0
    final.madM=mad
    final.outlierThresholdM=threshold
    return final,nil
end

function Estimator.measure(samples,options)
    if type(samples)~="table" or #samples<4 then
        return nil,"insufficient samples"
    end

    local plane,reason=Estimator.fitReferencePlane(samples,options)
    if plane==nil then return nil,reason end

    local ss=0
    local minResidual=math.huge
    local maxResidual=-math.huge
    local centerResidual=nil
    local sumY=0
    local n=0

    for i,s in ipairs(samples) do
        if validNumber(s.dx) and validNumber(s.dz) and validNumber(s.y) then
            local residual=s.y-planeY(plane,s.dx,s.dz)
            if i==1 or s.center==true then
                centerResidual=residual
            end
            minResidual=math.min(minResidual,residual)
            maxResidual=math.max(maxResidual,residual)
            ss=ss+residual*residual
            sumY=sumY+s.y
            n=n+1
        end
    end

    if n==0 then return nil,"no valid samples" end
    centerResidual=centerResidual or 0

    return {
        referenceCenterY=planeY(plane,0,0),
        planeAx=plane.ax,
        planeAz=plane.az,
        centerResidualM=centerResidual,
        centerDeficitM=math.max(0,-centerResidual),
        valleyDepthM=math.max(0,-minResidual),
        peakHeightM=math.max(0,maxResidual),
        reliefRangeM=math.max(0,maxResidual-minResidual),
        roughnessM=math.sqrt(ss/n),
        meanY=sumY/n,
        boundaryInlierRatio=plane.inlierRatio,
        boundaryMadM=plane.madM,
        boundaryOutlierThresholdM=plane.outlierThresholdM
    },nil
end

function Estimator.compare(before,after)
    if type(before)~="table" or type(after)~="table" then return nil end
    return {
        reliefReductionM=(before.reliefRangeM or 0)
            -(after.reliefRangeM or 0),
        valleyReductionM=(before.valleyDepthM or 0)
            -(after.valleyDepthM or 0),
        centerDeficitReductionM=(before.centerDeficitM or 0)
            -(after.centerDeficitM or 0),
        roughnessReductionM=(before.roughnessM or 0)
            -(after.roughnessM or 0),
        meanShiftM=(after.meanY or 0)-(before.meanY or 0)
    }
end

return Estimator
