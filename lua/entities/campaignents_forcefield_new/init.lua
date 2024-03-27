--DOES WORK WHEN DUPED!

AddCSLuaFile( "cl_init.lua" ) -- Make sure clientside
AddCSLuaFile( "shared.lua" ) -- and shared scripts are sent.
include( "shared.lua" )

resource.AddSingleFile( "sound/campaign_entities/combineshield_activate.wav" )
resource.AddSingleFile( "sound/campaign_entities/combineshield_deactivate.wav" )

-- Forcefield is taken from nutscript, which is released under a MIT License. ( which was then taken by straw w wagen for campaign entities )
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2001220293
-- https://github.com/Chessnut/hl2rp/blob/1.1/LICENSE

local upFourty = Vector( 0, 0, 40 )

function ENT:SpawnFunction( ply, trace )
    local angles = ( ply:GetPos() - trace.HitPos ):Angle()
    angles.p = 0
    angles.r = 0

    local snapToFloorTrace = {}
    snapToFloorTrace.start = trace.HitPos + upFourty
    snapToFloorTrace.endpos = trace.HitPos + -upFourty * 10

    local snapToFloorTraceR = util.TraceLine( snapToFloorTrace )

    angles:RotateAroundAxis( angles:Up(), 270 )
    local entity = ents.Create( "campaignents_forcefield_new" )
    entity:SetCreator( ply )
    entity:SetPos( snapToFloorTraceR.HitPos + upFourty )
    entity:SetAngles( angles:SnapTo( "y", 45 ) )
    entity:Spawn()
    entity:SetName( "Forcefield" .. entity:GetCreationID() )

    return entity

end
function ENT:SetupSessionVars()
    self.doDissolveTime = 0
    self.nextCreateSound = 0
    self.redoTheShieldSound = 0
    self.buzzerSoundsPlaying = {}
    self.fieldShouldCollideCache = {}
    self.field_loopingSound = nil
    self.field_loopingSoundDummy = nil
    self.oldPositionProductLeng = 0
    self.shieldIsOn = true -- starts on?!?!?
    self.isForceField = true

end

local forceFields = {}

function ENT:Initialize()

    forceFields[self] = true
    self:UpdateShouldCollideHook()

    self:CallOnRemove( "campaignents_removefrom_forcefieldcache", function( me )
        forceFields[me] = nil
        me:UpdateShouldCollideHook()

    end )

    self:SetupSessionVars()

    self:SetName( "Forcefield" .. self:GetCreationID() )
    self:SetModel( "models/props_combine/combine_fence01b.mdl" )

    self:DrawShadow( false )

    campaignents_doFadeDistance( self, 4000 )

    self.startDummy = ents.Create( "prop_physics" )
    self.startDummy:SetModel( "models/props_combine/combine_fence01b.mdl" )
    self.startDummy:SetPos( self:GetPos() )
    self.startDummy:SetAngles( self:GetAngles() )
    self.startDummy:Spawn()
    self.startDummy:SetName( "Forcefield" .. self:GetCreationID() )
    self.startDummy.DoNotDuplicate = true

    self.startDummy:SetOwner( self )
    self:DeleteOnRemove( self.startDummy )
    self:SetDummyStart( self.startDummy )

    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )

    self:AddSolidFlags( FSOLID_CUSTOMRAYTEST )
    self:SetCustomCollisionCheck( true )
    self:EnableCustomCollisions( true )

    self:DoShieldCollisions()

    campaignEnts_EasyFreeze( self )
    campaignEnts_EasyFreeze( self.startDummy )

    timer.Simple( 0, function()
        if not self:IsValid() then return end

        local dummyEndPos = self.dummyEndPos
        local dummyEndAng = self.dummyEndAng
        if not dummyEndPos or not dummyEndAng then
            dummyEndAng = self:GetAngles()

            local dummyEndTrData = {}
            dummyEndTrData.start = self:GetPos() + self:GetRight() * -16
            dummyEndTrData.endpos = self:GetPos() + self:GetRight() * -800
            dummyEndTrData.filter = { self, self:GetCreator() }

            local dummyEndTrace = util.TraceLine( dummyEndTrData )
            dummyEndPos = dummyEndTrace.HitPos

        end

        self.endDummy = ents.Create( "prop_physics" )
        self.endDummy:SetModel( "models/props_combine/combine_fence01a.mdl" )
        self.endDummy:SetPos( dummyEndPos )
        self.endDummy:SetAngles( dummyEndAng )
        self.endDummy:Spawn()
        self.endDummy:SetName( "Forcefield" .. self:GetCreationID() )
        self.endDummy.DoNotDuplicate = true

        self.endDummy:SetOwner( self )
        self:DeleteOnRemove( self.endDummy )
        self:SetDummyEnd( self.endDummy )

        campaignEnts_EasyFreeze( self.endDummy )

    end )
