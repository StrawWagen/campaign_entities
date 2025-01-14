AddCSLuaFile()

ENT.Base = "npc_antlion_burrowed"
ENT.Type = "anim"

ENT.PrintName = "Burrowed Antlionguard"

ENT.DebugModel = "models/maxofs2d/balloon_gman.mdl"
ENT.DebugColor = Color( 0, 50, 0 )
ENT.AmbushDist = 1000
ENT.MyClass = "npc_antlionguard_burrowed"
ENT.ModelToPrecache = "models/antlion_guard.mdl"
ENT.AmbusherClass = "npc_antlionguard"
ENT.HintSoundChance = 10

function ENT:InitializeAmbusher()
    local ambusher = ents.Create( self.AmbusherClass )
    ambusher:SetPos( self:GetPos() )
    ambusher:SetAngles( self:GetAngles() )
    ambusher:SetKeyValue( "spawnflags", bit.bor( SF_NPC_FADE_CORPSE ) )
    ambusher:SetKeyValue( "startburrowed", "1" )
    ambusher:SetKeyValue( "allowbark", "1" )
    ambusher:Spawn()
    ambusher:Activate()

    ambusher.DynamicNpcSquadsIgnore = true

    return ambusher

end

function ENT:Ambush()

    self.ambusher.DynamicNpcSquadsIgnore = true

    self.ambusher:Fire( "unburrow", "", 0.1 )

end

function ENT:PostSetupData()
    self:SetWakeNearTeammates( true )

end