AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "campaignents_base_usable"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Note"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Shows text when Used"
ENT.Spawnable    = true
ENT.AdminOnly    = false

ENT.campents_MoveType = MOVETYPE_FLY
ENT.campents_ColGroup = COLLISION_GROUP_WEAPON
ENT.campents_Model = "models/props_c17/paper01.mdl"
ENT.campents_IsAnimated = false

function ENT:AdditionalSetupDataTables()
    local i = 1
    self:NetworkVar( "String",  0, "Text", { KeyName = "text", Edit = { order = i, type = "String", waitforenter = true } } )
    self:NetworkVar( "Bool",    1, "Preamble", { KeyName = "preamble", Edit = { order = i + 1, type = "Bool", title = "Do \"The note reads\" preamble?" } } )
    self:NetworkVar( "Bool",    2, "UsedSound", { KeyName = "usedsound", Edit = { order = i + 1, type = "Bool", title = "Make a sound?" } } )
    self:NetworkVar( "Bool",    3, "OneTime",   { KeyName = "onetime", Edit = { order = i + 1, type = "Bool", title = "Hide when read?" } } )
    self:NetworkVar( "Vector",  0, "ChatColor", { KeyName = "chatcolor", Edit = { order = i + 1, type = "VectorColor", title = "Chat color" } } )
    if SERVER then
        self:NetworkVarNotify( "Text", function()
            if not SERVER then return end
            if not IsValid( self ) then return end
            if not WireLib then return end
            Wire_TriggerOutput( self, "Text", self:GetText() )

        end )

        self:SetText( "lorup ipsum" )
        self:SetPreamble( true )
        self:SetUsedSound( true )
        self:SetChatColor( Vector( 1, 1, 1 ) )

    end

end

if CLIENT then
    net.Receive( "campaignents_readnote", function()
        local toRead = net.ReadEntity()
        if not IsValid( toRead ) then return end
        if not toRead.GetText then return end

        local msg = toRead:GetText()
        if toRead:GetPreamble() then
            msg = "The note reads...\n" .. msg

        end

        local color = toRead:GetChatColor() * 255
        color = color:ToColor()

        chat.AddText( color, msg )

        net.Start( "campaignents_readnote" )
            net.WriteEntity( toRead )
        net.SendToServer()

    end )

    return

end

util.AddNetworkString( "campaignents_readnote" )

function ENT:TriggerInput( iname, value )
    if iname == "Text" then
        self:SetText( value )
    end
end

function ENT:SetupOutputs()
    self.Inputs = WireLib.CreateSpecialInputs( self, { "Text" }, { "STRING" } )
    self.Outputs = WireLib.CreateSpecialOutputs( self, { "Text", "LastUser", "Pressed", "UsedCount" }, { "STRING", "ENTITY", "NORMAL", "NORMAL" } )

end

function ENT:AdditionalInitialize()
    self.UsedCount = 0

end

function ENT:OnUsed( ply )
    self.UsedCount = self.UsedCount + 1

    if WireLib then
        Wire_TriggerOutput( self, "Pressed", 1 )
        timer.Simple( 0, function()
            Wire_TriggerOutput( self, "Pressed", 0 )

        end )
        Wire_TriggerOutput( self, "LastUser", ply )
        Wire_TriggerOutput( self, "UsedCount", self.UsedCount )

    end

    net.Start( "campaignents_readnote" )
        net.WriteEntity( self )
    net.Send( ply )

    if self:GetUsedSound() then
        self:EmitSound( "physics/cardboard/cardboard_box_impact_soft" .. math.random( 1, 7 ) .. ".wav" )
        self:EmitSound( "campaign_entities/562019__mattruthsound__paper-ball.mp3" )

    end

    if self:GetOneTime() then
        self.WaitingForReply = self.WaitingForReply or {}
        self.WaitingForReply[ply] = true

    end
end

net.Receive( "campaignents_readnote", function( _, sender )
    local toRead = net.ReadEntity()
    if not IsValid( toRead ) then return end

    if not ( toRead.WaitingForReply and toRead.WaitingForReply[sender] ) then return end

    toRead:AddPreventTransmitReason( sender, "campaignents_readnote" )

end )