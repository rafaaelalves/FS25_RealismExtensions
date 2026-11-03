-- No engine/GIANTS dependency. Verify positional continuity BEFORE
-- using old wheel contacts to produce candidate rut samples.
dofile("scripts/terrain/TerrainWheelPathContinuity.lua")
local P=RealismExtensionsTerrainWheelPathContinuity
local o={vehicleSpeedKph=18,spacingM=0.25,maxSamples=6}
local function a(x0,z0,x,z,ms,opt)
    return P.analyze(x0,z0,x,z,ms,opt or o)
end
local first=a(nil,nil,2,2,250)
assert(first.state=="RESET_ANCHOR" and not first.pathContinuous)
assert(first.movingSamples==1 and first.dirX==nil)
local normal=a(0,0,1,0,250)
assert(normal.state=="CONTINUOUS" and normal.completeCoverage)
assert(normal.movingSamples==4 and math.abs(normal.dirX-1)<1e-9)
assert(normal.dirZ==0)
local reverse=a(1,0,0,0,250)
assert(reverse.state=="CONTINUOUS" and reverse.dirX==-1)
local diag=a(0,0,0.6,0.8,250)
assert(diag.state=="CONTINUOUS"
    and math.abs(diag.dirX-0.6)<1e-9
    and math.abs(diag.dirZ-0.8)<1e-9)
local stationary=a(0,0,0.01,0.01,250)
assert(stationary.state=="STATIONARY"
    and not stationary.pathContinuous and stationary.dirX==nil)
-- Physical plausibility: vehicle reset/teleport never creates intermediate
-- fictitious wheel contact or 100m worth of synthetic ruts.
local teleport=a(10,20,110,20,250)
assert(teleport.state=="RESET_ANCHOR")
assert(teleport.reason=="IMPLAUSIBLE_POSITION_JUMP")
assert(teleport.movingSamples==1 and not teleport.pathContinuous)
-- Realistic low-speed transport, but position moved like a 30km/h car.
local slow=a(0,0,4,0,250,{vehicleSpeedKph=2,
    spacingM=0.25,maxSamples=6})
assert(slow.state=="RESET_ANCHOR")
-- At 30km/h + slack, an actually continuous 2m pass may legitimately
-- exceed the interpolation budget. Its segment is NOT fully covered.
local undersampled=a(0,0,2,0,250,{vehicleSpeedKph=30,
    spacingM=0.20,maxSamples=6})
assert(undersampled.state=="UNDER_SAMPLED")
assert(undersampled.pathContinuous and not undersampled.completeCoverage)
assert(undersampled.movingSamples==6)
-- No inferred travel heading on long pause, backwards clock or missing
-- movement evidence. Reanchor even when the physical delta seems small.
assert(a(0,0,0.2,0,2000).state=="RESET_ANCHOR")
assert(a(0,0,0.2,0,0).state=="RESET_ANCHOR")
assert(a(0,0,0.2,0,0/0).state=="RESET_ANCHOR")
assert(a(0,0,0.2,0,250,{spacingM=0}).state=="REJECT")
assert(a(0,0,0/0,1,250).state=="REJECT")
-- Missing body-speed evidence falls back to a fixed hard safety ceiling;
-- it never gets silently treated as zero-speed or as infinite permission.
local unknown=a(0,0,1,0,250,{spacingM=0.25})
assert(unknown.state=="CONTINUOUS")
assert(a(0,0,90,0,250,{spacingM=0.25}).state=="RESET_ANCHOR")
print("terrain_wheel_path_continuity_harness: OK")
