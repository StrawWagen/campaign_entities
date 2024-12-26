AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "NPC Combat 'Node'"
ENT.Author      = "straw wage"
ENT.Purpose     = "Makes NPCs with enemies, that aren't moving, path to it."
ENT.Spawnable   = true
ENT.AdminOnly   = true

if not SERVER then return end

ENT.DefaultModel = "models/props_phx/games/chess/white_dama.mdl"

local CurTime = CurTime

local shootinMask = MASK_SHOT
local movementGroup = COLLISION_GROUP_NPC

local function PosCanSee( startPos, endPos, filter )
    if not startPos then return end
    if not endPos then return end

    mask = mask or shootinMask

    local trData = {
        start = startPos,
        endpos = endPos,
        mask = mask,
        filter = filter
    }
    local trace = util.TraceLine( trData )
    return not trace.Hit, trace

end

local function IsntBlocked( startPos, endPos, filter )
    if not startPos then return end
    if not endPos then return end

    local trData = {
        start = startPos,
        endpos = endPos,
        collisiongroup = movementGroup,
        filter = filter
    }
    local trace = util.TraceLine( trData )
    return not trace.Hit, trace

end

local cachedScale = 0
local nextCache = 0

local function lagScale()
    if nextCache > CurTime() then return cachedScale end

    local simTime = physenv.GetLastSimulationTime() * 1000
    nextCache = CurTime() + 0.01

    if simTime < 0.1 then
        cachedScale = 1

    elseif simTime < 0.15 then
        cachedScale = 1.5

    elseif simTime < 0.2 then
        cachedScale = 2

    elseif simTime >= 0.25 then
        cachedScale = 3

    end
    return cachedScale

end

local math_Rand = math.Rand

local function randScaled( min, max )
    return math_Rand( min, max ) * lagScale()

end

local function CanSeeOrHitNpc( startPos, endPos, filter, mask )
    local noHit, trace = PosCanSee( startPos, endPos, filter, mask )
    if noHit then return true end
    if IsValid( trace.Entity ) and trace.Entity:IsNPC() then return true end
    return false

end

function ENT:SetupSessionVars()
    self.nextFindNearby = 0
    self.stuffNearby = nil

end

local defaultMat = "models/weapons/v_slam/new light2"
local blockedMat = "models/weapons/v_slam/new light1"

function ENT:Initialize()
    if SERVER then
        self:SetModel( self.DefaultModel )
        self:SetNoDraw( false )
        self:DrawShadow( false )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_WORLD )
        self:SetMaterial( defaultMat )

        self:SetupSessionVars()

        CAMPAIGN_ENTS.doFadeDistance( self, 3000 )
        CAMPAIGN_ENTS.StartUglyHiding( self )
        CAMPAIGN_ENTS.EasyFreeze( self )

        self.PersonalNextTimes = {}

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:SelfSetup()

        end )
    end
end

local nextMessage = 0
function ENT:SelfSetup()
    if self.duplicatedIn then return end
    if nextMessage > CurTime() then return end

    if CAMPAIGN_ENTS.EnabledAi() then
        local MSG = "I give NPCS in combat, somewhere to move to, even if there's no AI nodes!\nPlace me behind cover, in the open, npcs will use me with intent!"
        CAMPAIGN_ENTS.MessageOwner( self, MSG )
        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            MSG = "Spawn a big plate, put it high up, and spam copies of me on it, to see a demo!\nThis will not appear when duped in."
            CAMPAIGN_ENTS.MessageOwner( self, MSG )

        end )

        nextMessage = CurTime() + 25

    end
end

function ENT:OnDuplicated()
    self.duplicatedIn = true
    self:SetupSessionVars()

end

local debugging = CreateConVar( "campaignents_debug_combatnode", "0", FCVAR_NONE, "Enable developer 1 info for combat nodes" )

local debuggingBool = debugging:GetBool()
cvars.AddChangeCallback( "campaignents_debug_combatnode", function( _, _, new )
    debuggingBool = tobool( new )

end, "campaignents_detectchange" )

