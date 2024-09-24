-- overcomplicated hooks for when players get close to ents

CAMPAIGN_ENTS = CAMPAIGN_ENTS or {}

local entMeta = FindMetaTable( "Entity" )
local GetPos = entMeta.GetPos

local plyMeta = FindMetaTable( "Player" )
local SteamID64 = plyMeta.SteamID64

local vecMeta = FindMetaTable( "Vector" )
local DistToSqr = vecMeta.DistToSqr

local ipairs        = ipairs
local CurTime       = CurTime
local IsValid       = IsValid
local player_GetAll = player.GetAll
local table_insert  = table.insert
local table_remove  = table.remove
local math_max      = math.max
local math_Rand     = math.Rand

CAMPAIGN_ENTS.stuffTracked  = CAMPAIGN_ENTS.stuffTracked or {}
CAMPAIGN_ENTS.isTracked     = CAMPAIGN_ENTS.isTracked or {}
CAMPAIGN_ENTS.trackRadiuses = CAMPAIGN_ENTS.trackRadiuses or {} -- radiii?

CAMPAIGN_ENTS.triggered     = CAMPAIGN_ENTS.triggered or {}
CAMPAIGN_ENTS.nextTracks    = CAMPAIGN_ENTS.nextTracks or {}
CAMPAIGN_ENTS.lastPlayerCheckVecs = CAMPAIGN_ENTS.lastPlayerCheckVecs or {}
CAMPAIGN_ENTS.lastPlayerCheckTimes = CAMPAIGN_ENTS.lastPlayerCheckTimes or {}

local waitTime = 0.05

local debugging = CreateConVar( "campaignents_debug_proximity", "0", FCVAR_NONE, "Enable developer 1 info for combat nodes" )

local debuggingBool = debugging:GetBool()
cvars.AddChangeCallback( "campaignents_debug_proximity", function( _, _, new )
    debuggingBool = tobool( new )

end, "campaignents_proximity_detectchange" )

-- internal adder/remover
local function stopTrackingEnt( toTrack )
    local isTracked = CAMPAIGN_ENTS.isTracked[toTrack]
    if not isTracked then return end
    -- yuck
    for ind, ent in ipairs( CAMPAIGN_ENTS.stuffTracked ) do
        if ent == toTracked then
            table_remove( CAMPAIGN_ENTS.stuffTracked, ind )

        end
    end
    CAMPAIGN_ENTS.trackRadiuses[toTrack]  = nil
    CAMPAIGN_ENTS.isTracked[toTrack]     = nil
    CAMPAIGN_ENTS.triggered[toTrack]      = nil

end

local function startTrackingEnt( toTrack, radius )
    local isTracked = CAMPAIGN_ENTS.isTracked[toTrack]
    CAMPAIGN_ENTS.trackRadiuses[toTrack] = radius
    if isTracked then return end
    CAMPAIGN_ENTS.nextMainTrackThink = CurTime()
    CAMPAIGN_ENTS.isTracked[toTrack] = true

    table_insert( CAMPAIGN_ENTS.stuffTracked, toTrack )

    -- let the ent setup!
    CAMPAIGN_ENTS.nextTracks[toTrack] = CurTime() + waitTime
    -- check, NOW!
    CAMPAIGN_ENTS.lastPlayerCheckVecs = {}
    CAMPAIGN_ENTS.lastPlayerCheckTimes = {}

    toTrack:CallOnRemove( "campaignents_proximityteardown", function( removing )
        stopTrackingEnt( removing )

    end )
end

function CAMPAIGN_ENTS.TrackPlyProximity( toTrack, radius )
    startTrackingEnt( toTrack, radius )

end

function CAMPAIGN_ENTS.StopTrackingPlyProximity( toTrack )
    startTrackingEnt( toTrack )

end

function CAMPAIGN_ENTS.PlyInProxmity( toTrack )
    if CAMPAIGN_ENTS.triggered[toTrack] then return CAMPAIGN_ENTS.triggered[toTrack] end

