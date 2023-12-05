AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "NPC Combat 'Node'"
ENT.Author      = "straw wage"
ENT.Purpose     = "Makes NPCs with enemies, that aren't moving, path to it."
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.Editable    = true
ENT.DefaultModel = "models/props_phx/games/chess/white_dama.mdl"

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

function ENT:SetupSessionVars()
    self.nextFindNearby = 0
    self.stuffNearby = nil

end

function ENT:Initialize()
    if SERVER then
        self:SetModel( self.DefaultModel )
        self:SetNoDraw( false )
        self:DrawShadow( false )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_WORLD )
        self:SetMaterial( "models/props_lab/xencrystal_sheet" )

        self:SetupSessionVars()
        self:GetPhysicsObject():EnableMotion( false )

        campaignents_doFadeDistance( self, 3000 )

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:SelfSetup()

        end )
    else
        self.ShouldDraw = nil

    end
end

local nextMessage = 0
function ENT:SelfSetup()
    if self.duplicatedIn then return end
    if nextMessage > CurTime() then return end

    if campaignents_EnabledAi() then
        local MSG = "I give NPCS in combat, somewhere to move to, even if there's no AI nodes!\nPlace me behind cover, in the open, npcs will use me with intent!"
        self:TryToPrintOwnerMessage( MSG )
        timer.Simple( 0, function()
            MSG = "Spawn a big plate, put it high up, and spam copies of me on it, to see a demo!\nThis will not appear when duped in."
            self:TryToPrintOwnerMessage( MSG )

        end )

        nextMessage = CurTime() + 25

    end
end

function ENT:OnDuplicated()
    self.duplicatedIn = true
    self:SetupSessionVars()

end

if CLIENT then
    function ENT:Draw()
        if campaignents_IsEditing() or not campaignents_EnabledAi() then
            self:DrawModel()

        end
    end
end
if not SERVER then return end

local myClass = "campaignents_combatnode"
local shareFindResultsDist = 200
local pathDistNoAiNodes = 500
local findAllDist = pathDistNoAiNodes + shareFindResultsDist

pathDistNoAiNodes = pathDistNoAiNodes^2
shareFindResultsDist = shareFindResultsDist^2

function ENT:Think()
    if not SERVER then return end

    local myPos = self:GetPos()
    local nextFindNearby = self.nextFindNearby or 0
    local stuffNearby = self.stuffNearby
    if not stuffNearby or nextFindNearby < CurTime() then
        self.nextFindNearby = CurTime() + math.Rand( 2, 4 )
        stuffNearby = ents.FindInSphere( self:GetPos(), findAllDist )
        self.stuffNearby = stuffNearby

        -- save on FindInSpheres by sharing our results with neighbors
        for _, potentialNode in ipairs( stuffNearby ) do
            if IsValid( potentialNode ) and potentialNode:GetClass() == myClass and potentialNode:GetPos():DistToSqr( myPos ) < shareFindResultsDist then
                potentialNode.stuffNearby = self.stuffNearby
                potentialNode.nextFindNearby = CurTime() + math.Rand( 2, 4 )

            end
        end
    end

    local didSomething
    local isFighting
    local operatedOnNpc

    for _, currThing in ipairs( stuffNearby ) do
        -- make sure its a normal npc that was constructed by someone who is sane.
        if IsValid( currThing ) and currThing:IsNPC() and currThing.SetSchedule and currThing.GetMoveVelocity and currThing:GetPos():DistToSqr( myPos ) < pathDistNoAiNodes then
            local result = self:ManageNPC( currThing )
            didSomething = didSomething or result
            isFighting = currThing.GetEnemy and IsValid( currThing:GetEnemy() )
            operatedOnNpc = true

        end
    end
    -- op tem is ation
    if not operatedOnNpc then
        self:NextThink( CurTime() + math.Rand( 6, 12 ) )
        return true

    end
    if not isFighting then
        self:NextThink( CurTime() + math.Rand( 3, 6 ) )
        return true

    end
    if not didSomething then
        self:NextThink( CurTime() + math.Rand( 0.25, 1 ) )
        return true

    end
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

    local reactionSpeed = reactDiff * reactionSpeedScalar -- get the opposite reaction speed
    reactionSpeed = math.abs( reactionSpeed - lowHpsReactionTime ) -- make opposite speed not opposite
    return reactionSpeed

end

local busySpeed = 25^2
local meleeCloseEnough = 500^2
local tooCloseToNode = 45^2

local COND_LOW_AMMO = 3
local COND_NO_AMMO = 4

