AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "campaignents_empty_turret"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Armed Airboat"
ENT.Author      = "straw"
ENT.Purpose     = "Spawns a prop_vehicle_airboat with the heligun enabled."
ENT.Spawnable   = true
ENT.AdminOnly   = false

ENT.ProxyEntClass   = "prop_vehicle_airboat"
ENT.ProxyEntModel   = "models/airboat.mdl"
ENT.EntModifierName = "campaignents_armed_airboat"
ENT.DoDropToFloor   = false

ENT.ProxyPostSpawnFunc = function( _, toApply, _ )
    toApply:SetKeyValue( "vehiclescript", "scripts/vehicles/airboat.txt" )
    toApply:SetKeyValue( "EnableGun", 1 )
    toApply:Spawn()
    toApply:Activate()

end

duplicator.RegisterEntityModifier( ENT.EntModifierName, ENT.ProxyPostSpawnFunc )
