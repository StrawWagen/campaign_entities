AddCSLuaFile()

ENT.Base = "npc_fastzombie_slump_a"
ENT.Type = "anim"

ENT.PrintName = "Sleeping Fastzombie B"

ENT.DebugModel = "models/balloons/balloon_dog.mdl"
ENT.DebugColor = Color( 150,0,0 )
ENT.AmbushDist = 256
ENT.MyClass = "npc_fastzombie_slump_b"
ENT.AmbusherClass = "npc_fastzombie"

ENT.Slump = "slump_b"
ENT.RiseStyle = "slumprise_b"

function ENT:Ambush()
    if not IsValid( self.waking_sequence ) then return end
    self.waking_sequence:Fire( "BeginSequence", "", 0 )
    if self:GetIsSilent() then return end
    self.ambusher:EmitSound( "npc/fast_zombie/wake1.wav", 75, 100 )

end