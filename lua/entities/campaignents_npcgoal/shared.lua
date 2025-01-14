AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "NPC Goal"
ENT.Author      = "straw wage"
ENT.Purpose     = "Make npcs go places after a thing respawner spawns em!"
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.Editable    = true
ENT.DefaultModel = "models/hunter/plates/plate05x05.mdl"

function ENT:SetupDataTables()
    self:NetworkVar( "Bool",    0, "IsWorthDyingFor",   { KeyName = "isworthdyingfor",  Edit = { type = "Bool", order = 1 } } )
    self:NetworkVar( "Int",     0, "GoalID",            { KeyName = "goalid",           Edit = { type = "Int",  order = 2, min = -1, max = 10000 } } )

    self:NetworkVarNotify( "GoalID", function( _, _, _, _ )
        if not CLIENT then return end
        if not IsValid( self ) then return end

        CAMPAIGN_ENTS.DoBeamColor( self )

    end )
    self:NetworkVarNotify( "IsWorthDyingFor", function( _, _, old, new )
        if not SERVER then return end
        if not IsValid( self ) then return end

        if math.abs( self:GetCreationTime() - CurTime() ) <= 1 then return end
        if old == new then return end

        local MSG = "NPC Goal: Reload the save for IsWorthDyingFor changes to apply. ( crash prevention. )"
        CAMPAIGN_ENTS.MessageOwner( self, MSG )

        if new == true then
            MSG = "IsWorthDyingFor Is set to true...\nNPCS will blindly attack this goal.\nThrow away their life just at the slim chance they will glance upon it...."
            CAMPAIGN_ENTS.MessageOwner( self, MSG )

        end
    end )

    if SERVER then
        self:SetIsWorthDyingFor( false )
        self:SetGoalID( -1 )

    end
end

function ENT:SetupSessionVars()
    self.goRunningNpcs = {}

end

function ENT:Initialize()
    if SERVER then
        self:SetupSessionVars()

        self:SetModel( self.DefaultModel )
        self:SetNoDraw( false )
        self:DrawShadow( false )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER )
        self:SetMaterial( "phoenix_storms/bluemetal" )

        CAMPAIGN_ENTS.doFadeDistance( self, 3000 )
        CAMPAIGN_ENTS.StartUglyHiding( self )
        CAMPAIGN_ENTS.EasyFreeze( self )

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:SelfSetup()

        end )

    else
        CAMPAIGN_ENTS.DoBeamColor( self )

    end
end

local nextMessage = 0
function ENT:SelfSetup()
    if self.duplicatedIn then return end
    if nextMessage > CurTime() then return end

    if CAMPAIGN_ENTS.EnabledAi() then
        local MSG = "Noclip and edit me!\nDrag me into a thing respawner for EZPZ mode!\nBut, a technical explanation,\nif my GoalID matches the GoalID of a thing respawner,\nI'll try and make any npcs it spawns, run to me!"
        CAMPAIGN_ENTS.MessageOwner( self, MSG )
        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            MSG = "The short line above me is the direction combine soldiers will face!\nThis will not appear when duped in."
            CAMPAIGN_ENTS.MessageOwner( self, MSG )

        end )

        nextMessage = CurTime() + 25

    end
end

function ENT:OnDuplicated()
    self.duplicatedIn = true
    self:SetupSessionVars()

end

if CLIENT then
    local beamMat = Material( "sprites/physbeama" )

    function ENT:Draw()
        self:DrawModel()

        local up = self:GetUp()
        local forwardIndStart = self:GetPos() + up * 25
        local forwardIndEnd = forwardIndStart + self:GetForward() * 50
        render.SetMaterial( beamMat )
        render.DrawBeam( forwardIndStart, forwardIndEnd, 20, 0, 0.1, self.GoalLinkColor )

    end
end

local assaultingClasses = {
    ["npc_combine_s"] = true,

}

function ENT:AssaultTargetName() -- per goalid, wildcard if multiple goals of same id
    return "campaignents_assaultpoint_" .. self:GetGoalID()

end

function ENT:PathName() -- per goalid, wildcard if multiple goals of same id
    return "campaignents_pathcorner_" .. self:GetGoalID()

end

function ENT:ManageNPC( npc )
    local class = npc:GetClass()
    if assaultingClasses[ class ] then
        self:MakeTheAssaultPoint()

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            if not IsValid( npc ) then return end
            self:MakeNpcGotoAssaultPoint( npc )

        end )
    elseif class == "prop_vehicle_apc" then
        self:ApcChasePath( npc )

    else
        self.goRunningNpcs[ npc:GetCreationID() ] = npc

    end
end

local printedMessage

local COND_HEAVY_DAMAGE     = 18
local COND_LIGHT_DAMAGE     = 17
local COND_SEE_ENEMY        = 10
local COND_NEW_ENEMY        = 26
local COND_HAVE_ENEMY_LOS   = 15

