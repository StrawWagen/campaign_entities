AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Checkpoint"
ENT.Author      = "straw wage"
ENT.Purpose     = "When touched, spawns player there next time they die."
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.Editable    = true
ENT.DefaultModel = "models/hunter/blocks/cube2x2x025.mdl"
ENT.campaignents_Usable = true

function ENT:SetupDataTables()
    self:NetworkVar( "Bool",    0, "CanOverride",    { KeyName = "canbeoverriden",   Edit = { type = "Bool", title = "Let respawn manager override?", order = 1 } } )
    self:NetworkVar( "Bool",    1, "DoFx",    { KeyName = "dofx",   Edit = { type = "Bool", title = "Do sounds, shake & chat print?", order = 2 } } )

    if SERVER then
        self:SetCanOverride( true )
        self:SetDoFx( true )

    end
end

if CLIENT then
    local colorGreen = Color( 0,255,0 )
    local colorRed = Color( 255,0,0 )
    function ENT:Draw()
        local plysCheckpoint = LocalPlayer():GetNW2Entity( "campaignents_currcheckpoint" )
        local isMe = IsValid( plysCheckpoint ) and plysCheckpoint == self
        if self.checkpointWasMe ~= isMe then
            if isMe then
                self.checkpointWasMe = true
                self:SetColor( colorGreen )

            else
                self.checkpointWasMe = false
                self:SetColor( colorRed )

            end
        end
        self:DrawModel()

    end
end

function ENT:SetupSessionVars()
    self.nextAction = 0

end


function ENT:Initialize()
    if SERVER then
        self:SetupSessionVars()

        self:SetModel( self.DefaultModel )
        self:SetNoDraw( false )
        self:DrawShadow( false )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_NONE )
        self:SetUseType( SIMPLE_USE )
        self:SetMaterial( "phoenix_storms/stripes" )

        campaignEnts_EasyFreeze( self )
        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:SelfSetup()

        end )
    end
end

local nextMessage = 0
function ENT:SelfSetup()
    if self.duplicatedIn then return end
    if nextMessage > CurTime() then return end
    if campaignents_EnabledAi() then
        local MSG = "If people touch me, they'll respawn on top of me!"
        campaignents_MessageOwner( self, MSG )
        timer.Simple( 0, function()
            MSG = "This message will not appear when duped in."
            campaignents_MessageOwner( self, MSG )

        end )
        nextMessage = CurTime() + 25

    end
end

function ENT:OnDuplicated()
    self.duplicatedIn = true
    self:SetupSessionVars()

end

function ENT:linkPlayerToMe( toLink )
    if self.nextAction > CurTime() then return end
    if not IsValid( toLink ) then return end
    if not toLink:IsPlayer() then return end
    if IsValid( toLink.campaignents_CurrCheckpoint ) and toLink.campaignents_CurrCheckpoint == self then return end

    toLink:SetNW2Entity( "campaignents_currcheckpoint", self )
    toLink.campaignents_CurrCheckpoint = self

    self.nextAction = CurTime() + 0.5

    if not self:GetDoFx() then return end

    self:EmitSound( "buttons/button6.wav", 80, 80, CHAN_STATIC )
    self:EmitSound( "buttons/button14.wav", 80, 100, CHAN_STATIC )
    util.ScreenShake( self:GetPos(), 2, 10, 0.25, 1000 )

    if toLink.campaignents_CheckpointHints and toLink.campaignents_CheckpointHints > 3 then return end
    toLink.campaignents_CheckpointHints = ( toLink.campaignents_CheckpointHints or 0 ) + 1
    toLink:PrintMessage( HUD_PRINTCENTER, "When you die, you'll respawn here." )

end

function ENT:unlinkPlayerToMe( toLink )
    if self.nextAction > CurTime() then return end
    if not IsValid( toLink ) then return end
    if not toLink:IsPlayer() then return end
    if IsValid( toLink.campaignents_CurrCheckpoint ) and toLink.campaignents_CurrCheckpoint ~= self then return end

    toLink:SetNW2Entity( "campaignents_currcheckpoint", NULL )
    toLink.campaignents_CurrCheckpoint = nil

    self.nextAction = CurTime() + 0.5

    if not self:GetDoFx() then return end

    self:EmitSound( "buttons/button19.wav", 80, 100, CHAN_STATIC )
    self:EmitSound( "buttons/lever7.wav", 80, 100, CHAN_STATIC )
    util.ScreenShake( self:GetPos(), 0.5, 10, 0.25, 500 )

end

local above = Vector( 0,0,1000 )
local up = Vector( 0, 0, 1 )

hook.Add( "PlayerSpawn", "campaignents_checkpoint_plyrespawn", function( ply, transition )
    if transition and transition == true then return end
    if not IsValid( ply.campaignents_CurrCheckpoint ) then return end

    timer.Simple( engine.TickInterval() * 1, function()
        if not IsValid( ply ) then return end

        local check = ply.campaignents_CurrCheckpoint
        if not IsValid( check ) then return end

        local toGoto = nil
        local startPos = check:NearestPoint( check:GetPos() + above )

        local mins, maxs = ply:GetCollisionBounds()
        local mask = MASK_PLAYERSOLID

        local traceStruct = {
            start = startPos,
            endpos = startPos + up,
            mins = mins * 1.1,
            maxs = maxs * 1.1,
            mask = mask
        }

        for _ = 1, 150 do
            local result = util.TraceHull( traceStruct )
            local started = traceStruct.start
            if not result.Hit then
                toGoto = started
                break

            else
                traceStruct.start = started + ( up * 10 )
                traceStruct.endpos = started + ( up * 11 )

            end
        end

        if not toGoto then return end

        ply:SetPos( toGoto )

    end )
end )

function ENT:StartTouch( toucher )
    self:linkPlayerToMe( toucher )

end

function ENT:Use( presser )
    if IsValid( presser.campaignents_CurrCheckpoint ) and presser.campaignents_CurrCheckpoint == self then
        self:unlinkPlayerToMe( presser )
        return

    end
    self:linkPlayerToMe( presser )

end