end

function ENT:SpawnMyPlug()
    local plug = ents.Create( "campaignents_forcefield_plug" )
    local plugPos, plugAng = nil, nil

    if self.plugDupedPos and self.plugDupedAng then
        plugPos = self.plugDupedPos
        plugAng = self.plugDupedAng

    else
        plugPos = self.startDummy:GetPos() + self.startDummy:GetRight() * -20.525 + self.startDummy:GetUp() * -16
        plugAng = self.startDummy:GetAngles()

    end

    plug.DoNotDuplicate = true

    plug:SetPos( plugPos )
    plug:SetAngles( plugAng )
    plug:SetModel( "models/props_lab/tpplug.mdl" )
    plug:Activate()
    plug:SetName( "Forcefield" .. self:GetCreationID() )
    plug:Spawn()

    constraint.Rope( plug, self.startDummy, 0, 0, Vector( 11, 0, 0 ), Vector( 0, 12, 5 ), 350, 0, 0, 2.5, "Cable/cable2", false )

    self.forcefield_Plug = plug

end

function ENT:OnDuplicated()
    self.duplicatedIn = true
    self:SetupSessionVars()

end


duplicator.RegisterEntityModifier( "forcefield_wheremyplugwas", function( _, pasted, offsets )
    if offsets.posOffset and offsets.angOffset then
        pasted.plugDupedPos = pasted:LocalToWorld( offsets.posOffset )
        pasted.plugDupedAng = pasted:LocalToWorldAngles( offsets.angOffset )

    end

    if offsets.dummyEndPosOffset and offsets.dummyEndAngOffset then
        pasted.dummyEndPos = pasted:LocalToWorld( offsets.dummyEndPosOffset )
        pasted.dummyEndAng = pasted:LocalToWorldAngles( offsets.dummyEndAngOffset )

    end
end )

function ENT:PreEntityCopy()
    local offsets = {}
    if IsValid( self.forcefield_Plug ) then
        offsets.posOffset = self:WorldToLocal( self.forcefield_Plug:GetPos() )
        offsets.angOffset = self:WorldToLocalAngles( self.forcefield_Plug:GetAngles() )

    end

    if IsValid( self.endDummy ) then
        offsets.dummyEndPosOffset = self:WorldToLocal( self.endDummy:GetPos() )
        offsets.dummyEndAngOffset = self:WorldToLocalAngles( self.endDummy:GetAngles() )

    end

    duplicator.StoreEntityModifier( self, "forcefield_wheremyplugwas", offsets )

end

function ENT:PositionsThink()
    local dummyStart = self:GetDummyStart()
    local dummyEnd = self:GetDummyEnd()
    if not IsValid( dummyStart ) then return end
    if not IsValid( dummyEnd ) then return end

    if dummyStart:GetPhysicsObject():IsMotionEnabled() then return false end
    if dummyEnd:GetPhysicsObject():IsMotionEnabled() then return false end

    local posProductLeng = ( dummyStart:GetPos() + dummyEnd:GetPos() ):Length()
    posProductLeng = math.Round( posProductLeng )

    if self.oldPositionProductLeng and self.oldPositionProductLeng == posProductLeng then return true end

    self.oldPositionProductLeng = posProductLeng

    self:SetPos( dummyStart:GetPos() )
    self:SetAngles( dummyStart:GetAngles() )

    return false

end

