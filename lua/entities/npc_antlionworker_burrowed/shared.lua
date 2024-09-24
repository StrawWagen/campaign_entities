AddCSLuaFile()

ENT.Base = "npc_antlion_burrowed"
ENT.Type = "anim"

ENT.PrintName = "Burrowed Antlion Worker"

ENT.DebugModel = "models/maxofs2d/companion_doll.mdl"
ENT.DebugColor = Color( 0, 255, 0 )
ENT.AmbushDist = 512
ENT.MyClass = "npc_antlionworker_burrowed"
ENT.ModelToPrecache = "models/antlion_worker.mdl"
ENT.AmbusherClass = "npc_antlion"

function ENT:InitializeAmbusher()
    local ambusher = ents.Create( self.AmbusherClass )
    ambusher:SetPos( self:GetPos() )
    ambusher:SetAngles( self:GetAngles() )
    ambusher:SetKeyValue( "spawnflags", bit.bor( 262144, SF_NPC_FADE_CORPSE ) )
    ambusher:SetKeyValue( "startburrowed", "1" )
    ambusher:Spawn()
    ambusher:Activate()

    ambusher.DynamicNpcSquadsIgnore = true

    return ambusher

end

function ENT:Ambush()
    self.ambusher.DynamicNpcSquadsIgnore = true

    self.ambusher:Fire( "unburrow", "", 0.1 )

end