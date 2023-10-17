
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Soundscape Silencer"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Deafens all default ambient sounds"
ENT.Spawnable    = true
ENT.AdminOnly    = true
ENT.Model = "models/props_trainstation/payphone001a.mdl"
ENT.Material = "phoenix_storms/smallwheel"


function ENT:OnDuplicated()
    self.duplicatedIn = true
    self.overriddenCommand = nil
    self.defaultVariable = nil

end

function ENT:Initialize()
    if SERVER then
        self:SetModel( self.Model )
        self:SetNoDraw( false )
        self:DrawShadow( false )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_NONE )
        self:SetMaterial( self.Material )

        timer.Simple( 0, function()
            self:BlockerSetup()

        end )
    end
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


function ENT:Silence()
    local soundscapes = ents.FindByClass( "env_soundscape" )
    local triggerableScapes = ents.FindByClass( "env_soundscape_triggerable" )

    table.Add( soundscapes, triggerableScapes )

    --PrintTable( soundscapes )

    for _, soundscape in ipairs( soundscapes ) do
        SafeRemoveEntity( soundscape )

    end

    timer.Simple( 0.1, function()
        net.Start( "ambientdeafener_postdeafen" )
        net.Broadcast()

    end )
end

local campaignents_nextAmbientDeafenerMessage = 0
local campaignents_theAmbientDeafener = nil
function ENT:BlockerSetup()
    if not IsValid( self ) then return end
    if campaignents_theAmbientDeafener then
        SafeRemoveEntity( campaignents_theAmbientDeafener )

    end
    campaignents_theAmbientDeafener = self
    self:Silence()

    if self.duplicatedIn then return end

    if campaignents_nextAmbientDeafenerMessage > CurTime() then return end
    campaignents_nextAmbientDeafenerMessage = CurTime() + 30

    local MSG = "Soundscape Silencer: Your ears should be much clearer!"
    self:TryToPrintOwnerMessage( MSG )

end

if SERVER then
    util.AddNetworkString( "ambientdeafener_postdeafen" )

else
    local nextRecieve = 0
    net.Receive( "ambientdeafener_postdeafen", function()
        if nextRecieve > CurTime() then return end
        nextRecieve = CurTime() + 15

        LocalPlayer():ConCommand( "stopsound" )
        LocalPlayer():ConCommand( "snd_restart" )

    end )
end