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

--[[
local noclipCached
local noclipNextCache = 0
function campaignents_IsAPlayerInNoclip()
    if not noclipCached or noclipNextCache < CurTime() then
        noclipNextCache = CurTime() + 0.1
        noclipCached = false
        for _, ply in ipairs( player.GetAll() ) do
            if ply:CampaignEnts_IsInNoclip() then
                noclipCached = true
                break

            end
        end
    end
    return noclipCached

end
--]]

local meta = FindMetaTable( "Player" )
function meta:CampaignEnts_IsInNoclip()
    local moveType = self:GetMoveType()
    if moveType ~= MOVETYPE_NOCLIP then return end
    if self:InVehicle() then return end
    return true

end

function campaignents_doFadeDistance( ent, dist )
    ent:SetKeyValue( "fademindist", dist )
    ent:SetKeyValue( "fademaxdist", dist + ( dist / 10 ) )

end