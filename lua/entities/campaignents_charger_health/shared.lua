AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "campaignents_charger"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Snapping Charger Health"
ENT.Author      = "straw"
ENT.Purpose     = "Spawns an item_healthcharger that heals, and sticks to the wall it's spawned on."
ENT.Spawnable   = true
ENT.AdminOnly   = false

ENT.ProxyEntClass   = "item_healthcharger"
ENT.EntModifierName = "campaignents_healthcharger"

ENT.ProxyPostSpawnFunc = function( _, toApply, _ )
    toApply:Fire( "Recharge" )

end

duplicator.RegisterEntityModifier( ENT.EntModifierName, ENT.ProxyPostSpawnFunc )
