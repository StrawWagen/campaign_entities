AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "campaignents_charger"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Snapping Charger Citadel"
ENT.Author      = "straw"
ENT.Purpose     = "Spawns an item_suitcharger that heals, overcharges, and sticks to the wall it's spawned on."
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.ProxyEntClass   = "item_suitcharger"
ENT.EntModifierName = "campaignents_suitcharger_citadel"

ENT.ProxyPostSpawnFunc = function( _, toApply, _ )
    toApply:SetKeyValue( "spawnflags", 8192 )
    toApply:Fire( "Recharge" )

end

duplicator.RegisterEntityModifier( ENT.EntModifierName, ENT.ProxyPostSpawnFunc )
