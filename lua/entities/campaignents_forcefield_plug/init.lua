AddCSLuaFile( "cl_init.lua" ) -- Make sure clientside
AddCSLuaFile( "shared.lua" ) -- and shared scripts are sent.
include( "shared.lua" )

function ENT:SetupSessionVars()
    self.Shield_CanPlug = true
    self.Shield_Plugged = false

end

function ENT:Initialize()
    self:PhysicsInit( SOLID_VPHYSICS ) -- Make us work with physics,
    self:SetCollisionGroup( COLLISION_GROUP_NONE )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )
    self:SetMoveType( MOVETYPE_VPHYSICS ) -- after all, gmod is a physics, or is it?

    self:SetupSessionVars()
    self:SetModel( "models/props_lab/tpplug.mdl" )
    campaignents_doFadeDistance( self, 3000 )

    local phys = self:GetPhysicsObject()
    if phys and phys:IsValid() then
        phys:Wake()

    end

    local result = util.QuickTrace( self:WorldSpaceCenter(), -self:GetForward() * 100, self )

    if not result.Entity then return end
    self:TryToPlugInto( result.Entity )

end

function ENT:MakeALilSpark()
    self:EmitSound( "ambient/energy/spark" .. math.random( 1, 6 ) .. ".wav" )
    effect = EffectData()
    effect:SetOrigin( self:GetPos() )
    effect:SetEntity( self )
    effect:SetMagnitude( 2 )
    effect:SetScale( 2 )
    effect:SetRadius( 2 )

    util.Effect( "ElectricSpark", effect, true, true )

end

function ENT:TryToPlugInto( socket )
    if not IsValid( socket ) then return end
    if self.Shield_Plugged ~= false then return end
    if self.Shield_CanPlug ~= true then return end
    if socket:GetModel() ~= "models/props_lab/tpplugholder_single.mdl" then return end

    self.Shield_Plugged = true
    self.Shield_Socket = socket
    self:ForcePlayerDrop()

    self:SetPos( socket:GetPos() + socket:GetForward() * 5 + socket:GetUp() * 10 + socket:GetRight() * -13 )
    self:SetAngles( socket:GetAngles() * 1 )

    self.pluggingConstraint = constraint.Weld( self, socket, 0, 0, 5000, true, false )

    self.pluggingConstraint:CallOnRemove( "unplugged", function()
        if not IsValid( self ) then return end
        self:TryToUnplug()
        if IsValid( socket ) and socket:GetIsPowered() then
            self:MakeALilSpark()

        end
    end )

    if IsValid( socket ) and socket:GetIsPowered() then
        self:MakeALilSpark()

    end
end

function ENT:TryToUnplug()
    if self.Shield_Plugged ~= true then return end

    self.Shield_CanPlug = false
    timer.Simple( 0.5, function()
        self.Shield_CanPlug = true
    end )

    self.Shield_Plugged = false
    self.Shield_Socket = nil
    self:SetPos( self:GetPos() + self:GetForward() * 8 )

    if IsValid( self.pluggingConstraint ) then
        SafeRemoveEntity( self.pluggingConstraint )

    end

    timer.Simple( 0.01, function()
        if not IsValid( self ) then return end
        local phys = self:GetPhysicsObject()
        if phys and phys.IsValid and phys:IsValid() then
            phys:EnableMotion( true ) -- unFreeze the plug!
            phys:Wake()

        end
    end )
end

function ENT:StartTouch( other )
    self:TryToPlugInto( other )

end

function ENT:Use( user )
    self:TryToUnplug()
    user:PickupObject( self )

end

function ENT:OnTakeDamage( dmgInfo )
    self:TakePhysicsDamage( dmgInfo )

    if dmgInfo:GetDamage() < 49 then return end

    self:TryToUnplug()

end