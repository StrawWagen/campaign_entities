AddCSLuaFile()

ENT.Type = "anim"
if WireLib then
    ENT.Base = "base_wire_entity"

else
    ENT.Base = "base_gmodentity" -- :(

end

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Thing Respawner"
ENT.Author      = "Initially coded by gpt-4, completely reworked by straw"
ENT.Purpose     = "Spawns a new thing if the previous one is removed."
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.isCampaignEntsRespawner = true
ENT.Editable    = true
ENT.DefaultModel = "models/props_c17/oildrum001_explosive.mdl"
ENT.Material = "models/shadertest/shader5"
ENT.CanCopy = true -- can copy the data of stuff

ENT.entsToWaitFor = {}

local function bearingToPos( pos1, ang1, pos2, ang2 )
    local localPos = WorldToLocal( pos1, ang1, pos2, ang2 )
    local bearing = 180 / math.pi * math.atan2( localPos.y, localPos.x )

    return bearing

end

-- only works on players!
local function EntIsLookingAtEnt( looker, lookedAt )
    if math.abs( bearingToPos( lookedAt:GetPos(), looker:EyeAngles(), looker:GetPos(), looker:EyeAngles() ) ) < 90 then return true end
    return nil

end

local function hitAnythingButPlacers( ent )
    if ent.isCampaignEntsRespawner then return false end
    return true

end

function ENT:DoIdNotify()
    self:NetworkVarNotify( "MyId", function( _, _, old, new )
        if not SERVER then return end
        if not IsValid( self ) then return end

        if self:GetCreationTime() + 1 < CurTime() and not self.hasSaidWeChangedName then
            local MSG

            if new > -1 then
                MSG = "My Id is " .. new .. "!"
            else
                MSG = "I dont have an id anymore"

            end
            campaignents_MessageOwner( self, MSG )
        end

        -- it prints twice???? i dont want to find out why, this hack works fine
        self.hasSaidWeChangedName = true
        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self.hasSaidWeChangedName = nil

            if new > -1 then
                self:FindAndManageOthersThatShouldDependOnMe( old, self:GetMyId() )

            end
        end )
    end )

    self:NetworkVarNotify( "IdToWaitFor", function( _, _, _, new )
        if not SERVER then return end
        if not IsValid( self ) then return end

        if not self.hasSaidWeChangedWaitFor then
            self:FindAndManageWithThisId( new )

        end

        self.hasSaidWeChangedWaitFor = true
        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self.hasSaidWeChangedWaitFor = nil

        end )
    end )
end

function ENT:DoDefaultVariables()
    self:SetModelToSpawn( self.DefaultModel )
    self:SetClassToSpawn( "prop_physics" )
    self:SetNPCWeapon( "" )
    self:SetDropToFloor( true )

    self:SetNeedToLookAway( true )
    self:SetOn( true )

    self:SetMaxToSpawn( -1 )
    self:SetMinSpawnInterval( 15 )
    self:SetSpawnRadiusStart( 0 )
    self:SetSpawnRadiusEnd( 32000 )

    self:SetMyId( -1 )
    self:SetIdToWaitFor( -1 )

    self:SetGoalID( -1 )
    self:SetShowGoalLinks( true )

end

