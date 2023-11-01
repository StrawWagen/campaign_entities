AddCSLuaFile( "autorun/client/campaignents_clientfuncs.lua" )
AddCSLuaFile()

local aiVar = GetConVar( "ai_disabled" )

function campaignents_EnabledAi()
    return aiVar:GetInt() == 0

end

local ignorePly = GetConVar( "ai_ignoreplayers" )

function campaignents_IgnoringPlayers()
    return ignorePly:GetInt() == 1

end

local meta = FindMetaTable( "Player" )
function meta:CampaignEnts_IsInNoclip()
    local moveType = self:GetMoveType()
    if moveType ~= MOVETYPE_NOCLIP then return end
    if self:InVehicle() then return end
    return true

end