function ENT:ManageNPC( npc )
    local busy = ( npc.campaignents_NextMove or 0 ) > CurTime()
    if busy then return end
    busy = npc:GetMoveVelocity():LengthSqr() > busySpeed and npc:GetPathTimeToGoal() > 0.5
    if busy then return end
    busy = npc.GetNPCState and npc:GetNPCState() == NPC_STATE_SCRIPT -- npc mannable emplacement patch
    if busy then return end


    local npcsEnemy = npc:GetEnemy()
    if not IsValid( npcsEnemy ) then return end


    local npcsEyePos = npc:EyePos()
    local enemysEyePos = npcsEnemy:EyePos()

    local noAmmo = npc:HasCondition( COND_NO_AMMO ) or npc:HasCondition( COND_LOW_AMMO )
    local canShoot = PosCanSee( npcsEyePos, enemysEyePos, { npc, npcsEnemy } )
    local nextMove = npc.campaignents_NextMoveWhenSeeing or 0
    if ( nextMove > CurTime() ) and ( canShoot and not noAmmo ) then return end

    local rand2DOffset = VectorRand()
    rand2DOffset.z = 0
    rand2DOffset:Normalize()
    rand2DOffset = rand2DOffset * math.random( 0, 45 )

    local npcsPos = npc:GetPos()
    local nodesPos = self:GetPos() + rand2DOffset
    if npcsPos:DistToSqr( nodesPos ) < tooCloseToNode then return end -- already at this node!   


    local theirCaps = npc:CapabilitiesGet()
    local isGround = bit.band( theirCaps, CAP_MOVE_GROUND ) ~= 0
    if not isGround then return end


    local viewOffset = self:ViewOffsetOfNpc( npc )

    local footOffset = ( viewOffset / 5.5 )
    local traverseStartPos = npcsPos + footOffset
    local nodePosFootHeight = nodesPos + footOffset
    local canJump = bit.band( theirCaps, CAP_MOVE_JUMP ) ~= 0

    local npcDangerHint = npc:GetBestSoundHint( SOUND_DANGER )
    if npcDangerHint and npcDangerHint.origin:DistToSqr( nodesPos ) < ( npcDangerHint.volume * 1.5 ) ^ 2 then
        npc.campaignents_NextFallbackMove = CurTime()
        npc.campaignents_NextMoveWhenSeeing = CurTime()
        return

    end

    -- they can jump!
    -- ignore height 
    if canJump then
        highestZ = math.max( traverseStartPos.z, nodePosFootHeight.z ) + viewOffset.z --allow npc to jump over low down stuff!
        traverseStartPos.z = highestZ
        nodePosFootHeight.z = highestZ

    end

    local npcCanTraverseToNode = PosCanSee( traverseStartPos, nodePosFootHeight, { npc, self } )

    if not npcCanTraverseToNode then return end


    local nodePosEyeHeight = nodesPos + viewOffset
    local npcCanSeeNode = PosCanSee( npcsEyePos, nodePosEyeHeight, npc )

    if not npcCanSeeNode then return end


    local fallbackMove = ( npc.campaignents_NextFallbackMove or 0 ) < CurTime()
    local canWeaps = bit.band( theirCaps, CAP_USE_WEAPONS ) ~= 0
    local activeWep
    local potentialShotgun
    local canRangedWep
    local canMeleeWep
    if canWeaps then
        activeWep = npc:GetActiveWeapon()
        canRangedWep = IsValid( activeWep ) and ( bit.band( theirCaps, CAP_WEAPON_RANGE_ATTACK1 ) or bit.band( theirCaps, CAP_WEAPON_RANGE_ATTACK2 ) )
        canMeleeWep = IsValid( activeWep ) and ( bit.band( theirCaps, CAP_WEAPON_MELEE_ATTACK1 ) or bit.band( theirCaps, CAP_WEAPON_MELEE_ATTACK2 ) )

    end
    if canRangedWep then
        potentialShotgun = string.find( activeWep:GetClass(), "shotgun" )

    end

    local nodeCanSeeEnemy = PosCanSee( nodePosEyeHeight, enemysEyePos, enemy )
    local distToEnemySqr = npcsEyePos:DistToSqr( enemysEyePos )
    local nodeIsCloser = nodesPos:DistToSqr( enemysEyePos ) < distToEnemySqr

    if canWeaps and canRangedWep then
        local react = npcsReactionSpeed( npc )
        local lowHealth = self:Health() < ( self:GetMaxHealth() * 0.25 )

        -- either approach enemy or keep our distance!
        local canApproach = distToEnemySqr > meleeCloseEnough
        local getCloseThenOrbit = ( canApproach or not nodeIsCloser )
        local justChargeEm = ( potentialShotgun and nodeIsCloser )
        local advantagousPosition = justChargeEm or getCloseThenOrbit

        local nodeCanSeeEnemysFeet = PosCanSee( nodePosFootHeight, npcsEnemy:GetPos() + footOffset, { enemy, self } )
        local enemyCanSeeNodesFoot = PosCanSee( nodePosFootHeight, npcsEyePos, { enemy, self } )
        local goodCover = not nodeCanSeeEnemysFeet and not enemyCanSeeNodesFoot

        if noAmmo or lowHealth then
            -- take cover!
            if goodCover and nodeCanSeeEnemy then
                -- stay in cover!
                npc.campaignents_NextMoveWhenSeeing = CurTime() + 4 + react
                self:MakeNPCGotoUs( npc, rand2DOffset )

            -- it timed out! just go to non-ideal cover!
            elseif fallbackMove and not nodeCanSeeEnemy then
                self:MakeNPCGotoUs( npc, rand2DOffset )

            end
            -- reloadin

        -- acquire los!
        elseif not canShoot then
            local justHadLos = ( npc.campaignents_NextAcquireLos or 0 ) > CurTime()
            if nodeCanSeeEnemy and not justHadLos then
                self:MakeNPCGotoUs( npc, rand2DOffset )
                npc.campaignents_NextMoveWhenSeeing = CurTime() + math.Rand( 2, 4 ) + react
                npc.campaignents_NextFallbackMove = CurTime() + 20

            elseif nodeIsCloser and not justHadLos then
                npc.campaignents_NextFallbackMove = CurTime() + 10
                self:MakeNPCGotoUs( npc, rand2DOffset )

            elseif fallbackMove then
                self:MakeNPCGotoUs( npc, rand2DOffset ) -- move random if all else fails

            end

        -- charge the npc, or 'orbit' them at the preset dist!
        elseif canShoot and advantagousPosition and nodeCanSeeEnemy then
            self:MakeNPCGotoUs( npc, rand2DOffset )
            -- charge
            if potentialShotgun then
                npc.campaignents_NextMoveWhenSeeing = CurTime() + math.Rand( 1, 2 )
                npc.campaignents_NextFallbackMove = CurTime() + 20

            -- orbit!
            else
                -- going into cover
                if goodCover and nodeCanSeeEnemy then
                    npc.campaignents_NextAcquireLos = CurTime() + math.Rand( 2, 4 ) + react
                    npc.campaignents_NextMoveWhenSeeing = CurTime() + math.Rand( 8, 12 )
                    npc.campaignents_NextFallbackMove = CurTime() + 25

                else
                    npc.campaignents_NextAcquireLos = CurTime() + math.Rand( 1, 2 ) + react
                    npc.campaignents_NextMoveWhenSeeing = CurTime() + math.Rand( 6, 8 )
                    npc.campaignents_NextFallbackMove = CurTime() + 20

                end
            end

        elseif fallbackMove then
            self:MakeNPCGotoUs( npc, rand2DOffset )

        end
    -- npc_citizen without weapons? maybe?
    elseif canWeaps and not canRangedWep and not canMeleeWep then
        if not nodeIsCloser then
            self:MakeNPCGotoUs( npc, rand2DOffset )
            npc.campaignents_NextMoveWhenSeeing = CurTime() + 2
            npc.campaignents_NextFallbackMove = CurTime() + 10

        elseif fallbackMove then
            self:MakeNPCGotoUs( npc, rand2DOffset )

        end
    -- zombie or antions!
    else
        -- allow default melee behaviour to do it's thing
        if distToEnemySqr < meleeCloseEnough and not npc:IsUnreachable( npcsEnemy ) then

        -- acquire los!
        elseif not canShoot and nodeCanSeeEnemy then
            self:MakeNPCGotoUs( npc, rand2DOffset )
            npc.campaignents_NextFallbackMove = CurTime() + 10

        -- approach enemy!
        elseif nodeIsCloser then
            self:MakeNPCGotoUs( npc, rand2DOffset )
            npc.campaignents_NextFallbackMove = CurTime() + 10

        -- don't stand still!
        elseif fallbackMove then
            self:MakeNPCGotoUs( npc, rand2DOffset )

        end
    end
    return true

end

function ENT:MakeNPCGotoUs( npc, offset )
    npc.campaignents_NextMove = CurTime() + 0.35 -- flat delay
    npc:SetSaveValue( "m_vecLastPosition", self:GetPos() + offset )
    npc:SetSchedule( SCHED_FORCED_GO_RUN )

end

function ENT:ViewOffsetOfNpc( npc )
    if not npc.campaignents_ViewOffset then
        npc.campaignents_ViewOffset = npc:WorldToLocal( npc:EyePos() )

    end
    return npc.campaignents_ViewOffset

end

function ENT:TryToPrintOwnerMessage( MSG )
    local done = nil
    if CPPI then
        local owner, _ = self:CPPIGetOwner()
        if IsValid( owner ) then
            owner:PrintMessage( HUD_PRINTTALK, MSG )
            done = true

        end
    end
    if not done then
        PrintMessage( HUD_PRINTTALK, MSG )
        done = true

    end
end