function ENT:SetupDataTables()
    local i = 1
    self:NetworkVar( "String",  0, "ModelToSpawn",       { KeyName = "modeltospawn",        Edit = { order = i, type = "String",        category = "Thing spawned", waitforenter = true } } )
    self:NetworkVar( "String",  1, "ClassToSpawn",       { KeyName = "classtospawn",        Edit = { order = i + 1, type = "String",    category = "Thing spawned", waitforenter = true } } )
    self:NetworkVar( "String",  2, "NPCWeapon",          { KeyName = "weaponclass",         Edit = { order = i + 1, type = "String",    category = "Thing spawned", waitforenter = true } } )
    self:NetworkVar( "Bool",    5, "DropToFloor",        { KeyName = "droptofloor",         Edit = { order = i + 1, type = "Bool",      category = "Thing spawned" } } )
    self:NetworkVar( "Bool",    6, "NoAutoModel",        { KeyName = "noautomodel",         Edit = { order = i + 1, type = "Bool",      category = "Thing spawned", title = "Disable NPC model Auto-Detect?" } } )

    self:NetworkVar( "Bool",    1, "NeedToLookAway",     { KeyName = "needtolookaway",      Edit = { order = i + 1, type = "Bool",      category = "Generic conditions" } } )
    self:NetworkVar( "Bool",    2, "On",                 { KeyName = "on",                  Edit = { readonly = true } } ) -- wire inputs internal
    self:NetworkVar( "Bool",    3, "ForceSpawn",         { KeyName = "forcespawn",          Edit = { readonly = true } } ) -- wire inputs internal
    self:NetworkVar( "Int",     1, "MaxToSpawn",         { KeyName = "maxtospawn",          Edit = { order = i + 1, type = "Int",       min = -1, max = 120, category = "Generic conditions" } } )
    self:NetworkVar( "Int",     2, "MinSpawnInterval",   { KeyName = "minspawninterval",    Edit = { order = i + 1, type = "Int",       min = 0, max = 240, category = "Generic conditions" } } )
    self:NetworkVar( "Int",     3, "SpawnRadiusStart",   { KeyName = "spawnradiusstart",    Edit = { order = i + 1, type = "Int",       min = 0, max = 32000, category = "Generic conditions" } } )
    self:NetworkVar( "Int",     4, "SpawnRadiusEnd",     { KeyName = "spawnradiusend",      Edit = { order = i + 1, type = "Int",       min = 0, max = 32000, category = "Generic conditions" } } )

    self:NetworkVar( "Int",     5, "MyId",               { KeyName = "myid",                Edit = { order = i + 1, type = "Int",       min = -1, max = 1000, category = "Id conditions", waitforenter = true } } )
    self:NetworkVar( "Int",     6, "IdToWaitFor",        { KeyName = "idtowaitfor",         Edit = { order = i + 1, type = "Int",       min = -1, max = 1000, category = "Id conditions", waitforenter = true } } )

    self:NetworkVar( "Int",     7, "GoalID",             { KeyName = "goalid",              Edit = { order = i + 1, type = "Int",       min = -1, max = 1000, category = "NPC Goal", waitforenter = true } } )
    self:NetworkVar( "Bool",    4, "ShowGoalLinks",      { KeyName = "forcespawn",          Edit = { order = i + 1, type = "Bool",      category = "NPC Goal" } } )

    if SERVER then
        self:DoDefaultVariables()

    end

    self:NetworkVarNotify( "ClassToSpawn", function()
        if not SERVER then return end
        if not IsValid( self ) then return end
        SafeRemoveEntity( self.campaignents_Thing )
        self.nextThingSpawn = CurTime()
        self.nextSpawningThink = CurTime()
        self.doASimpleSpawn = true

    end )

    self:NetworkVarNotify( "ModelToSpawn", function( _, _, _, new )
        if not IsValid( self ) then return end
        if self.IsCyclicSetModel then return end
        self:DoModel( new )

    end )

    self:NetworkVarNotify( "NPCWeapon", function()
        if not IsValid( self ) then return end
        SafeRemoveEntity( self.campaignents_Thing )
        self.nextThingSpawn = CurTime()
        self.nextSpawningThink = CurTime()
        self.doASimpleSpawn = true

    end )

    self:NetworkVarNotify( "GoalID", function( _, _, _, _ )
        if not CLIENT then return end
        if not IsValid( self ) then return end

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            campaignents_DoBeamColor( self )

        end )
    end )

    self:DoIdNotify()

end

