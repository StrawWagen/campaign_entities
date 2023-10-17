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