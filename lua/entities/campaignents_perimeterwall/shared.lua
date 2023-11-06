AddCSLuaFile()

ENT.Type = "anim"
if WireLib then
    ENT.Base = "base_wire_entity"

else
    ENT.Base = "base_gmodentity" -- :(

end

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Combine Perimeter Wall"
ENT.Author      = "straw wage"
ENT.Purpose     = "Crushes stuff."
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.PhysgunDisabled = true
ENT.Editable    = true
ENT.DefaultModel = "models/props_combine/combineinnerwall001a.mdl"

if CLIENT then
    language.Add( "campaignents_perimeterwall", ENT.PrintName )

end

function ENT:SetupDataTables()
    self:NetworkVar( "Bool",    0, "DoRandomSteps",     { KeyName = "dorandomsteps",        Edit = { order = 1, type = "Bool", min = 0, max = 8 } } )
    self:NetworkVar( "Int",     0, "MaxSteps",          { KeyName = "maxsteps",             Edit = { order = 2, type = "Int", min = -1, max = 8 } } )
    self:NetworkVar( "Int",     2, "RandomStepChance",  { KeyName = "randomstepchance",     Edit = { order = 3, type = "Int", min =  1, max = 100 } } )
    self:NetworkVar( "Bool",    1, "DoInternalWall",    { KeyName = "dointernalwall",       Edit = { order = 4, type = "Bool", min = 0, max = 8 } } )
    self:NetworkVar( "Int",     1, "ActivationDist",    { KeyName = "activationdist",       Edit = { order = 5, type = "Int", min =  1, max = 12000 } } )
    self:NetworkVar( "Int",     3, "DustParticleCount", { KeyName = "dustparticlecount",    Edit = { order = 6, type = "Int", min =  0, max = 25 } } )

    self:NetworkVar( "Bool",    2, "On",                { KeyName = "on",                   Edit = { readonly = true } } )
    self:NetworkVar( "Bool",    3, "HasSetPosEmbed",    { KeyName = "hassetposembed",       Edit = { readonly = true } } )
    self:NetworkVar( "Float",   0, "Step",              { KeyName = "step",                 Edit = { readonly = true } } )
    self:NetworkVar( "Vector",  0, "OriginalPos",       { KeyName = "originalpos",          Edit = { readonly = true } } )

    if SERVER then
        self:SetDoRandomSteps( true )
        self:SetDoInternalWall( true )

        self:SetMaxSteps( 2 )
        self:SetActivationDist( 2500 )
        self:SetRandomStepChance( 25 )
        self:SetDustParticleCount( 20 )

        self:SetOn( true )
        self:SetHasSetPosEmbed( false )
        self:SetStep( 0 )

        self:NetworkVarNotify( "DoInternalWall", function( _, _, _, _ )
            timer.Simple( 0, function()
                if not IsValid( self ) then return end
                self:DoInternalWall()

            end )
        end )
        self:NetworkVarNotify( "OriginalPos", function( _, _, _, _ )
            timer.Simple( 0, function()
                if not IsValid( self ) then return end
                self:DoInternalWall()

            end )
        end )
    end
end

function ENT:Draw()
    self:DrawModel()

end

if not SERVER then return end

-- positions left/right of walls
local connectionOffsets = {
    Vector( 0, 80, 0 ),
    Vector( 0, -80, 0 ),

}

function ENT:SpawnFunction( spawner, tr )
    local SpawnPos = tr.HitPos + vector_up * 25
    local ent = ents.Create( self.ClassName )
    ent:SetPos( SpawnPos )

    if IsValid( spawner ) and spawner.EyeAngles then
        local flat = spawner:GetAimVector()
        flat.z = 0
        flat:Normalize()

        local rand = VectorRand()
        rand.z = 0
        rand:Normalize()
        rand = rand * 0.15

        local ang = ( -( flat + rand ) ):Angle()
        local newAng = Angle( 0, ang.y, 0 )
        ent:SetAngles( newAng )

    end

    ent:Spawn()

    local effectdata = EffectData()
    effectdata:SetEntity( ent )
    util.Effect( "propspawn", effectdata )

    return ent

end

function ENT:SetupSessionVars()
    self:SetStep( 0 )
    self:DoStepLater()

    self.internalWall = nil
    self.oldFraction = 0
    self.oldUpOffset = 0
    self.nextShake = 0
    self.takingAStep = false
    self.stepType = 0
    self.wasClosePly = nil
    self.stepsTaken = 0
    self.wasEnabledAi = nil

    self.oldAttachedTo = nil

end

local snapWiggleRoom = 100
local no_ang = Angle( 0, 0, 0 )

function ENT:Initialize()
    if SERVER then
        self:SetupSessionVars()

        self:SetModel( self.DefaultModel )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_NONE )

        self:GetPhysicsObject():SetMass( 50000 )
        self:GetPhysicsObject():EnableMotion( false )

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:SelfSetup()

            timer.Simple( 0, function()
                if not IsValid( self ) then return end

                local myClosest, theirClosest, closest = self:GetBestToAttachTo()

                if myClosest and theirClosest then
                    local randVert = vector_up * math.random( -10, 10 )
                    local originalPos = self:GetPos()
                    local myAngs = self:GetAngles()

                    self:EmitSound( "physics/metal/metal_canister_impact_hard3.wav", 90, math.random( 40, 50 ) )
                    local offsetFromThem = connectionOffsets[ theirClosest.attachId ]
                    local offsetFromMe = -connectionOffsets[ myClosest.attachId ]
                    offsetFromMe:Rotate( myAngs )

                    local newPos = closest:LocalToWorld( offsetFromThem ) + offsetFromMe + randVert

                    -- the hl2 wall models stagger the walls forward/back, so we do too!
                    local offsetNeeded = WorldToLocal( originalPos, no_ang, newPos, myAngs )[1]
                    offsetNeeded = math.Clamp( offsetNeeded, -snapWiggleRoom + ( snapWiggleRoom / 2 ), snapWiggleRoom + -( snapWiggleRoom / 2 ) )
                    local offset = self:GetForward() * offsetNeeded
                    local offsettedPos = newPos + offset
                    self:SetPos( offsettedPos )

                    self:SetOriginalPos( self:GetPos() )

                -- don't drift slowly into the ground PLS!
                else
                    local groundPos = util.QuickTrace( self:GetPos(), -vector_up * 1000, { self, self.internalWall } ).HitPos
                    local newPos = groundPos + vector_up * math.random( 440, 460 )
                    self:SetPos( newPos )

                    self:SetOriginalPos( self:GetPos() )

                end
            end )

            self:DoInternalWall()

        end )

    end

    if not WireLib then return end

    self.Inputs = Wire_CreateInputs( self, { "ForceStep", "On" } )
    self.Outputs = Wire_CreateOutputs( self, { "StepsTaken" } )