end

local function onProximity( toTrack, proxPly )
    -- tracked, entering prox
    hook.Run( "campaignents_OnProximity", toTrack, proxPly )
    if toTrack.CampaignEnts_OnProximity then
        toTrack:CampaignEnts_OnProximity( proxPly )

    end
end

local function onNoProximity( toTrack, proxPly )
    -- tracked, leaving prox
    hook.Run( "campaignents_OnProximityEmpty", toTrack, proxPly )
    if toTrack.CampaignEnts_OnNoProximity then
        toTrack:CampaignEnts_OnNoProximity( proxPly )

    end
end

local function findOnesThatTrigger( toTrack, ourThreshold, toCheckPlys, cur )
    local ourPos = GetPos( toTrack )

    local nextTrack = CAMPAIGN_ENTS.nextTracks[toTrack] or 0
    if nextTrack > cur then return end

    local threshDoubled = ourThreshold * 2
    threshDoubled   = threshDoubled^2
    ourThreshold    = ourThreshold^2

    local bestPlayer
    local anyWereRemotelyClose
    local bestDist = math.huge
    local filterFunc = toTrack.CampaignEnts_ProximityFilter

    for _, checkDat in ipairs( toCheckPlys ) do
        local currPly = checkDat[1]

        local pos = checkDat[2]
        local distSqr = DistToSqr( pos, ourPos )
        if distSqr < ourThreshold then
            if filterFunc and not filterFunc( toTrack, currPly ) then
                anyWereRemotelyClose = true

            else
                CAMPAIGN_ENTS.triggered[toTrack] = currPly
                return true, currPly

            end

        elseif distSqr < threshDoubled then
            anyWereRemotelyClose = true

        end
        if distSqr < bestDist then
            bestDist = distSqr
            bestPlayer = currPly

        end
    end

    if not anyWereRemotelyClose then
        CAMPAIGN_ENTS.nextTracks[toTrack] = cur + math_Rand( 2, 4 )

    else
        CAMPAIGN_ENTS.nextTracks[toTrack] = cur + math_Rand( 0.05, 0.1 )

    end

    return false, nil, bestPlayer

end

local nextMainTrackThink = nextMainTrackThink or 0

-- check, NOW!
local function resetTriggerCache()
    nextMainTrackThink = CurTime() + waitTime
    CAMPAIGN_ENTS.triggered = {}
    CAMPAIGN_ENTS.nextTracks = {}
    CAMPAIGN_ENTS.lastPlayerCheckVecs = {}
    CAMPAIGN_ENTS.lastPlayerCheckTimes = {}

end

-- wipe cache so thing respawners, etc. dont break
cvars.AddChangeCallback( "ai_disabled", resetTriggerCache, "campaignents_resettriggercache" )
cvars.AddChangeCallback( "ai_ignoreplayers", resetTriggerCache, "campaignents_resettriggercache" )

-- you should think, NOW!
hook.Add( "LoadGModSave", "campaignents_refreshproximitysystem", function()
    timer.Simple( 1, function() -- do this after everything registers as spawned in
        resetTriggerCache()

    end )
end )