function ENT:SpawnFunction( spawner, tr )
    local originalPos = tr.HitPos
    local distUp = 120
    local spawnPos = originalPos + vector_up * distUp
    local ent = ents.Create( self.ClassName )
    ent:SetPos( spawnPos )

    if IsValid( spawner ) and spawner.GetAimVector then
        local dir = -spawner:GetAimVector()
        local ang = dir:Angle()
        local newAng = Angle( 0, ang.y, 0 )
        ent:SetAngles( newAng )

    end

    ent:Spawn()
    ent:Activate()
    local effectdata = EffectData()
    effectdata:SetEntity( ent )
    util.Effect( "propspawn", effectdata )

    local activeWep = spawner:GetActiveWeapon()
    local justToolGunned = activeWep and activeWep:GetClass() == "gmod_tool" and spawner:GetTool():GetMode() == "creator" and spawner:KeyDown( IN_ATTACK )

    if justToolGunned and IsValid( tr.Entity ) and ent.CanCopy then
        -- certiancopy, did the player 100% mean for this to copy?
        local canCopy, certianCopy = ent:CanAutoCopyThe( tr.Entity )
        if canCopy then

            distUp = math.Clamp( tr.Entity:GetModelRadius(), 25, 160 )
            spawnPos = originalPos + vector_up * distUp
            ent:SetPos( spawnPos )

            timer.Simple( 0, function()
                if not IsValid( ent ) then return end
                if not IsValid( tr.Entity ) then return end
                ent:CaptureCollidersInfo( tr.Entity )
                ent:SetAngles( tr.Entity:GetAngles() )

                campaignents_MessageOwner( ent, "Autocopied!" )

                if not certianCopy then return end
                SafeRemoveEntity( tr.Entity )

            end )
        end
    end

    return ent

end

function ENT:CanAutoCopyThe( the )
    return IsValid( the ), false

end

function ENT:ResetVars()
    self.campaignents_ThingRespawner = true
    self.spawnedFirstThing = nil
    self.aiWasDisabled = nil
    self.nextSpawningThink = 0
    self.nextThingSpawn = 0
    self.spawnedCount = 0

    if not WireLib then return end
    Wire_TriggerOutput( self, "SpawnedCount", self.spawnedCount )

end

function ENT:Initialize()
    self:AdditionalInitialize()

    if SERVER then
        self:SetModel( self.DefaultModel )
        campaignents_doFadeDistance( self, 3500 )
        self.OldModel = self.DefaultModel
        self:SetMaterial( self.Material )
        self:DrawShadow( false )

        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetMoveType( MOVETYPE_FLY )
        self:SetCollisionGroup( COLLISION_GROUP_WORLD )

        self:SetCustomCollisionCheck( true )

        campaignEnts_EasyFreeze( self )

        self:ResetVars()

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:DoModel()
            self:SelfSetup()

        end )

        if not WireLib then return end

        self.Inputs = WireLib.CreateSpecialInputs( self, { "ForceSpawn", "On" }, { "NORMAL", "NORMAL" } )
        self.Outputs = WireLib.CreateSpecialOutputs( self, { "Spawned", "SpawnedCount" }, { "ENTITY", "NORMAL" } )

    else
        campaignents_DoBeamColor( self )

    end
end

hook.Add( "ShouldCollide", "campaignents_respawnersdontcollide", function( ent1, ent2 )
    if ent1.isCampaignEntsRespawner or ent2.isCampaignEntsRespawner then
        if ent2:IsPlayer() then return end -- physgunning it!
        return false

    end
end )

function ENT:AdditionalInitialize()
end

function ENT:TriggerInput( iname, value )
    if iname == "On" then
        if value >= 1 then
            self:SetOn( true )
            self:NextThink( CurTime() + 0.01 )

        else
            self:SetOn( false )
            self:NextThink( CurTime() + 0.01 )

        end
    elseif iname == "ForceSpawn" then
        if value >= 1 then
            self:SetForceSpawn( true )
            self:NextThink( CurTime() + 0.01 )

        else
            self:SetForceSpawn( false )
            self:NextThink( CurTime() + 0.01 )

        end
    end