local vector_up = Vector( 0, 0, 1 )

local blockedCheckOffset = vector_up * 25
local blockedCheckMaxs = Vector( 10, 10, 2 )
local blockedCheckMins = Vector( -10, -10, 1 )

local red = Color( 255, 0, 0 )
local green = Color( 0, 255, 0 )
local white = Color( 255, 255, 255 )

local myClass = "campaignents_combatnode"
local shareFindResultsDist = 200
local pathDistNoAiNodes = 500
local findAllDist = pathDistNoAiNodes + shareFindResultsDist

pathDistNoAiNodes = pathDistNoAiNodes^2
shareFindResultsDist = shareFindResultsDist^2

local entMeta = FindMetaTable( "Entity" )
local GetClass = entMeta.GetClass
local game_GetWorld = game.GetWorld

local npcMeta = FindMetaTable( "NPC" )

function ENT:Think()
    if not SERVER then return end

    local myTbl = self:GetTable()

    local myPos = entMeta.GetPos( self )
    local nextFindNearby = myTbl.nextFindNearby or 0
    local stuffNearby = myTbl.stuffNearby
    if not game_GetWorld( myPos ) then
        myTbl.OnBlocked( self, game_GetWorld() )
        return true

    end

    local trStruc = {
        start = myPos + blockedCheckOffset,
        endpos = myPos,
        filter = self,
        collisiongroup = movementGroup,
        maxs = blockedCheckMaxs,
        mins = blockedCheckMins,

    }
    local blockedCheck = util.TraceHull( trStruc )
    if blockedCheck.Hit or blockedCheck.StartSolid then
        myTbl.OnBlocked( self, blockedCheck.Entity )
        return true

    end

    if myTbl.fixColor then
        myTbl.fixColor = nil
        entMeta.SetColor( self, white )
        entMeta.SetMaterial( self, defaultMat )

    end

    if not stuffNearby or nextFindNearby < CurTime() then
        myTbl.nextFindNearby = CurTime() + randScaled( 2, 4 )
        stuffNearby = ents.FindInSphere( myPos, findAllDist )
        myTbl.stuffNearby = stuffNearby

        -- save on FindInSpheres by sharing our results with neighbors
        for _, potentialNode in ipairs( stuffNearby ) do
            if IsValid( potentialNode ) and GetClass( potentialNode ) == myClass and entMeta.GetPos( potentialNode ):DistToSqr( myPos ) < shareFindResultsDist then
                potentialNode.stuffNearby = myTbl.stuffNearby
                potentialNode.nextFindNearby = CurTime() + randScaled( 2, 4 )

            end
        end
    end

    local didSomething
    local isFighting
    local operatedOnNpc
    local nextTimes = myTbl.PersonalNextTimes
    local cur = CurTime()

    for _, currThing in ipairs( stuffNearby ) do
        -- make sure its a normal npc that was constructed by someone who is sane.
        if IsValid( currThing ) then
            local normalNpc = currThing.campaignents_combatNodeNormalNpc
            if normalNpc == nil then
                normalNpc = currThing:IsNPC() and currThing.SetSchedule and currThing.GetMoveVelocity
                currThing.campaignents_combatNodeNormalNpc = normalNpc

            end
            if normalNpc then
                local nextTime = nextTimes[currThing]

                if currThing:GetPos():DistToSqr( myPos ) < pathDistNoAiNodes and ( not nextTime or nextTime < cur ) then
                    local result = self:ManageNPC( currThing )
                    didSomething = didSomething or result
                    isFighting = isFighting or ( currThing.GetEnemy and IsValid( currThing:GetEnemy() ) )
                    operatedOnNpc = true

                end
            end
        end
    end
    -- op tem is ation
    if not operatedOnNpc then
        entMeta.NextThink( self, CurTime() + randScaled( 8, 16 ) )
        return true

    end
    if not isFighting then
        entMeta.NextThink( self, CurTime() + randScaled( 4, 8 ) )
        return true

    end
    if not didSomething then
        entMeta.NextThink( self, CurTime() + randScaled( 0.25, 1.5 ) )
        return true

    end

    entMeta.NextThink( self, CurTime() + randScaled( 0.2, 0.4 ) )
    return true

