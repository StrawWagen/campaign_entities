AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "campaignents_empty_turret"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Armed Jeep"
ENT.Author      = "straw"
ENT.Purpose     = "Spawns a prop_vehicle_jeep with the TAU cannon enabled."
ENT.Spawnable   = true
ENT.AdminOnly   = false

ENT.ProxyEntClass   = "prop_vehicle_jeep"
ENT.ProxyEntModel   = "models/buggy.mdl"
ENT.EntModifierName = "campaignents_armed_jeep"

ENT.ProxyPostSpawnFunc = function( _, toApply, _ )
    toApply:SetKeyValue( "EnableGun", 1 )
    toApply:SetKeyValue( "vehiclescript", "scripts/vehicles/jeep_test.txt" )
    toApply:Spawn()

end

duplicator.RegisterEntityModifier( ENT.EntModifierName, ENT.ProxyPostSpawnFunc )