end

local nextRespawnerMessage = 0
function ENT:SelfSetup()
    if self.duplicatedIn then return end
    if nextRespawnerMessage > CurTime() then return end
    if campaignents_EnabledAi() then
        local MSG = "Noclip and look up!\nI spawn stuff in! Check my context menu!!\nDrag me into something to \"copy\" it!\nIf 'need to look away' is set, I'll only spawn stuff behind your back!"
        campaignents_MessageOwner( self, MSG )
        timer.Simple( 0, function()
            MSG = "Change 'maxtospawn' and I'll eventually stop spawning stuff!\nThe radius settings change how far before I spawn!\nThis message will not appear when duped in."
            campaignents_MessageOwner( self, MSG )
        end )

        nextRespawnerMessage = CurTime() + 25

    end
end

function ENT:OnDuplicated()
    self:ResetVars()
    self.duplicatedIn = true

end

function ENT:DoModel( new )
    if not new then return end
    if self:GetModel() == new then return end
    -- reset the text if invalid model
    if not util.IsValidModel( new ) then
        if not SERVER then return end
        timer.Simple( 0.05, function()
            if not IsValid( self ) then return end
            self.IsCyclicSetModel = true
            -- inf loop
            self:SetModelToSpawn( self.OldModel )
            self.IsCyclicSetModel = nil

        end )
        return

    end
    -- wow valid model!
    self.OldModel = self:GetModel()
    self:SetModel( new )

end

function ENT:GetMyNPCGoals()
    if not self.GetGoalID then return end
    if self:GetGoalID() <= -1 then return end

    local matchingGoals = {}

    local goals = ents.FindByClass( "campaignents_npcgoal" )
    for _, potentialGoal in ipairs( goals ) do
        if potentialGoal:GetGoalID() == self:GetGoalID() then
            table.insert( matchingGoals, potentialGoal )

        end
    end
    return matchingGoals

end

function ENT:IfGoalMakeSpawnedGoThere()
    if not self.GetGoalID then return end --backwards compat

    local potentialNPC = self.campaignents_Thing
    if not IsValid( potentialNPC ) then return end
    if not potentialNPC:IsNPC() then return end

    local goals = self:GetMyNPCGoals()

    if not goals or #goals < 1 then return end

    for _, goal in ipairs( goals ) do
        goal:ManageNPC( self.campaignents_Thing )

    end
end

function ENT:SetEntsModelComprehensive( ent, model )
    local keys = ent:GetKeyValues()
    if keys["model"] then
        ent:SetKeyValue( self:GetModelToSpawn() )

    end
    ent:SetModel( model )

end