end

function ENT:TriggerInput( iname, value )
    if iname == "On" then
        if value >= 1 then
            self:SetOn( true )

        else
            self:SetOn( false )

        end
    elseif iname == "ForceStep" then
        if value >= 1 then
            self.takingAStep = true
            self.stepType = 1

        end
    end
end

local internalWallPos = Vector( 0,0,-97 )

function ENT:DoInternalWall( doWall )
    doWall = doWall or self:GetDoInternalWall()

    local internalWall = self.internalWall
    if IsValid( internalWall ) then
        SafeRemoveEntity( internalWall )

    end
    if doWall == true then
        internalWall = ents.Create( "prop_physics" )
        internalWall:SetPos( self:LocalToWorld( internalWallPos ) )
        internalWall:SetAngles( self:GetAngles() )
        internalWall:SetModel( "models/props_combine/combineinnerwall001c.mdl" )
        internalWall:Spawn()

        internalWall:GetPhysicsObject():EnableMotion( false )

        internalWall.PhysgunDisabled = true
        internalWall.DoNotDuplicate = true
        self:DeleteOnRemove( internalWall )

        self.internalWall = internalWall

    end
end

local nextMessage = 0
function ENT:SelfSetup()
    if self.duplicatedIn then return end
    if nextMessage > CurTime() then return end
    if campaignents_EnabledAi() then
        local MSG = "I slowly advance when spawned into chains!\nI'll stop after 'stepping' two times!\nYou can config that though!"
        self:TryToPrintOwnerMessage( MSG )
        timer.Simple( 0, function()
            MSG = "I'll only take 'steps' when a player is nearer than my ActivationDist, set it to max to disable this!\nUncheck DoIntenralWall to get rid of the barrier inside me!\nThis message will not appear when duped in."
            self:TryToPrintOwnerMessage( MSG )

        end )
        nextMessage = CurTime() + 25

    end
