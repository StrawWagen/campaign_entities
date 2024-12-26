AddCSLuaFile()

ENT.Type = "anim"
if WireLib then
    ENT.Base = "base_wire_entity"

else
    ENT.Base = "base_gmodentity" -- :(

end

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Base Usable Entity"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Does stuff when used"
ENT.Spawnable   = false
ENT.AdminOnly   = false
ENT.Editable    = true

ENT.campents_MoveType = MOVETYPE_VPHYSICS
ENT.campents_ColGroup = COLLISION_GROUP_NONE
ENT.campents_Model = "models/maxofs2d/button_05.mdl"
ENT.campents_IsAnimated = true
ENT.campaignents_Usable = true
ENT.hasLever = true

function ENT:AdditionalSetupDataTables() end -- stub

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", 0, "On" )
    self:AdditionalSetupDataTables()

end

function ENT:SetupOutputs() end

function ENT:AdditionalInitialize() end

function ENT:Initialize()
    if SERVER then
        self:SetModel( self.campents_Model )
        self:SetNoDraw( false )
        self:DrawShadow( true )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetMoveType( self.campents_MoveType )
        self:SetCollisionGroup( self.campents_ColGroup )
        self:SetUseType( SIMPLE_USE )

        self.beingUsed = nil

        self:AdditionalInitialize()

        CAMPAIGN_ENTS.EasyFreeze( self )

        if not WireLib then return end

        self:SetupOutputs()

    end
end

function ENT:OnDuplicated()
    self.duplicatedIn = true

end

function ENT:CanBePressedBy( ply )
    if not IsValid( ply ) then return end
    if not ply:IsPlayer() then return end
    return true

end

function ENT:OnUsed( ply ) end -- stub

function ENT:Use( activator, _, _, _ )
    if self.beingUsed then return end
    if not self:CanBePressedBy( activator ) then return end
    self:OnUsed( activator )
    self:SetOn( true )
    self.beingUsed = true

    timer.Simple( 0.1, function()
        if not IsValid( self ) then return end
        self:SetOn( false )
        self.beingUsed = nil

    end )
end

function ENT:Think()
    -- Update the animation
    if CLIENT then
        self:UpdateLever()

    end
end

function ENT:UpdateLever()
    if not self.hasLever then return end
    self.PosePosition = self.PosePosition or 0
    local TargetPos = 0.0
    if self:GetOn() then TargetPos = 1.0 end

    self.PosePosition = math.Approach( self.PosePosition, TargetPos, FrameTime() * 20 )

    self:SetPoseParameter( "switch", self.PosePosition )
    self:InvalidateBoneCache()

end