
ENT.Type = "anim"

if WireLib then
    ENT.Base = "base_wire_entity"

else
    ENT.Base = "base_gmodentity" -- :(

end

ENT.PrintName       = "Combine Forcefield Socket"
ENT.Category        = "Campaign Entities"
ENT.Spawnable       = true
ENT.AdminOnly       = false
ENT.RenderGroup     = RENDERGROUP_BOTH
ENT.Editable = true

ENT.campaignents_Usable = true

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", 0, "IsPowered", { KeyName = "ispowered", Edit = { type = "Bool", order = 1 } } )

    if SERVER then
        self:SetIsPowered( true )

        self:NetworkVarNotify( "IsPowered", function( _, _, _, new )
            if not IsValid( self ) then return end
            if new ~= true then return end
            self:MakeALilSpark()

        end )
    end
end