end

function ENT:OnBlocked( blocker )
    self:SetColor( red )
    self:SetMaterial( blockedMat )
    self.fixColor = true
    local blockTime = 10
    if blocker and blocker:IsWorld() then
        blockTime = 5

    elseif blocker then
        local obj = blocker:GetPhysicsObject()
        if blocker:IsNPC() or blocker:IsPlayer() or ( IsValid( obj ) and obj:IsMotionEnabled() ) then
            blockTime = 1

        end
    end
    self:NextThink( CurTime() + randScaled( blockTime * 0.5, blockTime * 1.5 ) )

end

local attackingSchedules = {
    [SCHED_RELOAD] = true,
    [SCHED_HIDE_AND_RELOAD] = true,
    [SCHED_RANGE_ATTACK1] = true,
    [SCHED_RANGE_ATTACK2] = true,
    [SCHED_MELEE_ATTACK1] = true,
    [SCHED_MELEE_ATTACK2] = true,
    [SCHED_SPECIAL_ATTACK1] = true,
    [SCHED_SPECIAL_ATTACK2] = true,

}

local function isAttacking( npcsSched )
    return attackingSchedules[npcsSched]

end

local lowHp = 40 -- metrocoooop
local highHp = 70 -- elite soldierrrr
local hpDiff = math.abs( lowHp - highHp )
local lowHpsReactionTime = 10
local highHpsReactionTime = 1
local reactDiff = math.abs( lowHpsReactionTime - highHpsReactionTime )

-- make the stronger npcs move around alot more, and the weaker npcs, move around less

local function npcsReactionSpeed( npc )
    npcsHpClamped = math.Clamp( npc:GetMaxHealth(), lowHp, highHp )
    local reactionSpeedScalar = ( npcsHpClamped + -lowHp ) / hpDiff

    local reactionSpeed = reactDiff * reactionSpeedScalar -- get the reaction speed, but its opposite.
    reactionSpeed = math.abs( reactionSpeed - lowHpsReactionTime ) -- make opposite speed not opposite
    return reactionSpeed

end

local busySpeed = 25^2
local meleeCloseEnough = 500^2
local tooCloseToNode = 45^2
local jumpSameZTolerance = 35

local COND_LOW_AMMO = COND.LOW_PRIMARY_AMMO
local COND_NO_AMMO = COND.NO_PRIMARY_AMMO