end

function ENT:OnDuplicated()
    self.duplicatedIn = true
    self:SetupSessionVars()

end

function ENT:DoStepLater()
    self.nextStep = CurTime() + math.Rand( 0, 45 )

end

local tooFar = 140
local tooFarHalf = ( tooFar / 2 ) ^ 2
tooFar = tooFar^2
local stepDist = 120

function ENT:CanStep()
    local maxSteps = self:GetMaxSteps()
    if maxSteps ~= -1 and ( self.stepsTaken + 1 ) > self:GetMaxSteps() then return end

    local stepOffset = self:GetForward() * stepDist
    if not util.IsInWorld( self:GetPos() + stepOffset ) then return end

    return true

end

function ENT:DecideToTakeAStep()
    if not self:GetDoRandomSteps() then return end

    if not self:CanStep() then return end

    if self.nextStep > CurTime() then return end
    if self.GetRandomStepChance and math.random( 1, 100 ) > self:GetRandomStepChance() then self:DoStepLater() return end

    -- only step when ply was near one time!
    if self.wasClosePly ~= true then
        local activationDist = self:GetActivationDist()
        if activationDist >= 11999 then self.wasClosePly = true return end

        activationDist = activationDist^2

        local myPos = self:GetPos()
        local allPlayers = player.GetAll()
        local wasClose = nil
        for _, ply in ipairs( allPlayers ) do
            if ply:GetPos():DistToSqr( myPos ) < activationDist then
                wasClose = true
                break

            end
        end

        if not wasClose then self:DoStepLater() return end
        self.wasClosePly = true

    end

    local myClosest, theirClosest, theAttached = self:GetBestToAttachTo()

    if IsValid( theAttached ) and theAttached.takingAStep then return end

    if not myClosest and not theirClosest then self:DoStepLater() return end

    local stepOffset = self:GetForward() * stepDist
    local myClosestWorld = self:LocalToWorld( connectionOffsets[ myClosest.attachId ] )
    local theirClosestWorld = theAttached:LocalToWorld( connectionOffsets[ theirClosest.attachId ] )
    local whereConnectionEndsUp = myClosestWorld + stepOffset

    if whereConnectionEndsUp:DistToSqr( theirClosestWorld ) > tooFar then self:DoStepLater() return end

    timer.Simple( 1, function()
        if not IsValid( self ) then return end
        self.takingAStep = true
        self.stepType = 1

    end )
end

local wallAlmostBottom = Vector( 100, 0, -400 )
local wallHalfBottom = Vector( 100, 0, -200 )

local stepSize = 1
local stepHeight = { 300, 0 }
local transition = 0.85
local rate = { 0.0015, 0.01 }

