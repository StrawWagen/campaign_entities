CAMPAIGN_ENTS = CAMPAIGN_ENTS or {}

local entsMeta = FindMetaTable( "Entity" )
local plyMeta = FindMetaTable( "Player" )
local InVehicle = plyMeta.InVehicle
local GetMoveType = entsMeta.GetMoveType

local IsValid = IsValid
local CurTime = CurTime
local timer_Remove = timer.Remove
local timer_Create = timer.Create

local MOVETYPE_NOCLIP = MOVETYPE_NOCLIP
local FAUXTYPE_INVEHICLE = 55556666 -- dumb 'random' number

CAMPAIGN_ENTS.oldMoveTypes = CAMPAIGN_ENTS.oldMoveTypes or {}
local nextChecks = {}

-- catches ULX noclip, etc. unlike the default hooks
hook.Add( "FinishMove", "campaignents_detectnoclip", function( ply )
    local cur = CurTime()
    if ( nextChecks[ply] or 0 ) > cur then return end

    nextChecks[ply] = cur + 0.1
    local newType = GetMoveType( ply )
    local oldType = CAMPAIGN_ENTS.oldMoveTypes[ ply ] or 0

    -- people in vehicles are "MOVETYPE_NOCLIP"
    if InVehicle( ply ) then
        newType = FAUXTYPE_INVEHICLE
    end

    if oldType == newType then return end

    CAMPAIGN_ENTS.oldMoveTypes[ ply ] = newType

    if newType == MOVETYPE_NOCLIP then hook.Run( "campaignents_OnPlayerEnterGenericNoclip", ply ) end
    if oldType == MOVETYPE_NOCLIP then hook.Run( "campaignents_OnPlayerExitGenericNoclip", ply ) end

end )

if CLIENT then
    CreateClientConVar( "campaignents_cl_alwayshideugly", "0", true, true, "Always hide 'ugly' ents? 0 for default, 1 to always hide, 2 to always show." )

end

