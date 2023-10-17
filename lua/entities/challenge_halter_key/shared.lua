
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_halter"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Noclip Granter Key"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Prerequisite to the Noclip granter."
ENT.Spawnable    = true
ENT.AdminOnly    = true
ENT.Model = "models/maxofs2d/balloon_gman.mdl"

ENT.campaignents_Usable = true

if not istable( noclipBestowingKeys ) then
    noclipBestowingKeys = {}

end

function ENT:BestowerSetup()
    table.insert( noclipBestowingKeys, self )

end

function ENT:OnDuplicated()
    self.beenActivated = nil

end

function ENT:CanBePressedBy( ply )
    if not IsValid( ply ) then return end
    if not ply:IsPlayer() then return end
    if not self.beenActivated then return true end
    self:EmitSound( "buttons/lightswitch2.wav", 80, 80 )
    ply:PrintMessage( HUD_PRINTCENTER, "This key is already activated." )

    return false

end

function ENT:BestowPlayer( ply )
    if not IsValid( ply ) then return end
    if not ply:IsPlayer() then return end

    self.beenActivated = true

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
    local remaining = math.abs( #validKeys - validCount )
    if remaining > 0 then
        local s1 = ""
        local s2 = "s"
        if remaining > 1 then
            s1 = "s"
            s2 = ""

        end

        ply:PrintMessage( HUD_PRINTCENTER, remaining .. " unactivated key" .. s1 .. " remain" .. s2 .. "." )
        self:EmitSound( "physics/plastic/plastic_barrel_impact_hard4.wav", 80, math.random( 100, 120 ), 1, 6 )
        self:EmitSound( "plats/elevbell1.wav", 80, 90 + validCount * 4 )

    else
        ply:PrintMessage( HUD_PRINTCENTER, "No more keys remain." )
        self:EmitSound( "physics/plastic/plastic_barrel_impact_hard4.wav", 80, math.random( 80, 100 ), 1, 6 )
        self:EmitSound( "ambient/alarms/warningbell1.wav", 80, 100 )

    end
end