function ENT:Think()
    if not SERVER then return end

    if self:IsPlayerHolding() then
        if not printedMessage then
            printedMessage = true
            CAMPAIGN_ENTS.MessageOwner( self, "NPC Goal: Drag me into a respawner so i can copy it's GoalID!" )

        end
        CAMPAIGN_ENTS.captureGoalID( self )

    end

    local approachSchedule = SCHED_TARGET_CHASE
    local worthDyingFor = nil

    if self.GetIsWorthDyingFor and self:GetIsWorthDyingFor() then
        approachSchedule = SCHED_FORCED_GO_RUN
        worthDyingFor = true

    end

    for _, runningNpc in pairs( self.goRunningNpcs ) do
        if not IsValid( runningNpc ) then continue end

        local interrupted
        if not worthDyingFor then
            interrupted = runningNpc:HasCondition( COND_HAVE_ENEMY_LOS ) or runningNpc:HasCondition( COND_NEW_ENEMY ) or runningNpc:HasCondition( COND_SEE_ENEMY ) or runningNpc:HasCondition( COND_LIGHT_DAMAGE ) or runningNpc:HasCondition( COND_HEAVY_DAMAGE )

        end

        local distSqrToGoal = runningNpc:GetPos():DistToSqr( self:GetPos() )

        if runningNpc:IsCurrentSchedule( approachSchedule ) then
            -- hard cancel
            if interrupted then
                runningNpc:SetSchedule( SCHED_COMBAT_STAND )
                self.goRunningNpcs[ runningNpc:GetCreationID() ] = nil

            -- hard cancel if at goal or if we're near it
            elseif distSqrToGoal < 25^2 or ( IsValid( runningNpc:GetBlockingEntity() ) and distSqrToGoal < 150^2 ) then
                self.goRunningNpcs[ runningNpc:GetCreationID() ] = nil

            end
        elseif not interrupted then
            if distSqrToGoal < 150^2 then
                self.goRunningNpcs[ runningNpc:GetCreationID() ] = nil

            else
                if worthDyingFor then
                    runningNpc:SetSaveValue( "m_vecLastPosition", self:GetPos() )
                    runningNpc:SetSchedule( approachSchedule )

                else
                    runningNpc:SetSaveValue( "m_hTargetEnt", self )
                    runningNpc:SetSchedule( approachSchedule )

                end
            end
        end
    end
end

function ENT:MakeTheAssaultPoint()
    if not IsValid( self.assaultPoint ) then -- only need 1!
        -- WARNING don't delete assaultpoints when they have npcs goin to em, crashes session!
        local assaultPoint = ents.Create( "assault_assaultpoint" )
        self.assaultPoint = assaultPoint

        assaultPoint.campaignents_ParentGoal = self

        assaultPoint:SetKeyValue( "targetname", self:AssaultTargetName() )
        assaultPoint:SetKeyValue( "assaulttimeout", 1 )

        assaultPoint:SetPos( self:GetPos() )
        assaultPoint:SetAngles( self:GetAngles() )

        assaultPoint:Spawn()
        -- just in case!
        assaultPoint.DoNotDuplicate = true

        -- IS worth dying for
        if self.GetIsWorthDyingFor and self:GetIsWorthDyingFor() == true then return end

        -- is not worth dying for, dont throw our life away for it!
        assaultPoint:Fire( "SetClearOnContact", 1 )
        assaultPoint:Fire( "SetAllowDiversion", 1 )
        assaultPoint:SetKeyValue( "allowdiversionradius", 0 )

    else
        local assaultPoint = self.assaultPoint
        assaultPoint:SetPos( self:GetPos() )
        assaultPoint:SetAngles( self:GetAngles() )

    end
end

function ENT:MakeNpcGotoAssaultPoint( npc )
    local rallyPointsName = "campaignents_rallypoint_for_" .. npc:GetCreationID()
    local alreadyExistingRallies = ents.FindByName( rallyPointsName )

    if alreadyExistingRallies and #alreadyExistingRallies >= 1 then return end

    local ralliesPos = npc:GetPos()
    local dirToMe = self:GetPos() - ralliesPos
    local angToMe = -( dirToMe:GetNormalized() ):Angle()

    local rallyPoint = ents.Create( "assault_rallypoint" )
    rallyPoint:SetKeyValue( "targetname", rallyPointsName )
    rallyPoint:SetKeyValue( "assaultdelay", 0 )
    rallyPoint:SetKeyValue( "assaultpoint", self:AssaultTargetName() )

    npc:DeleteOnRemove( rallyPoint )

    rallyPoint:Spawn()
    rallyPoint:SetPos( ralliesPos )
    rallyPoint:SetAngles( angToMe )

    rallyPoint.DoNotDuplicate = true

    timer.Simple( 0, function()
        if not IsValid( npc ) then return end
        npc:Fire( "Assault", rallyPointsName )

    end )
end

function ENT:ApcChasePath( npc )
    if not IsValid( npc.campaignents_ApcDriver ) then return end
    if not IsValid( self.pathCorner ) then
        local pathCorner = ents.Create( "path_corner" )
        self:DeleteOnRemove( pathCorner )
        self.pathCorner = pathCorner

        pathCorner:SetKeyValue( "targetname", self:PathName() )
        pathCorner:SetPos( self:GetPos() )
        pathCorner.DoNotDuplicate = true

    end
    npc.npcGoalGrace = CurTime() + 5

    self.pathCorner:SetAngles( self:GetAngles() )
    self.pathCorner:SetPos( self:GetPos() )

    npc.campaignents_ApcFallbackCorner = self.pathCorner
    npc.campaignents_ApcDriver:Fire( "GotoPathCorner", self:PathName(), 1 )
    npc.campaignents_ApcDriver:Fire( "SetDriversMaxSpeed", 0.9 )
    npc.campaignents_ApcDriver:Fire( "SetDriversMinSpeed", 0.35 )

end