if SERVER then
    -- what is/isnt hidden for a specific ply
    CAMPAIGN_ENTS.hiddenIndex = CAMPAIGN_ENTS.hiddenIndex or {}
    CAMPAIGN_ENTS.hiddenList = CAMPAIGN_ENTS.hiddenList or {}
    CAMPAIGN_ENTS.uglyDealBreakers = CAMPAIGN_ENTS.uglyDealBreakers or {}
    CAMPAIGN_ENTS.isSeeingUgly = CAMPAIGN_ENTS.isSeeingUgly or {}

    -- stuff that every ply should loop over to determine if its hidden or not
    CAMPAIGN_ENTS.hidden_indexTbl = CAMPAIGN_ENTS.hidden_indexTbl or {}
    CAMPAIGN_ENTS.uglyHidingEnts = CAMPAIGN_ENTS.uglyHidingEnts or {}

    local function rebuildIndexTbl()
        local newIndexTbl = {}
        local hidingEnts = CAMPAIGN_ENTS.uglyHidingEnts
        for ind, ent in ipairs( hidingEnts ) do
            newIndexTbl[ent] = ind

        end
        CAMPAIGN_ENTS.hidden_indexTbl = newIndexTbl

    end

    local timerName = "campents_hiding_indexrebuilder"
    local function rebuildIndexTableInBatches()
        timer.Stop( timerName )
        timer.Create( timerName, 0.05, 1, function()
            rebuildIndexTbl()

        end )
    end

    local function hideFor( ent, ply, cache, indexCache )
        if not IsValid( ent ) then return end
        if not IsValid( ply ) then return end
        ent:AddPreventTransmitReason( ply, "campents_hiding" )
        indexCache[ent] = table.insert( cache, ent )

    end

    local function showFor( ent, ply )
        if not IsValid( ent ) then return end
        if not IsValid( ply ) then return end
        ent:RemovePreventTransmitReason( ply, "campents_hiding" )

    end

    -- use diff method for this/the hooks, because hooks need to be optimized
    local function inNoclip( ply )
        if GetMoveType( ply ) ~= MOVETYPE_NOCLIP then return false end
        if InVehicle( ply ) then return false end
        return true

    end

    local function usingCamera( ply )
        local wep = ply:GetActiveWeapon()
        if not IsValid( wep ) then return end

        if not string.find( wep:GetClass(), "camera" ) then return end
        return true

    end

    local function stopUglyHiding( ent )
        local indexImAt = CAMPAIGN_ENTS.hidden_indexTbl[ent]
        if not indexImAt then return end
        table.remove( CAMPAIGN_ENTS.uglyHidingEnts, indexImAt )
        rebuildIndexTableInBatches()

    end

    local uglyDelayTimer = "campaignents_manageugly"

    local function manageUgly( ply, breakers )
        -- wait until a batch of stuff is available to do
        timer_Remove( uglyDelayTimer )
        timer_Create( uglyDelayTimer, 0.05, 1, function()
            local hideUglySetting = ply:GetInfoNum( "campaignents_cl_alwayshideugly", 0 )
            local canBeUgly
            -- default
            if hideUglySetting < 1 then
                canBeUgly = true

                for _, isBreaking in pairs( breakers ) do
                    if isBreaking then
                        canBeUgly = false
                        break

                    end
                end
            -- always ugly
            elseif hideUglySetting >= 2 and ply:IsAdmin() then -- only if they have perms
                canBeUgly = true

            -- never ugly
            elseif hideUglySetting >= 1 then
                canBeUgly = false

            end

            local oldUgly = CAMPAIGN_ENTS.isSeeingUgly[ply]
            local needsUpdate = canBeUgly ~= oldUgly

            -- reveal everything
            if canBeUgly == true and needsUpdate then
                local currIndex = CAMPAIGN_ENTS.hiddenIndex[ply]
                -- nothing is hidden
                if not currIndex then return end

                local currList = CAMPAIGN_ENTS.hiddenList[ply]
                if not currList then return end

                for _, ent in ipairs( currList ) do
                    showFor( ent, ply, currIndex )

                end
                CAMPAIGN_ENTS.hiddenIndex[ply] = nil
                CAMPAIGN_ENTS.hiddenList[ply] = nil

            -- hide everything
            elseif not canBeUgly and needsUpdate then
                local currIndex = CAMPAIGN_ENTS.hiddenIndex[ply]
                if not currIndex then
                    currIndex = {}
                    CAMPAIGN_ENTS.hiddenIndex[ply] = currIndex

                end

                local currList = CAMPAIGN_ENTS.hiddenList[ply]
                if not currList then
                    currList = {}
                    CAMPAIGN_ENTS.hiddenList[ply] = currList

                end

                for _, ent in ipairs( CAMPAIGN_ENTS.uglyHidingEnts ) do
                    hideFor( ent, ply, currList, currIndex )

                end
            end
            CAMPAIGN_ENTS.isSeeingUgly[ply] = canBeUgly

        end )
    end

    local function addUglyDealbreaker( ply, breaker )
        local dealBreakers = CAMPAIGN_ENTS.uglyDealBreakers[ply]
        if not dealBreakers then
            dealBreakers = {}
            CAMPAIGN_ENTS.uglyDealBreakers[ ply ] = dealBreakers

        end
        dealBreakers[breaker] = true
        manageUgly( ply, dealBreakers )

    end
    local function removeUglyDealbreaker( ply, breaker )
        local dealBreakers = CAMPAIGN_ENTS.uglyDealBreakers[ply]
        if not dealBreakers then
            dealBreakers = {}
            CAMPAIGN_ENTS.uglyDealBreakers[ ply ] = dealBreakers

        end
        dealBreakers[breaker] = false
        manageUgly( ply, dealBreakers )

    end

    local function resetDealbreakers( ply )
        CAMPAIGN_ENTS.isSeeingUgly[ ply ] = nil
        if not inNoclip( ply ) then addUglyDealbreaker( ply, "notnoclipping" ) end
        if usingCamera( ply ) then addUglyDealbreaker( ply, "usingcamera" ) end

    end

    function CAMPAIGN_ENTS.StartUglyHiding( ent )
        local indexImAt = CAMPAIGN_ENTS.hidden_indexTbl[ent]
        if indexImAt then return end

        CAMPAIGN_ENTS.hidden_indexTbl[ent] = table.insert( CAMPAIGN_ENTS.uglyHidingEnts, #CAMPAIGN_ENTS.uglyHidingEnts + 1, ent )

        ent:CallOnRemove( "campaignents_cleanupnocliphiding", function( self )
            stopUglyHiding( self )

        end )

        for _, ply in player.Iterator() do
            resetDealbreakers( ply )

        end

        return true

    end

    function CAMPAIGN_ENTS.StopUglyHiding( ent, on )
        local indexImAt = CAMPAIGN_ENTS.hidden_indexTbl[ent]
        if not indexImAt then return end
        stopUglyHiding( ent )

    end

    hook.Add( "campaignents_SwitchedTransmit", "campaignents_hiding_fixtransmit", function( ply, updated )
        if not CAMPAIGN_ENTS.hidden_indexTbl[ updated ] then return end

        local currIndex = CAMPAIGN_ENTS.hiddenIndex[ply]
        if currIndex then
            currIndex[updated] = nil

        end
        resetDealbreakers( ply )

    end )

    hook.Add( "campaignents_OnPlayerExitGenericNoclip", "campaignents_hidewhennotnoclipping", function( ply )
        addUglyDealbreaker( ply, "notnoclipping" )

    end )

    hook.Add( "campaignents_OnPlayerEnterGenericNoclip", "campaignents_hidewhennotnoclipping", function( ply )
        removeUglyDealbreaker( ply, "notnoclipping" )

    end )

    hook.Add( "PlayerSwitchWeapon", "campaignents_hidewhencameraequipped", function( ply, old, new )
        local newIsCamera = IsValid( new ) and string.find( new:GetClass(), "camera" )
        local oldIsCamera = IsValid( old ) and string.find( old:GetClass(), "camera" )
        if oldIsCamera and not newIsCamera then
            removeUglyDealbreaker( ply, "usingcamera" )

        elseif not oldIsCamera and newIsCamera then
            addUglyDealbreaker( ply, "usingcamera" )

        end
    end )

    hook.Add( "PlayerDisconnected", "campaignents_cleanuphidingtables", function( ply )

    end )
end