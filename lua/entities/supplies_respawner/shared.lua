AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "thing_respawner"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Supplies Respawner"
ENT.Author      = "GPT-4, fixed by straw"
ENT.Purpose     = "Spawns a new supply crate if the previous one is removed."
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.Editable    = true
ENT.DefaultModel = "models/Items/item_item_crate.mdl"
ENT.CanCopy = nil

function ENT:SetModelToSpawn()
end
function ENT:SetNPCWeapon()
end

function ENT:GetModelToSpawn()
    return self.DefaultModel

end
function ENT:GetNPCWeapon()
    return ""

end

local function hitAnythingButPlacers( ent )
    if ent.isCampaignEntsRespawner then return false end
    return true

end

function ENT:SetupDataTables()
    local i = 1
    self:NetworkVar( "String", 1, "SupplyContentClass", { KeyName = "classtospawn",         Edit = { order = i + 1, type = "String", category = "Supplies Settings" } } )
    self:NetworkVar( "Int",    1, "SuppliesCount",      { KeyName = "suppliescount",        Edit = { order = i + 1, type = "Int", min = 1, max = 6, category = "Supplies Settings" } } )
    self:NetworkVar( "Bool",   1, "NeedToLookAway",     { KeyName = "needtolookaway",       Edit = { order = i + 1, type = "Bool", category = "Generic Conditions" } } )

    self:NetworkVar( "Bool",    2, "BlockSpawn",        { KeyName = "blockspawn",           Edit = { readonly = true } } )
    self:NetworkVar( "Bool",    3, "ForceSpawn",        { KeyName = "forcespawn",           Edit = { readonly = true } } )

    self:NetworkVar( "Int",     2, "MaxToSpawn",        { KeyName = "maxtospawn",           Edit = { order = i + 1, type = "Int", min = -1, max = 120, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     3, "MinSpawnInterval",  { KeyName = "minspawninterval",     Edit = { order = i + 1, type = "Int", min = 0, max = 240, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     4, "SpawnRadiusStart",  { KeyName = "spawnradiusstart",     Edit = { order = i + 1, type = "Int", min = 0, max = 32000, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     5, "SpawnRadiusEnd",    { KeyName = "spawnradiusend",       Edit = { order = i + 1, type = "Int", min = 0, max = 32000, category = "Generic Conditions" } } )

    self:NetworkVar( "Int",     7, "GoalID",            { KeyName = "goalid",               Edit = { readonly = true } } )
    self:NetworkVar( "Bool",    4, "ShowGoalLinks",     { KeyName = "forcespawn",           Edit = { readonly = true } } )

    if SERVER then
        self:NetworkVarNotify( "SpawnRadiusEnd", function( _, _, _, new )
            if not SERVER then return end
            if not IsValid( self ) then return end

            CAMPAIGN_ENTS.TrackPlyProximity( self, new )

        end )

        self:SetModelToSpawn( self.DefaultModel )
        self:SetSupplyContentClass( "item_dynamic_resupply" )
        self:SetNPCWeapon( "" )
        self:SetNeedToLookAway( false )
        self:SetBlockSpawn( false )

        self:SetMaxToSpawn( 1 )
        self:SetMinSpawnInterval( 0 )
        self:SetSpawnRadiusStart( 0 )
        self:SetSpawnRadiusEnd( 3000 )
        self:SetSuppliesCount( 1 )

    end
end

function ENT:SpawnFunction( spawner, tr )
    local SpawnPos = tr.HitPos + vector_up * 80
    local ent = ents.Create( self.ClassName )
    ent:SetPos( SpawnPos )

    if IsValid( spawner ) and spawner.EyeAngles then
        local ang = spawner:EyeAngles()
        local newAng = Angle( 0, ang.y, 0 )
        ent:SetAngles( newAng )

    end

    ent:Spawn()
    ent:Activate()
    local effectdata = EffectData()
    effectdata:SetEntity( ent )
    util.Effect( "propspawn", effectdata )

    return ent

end

if not SERVER then return end

function ENT:ResetVars()
    self.campaignents_Thing = nil
    self.spawnedFirstThing = nil
    self.aiWasDisabled = nil
    self.spawnedCount = 0
    self.nextSpawningThink = 0
    self.nextThingSpawn = 0

end

local nextRespawnerMessage = 0
function ENT:SelfSetup()
    if self.duplicatedIn then return end
    if nextRespawnerMessage > CurTime() then return end
    if CAMPAIGN_ENTS.EnabledAi() then
        local MSG = "Noclip and look up!\nI spawn in just supply crates with dynamic resupplies inside!\nOpen my context menu!"
        CAMPAIGN_ENTS.MessageOwner( self, MSG )
        MSG = "This message will not appear when duped in."
        CAMPAIGN_ENTS.MessageOwner( self, MSG )

        nextRespawnerMessage = CurTime() + 25

    end
end

local smarterSuppliesVar = CreateConVar( "campaignents_smarter_dynamicresupplies", 1, FCVAR_ARCHIVE, "Makes item_dynamic_resupplies spawned by 'supplies respawners' even smarter. " )

function ENT:SpawnThing()
    local modelRad = self:GetModelRadius()
    local downOffset = modelRad * 1.5

    local simpleDownTrace = util.QuickTrace( self:GetPos(), -vector_up * downOffset, hitAnythingButPlacers )
    local posToSetTo = simpleDownTrace.HitPos + simpleDownTrace.HitNormal * 5

    local newThing = ents.Create( "item_item_crate" )
    if not IsValid( newThing ) then return end

    local insideClass = self:GetSupplyContentClass()

    if smarterSuppliesVar:GetBool() and insideClass == "item_dynamic_resupply" then
        newThing.campaignents_DynamicResupplyCrate = true
        newThing.campaignents_DynamicResupplyCount = math.Clamp( self:GetSuppliesCount(), 0, 64 )
        newThing:SetKeyValue( "ItemClass", "item_dynamic_resupply" )
        newThing:SetKeyValue( "ItemCount", 0 )

    else
        newThing:SetKeyValue( "ItemClass", insideClass )
        newThing:SetKeyValue( "ItemCount", self:GetSuppliesCount() )

    end

    newThing:SetPos( posToSetTo )
    newThing:SetAngles( self:GetAngles() )

    self:TransferStuffTo( newThing )

    newThing:Spawn()

    newThing:Activate()
    newThing:DropToFloor()
    newThing.DoNotDuplicate = true

    self:DeleteOnRemove( newThing )
    self.campaignents_Thing = newThing
    self.spawnedCount = self.spawnedCount + 1

    if not WireLib then return end
    Wire_TriggerOutput( self, "SpawnedCount", self.spawnedCount )
    Wire_TriggerOutput( self, "Spawned", newThing )

end

local upOffset = Vector( 0, 0, 5 )

local maxAmmoVar = GetConVar( "gmod_maxammo" )
local overrides = {
    DesiredAmmo357 = 0.1,
    DesiredAmmoCrossbow = 0.1,
    DesiredAmmoAR2_AltFire = 0.05,
    DesiredAmmoSMG1_Grenade = 0.05,
    DesiredAmmoRPG_Round = 0.05,
}

local varsToDivide = {
    DesiredAmmoPistol = true,
    DesiredAmmoSMG1 = true,
    DesiredAmmoSMG1_Grenade = true,
    DesiredAmmoAR2 = true,
    DesiredAmmoAR2_AltFire = true,
    DesiredAmmoBuckshot = true,
    DesiredAmmoGrenade = true,
    DesiredAmmoRPG_Round = true,
    DesiredAmmo357 = true,
    DesiredAmmoCrossbow = true,

}

local wepsNeededToEnable = {
    DesiredAmmoPistol = "weapon_pistol",
    DesiredAmmoSMG1 = "weapon_smg1",
    DesiredAmmoSMG1_Grenade = "weapon_smg1",
    DesiredAmmoAR2 = "weapon_ar2",
    DesiredAmmoAR2_AltFire = "weapon_ar2",
    DesiredAmmoBuckshot = "weapon_shotgun",
    DesiredAmmoRPG_Round = "weapon_rpg",
    DesiredAmmo357 = "weapon_357",
    DesiredAmmoCrossbow = "weapon_crossbow",

}

-- cancel giving this ammo if player has more than this amount
-- when it reaches the max count, it then waits interval to start giving them to plys again.
local maxAmmoCounts = {
    DesiredAmmoSMG1_Grenade = { type = "SMG1_Grenade", count = 1, interval = 35, nextSpawn = 0 },
    DesiredAmmoAR2_AltFire = { type = "AR2AltFire", count = 1, interval = 45, nextSpawn = 0 },
    DesiredAmmoGrenade = { type = "Grenade", count = 1, interval = 25, nextSpawn = 0 },

}

local SF_DYNAMICRESUPPLY_ALWAYS_SPAWN = 4

local flags = bit.bor( 1, SF_DYNAMICRESUPPLY_ALWAYS_SPAWN )

local function spawnCustomResupplies( myPos, count )
    local randPitch = math.random( -1, 1 ) * 45
    local maxAmmoVarInt = maxAmmoVar:GetInt()
    local ammoVarCompensatorMul = 100 / maxAmmoVarInt

    local nearestPlysWeps = {}
    local nearestPly
    local nearestPlyDist = math.huge
    for _, ply in player.Iterator() do
        local dist = ply:GetPos():DistToSqr( myPos )
        if dist < nearestPlyDist then
            nearestPlyDist = dist
            nearestPly = ply

        end
    end

    if IsValid( nearestPly ) then
        for _, wep in ipairs( nearestPly:GetWeapons() ) do
            nearestPlysWeps[wep:GetClass()] = true

        end
    end

    local curTime = CurTime()

    for index = 1, count do
        local randYaw = math.random( -4, 4 ) * 45
        local angle = Angle( randPitch, randYaw, 0 )
        local pos = myPos + upOffset * index

        local item = ents.Create( "item_dynamic_resupply" )
        if not item then continue end
        for key, currSet in pairs( item:GetKeyValues() ) do
            local currMul = 1
            if index > 1 then
                -- if box is spawning multiple resupplies, randomize the targets
                -- stops box from spawning like 4 grenades when the target is 1
                currMul = currMul + ( math.Rand( -index, index ) )

            end

            local override = overrides[key]
            if override then
                item:SetKeyValue( key, override )

            end
            local doDivide = varsToDivide[key]
            if doDivide then
                local newVar = currSet * currMul

                -- max ammo var is crazy high
                if maxAmmoVarInt > 100 then
                    newVar = newVar * ammoVarCompensatorMul

                end

                -- ply doesnt have this weapon, dont spawn ammo for it
                local neededWep = wepsNeededToEnable[ key ]
                if neededWep and not nearestPlysWeps[ neededWep ] then
                    --print( key, neededWep, nearestPlysWeps[ neededWep ] )
                    newVar = 0

                end

                local maxCountDat = maxAmmoCounts[ key ]
                if maxCountDat then
                    local currCount = nearestPly:GetAmmoCount( maxCountDat.type )
                    if maxCountDat.nextSpawn < curTime then
                        newVar = 0

                    elseif currCount >= maxCountDat.count then
                        newVar = 0
                        maxCountDat.nextSpawn = curTime + maxCountDat.interval

                    end
                end
                item:SetKeyValue( key, newVar )

            end
        end

        item:SetKeyValue( "spawnflags", flags )

        item:SetAngles( angle )
        item:SetPos( pos )
        item:Spawn()

        item:NextThink( CurTime() )

    end
end


hook.Add( "EntityTakeDamage", "campaignents_messwithdynamicresupllies", function( ent, _ )
    if not ent.campaignents_DynamicResupplyCrate then return end

    local count = ent.campaignents_DynamicResupplyCount
    local myPos = ent:GetPos()

    timer.Simple( 0, function()
        if IsValid( ent ) and ent:Health() > 0 then return end
        spawnCustomResupplies( myPos, count )

    end )
end )

function ENT:CaptureCollidersInfo()
    return

end