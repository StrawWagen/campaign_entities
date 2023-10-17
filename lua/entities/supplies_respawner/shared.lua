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

local ourClass = "supplies_respawner"

local function hitAnythingButPlacers( ent )
    if ent:GetClass() == ourClass then return false end
    return true

end

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

function ENT:SetupDataTables()
    self:NetworkVar( "String", 1, "SupplyContentClass", { KeyName = "classtospawn",         Edit = { order = 1, type = "String", category = "Supplies Settings" } } )
    self:NetworkVar( "Int",    1, "SuppliesCount",      { KeyName = "suppliescount",        Edit = { order = 2, type = "Int", min = 1, max = 6, category = "Supplies Settings" } } )
    self:NetworkVar( "Bool",   1, "NeedToLookAway",     { KeyName = "needtolookaway",       Edit = { order = 3, type = "Bool", category = "Generic Conditions" } } )

    self:NetworkVar( "Bool",    2, "On",                { KeyName = "on",            Edit = { readonly = true } } )
    self:NetworkVar( "Bool",    3, "ForceSpawn",        { KeyName = "forcespawn",          Edit = { readonly = true } } )

    self:NetworkVar( "Int",    2, "MaxToSpawn",         { KeyName = "maxtospawn",           Edit = { order = 4, type = "Int", min = -1, max = 120, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",    3, "MinSpawnInterval",   { KeyName = "minspawninterval",     Edit = { order = 5, type = "Int", min = 0, max = 240, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",    4, "SpawnRadiusStart",   { KeyName = "spawnradiusstart",     Edit = { order = 6, type = "Int", min = 0, max = 32000, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",    5, "SpawnRadiusEnd",     { KeyName = "spawnradiusend",       Edit = { order = 7, type = "Int", min = 0, max = 32000, category = "Generic Conditions" } } )

    self:NetworkVar( "Int",     7, "GoalID",            { KeyName = "goalid",              Edit = { readonly = true } } )
    self:NetworkVar( "Bool",    4, "ShowGoalLinks",     { KeyName = "forcespawn",          Edit = { readonly = true } } )

    if SERVER then
        self:SetModelToSpawn( self.DefaultModel )
        self:SetSupplyContentClass( "item_dynamic_resupply" )
        self:SetNPCWeapon( "" )
        self:SetNeedToLookAway( false )
        self:SetOn( true )

        self:SetMaxToSpawn( 1 )
        self:SetMinSpawnInterval( 0 )
        self:SetSpawnRadiusStart( 0 )
        self:SetSpawnRadiusEnd( 3000 )
        self:SetSuppliesCount( 1 )

    end
end

function ENT:SpawnFunction( spawner, tr )
    local SpawnPos = tr.HitPos + vector_up * 80
    local ent = ents.Create( ourClass )
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

function ENT:ResetVars()
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
    if campaignents_EnabledAi() then
        local MSG = "Noclip and look up!\nI spawn in just supply crates with dynamic resupplies inside!\nOpen my context menu!"
        self:TryToPrintOwnerMessage( MSG )
        MSG = "This message will not appear when duped in."
        self:TryToPrintOwnerMessage( MSG )

        nextRespawnerMessage = CurTime() + 25

    end
end

function ENT:SpawnThing()
    local modelRad = self:GetModelRadius()
    local downOffset = modelRad * 1.5

    local simpleDownTrace = util.QuickTrace( self:GetPos(), -vector_up * downOffset, hitAnythingButPlacers )
    local posToSetTo = simpleDownTrace.HitPos + simpleDownTrace.HitNormal * 5

    local newThing = ents.Create( "item_item_crate" )
    if not IsValid( newThing ) then return end

    newThing:SetKeyValue( "ItemClass", self:GetSupplyContentClass() )
    newThing:SetKeyValue( "ItemCount", self:GetSuppliesCount() )

    newThing:SetPos( posToSetTo )
    newThing:SetAngles( self:GetAngles() )

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

function ENT:CaptureCollidersInfo()
    return

end