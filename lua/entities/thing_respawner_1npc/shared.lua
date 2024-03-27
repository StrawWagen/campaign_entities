AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "thing_respawner"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Thing Resp ( 1 NPC )"
ENT.Author      = "straw"
ENT.Purpose     = "Simple alias that just spawns 1 thing."
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.Editable    = true

function ENT:DoDefaultVariables()
    self:SetModelToSpawn( "models/Zombie/Classic.mdl" )
    self:SetClassToSpawn( "npc_zombie" )
    self:SetNPCWeapon( "" )
    self:SetDropToFloor( true )

    self:SetNeedToLookAway( false )
    self:SetOn( true )

    self:SetMaxToSpawn( 1 )
    self:SetMinSpawnInterval( 0 )
    self:SetSpawnRadiusStart( 0 )
    self:SetSpawnRadiusEnd( 3000 )

    self:SetMyId( -1 )
    self:SetIdToWaitFor( -1 )

    self:SetGoalID( -1 )
    self:SetShowGoalLinks( true )

end

local nextRespawnerMessage = 0
function ENT:SelfSetup()
    if self.duplicatedIn then return end
    if nextRespawnerMessage > CurTime() then return end
    if campaignents_EnabledAi() then
        local MSG = "I'm actially a Thing Respawner\nMy settings are just changed so I only spawn ONE thing!"
        campaignents_MessageOwner( self, MSG )
        timer.Simple( 0, function()
            MSG = "This message will not appear when duped in."
            campaignents_MessageOwner( self, MSG )
        end )

        nextRespawnerMessage = CurTime() + 25

    end
end

function ENT:CanAutoCopyThe( the )
    if not IsValid( the ) then return end
    if the:IsNPC() then return true, true end
    return true, false

end