function ENT:Think()
    if self.Dead then SafeRemoveEntity( self ) return end

    local alwaysOn = self.GetAlwaysOn and self:GetAlwaysOn()

    if alwaysOn then
        if IsValid( self.forcefield_Plug ) then
            SafeRemoveEntity( self.forcefield_Plug )

        end
    elseif not IsValid( self.forcefield_Plug ) then
        self:SpawnMyPlug()

    end

    local positionsResult = self:PositionsThink()
    local broken = positionsResult == nil
    local beingMoved = positionsResult == false
    local isOn = alwaysOn or ( IsValid( self.forcefield_Plug ) and IsValid( self.forcefield_Plug.Shield_Socket ) and self.forcefield_Plug.Shield_Socket:GetIsPowered() )

    for entIndex, soundDat in pairs( self.buzzerSoundsPlaying ) do
        if not IsValid( soundDat.entity ) then
            self.buzzerSoundsPlaying[ entIndex ] = nil
            continue

        end
        if not soundDat.theSound then
            self.buzzerSoundsPlaying[ entIndex ] = nil
            continue

        end

        if soundDat.stopTime < CurTime() then
            soundDat.theSound:Stop()
            soundDat.theSound = nil
            soundDat.entity:RemoveCallOnRemove( "stopplayingfieldsound" )
            soundDat.entity.field_BuzzerSound = nil

        end
    end

    if broken then
        self.Dead = true
        if self.shieldIsOn then
            self.shieldIsOn = nil
            TurnOff( self )

        end
    elseif beingMoved then
        if self.shieldIsOn then
            self.shieldIsOn = nil
            TurnOff( self )

        end

    elseif isOn and not self.shieldIsOn then
        self.shieldIsOn = true
        TurnOn( self )

    elseif not isOn and self.shieldIsOn then
        self.shieldIsOn = nil
        TurnOff( self )

    end

    if math.abs( self:GetCreationTime() - CurTime() ) < 0.25 then return end

    local dummyEnd = self:GetDummyEnd()

    -- fix it not playing sometimes
    local redoTheShieldSound = self.redoTheShieldSound < CurTime()

    if self.shieldIsOn then
        if not self.field_loopingSound then
            self:EmitSound( "campaign_entities/combineshield_activate.wav", 80, math.random( 95, 105 ) )

        end
        if not self.field_loopingSound or redoTheShieldSound then
            if self.field_loopingSound then
                self.field_loopingSound:Stop()

            end
            self.field_loopingSound = CreateSound( self, "ambient/machines/combine_shield_loop3.wav" )
            self.field_loopingSound:Play()
            self.field_loopingSound:ChangeVolume( 0.5, 0 )
            self.redoTheShieldSound = CurTime() + math.random( 10, 20 )

        end
        if not self.field_loopingSoundDummy then
            dummyEnd:EmitSound( "campaign_entities/combineshield_activate.wav", 80, math.random( 95, 105 ) )

        end
        if not self.field_loopingSoundDummy or redoTheShieldSound then
            if self.field_loopingSoundDummy then
                self.field_loopingSoundDummy:Stop()

            end
            self.field_loopingSoundDummy = CreateSound( dummyEnd, "ambient/machines/combine_shield_loop3.wav" )
            self.field_loopingSoundDummy:Play()
            self.field_loopingSoundDummy:ChangeVolume( 0.5, 0 )
            self.redoTheShieldSound = CurTime() + math.random( 10, 20 )

        end
    elseif not self.shieldIsOn then
        if self.field_loopingSound then
            self:EmitSound( "campaign_entities/combineshield_deactivate.wav", 80, math.random( 95, 105 ) )

            self.field_loopingSound:ChangeVolume( 0, 0 )
            self.field_loopingSound:Stop()
            self.field_loopingSound = nil

        end
        if self.field_loopingSoundDummy and IsValid( dummyEnd ) then
            dummyEnd:EmitSound( "campaign_entities/combineshield_deactivate.wav", 80, math.random( 95, 105 ) )

            self.field_loopingSoundDummy:ChangeVolume( 0, 0 )
            self.field_loopingSoundDummy:Stop()
            self.field_loopingSoundDummy = nil

        end
    end
    self:NextThink( 0.25 )
    return true

end

function ENT:TryToDissolve( entity )
    if self.doDissolveTime < CurTime() then return end

    local dummyStart = self:GetDummyStart()
    local dummyEnd = self:GetDummyEnd()

    if ( entity == dummyStart ) or ( entity == dummyEnd ) then return end

    local dissolveDamage = DamageInfo()
    dissolveDamage:SetDamage( 10000 )
    dissolveDamage:SetDamageType( bit.bor( DMG_DISSOLVE ) )
    dissolveDamage:SetAttacker( self )
    dissolveDamage:SetInflictor( self )
    entity:TakeDamageInfo( dissolveDamage )

end

function ENT:StartTouch( entity )
    self:TryToDissolve( entity )

end

