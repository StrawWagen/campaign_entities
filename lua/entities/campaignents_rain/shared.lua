
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_halter"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Rain Controller"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Controls rain."
ENT.Spawnable    = true
ENT.AdminOnly    = true

ENT.Editable = true
ENT.Model = "models/maxofs2d/cube_tool.mdl"

function ENT:SetupDataTables()
    self:NetworkVar( "Int", 0,      "Intensity",        { KeyName = "intensity",        Edit = { type = "Int", order = 1, min = 0, max = 3, } } )
    self:NetworkVar( "Float", 0,    "Responsiveness",   { KeyName = "responsiveness",   Edit = { type = "Float", order = 2, min = 0.1, max = 1, } } )

    self:NetworkVar( "Bool", 0,     "LongDistFx",       { KeyName = "longdistfx",       Edit = { type = "Bool", order = 3, title = "Laggy, background rain?" } } )

    if SERVER then
        self:SetIntensity( 1 )
        self:SetResponsiveness( 0.2 )
        self:SetLongDistFx( true )

    end
end

local campaignents_RainSpawner

function ENT:BestowerSetup()
    self:AddEFlags( EFL_FORCE_CHECK_TRANSMIT )
    self:SetMaterial( "models/campaignents/cube_rain" )

    game.AddParticles( "particles/forest_dynamic_rain_modified.pcf" )
    PrecacheParticleSystem( "forest_particle_rain_campaignents" )

    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        self:SelfSetup()

    end )

    if not WireLib then return end

    self.Inputs = Wire_CreateInputs( self, { "Intensity" } )

end

function ENT:TriggerInput( iname, value )
    if iname == "Intensity" then
        self:SetIntensity( value )

    end
end

local nextTinterMessage = 0

function ENT:SelfSetup()
    campaignents_RainSpawner = CAMPAIGN_ENTS.EnsureOnlyOneExists( self )
    if self.duplicatedIn then return end
    if nextTinterMessage > CurTime() then return end
    if CAMPAIGN_ENTS.EnabledAi() then
        local MSG = "I spawn in some modified rain!\nSounds included!\nI recommend spawning in some fog, maybe tint the player's screen?"
        CAMPAIGN_ENTS.MessageOwner( self, MSG )
        MSG = "This message will not appear when duped in."
        CAMPAIGN_ENTS.MessageOwner( self, MSG )

        nextTinterMessage = CurTime() + 25

    end
end

function ENT:Use( _, _, _, _ )
end

function ENT:OnDuplicated()
    self.duplicatedIn = true

end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS

end

if SERVER then
    -- FROM L4D2
    resource.AddSingleFile( "sound/campaign_entities/rain/crucial_int_rainverb_hard_loop.wav" )
    resource.AddSingleFile( "sound/campaign_entities/rain/crucial_int_rainverb_med_loop.wav" )
    resource.AddSingleFile( "sound/campaign_entities/rain/crucial_surfacerain_hard_loop.wav" )
    resource.AddSingleFile( "sound/campaign_entities/rain/crucial_surfacerain_med_loop.wav" )
    resource.AddSingleFile( "sound/campaign_entities/rain/crucial_surfacerain_light_loop.wav" )
    resource.AddSingleFile( "sound/campaign_entities/rain/interior_rain_med_loop.wav" )

    resource.AddSingleFile( "particles/forest_dynamic_rain_modified.pcf" )
    resource.AddSingleFile( "materials/particle/rain_campaignents.vtf" )
    resource.AddSingleFile( "materials/particle/raindrop-multi2_campaignents.vtf" ) -- from stormfox 2

    resource.AddSingleFile( "materials/models/campaignents/cube_rain.vmt" )
    resource.AddSingleFile( "materials/models/campaignents/cube_rain.vtf" )

end

if not CLIENT then return end

local function traceIsSky( tr )
    if tr.HitSky or ( not tr.Hit and not tr.StartSolid ) then return true end

end

local function PosCanSee( startPos, endPos, filter, mask )
    if not startPos then return end
    if not endPos then return end

    mask = mask or MASK_SHOT

    local trData = {
        start = startPos,
        endpos = endPos,
        mask = mask,
        filter = filter
    }
    local trace = util.TraceLine( trData )
    return not trace.Hit, trace

end

local upOffset = Vector( 0, 0, 25000 )

