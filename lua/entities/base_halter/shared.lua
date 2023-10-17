AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Noclip Granter Base"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Base for the noclip granter(s)"
ENT.Spawnable    = false
ENT.AdminOnly    = false
ENT.Model = "models/maxofs2d/button_04.mdl"

if not istable( noclipBestowers ) then
    noclipBestowers = {}
end

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", 0, "On" )

end

function ENT:SetupSessionVars()
    self.canUse = true

end

function ENT:Initialize()
    if SERVER then
        self:SetModel( self.Model )
        self:SetNoDraw( false )
        self:DrawShadow( true )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_NONE )
        self:SetUseType( SIMPLE_USE )

        self:SetupSessionVars()

        self:BestowerSetup()

    end
end

function ENT:OnDuplicated()
    self.duplicatedIn = true
    self:SetupSessionVars()

end

function ENT:BestowerSetup()
    self:EnsureOnlyOneExists()
end

function ENT:CanBePressedBy( ply )
    if not IsValid( ply ) then return end
    if not ply:IsPlayer() then return end
    return true

end

function ENT:EnsureOnlyOneExists()
    local otherBestower = noclipBestowers[self:GetClass()]
    if IsValid( otherBestower ) and otherBestower ~= self then
        otherBestower.overRidden = true
        SafeRemoveEntity( otherBestower )

    end
    noclipBestowers[self:GetClass()] = self

end

function ENT:BestowPlayer( ply )
    if not IsValid( ply ) then return end
    if not ply:IsPlayer() then return end

end

function ENT:Use( activator, _, _, _ )
    if not self.canUse then return end
    if not self:CanBePressedBy( activator ) then return end
    self:BestowPlayer( activator )
    self:SetOn( true )
    self.canUse = nil

    timer.Simple( 0.1, function()
        if not IsValid( self ) then return end
        self:SetOn( false )
        self.canUse = true

    end )
end

function ENT:Think()
    -- Update the animation
    if CLIENT then
        self:UpdateLever()

    end
end

function ENT:UpdateLever()
    self.PosePosition = self.PosePosition or 0
    local TargetPos = 0.0
    if self:GetOn() then TargetPos = 1.0 end

    self.PosePosition = math.Approach( self.PosePosition, TargetPos, FrameTime() * 20 )

    self:SetPoseParameter( "switch", self.PosePosition )
    self:InvalidateBoneCache()

end