function ENT:Touch( entity )
    if self:GetSkin() ~= 0 then return end

    local soundDat = self.buzzerSoundsPlaying[ entity:GetCreationID() ]
    if self.nextCreateSound > CurTime() then return end
    if not soundDat or not soundDat.theSound then
        self.nextCreateSound = CurTime() + 0.1
        local field_BuzzerSound = CreateSound( entity, "ambient/machines/combine_shield_touch_loop1.wav" )
        field_BuzzerSound:SetSoundLevel( 65 )
        field_BuzzerSound:Play()
        field_BuzzerSound:ChangeVolume( 0, 0.5 )
        self.buzzerSoundsPlaying[ entity:GetCreationID() ] = { entity = entity, theSound = field_BuzzerSound, stopTime = CurTime() + 0.5 }

        entity:CallOnRemove( "stopplayingfieldsound", function( ent )
            ent:StopSound( "ambient/machines/combine_shield_touch_loop1.wav" )

        end )

    else
        soundDat.theSound:SetSoundLevel( 65 )
        soundDat.theSound:ChangeVolume( 0.5, 0 )
        soundDat.theSound:ChangeVolume( 0, 0.5 )
        self.buzzerSoundsPlaying[ entity:GetCreationID() ].stopTime = CurTime() + 0.5

        entity:CallOnRemove( "stopplayingfieldsound", function( ent )
            ent:StopSound( "ambient/machines/combine_shield_touch_loop1.wav" )

        end )

    end

end

function ENT:OnRemove()
    if self.field_BuzzerSound then
        self.field_BuzzerSound:Stop()
        self.field_BuzzerSound = nil

    end
    if self.field_loopingSound then
        self.field_loopingSound:ChangeVolume( 0, 0 )
        self.field_loopingSound:Stop()
        self.field_loopingSound = nil

    end
    if self.field_loopingSoundDummy then
        self.field_loopingSoundDummy:ChangeVolume( 0, 0 )
        self.field_loopingSoundDummy:Stop()
        self.field_loopingSoundDummy = nil

    end
    for _, ent in pairs( ents.FindByName( "Forcefield" .. self:GetCreationID() ) ) do
        ent:Remove()

    end
end

local function isCombineModel( mdl )
    local mdlLower = mdl:lower()
    if string.find( mdlLower, "combine" ) then return true end
    if string.find( mdlLower, "metrocop" ) then return true end
    if string.find( mdlLower, "civilprotection" ) then return true end
    if string.find( mdlLower, "police" )  then return true end
    if string.find( mdlLower, "breen" ) then return true end
    if string.find( mdlLower, "overwatch" ) then return true end

end

local combineClasses = {
    ["npc_combine_s"] = true,
    ["npc_metropolice"] = true,
    ["npc_rollermine"] = true,
    ["npc_manhack"] = true,
    ["npc_clawscanner"] = true,
    ["npc_cscanner"] = true,
    ["npc_helicopter"] = true,
    ["npc_combinedropship"] = true,
    ["npc_combinegunship"] = true,
    ["npc_hunter"] = true,
    ["npc_stalker"] = true,
    ["npc_strider"] = true,
    ["npc_turret_floor"] = true,
    ["npc_zombine"] = true, -- lol

}

local function plyShouldBeBlocked( ply, field )
    local mdl = ply:GetModel()
    if field:GetAllowCombinePlys() and isCombineModel( mdl ) then return false end
    return true

end

-- returns two vars
-- first, if it should collide, second, if the result should never be cached ( big optimisation ) 
local function fieldShouldCollideExpensive( field, colliding )
    local collidingsClass = colliding:GetClass()

    -- !!!!!!!! return false, ent can pass through no problem, return TRUE and ent will be stopped by shield !!!!!!!!
    -- result is then CACHED by each shield!
    -- always double check after you impliment hooks that work with other peoples stuff!
    local hookShouldCollide, hookBlockCaching = hook.Run( "campaignents_field_shouldcollide", field, colliding, collidingsClass )
    if hookShouldCollide ~= nil then
        return hookShouldCollide, hookBlockCaching

    elseif colliding:IsNPC() and not ( combineClasses[collidingsClass] or isCombineModel( colliding:GetModel() ) ) then
        return true

    elseif colliding:IsPlayer() and plyShouldBeBlocked( colliding, field ) then
        return true

    elseif colliding:IsVehicle() then
        local mdl = colliding:GetModel()
        local driver = colliding:GetDriver()
        if isCombineModel( mdl ) then
            return false

        elseif IsValid( driver ) and not plyShouldBeBlocked( driver, field ) then
            return false, true

        else
            return true, true

        end

    end
    return false

end