function ENT:ManageNPC( npc )
    local npcsTbl = npc:GetTable()
    local busy = ( npcsTbl.campaignents_NextMove or 0 ) > CurTime()
    if busy then return end
    busy = npcMeta.GetMoveVelocity( npc ):LengthSqr() > busySpeed and npcMeta.GetPathTimeToGoal( npc ) > 0.25
    if busy then return end
    busy = npcsTbl.GetNPCState and npcMeta.GetNPCState( NPC ) == NPC_STATE_SCRIPT -- npc mannable emplacement/sleeping enemies patch
    if busy then return end

    -- this is a COMBAT node!
    local npcsEnemy = npcMeta.GetEnemy( npc )
    if not IsValid( npcsEnemy ) then return end


    local npcsEyePos = entMeta.EyePos( npc )
    local enemysEyePos = entMeta.EyePos( npcsEnemy )
    local distToEnemySqr = npcsEyePos:DistToSqr( enemysEyePos )

    local noAmmo = npcMeta.HasCondition( npc, COND_NO_AMMO ) or npcMeta.HasCondition( npc, COND_LOW_AMMO )
    local sightClearOrBlockedByNpc = CanSeeOrHitNpc( npcsEyePos, enemysEyePos, { npc, npcsEnemy } )
    local nextMove = npcsTbl.campaignents_NextMoveWhenSeeing or 0
    local needsToTakeCover
    if nextMove > CurTime() then
        -- only wait if we're fine with where we are
        if not ( sightClearOrBlockedByNpc and noAmmo and distToEnemySqr < 500^2 ) then
            return

        elseif debuggingBool then
            debugoverlay.Cross( npcsEyePos, 50, 5, color_white, true )

        end

        needsToTakeCover = true

    end

    local npcsSched = npcMeta.GetCurrentSchedule( npc )

    if isAttacking( npcsSched ) and not needsToTakeCover then return end

    local npcsPos = entMeta.GetPos( npc )
    local nodesPos = entMeta.GetPos( self )
    if npcsPos:DistToSqr( nodesPos ) < tooCloseToNode then return end -- already at this node!   


    local theirCaps = npcMeta.CapabilitiesGet( npc )
    local isGround = bit.band( theirCaps, CAP_MOVE_GROUND ) >= 1
    if not isGround then return end


    local viewOffset = self:ViewOffsetOfNpc( npc )

    local footOffset = ( viewOffset / 5.5 )
    local traverseStartPos = npcsPos + footOffset
    local nodePosFootHeight = nodesPos + footOffset
    local canJump = bit.band( theirCaps, CAP_MOVE_JUMP ) >= 1

    local npcDangerHint = sound.GetLoudestSoundHint( SOUND_DANGER, npcsPos )
    if npcDangerHint and npcDangerHint.origin:DistToSqr( nodesPos ) < ( npcDangerHint.volume * 1.5 ) ^ 2 then
        npcsTbl.campaignents_NextFallbackMove = CurTime()
        npcsTbl.campaignents_NextMoveWhenSeeing = CurTime()
        return

    end

    -- they can jump!
    -- ignore height 
    if canJump then
        -- jumping right now!
        if not entMeta.IsOnGround( npc ) then return end

        highestZ = math.max( traverseStartPos.z, nodePosFootHeight.z ) + viewOffset.z --allow npc to jump over low down stuff!
        traverseStartPos.z = highestZ
        nodePosFootHeight.z = highestZ

    end

    local canCrowFly = IsntBlocked( traverseStartPos, nodePosFootHeight, { npc, self } )

    if not canCrowFly then return end


    local nodePosEyeHeight = nodesPos + viewOffset
    local npcCanSeeNode = PosCanSee( npcsEyePos, nodePosEyeHeight, npc )

    if not npcCanSeeNode then return end


    local enemsPos = npcsEnemy:GetPos()
    local canShoot = PosCanSee( npcsEyePos, enemysEyePos, { npc, npcsEnemy } )
    local fallbackMove = ( npcsTbl.campaignents_NextFallbackMove or 0 ) < CurTime()
    local canWeaps = bit.band( theirCaps, CAP_USE_WEAPONS ) >= 1
    local activeWep
    local charger
    if canWeaps then
        activeWep = npc:GetActiveWeapon()

    end

    if IsValid( activeWep ) then
        charger = string.find( activeWep:GetClass(), "shotgun" )

    end

    local nodesDistToEnemySqr = nodesPos:DistToSqr( enemysEyePos )
    local nodeCanSeeEnemy = PosCanSee( nodePosEyeHeight, enemysEyePos, enemy )
    local nodeIsCloser = nodesDistToEnemySqr < distToEnemySqr

    if canWeaps and IsValid( activeWep ) then
        local react = npcsReactionSpeed( npc )
        local lowHealth = self:Health() < ( self:GetMaxHealth() * 0.25 )

        -- either approach enemy or keep our distance!
        local canApproach = distToEnemySqr > meleeCloseEnough
        local getCloseThenOrbit = ( canApproach or not nodeIsCloser )
        local justChargeEm = ( charger and nodeIsCloser )
        local advantagousPosition = justChargeEm or getCloseThenOrbit

        local nodesFeetCanSeeEnemyFeet  = CanSeeOrHitNpc( nodePosFootHeight, enemsPos + footOffset, { enemy, self } )
        local nodesFeetCanSeeEnemy      = CanSeeOrHitNpc( nodePosFootHeight, enemysEyePos, { enemy, self } )
        local greatSoftCover = not nodesFeetCanSeeEnemyFeet and not nodesFeetCanSeeEnemy and nodeCanSeeEnemy
        local greatHardCover = greatSoftCover and not nodeCanSeeEnemy and not nodeIsCloser

        if noAmmo or lowHealth then
            local enemysFeetCanSeeNpcsFeet  = CanSeeOrHitNpc( enemsPos + footOffset, npcsPos + footOffset, { enemy, self } )
            local enemyCanSeeNpcsFeet       = CanSeeOrHitNpc( enemysEyePos, npcsPos + footOffset, { enemy, self } )
            local imInSoftCover = not enemysFeetCanSeeNpcsFeet and not enemyCanSeeNpcsFeet

            -- stay in cover!
            if imInSoftCover then
                npcsTbl.campaignents_NextMoveWhenSeeing = CurTime() + 1
                npcsTbl.campaignents_NextFallbackMove = CurTime() + 5
                if debuggingBool then
                    debugoverlay.Line( nodePosFootHeight, enemsPos + footOffset, 5, white, true )
                    debugoverlay.Line( nodePosFootHeight, npcsEyePos, 5, white, true )

                end
            -- take cover!
            elseif greatHardCover then
                -- stay in cover!
                npcsTbl.campaignents_NextMoveWhenSeeing = CurTime() + 3 + react
                npcsTbl.campaignents_NextFallbackMove = CurTime() + 15
                self:MakeNPCGotoUs( npc )
                if debuggingBool then
                    debugoverlay.Line( nodePosFootHeight, enemsPos + footOffset, 5, white, true )
                    debugoverlay.Line( nodePosFootHeight, npcsEyePos, 5, white, true )

                end

            -- it timed out! just go to non-ideal cover!
            elseif fallbackMove and greatSoftCover then
                self:MakeNPCGotoUs( npc )
                if debuggingBool then
                    debugoverlay.Line( npc:GetPos(), self:GetPos(), 5, white, true )
                    debugoverlay.Line( nodePosFootHeight, enemsPos + footOffset, 5, white, true )
                    debugoverlay.Line( nodePosFootHeight, npcsEyePos, 5, white, true )

                end
            end
            -- reloadin

        -- acquire los!
        elseif not canShoot then
            local justHadLos = ( npcsTbl.campaignents_NextAcquireLos or 0 ) > CurTime()
            if nodeCanSeeEnemy and not justHadLos then
                self:MakeNPCGotoUs( npc )
                npcsTbl.campaignents_NextMoveWhenSeeing = CurTime() + randScaled( 1, 2 ) + react
                npcsTbl.campaignents_NextFallbackMove = CurTime() + 20

            elseif nodeIsCloser and not justHadLos then
                npcsTbl.campaignents_NextFallbackMove = CurTime() + 10
                self:MakeNPCGotoUs( npc )

            elseif fallbackMove then
                self:MakeNPCGotoUs( npc ) -- move random if all else fails

            end

        -- charge the npc, or 'orbit' them at the preset dist!
        elseif canShoot and advantagousPosition and nodeCanSeeEnemy then
            self:MakeNPCGotoUs( npc )
            -- charge
            if charger then
                npcsTbl.campaignents_NextAcquireLos = CurTime()
                npcsTbl.campaignents_NextMoveWhenSeeing = CurTime()
                npcsTbl.campaignents_NextFallbackMove = CurTime() + 20

            -- orbit!
            else
                -- going into great cover we can shoot from, wait a long time for the next movement
                if greatSoftCover and nodeCanSeeEnemy then
                    npcsTbl.campaignents_NextAcquireLos = CurTime() + randScaled( 6, 8 ) + react
                    npcsTbl.campaignents_NextMoveWhenSeeing = CurTime() + randScaled( 8, 12 )
                    npcsTbl.campaignents_NextFallbackMove = CurTime() + 25

                else
                    npcsTbl.campaignents_NextFallbackMove = CurTime() + 20

                end
            end

        elseif fallbackMove then
            self:MakeNPCGotoUs( npc )

        end
    -- npc_citizen without weapons? maybe?
    elseif canWeaps and not IsValid( activeWep ) then
        -- run away!!!
        if not nodeIsCloser then
            self:MakeNPCGotoUs( npc )
            npcsTbl.campaignents_NextMoveWhenSeeing = CurTime() + 2
            npcsTbl.campaignents_NextFallbackMove = CurTime() + 10

        elseif fallbackMove then
            self:MakeNPCGotoUs( npc )

        end
    -- zombie, antions or npc_hunter!
    else
        local jumpingToRightHeight = canJump
        if jumpingToRightHeight then
            local npcAtWrongHeight = math.abs( npcsPos.z - enemsPos.z ) > jumpSameZTolerance
            local nodeAtRightHeight = math.abs( nodesPos.z - enemsPos.z ) <= jumpSameZTolerance
            jumpingToRightHeight = npcAtWrongHeight and nodeAtRightHeight

        end
        local didMove = nil

        -- allow default melee behaviour to do it's thing
        if distToEnemySqr < meleeCloseEnough then
            -- cant reach them, or we're behind something, just path to the node!
            local notEngaging = not sightClearOrBlockedByNpc or ( jumpingToRightHeight and nodeIsCloser )
            if notEngaging and nodeCanSeeEnemy then
                self:MakeNPCGotoUs( npc )
                didMove = true
                npcsTbl.campaignents_NextFallbackMove = CurTime() + 8

            elseif notEngaging and fallbackMove then
                self:MakeNPCGotoUs( npc )
                didMove = true
                npcsTbl.campaignents_NextFallbackMove = CurTime() + 1

            end

        -- acquire los!
        elseif not canShoot and nodeCanSeeEnemy or jumpingToRightHeight then
            self:MakeNPCGotoUs( npc )
            didMove = true
            npcsTbl.campaignents_NextFallbackMove = CurTime() + 8

        -- approach enemy!
        elseif nodeIsCloser then
            self:MakeNPCGotoUs( npc )
            didMove = true
            npcsTbl.campaignents_NextFallbackMove = CurTime() + 5

        -- don't stand still!
        elseif fallbackMove then
            self:MakeNPCGotoUs( npc )
            didMove = true
            npcsTbl.campaignents_NextFallbackMove = CurTime() + 1

        end
        if didMove and jumpingToRightHeight and nodesDistToEnemySqr < meleeCloseEnough then
            -- let npc acquire targ
            npcsTbl.campaignents_NextMove = CurTime() + 3

        end
    end
    return true