function ENT:SpawnThing()
    local modelRad = self:GetModelRadius()
    local downOffset
    if not self.GetDropToFloor or ( self.GetDropToFloor and self:GetDropToFloor() == true ) then
        downOffset = math.max( modelRad * 4, 250 )

    else
        downOffset = 1

    end

    local simpleDownTrace = util.QuickTrace( self:GetPos(), -vector_up * downOffset, hitAnythingButPlacers )
    local offsetOffGround = simpleDownTrace.HitNormal * 5
    local posToSetTo = simpleDownTrace.HitPos + offsetOffGround
    local classToSpawn = self:GetClassToSpawn()

    local sentsTable =  scripted_ents.GetStored( classToSpawn )
    local newThing = nil

    local defaultPly = Entity( 1 )
    if sentsTable and sentsTable.SpawnFunction and IsValid( defaultPly ) then
        newThing = sentsTable:SpawnFunction( defaultPly, simpleDownTrace, classToSpawn )
        self:SetEntsModelComprehensive( newThing, self:GetModelToSpawn() )

        newThing:SetAngles( self:GetAngles() )
        didSpawnFunc = true

    else
        newThing = ents.Create( classToSpawn )
        if not IsValid( newThing ) then return end
        newThing:SetPos( posToSetTo )
        -- set model before finished spawning so npc's Spawn can override it, if it wants
        self:SetEntsModelComprehensive( newThing, self:GetModelToSpawn() )

        local ang = self:GetAngles()
        -- ik breaks if i dont do this
        if newThing.IsNPC and newThing:IsNPC() then
            ang.p = 0
            ang.r = 0

        end
        newThing:SetAngles( ang )

        newThing:Spawn()
        newThing:Activate()

    end

    -- check after it spawned, stuff like npcs override their model, so we follow!
    if newThing:GetModel() ~= self:GetModelToSpawn() then
        -- config says it NEEDS to be this model!
        if self:GetNoAutoModel() then
            timer.Simple( 0, function()
                if not IsValid( self ) then return end
                if not IsValid( newThing ) then return end
                self:SetEntsModelComprehensive( newThing, self:GetModelToSpawn() )
                -- dont fall thru displacements!
                newThing:SetPos( posToSetTo + offsetOffGround * 4 )

            end )
        else
            self:SetModelToSpawn( newThing:GetModel() )

        end
    end

    if self:GetDropToFloor() then
        newThing:DropToFloor()

    end

    if self:GetNPCWeapon() and newThing.Give then
        newThing:Give( self:GetNPCWeapon() )

    end
    newThing.DoNotDuplicate = true

    self:CallOnRemove( "campaignEnts_killChildEnts", function( _, spawnedThing )
        if not IsValid( spawnedThing ) then return end
        -- crash fix related to spawning airboats!
        spawnedThing:Fire( "KillHierarchy" )
        SafeRemoveEntityDelayed( spawnedThing, 0 )

    end, newThing )
    self.campaignents_Thing = newThing
    self.spawnedCount = self.spawnedCount + 1

    -- let them edit the goal before we ask it to set itself up!
    if not campaignents_EnabledAi() then
        self.doDelayedMakeSpawnedGotoGoals = true

    else
        self:IfGoalMakeSpawnedGoThere()

    end

    self:AdditionalSpawnStuff( newThing )

    if not WireLib then return end
    Wire_TriggerOutput( self, "SpawnedCount", self.spawnedCount )
    Wire_TriggerOutput( self, "Spawned", newThing )

end

function ENT:BlockGoodSpawn()
end

function ENT:IsGoodSpawn( ignoreBearing )

    if self:GetOn() ~= true then return end
    if self:BlockGoodSpawn() == true then return end

    local forcedSpawn = self.GetForceSpawn and self:GetForceSpawn()
    if forcedSpawn then return true end

    local tooClose = nil
    local somebodyCloseEnough = nil
    local someoneIsLooking = nil
    local dobearingCheck = self:GetNeedToLookAway() and not ignoreBearing
    local minDistSqr = self:GetSpawnRadiusStart() ^ 2
    local maxDistSqr = self:GetSpawnRadiusEnd() ^ 2
    if minDistSqr == 0 and maxDistSqr == 0 then return false end -- dont waste perf!

    for _, ply in ipairs( player.GetAll() ) do
        if dobearingCheck and EntIsLookingAtEnt( ply, self ) then
            someoneIsLooking = true
            break

        end
        local distToPlySqr = ply:GetPos():DistToSqr( self:GetPos() )
        if distToPlySqr < minDistSqr then
            tooClose = true
            break

        end
        if distToPlySqr < maxDistSqr then
            somebodyCloseEnough = true

        end
    end

    local goodSpawn = not someoneIsLooking and not tooClose and somebodyCloseEnough
    return goodSpawn

end

local printedMessage = nil

