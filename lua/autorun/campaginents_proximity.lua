
-- reset tracking when ai is enabled/disabled

local entMeta = FindMetaTable( "Entity" )
local GetPos = entMeta.GetPos

local plyMeta = FindMetaTable( "Player" )
local SteamID64 = plyMeta.SteamID64

local vecMeta = FindMetaTable( "Vector" )
local Distance = vecMeta.Distance
local DistToSqr = vecMeta.DistToSqr

local ipairs        = ipairs
local CurTime       = CurTime
local IsValid       = IsValid
local player_GetAll = player.GetAll
local table_insert  = table.insert

local stuffTracked  = {}
-- radiii?
local trackRadiuses = {}
local triggered     = {}
local indexTable    = {}
local nextTracks    = {}

local lastPlayerCheckVecs = {}
local lastPlayerCheckTimes = {}

-- internal adder/remover
local function handleTrackingTables( on, toTrack, radius )
    local indexItsAt = indexTable[toTrack]
    if on then
        trackRadiuses[toTrack] = radius
        if indexItsAt then return end
        local indexPlaced = table_insert( stuffTracked, toTrack )
        indexTable[toTrack] = indexPlaced

        toTrack:CallOnRemove( "campaignents_proximityteardown", function( removing )
            handleTrackingTables( false, removing )

        end )

        -- let it setup!
        nextTracks[toTrack] = CurTime() + 0.05
        -- check, NOW!
        lastPlayerCheckVecs = {}
        lastPlayerCheckTimes = {}

    else
        if not indexItsAt then return end
        table.remove( stuffTracked, indexItsAt )
        trackRadiuses[toTrack]  = nil
        indexTable[toTrack]     = nil
        triggered[toTrack]      = nil

    end
end

function campaignents_TrackPlyProximity( toTrack, radius )
    handleTrackingTables( true, toTrack, radius )

end

function campaignents_StopTrackingPlyProximity( toTrack )
    handleTrackingTables( false, toTrack )

end

function campaignEnts_PlyInProxmity( toTrack )
    return triggered[toTrack]

end

local function onProximity( toTrack, proxPly )
    -- tracked, new
    hook.Run( "campaignents_OnProximity", toTrack, proxPly )
    if toTrack.CampaignEnts_OnProximity then
        toTrack:CampaignEnts_OnProximity( proxPly )

    end
end

local function onNoProximity( toTrack, proxPly )
    -- tracked, old
    hook.Run( "campaignents_OnProximityEmpty", toTrack, proxPly )
    if toTrack.CampaignEnts_OnNoProximity then
        toTrack:CampaignEnts_OnNoProximity( proxPly )

    end
end

local function findOnesThatTrigger( toTrack, ourThreshold, toCheck, cur )
    local ourPos = GetPos( toTrack )

    local nextTrack = nextTracks[toTrack] or 0
    if nextTrack > cur then return end

    local threshDoubled = ourThreshold * 2
    threshDoubled   = threshDoubled^2
    ourThreshold    = ourThreshold^2

    local bestPlayer
    local anyWereRemotelyClose
    local bestDist = math.huge
    local filterFunc = toTrack.CampaignEnts_ProximityFilter

    for _, checkDat in ipairs( toCheck ) do
        local currPly = checkDat[1]

        local pos = checkDat[2]
        local distSqr = DistToSqr( pos, ourPos )
        if distSqr < ourThreshold then
            if filterFunc and not filterFunc( toTrack, currPly ) then
                anyWereRemotelyClose = true

            else
                triggered[toTrack] = currPly
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
        nextTracks[toTrack] = cur + math.Rand( 1, 2 )

    end

    return false, nil, bestPlayer

end

local function resetTriggerCache()
    triggered = {}

end

-- wipe cache so thing respawners, etc. dont break
cvars.AddChangeCallback( "ai_disabled", resetTriggerCache, "campaignents_resettriggercache" )
cvars.AddChangeCallback( "ai_ignoreplayers", resetTriggerCache, "campaignents_resettriggercache" )

local function manageTracked( toTrack, toCheck, cur )
    if not IsValid( toTrack ) then return end
    local wasLeave

    local ourThreshold = trackRadiuses[toTrack]
    if not ourThreshold then return end

    -- optimisation, dont have to check all players if they're close
    -- just have to check the one that was close last!
    local currTriggered = triggered[toTrack]
    if IsValid( currTriggered ) then
        -- they stopped being in proxmity!
        local filterFunc = toTrack.CampaignEnts_ProximityFilter
        local outdated = filterFunc and not filterFunc( toTrack, currTriggered )
        local tooFar = Distance( GetPos( currTriggered ), GetPos( toTrack ) ) > ourThreshold
        if outdated or tooFar then
            triggered[toTrack] = nil
            wasLeave = true

        -- they're still in proximity!
        else
            return

        end
    end
    -- okay this one doesnt have an easy to check player, near it, do the expensive check
    local foundAnother, newTriggered, nearestNonTriggering = findOnesThatTrigger( toTrack, ourThreshold, toCheck, cur )

    if wasLeave then
        if not foundAnother then
            onNoProximity( toTrack, currTriggered )

        elseif foundAnother then
            -- tracked, old, new
            hook.Run( "campaignents_OnProximitySwitch", toTrack, currTriggered, newTriggered )

        end
    elseif foundAnother then
        onProximity( toTrack, newTriggered )

    end
    if nearestNonTriggering then
        toTrack.campaignents_ProxNearbyPlayer = nearestNonTriggering

    end
end

local ignoreNoclippers = CreateConVar( "campaignents_ignorenoclippers", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Make thing respawners, etc, ignore noclipping players?" )

local nextTrack = 0
local function manage()
    local cur = CurTime()
    if nextTrack > cur then return true end
    if #stuffTracked <= 0 then
        nextTrack = cur + 0.5

    else
        nextTrack = cur + 0.05

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

    local toCheck = {}
    local scale = 40
    local timeToCheckWhenStill = 2

    for _, ply in ipairs( trackedPlayers ) do
        local steamId = SteamID64( ply )
        local lastCheckedVec = lastPlayerCheckVecs[steamId]
        local lastCheckedTime = lastPlayerCheckTimes[steamId]
        local plysPos = GetPos( ply )
        local needsCheck
        if not lastCheckedVec then
            needsCheck = true
        else
            -- check fast when ply is moving
            -- check slow when ply is standing still
            local tolerance = ( cur - lastCheckedTime ) * scale
            local toleranceSubt = ( scale * timeToCheckWhenStill ) - tolerance
            needsCheck = Distance( lastCheckedVec, plysPos ) > toleranceSubt

        end
        if needsCheck then
            lastPlayerCheckVecs[steamId] = plysPos
            lastPlayerCheckTimes[steamId] = cur

            table_insert( toCheck, { ply, plysPos } )

        end
    end

    if #toCheck <= 0 then return end

    for _, toTrack in ipairs( stuffTracked ) do
        manageTracked( toTrack, toCheck, cur )
    end
end

hook.Add( "Think", "campaginents_trackplyproxmity", function()
    if manage() then return end

end )