local function getSkyOfPos( startPos )
    local startOffsetVec = Vector()
    local trData = {
        mask = MASK_SOLID_BRUSHONLY,

    }
    local goingUpResult
    local success
    for extent = 1, 50 do
        trData.start = startPos + startOffsetVec
        trData.endpos = startPos + upOffset + startOffsetVec

        startOffsetVec.x = math.Rand( -6, 6 ) * extent
        startOffsetVec.y = math.Rand( -6, 6 ) * extent

        goingUpResult = util.TraceLine( trData )

        if traceIsSky( goingUpResult ) then success = true break end

    end

    if not success then return end

    return goingUpResult.HitPos

end

local downOffset = Vector( 0, 0, -30000 ) -- greater than going up one above, otherwise it never reaches ground next to ply

local function getBestRaindrop( startPos, targetPos )
    local startOffsetVec = Vector()
    local trData = {
        mask = bit.bor( MASK_SHOT, CONTENTS_GRATE ),

    }
    local doneCount = 0
    local goingDownResults = {}
    for extent = 1, 50 do
        trData.start = startPos + startOffsetVec
        trData.endpos = startPos + downOffset + startOffsetVec

        startOffsetVec.x = math.Rand( -1, 1 ) * extent^1.8
        startOffsetVec.y = math.Rand( -1, 1 ) * extent^1.8

        local goingDownResult = util.TraceLine( trData )
        if not goingDownResult.Hit then continue end
        if goingDownResult.StartSolid then continue end

        local distToTargSqr = goingDownResult.HitPos:DistToSqr( targetPos )
        goingDownResults[ distToTargSqr ] = goingDownResult
        doneCount = doneCount + 1

    end

    if doneCount <= 0 then return end

    local bestDropDist = math.huge
    local bestDrop = nil
    for dropDist, drop in pairs( goingDownResults ) do
        if dropDist < bestDropDist then
            bestDrop = drop
            bestDropDist = dropDist

        end
    end

    return bestDrop.HitPos, math.sqrt( bestDropDist )

end

local campaignents_rainIntensity = 0
local doneSomething = 0
local particleEffecting = false
local nextFarRain = 0

function ENT:OnRemove()
    if self.campaignents_Overriden then return end
    campaignents_rainIntensity = 0
    particleEffecting = false

end

function ENT:Think()
    if not campaignents_RainSpawner or campaignents_RainSpawner ~= self then
        campaignents_RainSpawner = self

    end
    local myIntensity = self:GetIntensity()
    if not campaignents_rainIntensity or campaignents_rainIntensity ~= myIntensity then
        campaignents_rainIntensity = math.Approach( campaignents_rainIntensity, myIntensity, self:GetResponsiveness() / 500 )
        doneSomething = 500

    end
    if campaignents_rainIntensity > 0 and particleEffecting ~= true then
        ParticleEffect( "forest_particle_rain_campaignents", self:GetPos(), Angle( 0,0,0 ), self )
        particleEffecting = true

    elseif campaignents_rainIntensity <= 0 and particleEffecting == true then
        self:StopParticleEmission()
        particleEffecting = false

    end
    if doneSomething <= 0 then
        self:SetNextClientThink( CurTime() + 1 )
        return true

    end
    doneSomething = doneSomething + -1
    self:SetNextClientThink( CurTime() )
    return true

end

hook.Add( "Think", "campaignents_rain_farrain", function()
    if campaignents_rainIntensity <= 0 then return end
    if nextFarRain > CurTime() then return end
    if not IsValid( campaignents_RainSpawner ) then return end
    if not campaignents_RainSpawner:GetLongDistFx() then return end

    local divisor = math.max( 1.5, campaignents_rainIntensity )
    nextFarRain = CurTime() + ( math.Rand( 0.75, 0.95 ) / divisor )

    local rain = EffectData()
    rain:SetEntity( LocalPlayer() )
    rain:SetScale( campaignents_rainIntensity )
    util.Effect( "eff_campaignents_rain_dense", rain )

end )

local underAwningSound = {
    [1] = "campaign_entities/rain/crucial_int_rainverb_med_loop.wav",
    [2] = "campaign_entities/rain/crucial_int_rainverb_hard_loop.wav",

}
local inTheRainSound = {
    [1] = "campaign_entities/rain/crucial_surfacerain_light_loop.wav",
    [2] = "campaign_entities/rain/crucial_surfacerain_med_loop.wav",
    [3] = "campaign_entities/rain/crucial_surfacerain_hard_loop.wav",

}