function ENT:Think()
    if not SERVER then return end
    local enabledAi = campaignents_EnabledAi()

    if self:IsPhysgunPickedUp() then
        if self.CanCopy then
            if not printedMessage then
                printedMessage = true
                campaignents_MessageOwner( self, "Thing Respawner: Drag me into something so i can maybe copy their settings!" )

            end
            self:CaptureCollidersInfo()

        end
        campaignents_captureGoalID( self )

    end

    -- upon ai enabling, despawn our thing, and reset our spawn count, so you can test without making tons of useless saves
    if self.aiWasDisabled and enabledAi then
        self.spawnedFirstThing = nil
        self.aiWasDisabled = nil
        self.spawnedCount = 0
        self.nextSpawningThink = 0
        SafeRemoveEntity( self.campaignents_Thing )

        if WireLib then
            Wire_TriggerOutput( self, "SpawnedCount", self.spawnedCount )

        end
    elseif not self.aiWasDisabled and not enabledAi then
        self.aiWasDisabled = true

    end

    if self.doDelayedMakeSpawnedGotoGoals and enabledAi then
        self.doDelayedMakeSpawnedGotoGoals = nil
        self:IfGoalMakeSpawnedGoThere()

    end

    -- if player is doing editing then we dont care about the limit
    if self:GetMaxToSpawn() > 0 and self.spawnedCount >= self:GetMaxToSpawn() and enabledAi then return end
    local forcedSpawn = self.GetForceSpawn and self:GetForceSpawn()

    if self.nextSpawningThink > CurTime() and not forcedSpawn then return end

    if #self.entsToWaitFor >= 1 then
        for _, waiting in ipairs( self.entsToWaitFor ) do
            if waiting.spawnedCount <= 0 then return end

        end
    end

    if not self.spawnedFirstThing or self.doASimpleSpawn then
        -- initial spawn
        self.spawnedFirstThing = true
        -- simple spawn is just for the editing callbacks
        self.doASimpleSpawn = nil
        -- ply spawned it from spawnmenu, or save just loaded, bypass fov check
        local goodSpawn = self:IsGoodSpawn( true )
        if goodSpawn then
            self:SpawnThing()

        end
        return

    end

    local time = 1
    if not IsValid( self.campaignents_Thing ) and ( self.nextThingSpawn < CurTime() or forcedSpawn ) then
        local goodSpawn = self:IsGoodSpawn( false )
        if goodSpawn then
            self:SpawnThing()
            time = self:GetMinSpawnInterval()
            self.nextThingSpawn = CurTime() + time

        end
    elseif IsValid( self.campaignents_Thing ) then
        time = self:GetMinSpawnInterval()
        self.nextThingSpawn = CurTime() + time

    end
    self.nextSpawningThink = CurTime() + 1

end



if CLIENT then

    local hintMatId = surface.GetTextureID( "effects/yellowflare" )
    local hintColor = Color( 255, 255, 255, 255 )
    local tooFar = 300^2

    function ENT:DrawOriginHint()
        local myPos = self:GetPos()
        if myPos:DistToSqr( LocalPlayer():GetPos() ) > tooFar then return end
        local pos2d = myPos:ToScreen()

        local size = 25

        local width = size
        local height = size

        local halfWidth = width / 2
        local halfHeight = height / 2

        local texturedQuadStructure = {
            texture = hintMatId,
            color   = hintColor,
            x 	= pos2d.x + -halfWidth,
            y 	= pos2d.y + -halfHeight,
            w 	= width,
            h 	= height
        }

        cam.Start2D()
            draw.TexturedQuad( texturedQuadStructure )
        cam.End2D()

    end
    local beamMat = Material( "sprites/physbeama" )

    function ENT:Draw()
        if campaignents_IsEditing() then
            self:DrawModel()
            self:DrawOriginHint()
            if not self:GetShowGoalLinks() then return end

            local nextNPCGoalCheck = self.nextNPCGoalCheck or 0
            local NPCGoals = self.NPCGoals
            if nextNPCGoalCheck < CurTime() then
                self.nextNPCGoalCheck = CurTime() + 0.75

                NPCGoals = self:GetMyNPCGoals()
                self.NPCGoals = NPCGoals

            end
            if not NPCGoals or #NPCGoals < 1 then return end

            for _, goal in ipairs( NPCGoals ) do
                if not IsValid( goal ) then continue end
                render.SetMaterial( beamMat )
                render.DrawBeam( self:GetPos(), goal:GetPos(), 20, 1, 0, self.GoalLinkColor )

            end
        end
    end
