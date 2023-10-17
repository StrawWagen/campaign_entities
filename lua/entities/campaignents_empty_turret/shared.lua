AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Empty Turret"
ENT.Author      = "straw"
ENT.Purpose     = "Spawns an npc_turret_floor with no ammunition" -- also a base entity for stuff that doesn't need to respawn
ENT.Spawnable   = true
ENT.AdminOnly   = false

ENT.ProxyEntModel   = nil
ENT.ProxyEntClass   = "npc_turret_floor"
ENT.EntModifierName = "campaignents_turretfloor_noammo"
ENT.DoDropToFloor   = true

ENT.ProxyPostSpawnFunc = function( _, toApply, _ )
    toApply:Spawn()

    toApply:Fire( "DepleteAmmo", "1" )

    -- do NOT TIP OVER
    timer.Simple( 0.1, function()
        if not IsValid( toApply ) then return end
        local obj = toApply:GetPhysicsObject()
        if not obj then return end
        obj:SetAngleVelocity( vector_origin )

    end )
    timer.Simple( 0.2, function()
        if not IsValid( toApply ) then return end
        local obj = toApply:GetPhysicsObject()
        if not obj then return end
        obj:SetAngleVelocity( vector_origin )

    end )
    timer.Simple( 0.3, function()
        if not IsValid( toApply ) then return end
        local obj = toApply:GetPhysicsObject()
        if not obj then return end
        obj:SetAngleVelocity( vector_origin )

    end )
    timer.Simple( 0.4, function()
        if not IsValid( toApply ) then return end
        local obj = toApply:GetPhysicsObject()
        if not obj then return end
        obj:SetAngleVelocity( vector_origin )

    end )

end

function ENT:AdditionalInitialize( proxyEnt )
    proxyEnt:Spawn()

end

function ENT:Initialize()
    if SERVER then
        local creator = self:GetCreator()
        SafeRemoveEntityDelayed( self, 0 )

        self:SetNoDraw( true )
        self:DrawShadow( false )

        local proxyEnt = ents.Create( self.ProxyEntClass )
        if self.ProxyEntModel then
            proxyEnt:SetModel( self.ProxyEntModel )

        end

        if IsValid( creator ) then
            proxyEnt:SetCreator( creator )

            undo.Create( self.PrintName )
                undo.AddEntity( proxyEnt )
                undo.SetPlayer( creator )

            undo.Finish()

        end
        proxyEnt:SetPos( self:GetPos() )
        proxyEnt:SetAngles( self:GetAngles() )

        local ProxyPostSpawnFunc = self.ProxyPostSpawnFunc
        ProxyPostSpawnFunc( creator, proxyEnt, nil )

        duplicator.StoreEntityModifier( proxyEnt, self.EntModifierName, {} )

        self:AdditionalInitialize( proxyEnt )

        if self.DoDropToFloor then
            proxyEnt:DropToFloor()

        end
    end
end

duplicator.RegisterEntityModifier( ENT.EntModifierName, ENT.ProxyPostSpawnFunc )