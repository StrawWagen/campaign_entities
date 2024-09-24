AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "thing_respawner"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Sniper Respawner"
ENT.Author      = "straw"
ENT.Purpose     = "Spawns a new Combine Sniper if the previous one is removed."
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.Editable    = true
ENT.DefaultModel = "models/combine_soldier.mdl"
ENT.CanCopy = false

local ourClass = "campaignents_sniper_respawner"

function ENT:SetModelToSpawn()
end
function ENT:SetNPCWeapon()
end

function ENT:GetModelToSpawn()
    return self.DefaultModel

end
function ENT:GetNPCWeapon()
    return

end

function ENT:CaptureCollidersInfo()
    return

end

function ENT:SetupDataTables()
    local i = 1
    self:NetworkVar( "Bool",    1, "NeedToLookAway",    { KeyName = "needtolookaway",       Edit = { order = i + 1, type = "Bool", category = "Generic Conditions" } } )
    self:NetworkVar( "Bool",    2, "BlockSpawn",        { KeyName = "blockspawn",           Edit = { readonly = true } } )
    self:NetworkVar( "Bool",    3, "ForceSpawn",        { KeyName = "forcespawn",           Edit = { readonly = true } } )

    self:NetworkVar( "Int",     2, "MaxToSpawn",        { KeyName = "maxtospawn",           Edit = { order = i + 1, type = "Int", min = -1, max = 120, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     3, "MinSpawnInterval",  { KeyName = "minspawninterval",     Edit = { order = i + 1, type = "Int", min = 0, max = 240, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     4, "SpawnRadiusStart",  { KeyName = "spawnradiusstart",     Edit = { order = i + 1, type = "Int", min = 0, max = 32000, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     5, "SpawnRadiusEnd",    { KeyName = "spawnradiusend",       Edit = { order = i + 1, type = "Int", min = 0, max = 32000, category = "Generic Conditions" } } )

    self:NetworkVar( "Int",     6, "MyId",              { KeyName = "myid",                 Edit = { order = i + 1, type = "Int", min = -1, max = 1000, category = "Id conditions", waitforenter = true } } )
    self:NetworkVar( "Int",     7, "IdToWaitFor",       { KeyName = "idtowaitfor",          Edit = { order = i + 1, type = "Int", min = -1, max = 1000, category = "Id conditions", waitforenter = true } } )

    self:NetworkVar( "Bool",    4, "Visible",           { KeyName = "visible",              Edit = { order = i + 1, type = "Bool", category = "Combine Sniper" } } )

    if SERVER then
        self:NetworkVarNotify( "SpawnRadiusEnd", function( _, _, _, new )
            if not SERVER then return end
            if not IsValid( self ) then return end

            CAMPAIGN_ENTS.TrackPlyProximity( self, new )

        end )

        self:SetNeedToLookAway( false )
        self:SetBlockSpawn( false )

        self:SetMyId( -1 )
        self:SetIdToWaitFor( -1 )
        self:DoIdNotify()

        self:SetMaxToSpawn( 1 )
        self:SetMinSpawnInterval( 0 )
        self:SetSpawnRadiusStart( 0 )
        self:SetSpawnRadiusEnd( 3000 )

        self:SetVisible( false )

    end
end

function ENT:SpawnFunction( spawner, tr )
    local SpawnPos = tr.HitPos + vector_up * 75
    local ent = ents.Create( ourClass )
    ent:SetPos( SpawnPos )

    if IsValid( spawner ) and spawner.EyeAngles then
        local ang = spawner:EyeAngles()
        local newAng = Angle( 0, ang.y, 0 )
        newAng:RotateAroundAxis( vector_up, 180 )
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
        local MSG = "Noclip and look up!\nI spawn an invisible sniper!\nOpen my context menu!"
        CAMPAIGN_ENTS.MessageOwner( self, MSG )
        MSG = "This message will not appear when duped in."
        CAMPAIGN_ENTS.MessageOwner( self, MSG )

        nextRespawnerMessage = CurTime() + 25

    end
end

function ENT:SpawnThing()
    local newThing = ents.Create( "npc_sniper" )
    if not IsValid( newThing ) then return end

    self:SetupSniper( newThing )
    self:TransferStuffTo( newThing )

    self:DeleteOnRemove( newThing )

    newThing.DoNotDuplicate = true

    self.campaignents_Thing = newThing
    self.spawnedCount = self.spawnedCount + 1

    if not WireLib then return end
    Wire_TriggerOutput( self, "SpawnedCount", self.spawnedCount )
    Wire_TriggerOutput( self, "Spawned", newThing )

end

function ENT:SetupSniper( sniper )
    if not self:GetVisible() then
        sniper:SetKeyValue( "spawnflags", 65536 )

    end

    sniper:SetKeyValue( "misses", 1 )
    sniper:SetKeyValue( "PaintInterval", 2 )

    sniper:SetPos( self:GetPos() + -vector_up * 25 )
    sniper:SetAngles( self:GetAngles() )
    sniper:Spawn()
    sniper:Activate()

    sniper:DropToFloor()

    if not self:GetVisible() then
        sniper:SetPos( sniper:GetPos() + vector_up * 50 )

    end
end