function ENT:Think()
    if not self:GetOn() then return end

    local enabledAi = campaignents_EnabledAi()
    if self.wasEnabledAi ~= enabledAi then
        self.wasEnabledAi = enabledAi
        self:DoStepLater()
        self:ResetSteps()

    end

    if enabledAi ~= true then return end

    if self.takingAStep == false then
        self:DecideToTakeAStep()

    else
        local pos = self:GetOriginalPos()

        local stepType = self.stepType
        local rateInt = rate[ stepType ]
        local heightInt = stepHeight[ stepType ]

        -- increase internal step
        local oldStep = self:GetStep()
        local newStep = oldStep + rateInt
        self:SetStep( newStep )

        -- modulo
        local newStepMod = ( newStep % stepSize )
        local oldFraction = self.oldFraction
        local fraction = ( newStep % 1 )
        self.oldFraction = fraction

        if fraction >= 0.01 and oldFraction <= 0.01 then
            self.oldAttachedTo = {}
            local _, _, _, potentiallyAttached = self:GetBestToAttachTo()
            if potentiallyAttached and #potentiallyAttached >= 1 then
                for _, potAtt in ipairs( potentiallyAttached ) do
                    if IsValid( potAtt ) and potAtt ~= self and self:IsConnectedToWall( potAtt, tooFar ) then
                        table.insert( self.oldAttachedTo, potAtt )

                    end
                end
            end
            self:DoStepLater()
            if stepType == 1 then
                self:EmitSound( "ambient/machines/wall_move5.wav", 90, 100, 1, CHAN_STATIC )
                self:EmitSound( "ambient/machines/floodgate_stop1.wav", 83, 80, 1, CHAN_STATIC )

            elseif stepType == 2 then
                self:EmitSound( "ambient/machines/wall_move1.wav", 90, 100, 1, CHAN_STATIC )
                self:WallSlideStart()

            end
        end

        if fraction >= 0.35 and oldFraction <= 0.35 and stepType == 1 then
            self:EmitSound( "ambient/machines/wall_move2.wav", 90, 95, 1, CHAN_STATIC )

        end

        if fraction >= 0.99 and oldFraction <= 0.99 then
            local distCheck = tooFarHalf
            if stepType == 2 then
                distCheck = tooFar

            end
            for _, attached in ipairs( self.oldAttachedTo ) do
                if IsValid( attached ) and not attached.takingAStep and attached:CanStep() and not self:IsConnectedToWall( attached, distCheck ) then
                    attached.takingAStep = true
                    attached.stepType = 2
                    attached:NextThink( CurTime() + math.Rand( 0.75, 1.5 ) )

                end
            end

            self.takingAStep = false
            self.stepsTaken = self.stepsTaken + 1

            if stepType == 1 then
                self:EmitSound( "ambient/machines/wall_crash1.wav", 90, 100 + math.random( -5, 5 ), 1, CHAN_STATIC )
                self:WallLand()

            end
            if WireLib then
                Wire_TriggerOutput( self, "StepsTaken", self.stepsTaken )

            end
        end

        local upOffset
        if newStepMod < transition then
            upOffset = Lerp( math.ease.OutQuart( fraction * transition ), 0, heightInt )

        else
            local outFraction = ( -transition + fraction ) * 7.5
            upOffset = Lerp( math.ease.InExpo( outFraction ), heightInt, 0 )

        end

        local offset = self:GetForward() * ( newStep * stepDist )
        offset = offset + ( self:GetUp() * upOffset )

        local newPos = pos + offset

        self:SetPos( newPos )

        if self.nextShake < CurTime() then
            self.nextShake = CurTime() + 0.5
            local diff = math.abs( upOffset - self.oldUpOffset )
            if fraction < 0.95 then
                util.ScreenShake( self:GetPos(), diff / 2, 20, 3, 1500 )

                sound.EmitHint( SOUND_DANGER, self:LocalToWorld( wallAlmostBottom ), 600, 2, self )

            end
            self.oldUpOffset = upOffset

            if stepType == 2 then
                self:WallSlide()

            end
        end

        self:NextThink( CurTime() )
        return true

    end
end

function ENT:PreEntityCopy()
    self:ResetSteps()

end

function ENT:ResetSteps()
    self:SetPos( self:GetOriginalPos() )
    self:SetStep( 0 )
    self:DoStepLater()
    self.takingAStep = false
    self.wasClosePly = false
    self.stepsTaken = 0
    if not WireLib then return end
    Wire_TriggerOutput( self, "StepsTaken", self.stepsTaken )

end

