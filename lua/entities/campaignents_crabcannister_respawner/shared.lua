AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "thing_respawner"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Headcrab Cannister Respawner"
ENT.Author      = "straw"
ENT.Purpose     = "Spawns a new Headcrab Cannister if the previous one is removed."
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.Editable    = true
ENT.DefaultModel = "models/props_combine/headcrabcannister01a.mdl"
ENT.CanCopy = nil

local ourClass = "campaignents_crabcannister_respawner"

local function PosCanSee( startPos, endPos, filter, mask )
    if not startPos then return end
    if not endPos then return end

    mask = mask or MASK_SHOT

    local trData = {
        start = startPos,
        endpos = endPos,
        mask = mask,
        filter = filter
    }
    local trace = util.TraceLine( trData )
    return not trace.Hit, trace

end

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
    self:NetworkVar( "Bool",    1, "NeedToLookAway",    { KeyName = "needtolookaway",       Edit = { order = 2, type = "Bool", category = "Generic Conditions" } } )
    self:NetworkVar( "Bool",    2, "On",                { KeyName = "on",                   Edit = { readonly = true } } )
    self:NetworkVar( "Bool",    3, "ForceSpawn",        { KeyName = "forcespawn",           Edit = { readonly = true } } )

    self:NetworkVar( "Int",     2, "MaxToSpawn",        { KeyName = "maxtospawn",           Edit = { order = 4, type = "Int", min = -1, max = 120, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     3, "MinSpawnInterval",  { KeyName = "minspawninterval",     Edit = { order = 5, type = "Int", min = 0, max = 240, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     4, "SpawnRadiusStart",  { KeyName = "spawnradiusstart",     Edit = { order = 6, type = "Int", min = 0, max = 32000, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     5, "SpawnRadiusEnd",    { KeyName = "spawnradiusend",       Edit = { order = 7, type = "Int", min = 0, max = 32000, category = "Generic Conditions" } } )

    self:NetworkVar( "Int",     6, "MyId",              { KeyName = "myid",                 Edit = { order = 9, type = "Int", min = -1, max = 1000, category = "Id conditions", waitforenter = true } } )
    self:NetworkVar( "Int",     7, "IdToWaitFor",       { KeyName = "idtowaitfor",          Edit = { order = 10, type = "Int", min = -1, max = 1000, category = "Id conditions", waitforenter = true } } )

    self:NetworkVar( "Bool",    4, "Static",            { KeyName = "static",               Edit = { order = 11, type = "Bool", category = "Headcrab Cannister" } } )
    self:NetworkVar( "Bool",    5, "RealTrajectory",    { KeyName = "realtrajectory",       Edit = { order = 12, type = "Bool", category = "Headcrab Cannister" } } )
    self:NetworkVar( "Int",     8, "CrabType",          { KeyName = "crabtype",             Edit = { order = 13, type = "Int", min = 0, max = 2, category = "Headcrab Cannister" } } )
    self:NetworkVar( "Int",     9, "CrabCount",         { KeyName = "crabcount",            Edit = { order = 14, type = "Int", min = 1, max = 10, category = "Headcrab Cannister" } } )
    self:NetworkVar( "Int",     10, "HitDamage",        { KeyName = "hitdamage",            Edit = { order = 15, type = "Int", min = 0, max = 500, category = "Headcrab Cannister" } } )
    self:NetworkVar( "Int",     11, "DamageRadius",     { KeyName = "damageradius",         Edit = { order = 16, type = "Int", min = 0, max = 750, category = "Headcrab Cannister" } } )

    if SERVER then
        self:SetNeedToLookAway( false )
        self:SetOn( true )

        self:SetMyId( -1 )
        self:SetIdToWaitFor( -1 )
        self:DoIdNotify()

        self:SetMaxToSpawn( 1 )
        self:SetMinSpawnInterval( 0 )
        self:SetSpawnRadiusStart( 0 )
        self:SetSpawnRadiusEnd( 3000 )

        self:SetStatic( false )
        self:SetRealTrajectory( true )
        self:SetCrabType( 0 )
        self:SetCrabCount( 5 )
        self:SetHitDamage( 150 )
        self:SetDamageRadius( 350 )

    end
end

if CLIENT then
    function ENT:Draw()
        if campaignents_IsEditing() then
            self:DrawModel()

        end
    end
end

if not SERVER then return end

function ENT:SpawnFunction( spawner, tr )
    local SpawnPos = tr.HitPos + vector_up * 350
    local ent = ents.Create( ourClass )
    ent:SetPos( SpawnPos )

    if IsValid( spawner ) and spawner.EyeAngles then
        local ang = spawner:EyeAngles()
        local newAng = Angle( 0, ang.y, 0 )
        newAng:RotateAroundAxis( vector_up, 180 )
        ent:SetAngles( newAng )

        local secondAng = ent:GetAngles()
        secondAng:RotateAroundAxis( ent:GetRight(), 75 )
        ent:SetAngles( secondAng )

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
        local MSG = "Noclip and look up!\nI set a target for a Headcrab Cannister!\nOpen my context menu!"
        self:TryToPrintOwnerMessage( MSG )
        MSG = "This message will not appear when duped in."
        self:TryToPrintOwnerMessage( MSG )

        nextRespawnerMessage = CurTime() + 25

    end
end

local donePrint

function ENT:BlockGoodSpawn()
    if campaignents_EnabledAi() ~= true then
        if not donePrint then
            donePrint = true
            local MSG = "Headcrab cannister(s) will wait for AI to be enabled..."
            self:TryToPrintOwnerMessage( MSG )

        end
        return true

    end
end

local airTime = 6
local noArcTime = 1

local nextSpawnCrabCanister = 0
local spawnedCount = 0

function ENT:SpawnThing()
    local newThing = ents.Create( "env_headcrabcanister" )
    if not IsValid( newThing ) then return end

    self:DeleteOnRemove( newThing )
    self.spawnedCount = self.spawnedCount + 1
    self.campaignents_Thing = newThing
    newThing.DoNotDuplicate = true

    local timeNeeded = 0
    if not self:GetStatic() then

        if nextSpawnCrabCanister > CurTime() then
            timeNeeded = math.abs( nextSpawnCrabCanister - CurTime() )

        end

        addedTime = math.Rand( 0.1, 0.5 )
        if ( spawnedCount % 3 ) == 0 then
            addedTime = addedTime * 6

        end
        nextSpawnCrabCanister = math.max( CurTime(), nextSpawnCrabCanister ) + addedTime

    end

    spawnedCount = spawnedCount + 1

    timer.Simple( timeNeeded, function()
        if not IsValid( newThing ) then return end

        if WireLib then
            Wire_TriggerOutput( self, "SpawnedCount", self.spawnedCount )
            Wire_TriggerOutput( self, "Spawned", newThing )

        end

        local timeToSpawn = airTime + -1
        if self:GetRealTrajectory() then
            timeToSpawn = 0

        end

        if not self:GetStatic() then
            self:LaunchSound()
            timer.Simple( airTime + -1, function()
                if not IsValid( self ) then return end
                if game.SinglePlayer() then return end -- this only doesnt play in multiplayer
                self:IncomingSound()

            end )

            timer.Simple( airTime + -2, function()
                if not IsValid( self ) then return end
                if not IsValid( newThing ) then return end
                local landingTr = self:CannisterLandingTr( newThing )
                sound.EmitHint( SOUND_DANGER, landingTr.HitPos, 600, 4, newThing )

            end )
        else -- override above if static
            timeToSpawn = 0

        end

        timer.Simple( timeToSpawn, function()
            if not IsValid( self ) then return end
            if not IsValid( newThing ) then return end

            self:SetupCannister( newThing )

        end )
    end )
end

local filterAllPlayers = RecipientFilter()

function ENT:LaunchSound()
    filterAllPlayers:AddAllPlayers()
    local launchSound = CreateSound( self, "HeadcrabCanister.LaunchSound", filterAllPlayers )
    launchSound:SetSoundLevel( 0 )
    launchSound:ChangePitch( math.Rand( 98, 102 ) )
    launchSound:Play()

end

function ENT:IncomingSound()
    if not IsValid( self.campaignents_Thing ) then return end
    filterAllPlayers:AddAllPlayers()
    local launchSound = CreateSound( self.campaignents_Thing, "HeadcrabCanister.IncomingSound", filterAllPlayers )
    launchSound:SetSoundLevel( 120 )
    launchSound:ChangePitch( math.Rand( 98, 102 ) )
    launchSound:Play()

end

function ENT:CannisterLandingTr( canister )
    local cannisterFloorStart = self:GetPos()
    local cannisterFloorEnd = self:GetPos() + -vector_up * 1500
    local _, flooringTr = PosCanSee( cannisterFloorStart, cannisterFloorEnd, { self, canister }, MASK_SOLID_BRUSHONLY )

    return flooringTr

end

function ENT:SetupCannister( canister )
    local landingTr = self:CannisterLandingTr( canister )
    canister:SetPos( landingTr.HitPos )
    local ang = self:GetAngles()
    canister:SetAngles( ang )

    if self:GetStatic() then
        local spawnFlags = 4096
        canister:SetKeyValue( "spawnflags", spawnFlags )

        canister:Spawn()
        canister:Activate()

    else
        local spawnFlags = 2 -- we do a 'fake' launch sound!
        local time = noArcTime
        local speed = 5000
        if self:GetRealTrajectory() then
            time = airTime

        end

        local dmg = self:GetHitDamage()
        if not campaignents_EnabledAi() then
            dmg = 0

        end

        -- tested cannister with startingheight set to all kinds of stuff
        -- worked best on the most maps with this spaghetti mess
        local theCamera
        local cameras = ents.FindByClass( "sky_camera" )
        for _, camera in ipairs( cameras ) do
            if not IsValid( camera ) then continue end
            theCamera = camera

        end
        -- map has no skybox!
        if not theCamera then
            theCamera = self

        end
        canister:SetKeyValue( "StartingHeight", theCamera:WorldToLocal( self:GetPos() ).z )

        canister:SetKeyValue( "headcrabType", self:GetCrabType() )
        canister:SetKeyValue( "HeadcrabCount", self:GetCrabCount() )
        canister:SetKeyValue( "Damage", dmg )
        canister:SetKeyValue( "DamageRadius", self:GetDamageRadius() )
        canister:SetKeyValue( "SmokeLifetime", 20 )
        canister:SetKeyValue( "FlightTime", time )
        canister:SetKeyValue( "FlightSpeed", speed )
        canister:SetKeyValue( "spawnflags", spawnFlags )

        canister:Spawn()
        canister:Activate()

        canister:Fire( "FireCanister" )

    end
end

local crabClasses = {
    ["npc_headcrab"] = true,
    ["npc_headcrab_fast"] = true,
    ["npc_headcrab_black"] = true,

}

hook.Add( "OnEntityCreated", "campaignents_dontcopy_cannistercrabs", function( ent )
    local class = ent:GetClass()
    if not crabClasses[ class ] then return end
    timer.Simple( 0, function()
        if not IsValid( ent ) then return end
        local owner = ent:GetOwner()
        if not IsValid( owner ) then return end
        if owner:GetClass() ~= "env_headcrabcanister" then return end

        owner:DeleteOnRemove( ent )
        ent.DoNotDuplicate = true

    end )
end )