end

function ENT:CaptureCollidersInfo( theHit )
    if not IsValid( theHit ) then
        local simpleCollider = util.QuickTrace( self:GetPos(), vector_up * 1, hitAnythingButPlacers )

        theHit = simpleCollider.Entity

    end

    if not IsValid( theHit ) then return end

    if theHit == self.campaignents_Thing then return end
    if theHit == self.lastInfoCaptured then return end

    self.lastInfoCaptured = theHit
    self:EmitSound( "buttons/button14.wav" )

    self:SetClassToSpawn( theHit:GetClass() )
    self:SetModelToSpawn( theHit:GetModel() )
    if theHit.Give then
        local weap = theHit:GetActiveWeapon()
        if not IsValid( weap ) then return end
        self:SetNPCWeapon( weap:GetClass() )

    end
end

function ENT:FindAndManageWithThisId( targetId )

    if targetId <= 0 and self:GetCreationTime() + 1 < CurTime() then
        local MSG = "Not waiting for anything!"
        campaignents_MessageOwner( self, MSG )

        self.entsToWaitFor = {}

        return

    end

    local entsToWaitFor = {}
    local everything = ents.GetAll()
    for _, potentialRespawner in ipairs( everything ) do
        if potentialRespawner.campaignents_ThingRespawner then
            local respawnerId = potentialRespawner:GetMyId()
            if respawnerId == "" then continue end
            if respawnerId <= -1 then continue end
            if respawnerId == targetId then
                table.insert( entsToWaitFor, potentialRespawner )

            end
        end
    end

    self.entsToWaitFor = entsToWaitFor

    if self:GetCreationTime() + 1 > CurTime() then return end

    local MSG = "Waiting for " .. #entsToWaitFor .. " other respawners with id " .. targetId .. " to have all spawned at least 1 thing."
    campaignents_MessageOwner( self, MSG )

end

function ENT:FindAndManageOthersThatShouldDependOnMe( myOldId, myId )

    if myId <= -1 then
        return

    end

    -- blegh
    local everythingElse = ents.GetAll()
    for _, potentialRespawner in ipairs( everythingElse ) do
        if potentialRespawner.GetIdToWaitFor then
            local respawnerWaitingId = potentialRespawner:GetIdToWaitFor()
            if respawnerWaitingId == "" then continue end
            if respawnerWaitingId == myId or respawnerWaitingId == myOldId then
                potentialRespawner:FindAndManageWithThisId( respawnerWaitingId )

            end
        end
    end
end

function ENT:AdditionalSpawnStuff( spawned )
    local class = spawned:GetClass()

    if class == "npc_combine_s" and math.random( 1, 100 ) > 50 then
        spawned:SetKeyValue( "NumGrenades", 2 )

    end
end

function ENT:IsPhysgunPickedUp()
    local pickerUpper = self.campaignents_PickerUpper
    if not IsValid( pickerUpper ) then return end
    if not pickerUpper:KeyDown( IN_ATTACK ) then return end

    local actWep = pickerUpper:GetActiveWeapon()
    if not IsValid( actWep ) then return end
    if actWep:GetClass() ~= "weapon_physgun" then return end

    return true

end

hook.Add( "PhysgunPickup", "campaignents_respawner_pickedup", function( picker, picked ) 
    if not picked.isCampaignEntsRespawner then return end

    picked.campaignents_PickerUpper = picker

end )

hook.Add( "PhysgunDrop", "campaignents_respawner_dropped", function( dropper, dropped )
    if not dropped.isCampaignEntsRespawner then return end

    dropped.campaignents_PickerUpper = nil

end )