function ENT:WallSlideStart()
    local scale = 12.5
    if self.GetDustParticleCount then
        scale = self:GetDustParticleCount() / 2

    end
    scale = math.Round( scale )
    local dust = EffectData()
    dust:SetOrigin( self:LocalToWorld( wallAlmostBottom ) )
    dust:SetNormal( self:GetForward() )
    dust:SetScale( scale )
    util.Effect( "eff_campaignents_dustpuff", dust )

end

function ENT:WallSlide()

    local splode = ents.Create( "env_explosion" )
    splode:SetOwner( self )
    splode:SetPos( self:LocalToWorld( wallAlmostBottom ) )
    splode:SetKeyValue( "spawnflags", bit.bor( 4, 64, 512, 16384 ) )
    splode:SetKeyValue( "iMagnitude", 500 )
    splode:SetKeyValue( "iRadiusOverride", 200 )
    splode:Spawn()
    splode:Activate()
    splode:Fire( "Explode" )

    SafeRemoveEntityDelayed( splode, 0.1 )

    local splodeTwo = ents.Create( "env_explosion" )
    splodeTwo:SetOwner( self )
    splodeTwo:SetPos( self:LocalToWorld( wallHalfBottom ) )
    splodeTwo:SetKeyValue( "spawnflags", bit.bor( 4, 64, 512, 16384 ) )
    splodeTwo:SetKeyValue( "iMagnitude", 500 )
    splodeTwo:SetKeyValue( "iRadiusOverride", 200 )
    splodeTwo:Spawn()
    splodeTwo:Activate()
    splodeTwo:Fire( "Explode" )

    SafeRemoveEntityDelayed( splodeTwo, 0.1 )

    -- create second splode, with bigger radius but like no damage, warns player not to get close ig
    local splodeWarning = ents.Create( "env_explosion" )
    splodeWarning:SetOwner( self )
    splodeWarning:SetPos( self:LocalToWorld( wallAlmostBottom ) )
    splodeWarning:SetKeyValue( "spawnflags", bit.bor( 4, 64, 512, 16384 ) )
    splodeWarning:SetKeyValue( "iMagnitude", 15 )
    splodeWarning:SetKeyValue( "iRadiusOverride", 500 )
    splodeWarning:Spawn()
    splodeWarning:Activate()
    splodeWarning:Fire( "Explode" )

    SafeRemoveEntityDelayed( splodeWarning, 0.1 )


    local shoveProp = ents.Create( "env_physexplosion" )
    shoveProp:SetOwner( self )
    shoveProp:SetPos( self:LocalToWorld( wallAlmostBottom ) )
    shoveProp:SetKeyValue( "spawnflags", bit.bor( 1, 4 ) )
    shoveProp:SetKeyValue( "magnitude", 10000 )
    shoveProp:SetKeyValue( "radius", 400 )
    shoveProp:Spawn()
    shoveProp:Activate()
    shoveProp:Fire( "Explode" )

    SafeRemoveEntityDelayed( shoveProp, 0.1 )

end