end

local COND_CAN_RANGE_ATTACK2 = 21
local COND_CAN_RANGE_ATTACK1 = 22
local COND_NEW_ENEMY = 26
local COND_LOST_ENEMY = 11

local targetChaseDontBreak = { COND_CAN_RANGE_ATTACK2, COND_CAN_RANGE_ATTACK1, COND_NEW_ENEMY, COND_LOST_ENEMY }

function ENT:MakeNPCGotoUs( npc, _ )
    npc.campaignents_NextMove = CurTime() + 0.5 -- flat delay
    npc:SetSaveValue( "m_hTargetEnt", self )
    npc.campaignents_CombatNodeOccupied = true
    npc:SetSchedule( SCHED_TARGET_CHASE )
    npc:SetIgnoreConditions( targetChaseDontBreak )

    if not debuggingBool then return end
    debugoverlay.Line( npc:GetPos(), self:GetPos(), 1, red, true )

end

function ENT:ViewOffsetOfNpc( npc )
    if not npc.campaignents_ViewOffset then
        npc.campaignents_ViewOffset = npc:WorldToLocal( npc:EyePos() )

    end
    return npc.campaignents_ViewOffset

end


hook.Add( "EntityTakeDamage", "campaignents_combatnode_breakspell", function( damaged )
    if damaged.campaignents_CombatNodeOccupied then
        if damaged:IsCurrentSchedule( SCHED_TARGET_CHASE ) then
            damaged:SetSchedule( SCHED_COMBAT_FACE )

        end
        damaged.campaignents_CombatNodeOccupied = nil
        damaged:RemoveIgnoreConditions( targetChaseDontBreak )

    end
end )