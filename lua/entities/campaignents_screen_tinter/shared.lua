
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_halter"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Screen Tinter"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Tints people's screens."
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.Model = "models/maxofs2d/cube_tool.mdl"

ENT.Editable    = true

local defaultTint = Vector( 0, 0, 0 )
local defaultAlpha = 200

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", 0,     "On",           { KeyName = "on",           Edit = { readonly = true } } )
    self:NetworkVar( "Vector", 0,   "TintColor",    { KeyName = "tintcolor",    Edit = { type = "VectorColor", order = 1 } } )
    self:NetworkVar( "Int", 0,      "TintAlpha",    { KeyName = "tintalpha",    Edit = { type = "Int", order = 2, min = 0, max = 255, } } )

    if SERVER then
        self:SetOn( true )
        self:SetTintColor( defaultTint )
        self:SetTintAlpha( defaultAlpha )

    end
end

function ENT:BestowerSetup()
    self:AddEFlags( EFL_FORCE_CHECK_TRANSMIT )
    self:SetMaterial( "models/campaignents/cube_tinter" )
    self:EnsureOnlyOneExists()

    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        self:SelfSetup()

    end )

    if not WireLib then return end

    self.Inputs = Wire_CreateInputs( self, { "On" } )

end

function ENT:TriggerInput( iname, value )
    if iname == "On" and value >= 1 then
        self:SetOn( true )

    else
        self:SetOn( false )

    end
end

local nextTinterMessage = 0

function ENT:SelfSetup()
    if self.duplicatedIn then return end
    if nextTinterMessage > CurTime() then return end
    if campaignents_EnabledAi() then
        local MSG = "I'm like a 0 distance fog editor!\nBut i tint equipped weapons too!\nCheck my context menu!"
        self:TryToPrintOwnerMessage( MSG )
        MSG = "This message will not appear when duped in."
        self:TryToPrintOwnerMessage( MSG )

        nextTinterMessage = CurTime() + 25

    end
end

function ENT:OnDuplicated()
    self.duplicatedIn = true

end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS

end
function ENT:TryToPrintOwnerMessage( MSG )
    local done = nil
    if CPPI then
        local owner, _ = self:CPPIGetOwner()
        if IsValid( owner ) then
            owner:PrintMessage( HUD_PRINTTALK, MSG )
            done = true

        end
    end
    if not done then
        PrintMessage( HUD_PRINTTALK, MSG )
        done = true

    end
end

if not CLIENT then return end

local campaignEnts_ScreenTint = nil
local campaingEnts_ScreenAlpha = nil
local doneSomething = 0

function ENT:OnRemove()
    if self.overRidden then return end
    campaignEnts_ScreenTint = nil
    campaignEnts_ScreenAlpha = nil

end

function ENT:Think()
    local myTint = self:GetTintColor()
    local myAlpha = self:GetTintAlpha()
    if not campaignEnts_ScreenTint or campaignEnts_ScreenTint ~= myTint then
        campaignEnts_ScreenTint = myTint * 255
        doneSomething = 5000

    end
    if not campaingEnts_ScreenAlpha or campaingEnts_ScreenAlpha ~= myAlpha then
        campaingEnts_ScreenAlpha = myAlpha
        doneSomething = 5000

    end
    if doneSomething <= 0 then
        self:SetNextClientThink( CurTime() + 1 )
        return true

    end
    doneSomething = doneSomething + -1
    self:SetNextClientThink( CurTime() )
    return true

end

local _ScrW                 = ScrW
local _ScrH                 = ScrH
local surface_SetDrawColor  = surface.SetDrawColor
local surface_DrawRect      = surface.DrawRect

hook.Add( "PreDrawHUD", "campaignents_screentinter_tint", function()
    if not campaignEnts_ScreenTint then return end
    surface_SetDrawColor( campaignEnts_ScreenTint[1], campaignEnts_ScreenTint[2], campaignEnts_ScreenTint[3], campaingEnts_ScreenAlpha )
    surface_DrawRect( -_ScrW() * 0.5, -_ScrH() * 0.5, _ScrW(), _ScrH() )

end )