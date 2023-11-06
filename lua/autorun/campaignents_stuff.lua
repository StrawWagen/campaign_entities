
local freeMode = CreateConVar( "campaignents_freemode", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Block the noclip/weapon/command mandators?" )

function campaignents_IsFreeMode()
    if freeMode:GetBool() then return true end

end
