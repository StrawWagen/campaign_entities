AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "campaignents_empty_turret"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Citadel Suit Charger"
ENT.Author      = "straw"
ENT.Purpose     = "Spawns an item_suitcharger that heals and overcharges."
ENT.Spawnable   = true
ENT.AdminOnly   = false

ENT.ProxyEntClass   = "item_suitcharger"
ENT.EntModifierName = "campaignents_suitcharger_citadel"


function ENT:AdditionalInitialize( proxyEnt )
    proxyEnt:Spawn()

end

ENT.ProxyPostSpawnFunc = function( _, toApply, _ )
    toApply:SetKeyValue( "spawnflags", 8192 )
    toApply:Fire( "Recharge" )

end

duplicator.RegisterEntityModifier( ENT.EntModifierName, ENT.ProxyPostSpawnFunc )
