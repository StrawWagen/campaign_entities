
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_halter"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Noclip Granter"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Disables noclip on everyone, until they use this entity"
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.Editable    = true
ENT.campaignents_Usable = true

if not istable( noclipBestowingKeys ) then
    noclipBestowingKeys = {}

end

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", 0, "On",           { KeyName = "on",           Edit = { readonly = true } } )
    self:NetworkVar( "Bool", 1, "DoBlocking",   { KeyName = "doblocking",   Edit = { type = "Bool", order = 1 } } )

    if SERVER then
        self:SetDoBlocking( true )

        self:NetworkVarNotify( "DoBlocking", function()
            timer.Simple( 0, function()
                if not IsValid( self ) then return end
                for _, currentplayer in pairs( player.GetAll() ) do
                    self:ManageNoclippingOfPly( currentplayer )

                end
            end )
        end )
    end
end

function ENT:RemoveNoclipFrom( ply )
    ply:SetMoveType( MOVETYPE_WALK )
    ply:SetNWBool( "challengeHalterBlockingNoclip", true )

end

function ENT:ReturnNoclipTo( ply )
    ply:SetNWBool( "challengeHalterBlockingNoclip", false )

end

function ENT:CelebrateWith( ply )
    ply:PrintMessage( HUD_PRINTCENTER, "Congragulations! It feels like you could take off and fly..." )
    self:EmitSound( "buttons/button6.wav", 80, 80, 1, CHAN_STATIC )
    self:EmitSound( "buttons/button3.wav", 80, 80, 1, CHAN_STATIC )

    ply:EmitSound( "vo/coast/odessa/male01/nlo_cheer04.wav", 80, math.random( 90, 110 ), 0.2, CHAN_STATIC )
    ply:EmitSound( "vo/coast/odessa/male01/nlo_cheer03.wav", 80, math.random( 90, 110 ), 0.2, CHAN_STATIC )
    ply:EmitSound( "vo/coast/odessa/male01/nlo_cheer02.wav", 80, math.random( 90, 110 ), 0.2, CHAN_STATIC )

end

function ENT:OnRemove()
    if self.overRidden then return end
    for _, currentplayer in pairs( player.GetAll() ) do
        if currentplayer:GetNWBool( "challengeHalterBlockingNoclip" ) then
            self:ReturnNoclipTo( currentplayer )
            currentplayer:PrintMessage( HUD_PRINTCENTER, "The Noclip granter is no more. It feels like you could sprout wings and take off.." )

        end
    end
end

function ENT:ManageNoclippingOfPly( ply )
    if self:GetDoBlocking() and ply:GetNWBool( "challengeHalterBlockingNoclip" ) ~= true and ply.conqueredNoclipBlocker ~= self then
        self:RemoveNoclipFrom( ply )

    else
        self:ReturnNoclipTo( ply )

    end
end


function ENT:BestowerSetup()
    self:EnsureOnlyOneExists()
    challengeNoclipHalter = self
    for _, currentplayer in pairs( player.GetAll() ) do
        self:ManageNoclippingOfPly( currentplayer )

    end
    if not WireLib then return end

    self.Inputs = Wire_CreateInputs( self, { "On" } )

end

function ENT:TriggerInput( iname, value )
    if iname == "On" and value >= 1 then
        self:SetDoBlocking( true )

    else
        self:SetDoBlocking( false )

    end
end

function ENT:CanBePressedBy( ply )
    if not ply:GetNWBool( "challengeHalterBlockingNoclip" ) then return end
    return true

end

function ENT:BestowPlayer( ply )
    if not IsValid( ply ) then return end
    if not ply:IsPlayer() then return end

    local areKeys = nil
    local validCount = 0
    local validKeys = {}
    for _, key in pairs( noclipBestowingKeys ) do
        if IsValid( key ) then
            areKeys = true
            table.insert( validKeys, key )
            if key.beenActivated then
                validCount = validCount + 1

            end
        end
    end
    if areKeys then
        if validCount >= #validKeys then
            self:ReturnNoclipTo( ply )
            self:CelebrateWith( ply )
            ply.conqueredNoclipBlocker = self

        else
            local remaining = math.abs( #validKeys - validCount )
            local s1 = ""
            local s2 = "s"
            if remaining > 1 then
                s1 = "s"
                s2 = ""
            end
            ply:PrintMessage( HUD_PRINTCENTER, remaining .. " unactivated key" .. s1 .. " remain" .. s2 .. "." )
            self:EmitSound( "buttons/lightswitch2.wav", 80, 120 )

        end
    else
        self:ReturnNoclipTo( ply )
        self:CelebrateWith( ply )
        ply.conqueredNoclipBlocker = self

    end
end

hook.Add( "PlayerNoClip", "challenge_noclip_halter", function( ply, desiredState )
    if not ply:GetNWBool( "challengeHalterBlockingNoclip" ) then return end
    if not campaignents_EnabledAi() then return end
    local exiting = desiredState == false
    if exiting then
        return true -- always allow

    else
        return false

    end
end )

hook.Add( "PlayerSpawn", "challenge_noclip_disablenoclip", function( Player )
    if not IsValid( challengeNoclipHalter ) then return end

    challengeNoclipHalter:ManageNoclippingOfPly( Player )

end )

