-- standalone ver https://github.com/StrawWagen/gm_better_preventransmit

CAMPAIGN_ENTS = CAMPAIGN_ENTS or {}

local entMeta = FindMetaTable( "Entity" )
local pairs = pairs
BETTER_PREVENT_TRANSMIT = true

entMeta._BetterPreventTransmit_SetPreventTransmit = entMeta._BetterPreventTransmit_SetPreventTransmit or entMeta.SetPreventTransmit

-- util func
local function getPreventTransmitReasonsForPly( entsTbl, ply )
    local preventTransmitReasons = entsTbl._BetterPreventTransmit_Reasons
    if not preventTransmitReasons then
        preventTransmitReasons = {}
        entsTbl._BetterPreventTransmit_Reasons = preventTransmitReasons

    end

    local preventTransmitReasonsForPly = preventTransmitReasons[ply]
    if not preventTransmitReasonsForPly then
        preventTransmitReasonsForPly = {}
        preventTransmitReasons[ply] = preventTransmitReasonsForPly

    end

    return preventTransmitReasonsForPly

end

-- figure out if we should transmit or not after a reason was removed/added
local function checkPreventTransmit( ent, entsTbl, ply, preventTransmitReasonsForPly )
    local transmitList = entsTbl._BetterPreventTransmit_List
    if not transmitList then
        transmitList = {}
        entsTbl._BetterPreventTransmit_List = transmitList

    end
    local oldState = transmitList[ply]

    local count = 0
    for _ in pairs( preventTransmitReasonsForPly ) do
        count = count + 1

    end

    local newState = count >= 1

    if oldState == newState then return end

    hook.Run( "BetterPrevenTransmit_SwitchedTransmit", ply, ent, newState )

    transmitList[ply] = newState
    return entMeta._BetterPreventTransmit_SetPreventTransmit( ent, ply, newState )

end


-- THE FUNCTIONS IN QUESTION
-- use these IF AT ALL POSSIBLE!
-- add reason to prevent transmit, if a player has any reason, transmit is prevented
function entMeta:AddPreventTransmitReason( ply, reason )
    local myTbl = entMeta.GetTable( self )
    local preventTransmitReasonsForPly = getPreventTransmitReasonsForPly( myTbl, ply )

    preventTransmitReasonsForPly[reason] = true
    checkPreventTransmit( self, myTbl, ply, preventTransmitReasonsForPly )

end

-- remove a reason
function entMeta:RemovePreventTransmitReason( ply, reason )
    local myTbl = entMeta.GetTable( self )
    local preventTransmitReasonsForPly = getPreventTransmitReasonsForPly( myTbl, ply )

    preventTransmitReasonsForPly[reason] = nil
    checkPreventTransmit( self, myTbl, ply, preventTransmitReasonsForPly )

end

-- drop-in replacement
function entMeta:SetPreventTransmitReason( ply, state, reason )
    local myTbl = entMeta.GetTable( self )
    local preventTransmitReasonsForPly = getPreventTransmitReasonsForPly( myTbl, ply )

    if state == true then
        preventTransmitReasonsForPly[reason] = true

    else -- so it works with nil or false
        preventTransmitReasonsForPly[reason] = nil

    end
    checkPreventTransmit( self, myTbl, ply, preventTransmitReasonsForPly )

end

-- util funcs
function entMeta:GetPreventTransmit( ply )
    local myTbl = entMeta.GetTable( self )
    local preventTransmitList = myTbl._BetterPreventTransmit_PreventTransmitList
    if not preventTransmitList then
        preventTransmitList = {}
        myTbl._BetterPreventTransmit_PreventTransmitList = preventTransmitList

    end

    local isPrevented = preventTransmitList[ply]
    if not isPrevented then return false end -- was never prevent transmitted

    return isPrevented, preventTransmitList

end

function entMeta:HasPreventTransmitReason( ply, reason )
    local myTbl = entMeta.GetTable( self )
    local preventTransmitReasonsForPly = getPreventTransmitReasonsForPly( myTbl, ply )

    if not preventTransmitReasonsForPly then return false end

    local has = preventTransmitReasonsForPly[reason]
    if has == true then
        return true

    else
        return false

    end
end


-- crappy backwards compat
entMeta.SetPreventTransmit = function( self, ply, bool )
    if bool then
        entMeta.AddPreventTransmitReason( self, ply, "generic" )

    else
        entMeta.RemovePreventTransmitReason( self, ply, "generic" )

    end
end