local insideBuildingSound = "campaign_entities/rain/interior_rain_med_loop.wav"

local aboveGround = Vector( 0,0,40 )
local LocalPlayer = LocalPlayer
local math_abs = math.abs
local CurTime = CurTime
local abovePlayerAtSkyHeight = Vector()
local rainSoundscape = {}
local rainAudibleDist = 1200
local timeBetweenChecksMul = 1

local function addSoundsForIntensity( sounds, currIntensity, maxVolume )
    local maxSound = table.maxn( sounds )
    for soundsIntensity, aSound in ipairs( sounds ) do
        local intensityDist = currIntensity - soundsIntensity

        -- last sound, don't fade down from it
        local isLast = intensityDist > -1 and soundsIntensity == maxSound
        if isLast then
            intensityDist = math.min( intensityDist, 0 )

        end

        local intensityDistAbs = math_abs( intensityDist )
        if intensityDistAbs > 1 and not isLast then continue end

        local distReversed = math_abs( intensityDistAbs - 1 )

        rainSoundscape[ aSound ] = maxVolume * distReversed

    end
end

hook.Add( "Think", "campaignents_rainaudio_think", function()
    if campaignents_rainIntensity <= 0 then return end

    local cur = CurTime()
    local ply = LocalPlayer()
    local shootPos = ply:GetShootPos()
    local vel = ply:GetVelocity()
    local velOffs = vel / 6

    -- if we are directly under the sky then just make rain noise
    local _, skyTrBasic = PosCanSee( shootPos, shootPos + upOffset, ply, MASK_SHOT )
    if traceIsSky( skyTrBasic ) then
        ply.campaignents_NearestSkyPos = skyTrBasic.HitPos
        addSoundsForIntensity( inTheRainSound, campaignents_rainIntensity, 1.25 )
        return

    end

    local nearestSky = ply.campaignents_NearestSkyPos
    local nextSkyUpdate = ply.campaignents_NextNearestSkyUpdate or 0

    local timeBetweenChecksMulInt = timeBetweenChecksMul
    if ply.campaignents_RainOldPos and ( shootPos - ply.campaignents_RainOldPos ):LengthSqr() < 0.1 then
        timeBetweenChecksMulInt = 6

    end
    ply.campaignents_RainOldPos = shootPos

    if not nearestSky or nextSkyUpdate < cur then
        local theNearestSky = getSkyOfPos( shootPos + velOffs )
        if theNearestSky then
            nearestSky = theNearestSky
            ply.campaignents_NearestSkyPos = nearestSky
            ply.campaignents_NextNearestSkyUpdate = CurTime() + ( 0.15 * timeBetweenChecksMulInt )

        end
    end

    if not nearestSky then return end

    local nearestRainLand = ply.campaignents_NearestRainLand
    local nearestLandDist = ply.campaignents_NearestRainLandDist
    local nearestLandHasLos = ply.campaignents_nearestLandHasLos
    local nextRainLandUpdate = ply.campaignents_NextNearestRainLandUpdate or 0

    if not nearestRainLand or nextRainLandUpdate < cur then
        abovePlayerAtSkyHeight.z = nearestSky.z
        if nearestRainLand and nearestLandDist < rainAudibleDist / 2 then
            abovePlayerAtSkyHeight.x = nearestRainLand.x
            abovePlayerAtSkyHeight.y = nearestRainLand.y

        else
            abovePlayerAtSkyHeight.x = shootPos.x
            abovePlayerAtSkyHeight.y = shootPos.y

        end

        local breakingLos
        local theNearestLandHasLos
        local theNearestRainLand, theNearestLandDist = getBestRaindrop( abovePlayerAtSkyHeight, shootPos + velOffs )
        if theNearestRainLand then
            local oldCanSee = nil
            if nearestRainLand then
                oldCanSee = PosCanSee( nearestRainLand + aboveGround, shootPos, ply, MASK_SHOT )

            end
            theNearestLandHasLos = PosCanSee( theNearestRainLand + aboveGround, shootPos, ply, MASK_SHOT )
            breakingLos = oldCanSee == true and theNearestLandHasLos ~= true and ( nearestLandDist < rainAudibleDist / 2 )

        end

        if theNearestRainLand and not breakingLos then
            nearestRainLand = theNearestRainLand
            ply.campaignents_NearestRainLand = nearestRainLand

            --debugoverlay.Cross( nearestRainLand, 10, 10, color_white, true )

            nearestLandDist = theNearestLandDist
            ply.campaignents_NearestRainLandDist = nearestLandDist

            nearestLandHasLos = theNearestLandHasLos
            ply.campaignents_nearestLandHasLos = nearestLandHasLos

            ply.campaignents_NextNearestRainLandUpdate = CurTime() + ( 0.08 * timeBetweenChecksMulInt )

        else
            nearestLandDist = shootPos:Distance( nearestRainLand )
            ply.campaignents_NearestRainLandDist = nearestLandDist

        end
    end

    local invertedDist = math.abs( nearestLandDist - rainAudibleDist )
    local distScalar = invertedDist / rainAudibleDist
    distScalar = distScalar * 10
    distScalar = distScalar^2.6
    distScalar = distScalar / 400

    local canHearTheRain = nearestLandDist < rainAudibleDist
    local inTheRain = nearestLandDist < math.max( 65, vel:Length() / 3.5 )

    if not canHearTheRain then
        return

    elseif not nearestLandHasLos then
        local _, traceToRainPos = PosCanSee( shootPos, nearestRainLand + aboveGround, ply, MASK_SHOT )
        local _, traceFromRainPos = PosCanSee( nearestRainLand + aboveGround, shootPos, ply, MASK_SHOT )
        local scaled = ( distScalar - 0.3 ) ^ 0.8
        addSoundsForIntensity( underAwningSound, campaignents_rainIntensity, scaled / 2 )

        -- thin roof/wall!
        if traceToRainPos.HitPos:Distance( traceFromRainPos.HitPos ) < 30 then
            rainSoundscape[ insideBuildingSound ] = scaled

        end

    elseif nearestLandHasLos and not inTheRain then
        addSoundsForIntensity( inTheRainSound, campaignents_rainIntensity, distScalar - 0.5 )
        addSoundsForIntensity( underAwningSound, campaignents_rainIntensity, distScalar )

    elseif nearestLandHasLos and inTheRain then
        addSoundsForIntensity( inTheRainSound, campaignents_rainIntensity, 1.25 )

    end
end )

