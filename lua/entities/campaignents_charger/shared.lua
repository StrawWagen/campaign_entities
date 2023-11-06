AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "campaignents_empty_turret"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Snapping Charger Suit"
ENT.Author      = "straw"
ENT.Purpose     = "Spawns an item_suitcharger, and sticks to the wall it's spawned on."
ENT.Spawnable   = true
ENT.AdminOnly   = false

ENT.DoDropToFloor   = false
ENT.PhysgunDisabled = true
ENT.ProxyEntClass   = "item_suitcharger"
ENT.EntModifierName = "campaignents_suitcharger"


local vec_up = Vector( 0, 0, 1 )

function ENT:AdditionalInitialize( proxyEnt )
    timer.Simple( 0, function()
        local myPos = proxyEnt:GetPos()
        local floorTr = {
            start = myPos,
            endpos = myPos + -vec_up * 200,
            filter = { proxyEnt },

        }
        local floorResult = util.TraceLine( floorTr )
        local up48Pos = floorResult.HitPos + vec_up * 48

        local behindTr = {
            start = up48Pos,
            endpos = up48Pos + -proxyEnt:GetForward() * 100,
            filter = { proxyEnt },

        }
        local behindResult = util.TraceLine( behindTr )
        if behindResult.Hit then
            proxyEnt:SetPos( behindResult.HitPos )
            proxyEnt:SetAngles( behindResult.HitNormal:Angle() )
            proxyEnt:EmitSound( "physics/metal/metal_box_impact_hard2.wav", 75, math.random( 100, 125 ) )

        end

    end )
    proxyEnt:Spawn()

end

ENT.ProxyPostSpawnFunc = function( _, toApply, _ )
    toApply:Fire( "Recharge" )

end

duplicator.RegisterEntityModifier( ENT.EntModifierName, ENT.ProxyPostSpawnFunc )