local function manageTracked( toTrack, toCheckPlys, cur )
    local ourThreshold = CAMPAIGN_ENTS.trackRadiuses[toTrack]
    if not ourThreshold then return end
    if ourThreshold <= 0 then return end

    local wasLeave

    -- optimisation, dont have to check all players if they're close
    -- just have to check the one that was close last!
    local currTriggered = CAMPAIGN_ENTS.triggered[toTrack]
    if IsValid( currTriggered ) then
        -- they stopped being in proxmity!
        local filterFunc = toTrack.CampaignEnts_ProximityFilter
        local outdated = filterFunc and not filterFunc( toTrack, currTriggered )
        local tooFar = DistToSqr( GetPos( currTriggered ), GetPos( toTrack ) ) > ourThreshold^2
        if outdated or tooFar then
            CAMPAIGN_ENTS.triggered[toTrack] = nil
            wasLeave = true

        -- they're still in proximity!
        else
            return

        end
    end

    -- okay this one doesnt have an easy to check player near it, do the expensive check
    local foundAnother, newTriggered, nearestNonTriggering = findOnesThatTrigger( toTrack, ourThreshold, toCheckPlys, cur )

    if wasLeave then
        if not foundAnother then
            onNoProximity( toTrack, currTriggered )
            if debuggingBool then
                debugoverlay.Line( toTrack:GetPos(), currTriggered:GetPos(), 5, Color( 255, 0, 0 ), true )

            end
        elseif foundAnother then
            -- tracked, old, new
            hook.Run( "campaignents_OnProximitySwitch", toTrack, currTriggered, newTriggered )

        end
    elseif foundAnother then
        onProximity( toTrack, newTriggered )
        if debuggingBool then
            debugoverlay.Line( toTrack:GetPos(), newTriggered:GetPos(), 5, Color( 255, 255, 0 ), true )

        end
    end
    if nearestNonTriggering then
        toTrack.campaignents_ProxNearbyPlayer = nearestNonTriggering

    end

    toTrack.campaignents_HasDoneAProximityPass = true

end

local ignoreNoclippers = CreateConVar( "campaignents_ignorenoclippers", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Make thing respawners, etc, ignore noclipping players?" )

local function manage()
    local cur = CurTime()
    if nextMainTrackThink > cur then return end
    if #CAMPAIGN_ENTS.stuffTracked <= 0 then
        -- think slower, nothing to track
        nextMainTrackThink = cur + 5

    else
        nextMainTrackThink = cur + waitTime

    end

    local potentialTrackedPlayers = player_GetAll()
    local trackedPlayers = {}

    local ignoreClippers = ignoreNoclippers:GetBool()
    for _, ply in ipairs( potentialTrackedPlayers ) do
        if ignoreClippers then
            local moveType = ply:GetMoveType()
            if moveType == MOVETYPE_NOCLIP and not IsValid( ply:GetVehicle() ) then continue end

        end
        table_insert( trackedPlayers, ply )

    end

    local toCheckPlys = {}
    local scale = 40
    local timeToCheckWhenStill = 2

    for _, ply in ipairs( trackedPlayers ) do
        local steamId = SteamID64( ply )
        local lastCheckedVec = CAMPAIGN_ENTS.lastPlayerCheckVecs[steamId]
        local lastCheckedTime = CAMPAIGN_ENTS.lastPlayerCheckTimes[steamId]
        local plysPos = GetPos( ply )
        local needsCheck
        if not lastCheckedVec then
            needsCheck = true

        else
            -- check fast when ply is moving
            -- check slow when ply is standing still
            local tolerance = ( cur - lastCheckedTime ) * scale
            local toleranceSubt = ( scale * timeToCheckWhenStill ) - tolerance
            toleranceSubt = math_max( toleranceSubt, 0 )

            needsCheck = DistToSqr( lastCheckedVec, plysPos ) > toleranceSubt^2

        end
        if needsCheck then
            CAMPAIGN_ENTS.lastPlayerCheckVecs[steamId] = plysPos
            CAMPAIGN_ENTS.lastPlayerCheckTimes[steamId] = cur

            table_insert( toCheckPlys, { ply, plysPos } )

        end
    end

    if #toCheckPlys <= 0 then return end

    for ind, toTrack in ipairs( CAMPAIGN_ENTS.stuffTracked ) do
        if not IsValid( toTrack ) then table_remove( CAMPAIGN_ENTS.stuffTracked, ind ) continue end
        manageTracked( toTrack, toCheckPlys, cur )

    end
end

hook.Add( "Think", "campaginents_trackplyproxmity", function()
    manage()

end )