function ENT:WallLand()
    sound.EmitHint( SOUND_THUMPER, self:LocalToWorld( wallAlmostBottom ), 1800, 10, self )

    util.ScreenShake( self:GetPos(), 80, 15, 5, 2000, true )
    util.ScreenShake( self:GetPos(), 3, 20, 10, 4000, true )

    local splode = ents.Create( "env_explosion" )
    splode:SetOwner( self )
    splode:SetPos( self:LocalToWorld( wallAlmostBottom ) )
    splode:SetKeyValue( "spawnflags", bit.bor( 4, 64, 512, 16384 ) )
    splode:SetKeyValue( "iMagnitude", 1000 )
    splode:SetKeyValue( "iRadiusOverride", 300 )
    splode:Spawn()
    splode:Activate()
    splode:Fire( "Explode" )

    SafeRemoveEntityDelayed( splode, 0.1 )


    local splodeTwo = ents.Create( "env_explosion" )
    splodeTwo:SetOwner( self )
    splodeTwo:SetPos( self:LocalToWorld( wallHalfBottom ) )
    splodeTwo:SetKeyValue( "spawnflags", bit.bor( 4, 64, 512, 16384 ) )
    splodeTwo:SetKeyValue( "iMagnitude", 1000 )
    splodeTwo:SetKeyValue( "iRadiusOverride", 300 )
    splodeTwo:Spawn()
    splodeTwo:Activate()
    splodeTwo:Fire( "Explode" )

    SafeRemoveEntityDelayed( splodeTwo, 0.1 )


    -- create second splode, with bigger radius but like no damage, warns player not to get close ig
    local splodeWarning = ents.Create( "env_explosion" )
    splodeWarning:SetOwner( self )
    splodeWarning:SetPos( self:LocalToWorld( wallAlmostBottom ) )
    splodeWarning:SetKeyValue( "spawnflags", bit.bor( 4, 64, 512, 16384 ) )
    splodeWarning:SetKeyValue( "iMagnitude", 30 )
    splodeWarning:SetKeyValue( "iRadiusOverride", 500 )
    splodeWarning:Spawn()
    splodeWarning:Activate()
    splodeWarning:Fire( "Explode" )

    SafeRemoveEntityDelayed( splodeWarning, 0.1 )


    local shoveProp = ents.Create( "env_physexplosion" )
    shoveProp:SetOwner( self )
    shoveProp:SetPos( self:LocalToWorld( wallAlmostBottom ) )
    shoveProp:SetKeyValue( "spawnflags", bit.bor( 1, 4 ) )
    shoveProp:SetKeyValue( "magnitude", 120000 )
    shoveProp:SetKeyValue( "radius", 500 )
    shoveProp:Spawn()
    shoveProp:Activate()
    shoveProp:Fire( "Explode" )

    SafeRemoveEntityDelayed( shoveProp, 0.1 )


    local scale = 25
    if self.GetDustParticleCount then
        scale = self:GetDustParticleCount()

    end
    local dust = EffectData()
    dust:SetOrigin( self:LocalToWorld( wallAlmostBottom ) )
    dust:SetNormal( self:GetForward() )
    dust:SetScale( scale )
    util.Effect( "eff_campaignents_dustpuff", dust )


end

local minDist = 350^2

function ENT:GetBestToAttachTo()
    local myPos = self:GetPos()
    local closest
    local others = ents.FindByClass( self.ClassName )
    local potentiallyConnected = {}
    if #others >= 1 then
        local maxDist = math.huge

        for _, other in ipairs( others ) do
            local distToOther = other:GetPos():DistToSqr( myPos )
            if other ~= self and not other.takingAStep and distToOther < minDist then
                table.insert( potentiallyConnected, other )
                if distToOther < maxDist then
                    maxDist = distToOther
                    closest = other

                end
            end
        end
    end
    if IsValid( closest ) then
        local isConnected, myClosest, theirClosest = self:IsConnectedToWall( closest, tooFar )
        if not isConnected then return end
        return myClosest, theirClosest, closest, potentiallyConnected

    end
end

function ENT:IsConnectedToWall( ent, distNeeded )
    local myPos = self:GetPos()
    local attachments = {}
    for id, attach in ipairs( connectionOffsets ) do
        table.insert( attachments, { attachId = id, pos = ent:LocalToWorld( attach ) } )

    end
    local myClosest
    local theirClosest
    local isConnected
    local nearestAttachDist = math.huge
    local furthesAttachDist = 0

    for _, attach in ipairs( attachments ) do
        local dist = myPos:DistToSqr( attach.pos )
        if dist < nearestAttachDist then
            theirClosest = attach
            nearestAttachDist = dist

        end
        if dist > furthesAttachDist then
            myClosest = attach
            furthesAttachDist = dist

        end
    end
    if myClosest and theirClosest then
        local myClosestWorld = self:LocalToWorld( connectionOffsets[ myClosest.attachId ] )
        local theirClosestWorld = ent:LocalToWorld( connectionOffsets[ theirClosest.attachId ] )
        if myClosestWorld:DistToSqr( theirClosestWorld ) < distNeeded then
            isConnected = true

        end
    end

    return isConnected, myClosest, theirClosest

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