function ENT:ResetShouldCollideCache()
    self.fieldShouldCollideCache = {}

end

local function fieldShouldCollideCheap( entA, entB )
    if not forceFields[entA] and not forceFields[entB] then return end

    local colliding
    local field

    local aIsForcefield = forceFields[entA]
    local bIsForcefield = forceFields[entB]

    if bIsForcefield then
        colliding = entA
        field = entB

    elseif aIsForcefield then
        colliding = entB
        field = entA

    end

    -- cache this for optomisation
    local shouldCollide = field.fieldShouldCollideCache[ colliding:GetCreationID() ]

    if shouldCollide ~= nil then
        return shouldCollide

    end

    local blockCaching
    shouldCollide, blockCaching = fieldShouldCollideExpensive( field, colliding, collidingsClass )

    if blockCaching == true then return shouldCollide end

    field.fieldShouldCollideCache[ colliding:GetCreationID() ] = shouldCollide

    return shouldCollide

end

local theHooksName = "campaignents_realistic_forcefield"
local hookExists

function ENT:UpdateShouldCollideHook()
    local shouldBeHook = table.Count( forceFields ) >= 1
    if shouldBeHook and not hookExists then
        hook.Add( "ShouldCollide", theHooksName, fieldShouldCollideCheap )
        hookExists = true

    elseif not shouldBeHook and hookExists then
        hookExists = nil
        hook.Remove( "ShouldCollide", theHooksName )

    end
end

function TurnOff( self )
    for _, ent in ipairs( ents.FindByName( "Forcefield" .. self:GetCreationID() ) ) do -- this code smells!
        ent:SetSkin( 1 )
        util.ScreenShake( ent:GetPos(), 0.25, 10, 0.25, 1500 )

    end
    timer.Simple( 0.05, function()
        if not IsValid( self ) then return end
        -- reset collision cache!
        self:ResetShouldCollideCache()
        self:DoShieldCollisions()

    end )
end

function TurnOn( self )
    for _, ent in ipairs( ents.FindByName( "Forcefield" .. self:GetCreationID() ) ) do -- this too!
        ent:SetSkin( 0 )
        util.ScreenShake( ent:GetPos(), 2, 10, 0.25, 1500 )

    end
    timer.Simple( 0.05, function()
        if not IsValid( self ) then return end
        -- ditto!
        self:ResetShouldCollideCache()
        -- munch stuff!
        self.doDissolveTime = CurTime() + 0.15
        self:DoShieldCollisions()

        self:TryToDissolveWithTraces()

    end )
end

local dissolveMaxs = Vector( 2, 2, 5 )
local dissolveMins = -dissolveMaxs

-- big munch!
function ENT:TryToDissolveWithTraces()
    local dummyStart = self:GetDummyStart()
    local dummyEnd = self:GetDummyEnd()
    local dummyStartPos = dummyStart:GetPos()
    local dummyEndPos = dummyEnd:GetPos()
    local dummyStartUp = dummyStart:GetUp()
    local dummyEndUp = dummyEnd:GetUp()

    local damagedStuff = {}

    local doStart = -10
    local doEnd = 47 + doStart
    local sounds = 0

    for index = doStart, doEnd do
        local offset = index * 4

        local currStart = dummyStartPos + ( dummyStartUp * offset )
        local currEnd = dummyEndPos + ( dummyEndUp * offset )

        local found = ents.FindAlongRay( currStart, currEnd, dissolveMins, dissolveMaxs )
        for _, entity in ipairs( found ) do
            if fieldShouldCollideExpensive( self, entity ) == false then continue end
            if damagedStuff[ entity:GetCreationID() ] then continue end -- just damage it once....

            local hadHealth = entity:Health() > 0

            self:TryToDissolve( entity )

            damagedStuff[ entity:GetCreationID() ] = true

            if not hadHealth then continue end
            if sounds >= 5 then continue end
            sounds = sounds + 1
            timer.Simple( 0, function()
                if not IsValid( entity ) then return end
                if entity:Health() > 0 then return end
                -- SLICE AND DICE!
                entity:EmitSound( "ambient/machines/slicer" .. math.random( 1, 4 ) .. ".wav", 75, 80 )

            end )
        end
    end
end

hook.Add( "PlayerSpawn", "campaignents_resetshieldcaches", function( spawned )
    for _, field in ipairs( ents.FindByClass( "campaignents_forcefield_new" ) ) do
        field.fieldShouldCollideCache[ spawned:GetCreationID() ] = nil

    end
end )