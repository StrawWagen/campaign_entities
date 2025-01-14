AddCSLuaFile()

ENT.Base = "npc_fastzombie_slump_a"
ENT.Type = "anim"
ENT.Author = "Chocofrolik + Straw W Wagen"

ENT.PrintName = "Slumped Zombie ( Attack )"

ENT.DebugModel = "models/maxofs2d/balloon_mossman.mdl"
ENT.DebugColor = Color( 255,255,0 )
ENT.AmbushDist = 64
ENT.MyClass = "npc_zombie_slump_attack"
ENT.ModelToPrecache = "models/Zombie/Classic.mdl"
ENT.AmbusherClass = "npc_zombie"

ENT.SnapBehind = true
ENT.Slump = "slump_a"
ENT.RiseStyle = "slumprise_a_attack"

ENT.HintSoundChance = 5
ENT.HintSounds = {
    "npc/zombie/zombie_pain3.wav",
    "npc/zombie/zombie_voice_idle3.wav",
    "npc/zombie/zombie_voice_idle4.wav",

}

ENT.MeleeDelay = 1.15
ENT.MeleeDamage = 25
ENT.MeleeHitSound = "Zombie.AttackHit"

function ENT:Ambush()
    if not IsValid( self.waking_sequence ) then return end
    self.waking_sequence:Fire( "BeginSequence", "", 0 )

    timer.Simple( self.MeleeDelay, function()
        if not IsValid( self ) then return end
        if not IsValid( self.ambusher ) then return end
        if self.ambusher:Health() <= 0 then return end
        self:MeleeAttack()

    end )

    if self:GetIsSilent() then return end
    self.ambusher:EmitSound( "npc/zombie/zombie_alert" .. math.random( 1, 3 ) .. ".wav" )

end