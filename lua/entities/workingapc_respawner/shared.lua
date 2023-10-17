AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "thing_respawner"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "APC Respawner"
ENT.Author      = "straw"
ENT.Purpose     = "Spawns a new Combine APC if the previous one is removed."
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.Editable    = true
ENT.DefaultModel = "models/combine_apc_wheelcollision.mdl"
ENT.CanCopy = nil

local ourClass = "workingapc_respawner"

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

function ENT:CaptureCollidersInfo()
    return

end

local function SparkEffect( SparkPos )
    local Sparks = EffectData()
    Sparks:SetOrigin( SparkPos )
    Sparks:SetMagnitude( 2 )
    Sparks:SetScale( 1 )
    Sparks:SetRadius( 6 )
    util.Effect( "Sparks", Sparks )

end

function ENT:SetupDataTables()
    self:NetworkVar( "Bool",    1, "NeedToLookAway",    { KeyName = "needtolookaway",       Edit = { order = 2, type = "Bool", category = "Generic Conditions" } } )
    self:NetworkVar( "Bool",    2, "On",                { KeyName = "on",            Edit = { readonly = true } } )
    self:NetworkVar( "Bool",    3, "ForceSpawn",        { KeyName = "forcespawn",          Edit = { readonly = true } } )

    self:NetworkVar( "Int",     2, "MaxToSpawn",        { KeyName = "maxtospawn",           Edit = { order = 4, type = "Int", min = -1, max = 120, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     3, "MinSpawnInterval",  { KeyName = "minspawninterval",     Edit = { order = 5, type = "Int", min = 0, max = 240, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     4, "SpawnRadiusStart",  { KeyName = "spawnradiusstart",     Edit = { order = 6, type = "Int", min = 0, max = 32000, category = "Generic Conditions" } } )
    self:NetworkVar( "Int",     5, "SpawnRadiusEnd",    { KeyName = "spawnradiusend",       Edit = { order = 7, type = "Int", min = 0, max = 32000, category = "Generic Conditions" } } )

    self:NetworkVar( "Int",     6, "MyId",              { KeyName = "myid",                Edit = { order = 9, type = "Int", min = -1, max = 1000, category = "Id conditions", waitforenter = true } } )
    self:NetworkVar( "Int",     7, "IdToWaitFor",       { KeyName = "idtowaitfor",         Edit = { order = 10, type = "Int", min = -1, max = 1000, category = "Id conditions", waitforenter = true } } )

    self:NetworkVar( "Int",     8, "GoalID",            { KeyName = "goalid",               Edit = { readonly = true } } )
    self:NetworkVar( "Bool",    4, "ShowGoalLinks",     { KeyName = "forcespawn",           Edit = { readonly = true } } )
    self:NetworkVar( "Entity",  31, "ProxyEnt",         { KeyName = "proxyEnt",             Edit = { readonly = true } } )

    self:NetworkVar( "Bool",    5, "DoManhacks",        { KeyName = "domanhacks",           Edit = { order = 11, type = "Bool", category = "Combine APC" } } )
    self:NetworkVar( "Bool",    6, "CanDrive",          { KeyName = "candrive",             Edit = { order = 12, type = "Bool", category = "Combine APC" } } )
    self:NetworkVar( "Bool",    7, "Static",              { KeyName = "static",                 Edit = { order = 12, type = "Bool", category = "Combine APC" } } )
    self:NetworkVar( "Int",     10, "PoliceCount",      { KeyName = "copcount",             Edit = { order = 13, type = "Int", min = 0, max = 10, category = "Combine APC" } } )
    self:NetworkVar( "Int",     11, "APCHealth",        { KeyName = "apchealth",            Edit = { order = 14, type = "Int", min = 750, max = 3000, category = "Combine APC" } } )
    self:NetworkVar( "Float",   0, "APCDamageMul",      { KeyName = "apcdamagemul",         Edit = { order = 14, type = "float", min = 0.5, max = 3, category = "Combine APC" } } )

    if SERVER then
        self:SetNeedToLookAway( false )
        self:SetOn( true )

        self:SetMyId( -1 )
        self:SetIdToWaitFor( -1 )
        self:DoIdNotify()

        self:SetGoalID( -1 )

        self:SetMaxToSpawn( 1 )
        self:SetMinSpawnInterval( 0 )
        self:SetSpawnRadiusStart( 0 )
        self:SetSpawnRadiusEnd( 3000 )

        self:SetDoManhacks( true )
        self:SetCanDrive( true )
        self:SetStatic( false )
        self:SetPoliceCount( 4 )
        self:SetAPCDamageMul( 1.5 )
        self:SetAPCHealth( 1250 )

    end

    self:NetworkVarNotify( "GoalID", function( _, _, _, new )
        if not CLIENT then return end
        if not IsValid( self ) then return end

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            campaignents_DoBeamColor( self )

        end )
    end )
end

local cached
function ENT:AdditionalInitialize()
    if cached then return end
    util.PrecacheModel( "models/police.mdl" )
    util.PrecacheModel( "models/manhack.mdl" )

end

function ENT:SpawnFunction( spawner, tr )
    local SpawnPos = tr.HitPos + vector_up * 180
    local ent = ents.Create( ourClass )
    ent:SetPos( SpawnPos )

    if IsValid( spawner ) and spawner.EyeAngles then
        local ang = spawner:EyeAngles()
        local newAng = Angle( 0, ang.y, 0 )
        newAng:RotateAroundAxis( vector_up, 90 )
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
        local MSG = "Noclip and look up!\nI spawn a boss APC!\nOpen my context menu!"
        self:TryToPrintOwnerMessage( MSG )
        MSG = "This message will not appear when duped in."
        self:TryToPrintOwnerMessage( MSG )

        nextRespawnerMessage = CurTime() + 25

    end
end

function ENT:SpawnThing()

    local newThing = ents.Create( "prop_vehicle_apc" )
    if not IsValid( newThing ) then return end

    self:SetupAPC( newThing )

    newThing.DoNotDuplicate = true

    self:CallOnRemove( "killspawnedapc", function()
        if not IsValid( newThing ) then return end
        -- crash fix!
        newThing:Fire( "KillHierarchy" )

    end )

    self.campaignents_Thing = newThing
    self.spawnedCount = self.spawnedCount + 1

    self:IfGoalMakeSpawnedGoThere()

    if not WireLib then return end
    Wire_TriggerOutput( self, "SpawnedCount", self.spawnedCount )
    Wire_TriggerOutput( self, "Spawned", newThing )

end

function ENT:IfGoalMakeSpawnedGoThere()
    if not self.GetGoalID then return end --backwards compat

    local potentialNPC = self.campaignents_Thing
    if not IsValid( potentialNPC ) then return end

    local goal = self:GetMyNPCGoal()

    if not IsValid( goal ) then return end

    goal:ManageNPC( self.campaignents_Thing )

end

function ENT:GetMyNPCGoal()
    if not self.GetGoalID then return end
    if self:GetGoalID() <= -1 then return end

    local goals = ents.FindByClass( "campaignents_npcgoal" )
    for _, potentialGoal in ipairs( goals ) do
        if potentialGoal:GetGoalID() == self:GetGoalID() then
            return potentialGoal

        end
    end
end

if CLIENT then
    local beamMat = Material( "egon_middlebeam" )

    function ENT:Draw()
        if campaignents_IsEditing() then
            self:DrawModel()

            local nextNPCGoalCheck = self.nextNPCGoalCheck or 0
            local NPCGoal = self.NPCGoal
            if nextNPCGoalCheck < CurTime() then
                self.nextNPCGoalCheck = CurTime() + 0.75

                NPCGoal = self:GetMyNPCGoal()
                self.NPCGoal = NPCGoal

            end
            if not IsValid( NPCGoal ) then return end

            render.SetMaterial( beamMat )
            render.DrawBeam( self:WorldSpaceCenter(), NPCGoal:GetPos(), 20, 1, 0, self.GoalLinkColor )

        end
    end
end

local doorOffset = Vector( 0, -120, 68 )
local policeOffset1 = Vector( -20, -160, 50 )
local policeOffset2 = Vector( 20, -160, 50 )

function ENT:SetupAPC( apc )
    local apcTargetName = "campaignents_apcnpc_" .. apc:GetCreationID()
    apc.campaignents_ApcDamageMul = self:GetAPCDamageMul()

    apc:SetKeyValue( "model", "models/combine_apc.mdl" )
    apc:SetKeyValue( "vehiclescript", "scripts/vehicles/apc_npc.txt" )

    apc:SetKeyValue( "targetname", apcTargetName )
    apc:SetKeyValue( "VehicleLocked", "1" )
    apc:SetKeyValue( "actionScale", "1" )

    apc:SetPos( self:GetPos() + -vector_up * 50 )
    apc:SetAngles( self:GetAngles() )
    apc:Spawn()
    apc:Activate()

    apc:DropToFloor()

    apc:SetMaxHealth( self:GetAPCHealth() )
    apc:SetHealth( self:GetAPCHealth() )

    self:SetProxyEnt( apc )

    if self:GetStatic() then return end

    local boneID = apc:LookupBone( "APC.Gun_Base" )
    local bonePos, _ = apc:GetBonePosition( boneID )

    local driver = ents.Create( "npc_apcdriver" )
    driver.DoNotDuplicate = true
    driver:SetPos( bonePos )
    driver:SetKeyValue( "Vehicle", apcTargetName )
    driver:SetParent( apc )
    driver:Spawn()
    driver:Activate()

    driver.fauxTask = "runover"
    driver.fauxTaskChangeTime = CurTime()

    apc.campaignents_ApcDriver = driver
    apc.doManhacks = self:GetDoManhacks()
    apc.policeLeft = self:GetPoliceCount()
    apc.policeSpawnCount = 0

    apc.canDrive = self:GetCanDrive()

    apc.nextForcedMissile = 0

    local idleGoal
    if apc.canDrive then
        driver.idleGoalName = "campaignents_apcgoal_chase_" .. self:GetCreationID()
        idleGoal = ents.Create( "path_corner" )
        apc:DeleteOnRemove( idleGoal )
        idleGoal.DoNotDuplicate = true
        idleGoal:SetKeyValue( "targetname", driver.idleGoalName )

    end

    local timerName = "campaignents_apc_runoverenemy" .. self:GetCreationID()
    timer.Create( timerName, 0.5, 0, function()
        if not IsValid( driver ) then timer.Remove( timerName ) return end
        if not IsValid( apc ) then timer.Remove( timerName ) return end
        if not IsValid( idleGoal ) then timer.Remove( timerName ) return end

        if apc:Health() <= 0 then
            apc:StopSound( "ambient/alarms/apc_alarm_loop1.wav" )
            return

        end

        local enemy = driver:GetEnemy()
        if not IsValid( enemy ) then return end

        local enemyPos = enemy:GetPos()
        -- hack!
        if not idleGoal.setToEnemysPos then
            idleGoal.setToEnemysPos = true
            idleGoal:SetPos( enemyPos )

        end

        local distToEnemySqr = apc:GetPos():DistToSqr( enemyPos )

        local fauxTask = driver.fauxTask
        local timeSinceChange = math.abs( driver.fauxTaskChangeTime - CurTime() )
        local newTask = nil

        local speed = apc:GetVelocity():Length()
        local moving = speed > 100
        local reallyNotMoving = speed < 10

        if fauxTask == "runover" then

            if not moving and apc.nextForcedMissile < CurTime() and apc:Health() < apc:GetMaxHealth() * 0.5 then
                newTask = "missilespam"
                apc:EmitSound( "ambient/alarms/apc_alarm_loop1.wav", 90 )

            elseif ( timeSinceChange > 20 and distToEnemySqr < 3000^2 and distToEnemySqr > 1000^2 ) or ( reallyNotMoving and timeSinceChange > 10 ) or ( reallyNotMoving and timeSinceChange > 2 and distToEnemySqr < 350^2 ) then
                newTask = "manhacks"
                apc:EmitSound( "ambient/alarms/apc_alarm_loop1.wav", 90 )

            elseif ( ( not moving and distToEnemySqr < 750^2 and timeSinceChange > 15 ) or ( reallyNotMoving and timeSinceChange > 5 ) ) and apc.policeLeft > 0 then
                newTask = "police"
                apc:EmitSound( "ambient/alarms/apc_alarm_loop1.wav", 90 )

            elseif apc.canDrive and ( apc.npcGoalGrace or 0 ) < CurTime() then
                driver:Fire( "GotoPathCorner", driver.idleGoalName, 0 )

                if driver:VisibleVec( enemyPos ) then
                    local toEnemy = ( enemyPos - apc:GetPos() ):GetNormalized()
                    toEnemy.z = 0
                    local offset = toEnemy * 350

                    local goalPos = enemyPos

                    if util.IsInWorld( goalPos + offset ) then
                        goalPos = enemyPos + offset
                        driver:Fire( "SetDriversMaxSpeed", 1 )
                        driver:Fire( "SetDriversMinSpeed", 0.45 )
                        apc.npcGoalGrace = CurTime() + 0.5

                    else
                        driver:Fire( "SetDriversMaxSpeed", 1 )
                        driver:Fire( "SetDriversMinSpeed", 0.35 )
                        apc.npcGoalGrace = CurTime() + 1

                    end

                    idleGoal:SetPos( goalPos )
                    idleGoal:SetAngles( enemy:GetAngles() )

                else
                    if IsValid( apc.campaignents_ApcFallbackCorner ) and apc:GetPos():DistToSqr( apc.campaignents_ApcFallbackCorner:GetPos() ) > 250^2 then
                        local fallbackCornerName = apc.campaignents_ApcFallbackCorner:GetName()

                        driver:Fire( "GotoPathCorner", fallbackCornerName, 0 )
                        driver:Fire( "SetDriversMaxSpeed", 0.75 )
                        driver:Fire( "SetDriversMinSpeed", 0.25 )

                    else
                        local toEnemy = ( enemyPos - apc:GetPos() ):GetNormalized()
                        local crossToEnemy = toEnemy:Cross( vector_up )
                        idleGoal:SetPos( enemyPos )
                        idleGoal:SetPos( apc:LocalToWorld( crossToEnemy * 400 ) )
                        driver:Fire( "SetDriversMaxSpeed", 0.75 )
                        driver:Fire( "SetDriversMinSpeed", 0.35 )
                        apc.npcGoalGrace = CurTime() + 2

                    end
                end
            end
        elseif fauxTask == "manhacks" then
            local maxTime = 2.5
            if distToEnemySqr < 450^2 then
                maxTime = 5

            end
            if timeSinceChange > maxTime then
                newTask = "runover"
                apc:StopSound( "ambient/alarms/apc_alarm_loop1.wav" )
            elseif timeSinceChange > 0.5 then
                local manhack = ents.Create( "npc_manhack" )
                manhack.DoNotDuplicate = true

                local hackSpawnPos = apc:LocalToWorld( doorOffset )

                SparkEffect( hackSpawnPos )

                manhack:SetPos( hackSpawnPos )
                manhack:Spawn()
                manhack:Activate()

                manhack:SetEnemy( enemy )
                manhack:Fire( "Break", 1, math.random( 30, 45 ) )

                apc:EmitSound( "npc/waste_scanner/grenade_fire.wav", 80, math.random( 100, 120 ), CHAN_STATIC )

                timer.Simple( 0, function()
                    if not IsValid( manhack ) then return end
                    if not IsValid( apc ) then return end
                    local obj = manhack:GetPhysicsObject()
                    if not obj and obj.IsValid and obj:IsValid() then return end
                    obj:ApplyForceCenter( ( manhack:GetPos() - apc:GetPos() ):GetNormalized() * math.random( 2000, 3000 ) )

                    manhack:SetSaveValue( "m_hTargetEnt", enemy )
                    manhack:SetSchedule( SCHED_TARGET_CHASE )

                end )
            end
            if moving and apc.canDrive and apc:Health() >= apc:GetMaxHealth() * 0.5 then
                driver:Fire( "SetDriversMaxSpeed", 0 )
                driver:Fire( "SetDriversMinSpeed", 0 )
                driver:Fire( "Stop" )

            end
        elseif fauxTask == "missilespam" then
            if timeSinceChange > 3 then
                newTask = "runover"
                apc:StopSound( "ambient/alarms/apc_alarm_loop1.wav" )
                apc.nextForcedMissile = CurTime() + 8
            elseif timeSinceChange > 0.5 then
                if apc.nextForcedMissile < CurTime() then
                    driver:SetSchedule( SCHED_RANGE_ATTACK2 )

                end
            end

            driver:Fire( "SetDriversMaxSpeed", 0.2 )
            driver:Fire( "SetDriversMinSpeed", 0.1 )

        elseif fauxTask == "police" then
            if timeSinceChange > 8 then
                newTask = "runover"
                apc.policeSpawnCount = 0
                apc:StopSound( "ambient/alarms/apc_alarm_loop1.wav" )
            elseif timeSinceChange > 1 and apc.policeLeft > 0 and apc.policeSpawnCount < 2 and ( apc.nextPolice or 0 ) < CurTime() then
                apc.policeLeft = apc.policeLeft + -1
                apc.nextPolice = CurTime() + 3
                apc.policeSpawnCount = apc.policeSpawnCount + 1

                local police = ents.Create( "npc_metropolice" )
                police.DoNotDuplicate = true

                local policeOffset = policeOffset1
                if ( apc.policeSpawnCount % 2 ) == 1 then
                    policeOffset = policeOffset2

                end

                local policePos = apc:LocalToWorld( policeOffset )
                police:SetPos( policePos )

                police:SetKeyValue( "weapondrawn", 1 )
                police:SetKeyValue( "additionalequipment", "weapon_pistol" )
                police:SetEnemy( enemy )

                police:Spawn()
                police:Activate()

                police:DropToFloor()

                timer.Simple( 0.1, function()
                    if not IsValid( police ) then return end
                    if not IsValid( apc ) then return end
                    police:SetSaveValue( "m_hTargetEnt", enemy )
                    police:SetSchedule( SCHED_TARGET_CHASE )

                end )

            end
            if moving and apc.canDrive then
                driver:Fire( "SetDriversMaxSpeed", 0 )
                driver:Fire( "SetDriversMinSpeed", 0 )
                driver:Fire( "Stop" )

            end
        end

        if newTask and newTask ~= fauxTask then
            driver.fauxTaskChangeTime = CurTime()
            driver.fauxTask = newTask

        end
    end )
end

hook.Add( "EntityTakeDamage", "campaignents_apcdamagemul", function( _, damageInfo )
    local attacker = damageInfo:GetAttacker()
    if not IsValid( attacker ) then return end

    local dmgMul = attacker.campaignents_ApcDamageMul
    if not dmgMul then return end

    damageInfo:ScaleDamage( dmgMul )

end )
