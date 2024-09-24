local entMeta = FindMetaTable( "Entity" )
local table_Count = table.Count

CAMPAIGN_ENTS = CAMPAIGN_ENTS or {}
CAMPAIGN_ENTS.GET_PREVENT_TRANSMITFIX = true

entMeta._GPT_CampaignEnts_SetPreventTransmit = entMeta._GPT_CampaignEnts_SetPreventTransmit or entMeta.SetPreventTransmit
entMeta.SetPreventTransmit = function( self, ply, bool ) -- backwards compat
    if bool then
        self:AddPreventTransmitReason( ply, "generic" )

    else
        self:RemovePreventTransmitReason( ply, "generic" )

    end
end


-- new stuff below

entMeta.GetPreventTransmit = function( self, ply )
    local preventTransmitList = self.campents_PreventTransmitList
    if not preventTransmitList then
        preventTransmitList = {}
        self.campents_PreventTransmitList = preventTransmitList

    end

    local isPrevented = preventTransmitList[ply]
    if isPrevented == nil then return false end -- was never prevent transmitted

    return isPrevented
end

-- util func
local function getPreventTransmitReasonsForPly( ent, ply )
    local preventTransmitReasons = ent.campents_PreventTransmitReasons
    if not preventTransmitReasons then
        preventTransmitReasons = {}
        ent.campents_PreventTransmitReasons = preventTransmitReasons

    end

    local preventTransmitReasonsForPly = preventTransmitReasons[ply]
    if not preventTransmitReasonsForPly then
        preventTransmitReasonsForPly = {}
        preventTransmitReasons[ply] = preventTransmitReasonsForPly

    end

    return preventTransmitReasonsForPly

end

-- figure out if we should transmit or not after a reason was removed/added
local function checkPreventTransmit( ent, ply, preventTransmitReasonsForPly )
    local preventTransmitList = ent.campents_PreventTransmitList
    if not preventTransmitList then
        preventTransmitList = {}
        ent.campents_PreventTransmitList = preventTransmitList

    end
    local oldState = preventTransmitList[ply]
    local newState = table_Count( preventTransmitReasonsForPly ) >= 1
    if oldState == newState then return end

    hook.Run( "campaignents_SwitchedTransmit", ply, ent, newState )

    preventTransmitList[ply] = newState
    return ent:_GPT_CampaignEnts_SetPreventTransmit( ply, newState )

end

-- use these IF AT ALL POSSIBLE!
entMeta.AddPreventTransmitReason = function( self, ply, reason )
    local preventTransmitReasonsForPly = getPreventTransmitReasonsForPly( self, ply )

    preventTransmitReasonsForPly[reason] = true
    checkPreventTransmit( self, ply, preventTransmitReasonsForPly )

end

entMeta.RemovePreventTransmitReason = function( self, ply, reason )
    local preventTransmitReasonsForPly = getPreventTransmitReasonsForPly( self, ply )

    preventTransmitReasonsForPly[reason] = nil
    checkPreventTransmit( self, ply, preventTransmitReasonsForPly )

end