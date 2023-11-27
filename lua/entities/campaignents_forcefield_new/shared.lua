ENT.Type            = "anim"
ENT.Base            = "base_anim"
ENT.PrintName       = "Combine Forcefield"
ENT.Category        = "Campaign Entities"
ENT.Spawnable       = true
ENT.AdminOnly       = false
ENT.RenderGroup     = RENDERGROUP_BOTH
ENT.Editable = true
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
    -- for servers or something idk, good luck editing this without lua
    -- above comment is wrong, you can just edit it when the shield is on 
    self:NetworkVar( "Bool", 0, "AllowCombinePlys", { KeyName = "allowcombineplys", Edit = { type = "Bool", order = 1 } } )
    self:NetworkVar( "Bool", 1, "AlwaysOn",         { KeyName = "alwayson",         Edit = { type = "Bool", order = 2 } } )

    self:NetworkVar( "Entity", 0, "DummyStart" )
    self:NetworkVar( "Entity", 1, "DummyEnd" )

    if SERVER then
        self:SetAllowCombinePlys( false )
        self:SetAlwaysOn( false )

        self:SetDummyEnd( nil )
        self:SetDummyStart( nil )

        self:NetworkVarNotify( "AllowCombinePlys", function()
            if not SERVER then return end
            if not IsValid( self ) then return end

            self:ResetShouldCollideCache()

        end )
    end
end

if CLIENT then
    language.Add( "campaignents_forcefield_new", ENT.PrintName )

end

function ENT:DoShieldCollisions()
    local dummyEnd = self:GetDummyEnd()

    if not IsValid( dummyEnd ) then return end

    local verts = {}
    local physMat = ""

    if self:GetSkin() == 0 then -- on
        local dummyEndPos = dummyEnd:GetPos()
        local dummyEndUp = dummyEnd:GetUp()
        verts = {
            {
                pos = Vector( 0, 0, -25 )
            },
            {
                pos = Vector( 0, 0, 150 )
            },
            {
                pos = self:WorldToLocal( dummyEndPos + dummyEndUp * 150 )
            },
            {
                pos = self:WorldToLocal( dummyEndPos + dummyEndUp * 150 )
            },
            {
                pos = self:WorldToLocal( dummyEndPos + -dummyEndUp * 25 )
            },
            {
                pos = Vector( 0, 0, -25 )
            },
        }
        physMat = "Default_silent"

    else
        verts = {
            {
                pos = Vector( 0, 0, -25 )
            },
            {
                pos = Vector( 0, 0, 150 )
            },
            {
                pos = Vector( 0, 15, 150 )
            },
            {
                pos = Vector( 0, 15, 150 )
            },
            {
                pos = Vector( 0, 15, -25 )
            },
            {
                pos = Vector( 0, 0, 25 )
            },
        }
        physMat = "Metal"

    end

    self:PhysicsFromMesh( verts )
    self:GetPhysicsObject():SetMaterial( physMat )
    self:GetPhysicsObject():EnableMotion( false )

    return true

end

-- let bullets thru!
local sent_contents = CONTENTS_GRATE
local bit_band = bit.band
function ENT:TestCollision( _, _, _, _, mask )
    if bit_band( mask, sent_contents ) ~= 0 then return true end

end
