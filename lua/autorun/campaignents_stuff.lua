CAMPAIGN_ENTS = CAMPAIGN_ENTS or {}

local freeMode = CreateConVar( "campaignents_freemode", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Block the noclip/weapon/command mandators?" )

function CAMPAIGN_ENTS.IsFreeMode()
    if freeMode:GetBool() then return true end

end