local theSounds = {}
local thinkInterval = 0.01
local nextThink = 0
local volumeMul = CreateClientConVar( "campaignents_cl_rainvolume", -1, true, false, "Rain volume, -1 for default", -1, 1 )
local defaultVol = 0.3

hook.Add( "Think", "campaignents_rainaudio_manage", function()
    local cur = CurTime()
    if nextThink > cur then return end
    nextThink = cur + ( thinkInterval * 1.1 )

    local ply = LocalPlayer()
    local globalVolume = volumeMul:GetFloat()
    if globalVolume <= -1 then
        globalVolume = defaultVol

    end

    for currPath, targetVolume in pairs( rainSoundscape ) do
        if currPath == "" then continue end
        local actualSound = theSounds[currPath]
        targetVolume = math.Round( targetVolume, 2 ) * globalVolume
        if targetVolume > thinkInterval and ( not actualSound or not actualSound:IsPlaying() ) then
            if actualSound then
                actualSound:Stop()

            end
            actualSound = CreateSound( ply, currPath )
            actualSound:PlayEx( 0, 100 )

            theSounds[currPath] = actualSound
            return

        end

        if not actualSound then continue end

        local offset = math.Rand( -0.01, 0.01 ) -- stop stupid bug from sticking around
        local currVolume = math.Round( actualSound:GetVolume() + offset, 2 )
        local approachRate = math.abs( currVolume - targetVolume ) / 6

        if currVolume < targetVolume then
            actualSound:ChangeVolume( currVolume + approachRate, thinkInterval )

        elseif currVolume > targetVolume then
            actualSound:ChangeVolume( currVolume + -approachRate, thinkInterval )
            if currVolume <= thinkInterval then
                actualSound:Stop()
                theSounds[currPath] = nil

            end
        end

        rainSoundscape[currPath] = targetVolume + -thinkInterval

    end
end )