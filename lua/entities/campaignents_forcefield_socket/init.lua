AddCSLuaFile( "cl_init.lua" ) -- Make sure clientside
AddCSLuaFile( "shared.lua" ) -- and shared scripts are sent.
include( "shared.lua" )


local vec_up = Vector( 0, 0, 1 )

function ENT:SpawnFunction( _, tr, class )
    if not tr.Hit then return end

    local ent = ents.Create( class )
    if not IsValid( ent ) then return end

    local spawnPos = tr.HitPos

    local hitNormal = tr.HitNormal
    local offset = hitNormal:Cross( vec_up ) * 12.5
    offset = offset + -hitNormal
    ent:SetPos( spawnPos + offset )
    ent:SetAngles( hitNormal:Angle() )
    ent:Spawn()

    return ent

end

function ENT:Initialize()
    self:SetModel( "models/props_lab/tpplugholder_single.mdl" )

    campaignents_doFadeDistance( self, 3000 )

    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )

    -- stop annoying bouncing off plug, when plugged after spawning!
    campaignEnts_EasyFreeze( self )

    if not WireLib then return end

    self.Inputs = Wire_CreateInputs( self, { "Powered" } )

end

function ENT:TriggerInput( iname, value )
    if iname == "Powered" and value >= 1 then
        self:SetIsPowered( true )

    else
        self:SetIsPowered( false )

    end
end

function ENT:MakeALilSpark()
    self:EmitSound( "ambient/energy/spark" .. math.random( 1, 6 ) .. ".wav" )
    effect = EffectData()
    effect:SetOrigin( self:WorldSpaceCenter() )
    effect:SetEntity( self )
    effect:SetMagnitude( 2 )
    effect:SetScale( 2 )
    effect:SetRadius( 2 )

    util.Effect( "ElectricSpark", effect, true, true )

end