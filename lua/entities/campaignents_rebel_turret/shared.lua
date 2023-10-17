AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "campaignents_empty_turret"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Rebel Turret"
ENT.Author      = "straw"
ENT.Purpose     = "Spawns an npc_turret_floor that's friendly to players."
ENT.Spawnable   = true
ENT.AdminOnly   = false

ENT.ProxyEntClass   = "npc_turret_floor"
ENT.EntModifierName = "campaignents_turretfloor_friendly_noammo"

local randMats = {
    "models/rebelturrets/floor_turret_citizen",
    "models/rebelturrets/floor_turret_citizen2",
    "models/rebelturrets/floor_turret_citizen4"

}

function ENT:AdditionalInitialize( proxyEnt )
    proxyEnt:SetMaterial( randMats[ math.random( 1, 3 ) ] )
    proxyEnt:Spawn()

end

ENT.ProxyPostSpawnFunc = function( _, toApply, _ )
    toApply:AddRelationship( "npc_combine_s D_HT 0" )
    toApply:AddRelationship( "npc_metropolice D_HT 0" )

    local timerName = "campaignents_rebelturret_protectowner" .. toApply:GetCreationID()
    timer.Create( timerName, 0.15, 0, function()
        if not timerName then return end
        if not IsValid( toApply ) then timer.Remove( timerName ) return end
        local myCreator = toApply:GetCreator()

        -- no creator!
        if not IsValid( myCreator ) then
            local plys = player.GetAll()
            if IsValid( plys[1] ) then
                toApply:SetCreator( plys[1] )
                return

            else
                return

            end
        end

        local enemy = toApply:GetEnemy()
        if not IsValid( enemy ) then return end
        if not enemy.Disposition then return end

        if enemy:Disposition( myCreator ) == D_HT then return end
        toApply:EmitSound( "npc/turret_floor/click1.wav" )
        toApply:AddEntityRelationship( enemy, D_LI )

        if not enemy.AddEntityRelationship then return end
        enemy:AddEntityRelationship( toApply, D_LI )

    end )

    local hookName = "campaignents_rebelturret_detectenemies" .. toApply:GetCreationID()
    hook.Add( "EntityTakeDamage", hookName, function( target, dmgInfo )
        if not hookName then return end
        if not IsValid( toApply ) then hook.Remove( "EntityTakeDamage", hookName ) return end

        local myCreator = toApply:GetCreator()
        -- no creator!
        if not IsValid( myCreator ) then
            if not target:IsPlayer() then return end

        else
            if target ~= myCreator then return end

        end

        local attacker = dmgInfo:GetAttacker()

        if not IsValid( attacker ) then return end
        if attacker == target then return end
        if not attacker:IsPlayer() and not attacker:IsNPC() and not attacker:IsNextBot() then return end

        if attacker.AddEntityRelationship and attacker:Disposition( toApply ) ~= D_HT then
            attacker:AddEntityRelationship( toApply, D_HT )

        end

        if toApply:Disposition( attacker ) == D_HT then return end
        toApply:EmitSound( "npc/turret_floor/deploy.wav" )
        toApply:AddEntityRelationship( attacker, D_HT )

    end )

    -- jump awake to show player that it is alive and wont shoot em
    toApply:Fire( "Enable", "1", 0.1 )

    toApply:SetCurrentWeaponProficiency( WEAPON_PROFICIENCY_PERFECT )

    toApply:AddRelationship( "player D_LI 100"  )

    -- do NOT TIP OVER
    timer.Simple( 0.1, function()
        if not IsValid( toApply ) then return end
        local obj = toApply:GetPhysicsObject()
        if not IsValid( obj ) then return end
        obj:SetAngleVelocity( Vector( 0, 0, 0 ) )

    end )
    timer.Simple( 0.2, function()
        if not IsValid( toApply ) then return end
        local obj = toApply:GetPhysicsObject()
        if not IsValid( obj ) then return end
        obj:SetAngleVelocity( Vector( 0, 0, 0 ) )

    end )
    timer.Simple( 0.3, function()
        if not IsValid( toApply ) then return end
        local obj = toApply:GetPhysicsObject()
        if not IsValid( obj ) then return end
        obj:SetAngleVelocity( Vector( 0, 0, 0 ) )

    end )
    timer.Simple( 0.4, function()
        if not IsValid( toApply ) then return end
        local obj = toApply:GetPhysicsObject()
        if not IsValid( obj ) then return end
        obj:SetAngleVelocity( Vector( 0, 0, 0 ) )

    end )
end

duplicator.RegisterEntityModifier( ENT.EntModifierName, ENT.ProxyPostSpawnFunc )

if not SERVER then return end

resource.AddFile( "combine_gun002.vmt" )
resource.AddFile( "combine_gun002.vtf" )
resource.AddFile( "combine_gun002_normal.vtf" )

resource.AddFile( "floor_turret_citizen.vmt" )
resource.AddFile( "floor_turret_citizen.vtf" )
resource.AddFile( "floor_turret_citizen_glow.vtf" )
resource.AddFile( "floor_turret_citizen_noalpha.vtf" )
resource.AddFile( "floor_turret_citizennormal.vtf" )

resource.AddFile( "floor_turret_citizen2.vmt" )
resource.AddFile( "floor_turret_citizen2.vtf" )
resource.AddFile( "floor_turret_citizen2_noalpha.vtf" )

resource.AddFile( "floor_turret_citizen4.vmt" )
resource.AddFile( "floor_turret_citizen4.vtf" )
resource.AddFile( "floor_turret_citizen4_noalpha.vtf" )
resource.AddFile( "floor_turret_citizen4normal.vtf" )
