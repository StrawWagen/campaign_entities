AddCSLuaFile()

ENT.Type = "anim"
if WireLib then
    ENT.Base = "base_wire_entity"

else
    ENT.Base = "base_gmodentity" -- :(

end

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Custom Soundscape"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Plays ambient sounds for players that get near"
ENT.Spawnable    = true
ENT.AdminOnly    = false

ENT.Editable    = true
ENT.Model       = "models/props_wasteland/speakercluster01a.mdl"
ENT.Material    = "lights/white001"
ENT.ThinkInterval = 0.25

local function PosCanSee( startPos, endPos, filterIn )
    if not startPos then return end
    if not endPos then return end

    local mask = {
        start = startPos,
        endpos = endPos,
        mask = MASK_SHOT,
        filter = filterIn
    }
    local trace = util.TraceLine( mask )
    return not trace.Hit, trace

end

function ENT:SetupDataTables()
    self:NetworkVar( "String",  0, "SoundPath",         { KeyName = "soundpath",        Edit = { order = 1, type = "String" } } )
    self:NetworkVar( "Bool",    0, "IsAmbient",         { KeyName = "isambient",        Edit = { order = 2, type = "Bool" } } )
    self:NetworkVar( "Bool",    1, "FadeBehindWalls",   { KeyName = "fadebehindwalls",  Edit = { order = 3, type = "Bool" } } )
    self:NetworkVar( "Bool",    2, "IsOn",              { KeyName = "ison",             Edit = { readonly = true } } )
    self:NetworkVar( "Bool",    3, "FadeOut",           { KeyName = "fadeout",          Edit = { order = 4, type = "Bool" } } )
    self:NetworkVar( "Int",     0, "Distance",          { KeyName = "distance",         Edit = { order = 4, type = "Int", min = 0, max = 32000 } } )
    self:NetworkVar( "Int",     1, "Pitch",             { KeyName = "pitch",            Edit = { order = 5, type = "Int", min = 0, max = 200 } } )
    self:NetworkVar( "Int",     2, "Decibels",          { KeyName = "decibels",         Edit = { order = 6, type = "Int", min = 0, max = 150 } } )
    self:NetworkVar( "Int",     3, "DSP",               { KeyName = "sounddsp",         Edit = { order = 7, type = "Int", min = 0, max = 200 } } )
    self:NetworkVar( "Int",     4, "MaxPlayCount",      { KeyName = "maxplaycount",     Edit = { order = 8, type = "Int", min = 0, max = 200 } } )
    self:NetworkVar( "Float",   0, "Volume",            { KeyName = "volume",           Edit = { order = 9, type = "Float", min = 0, max = 1 } } )
    self:NetworkVar( "Vector",  0, "DebugColor",        { KeyName = "debugcolor",       Edit = { order = 10, type = "VectorColor" } } )

    self:NetworkVarNotify( "DebugColor", function()
        if not IsValid( self ) then return end
        self:DoColor()
    end )

    self:NetworkVarNotify( "IsAmbient", function()
        if not IsValid( self ) then return end
        if not self.actualSound then return end
        self:destroySound()

        timer.Simple( 0.1, function()
            if not IsValid( self ) then return end
            self:setupSound( self.ThinkInterval )
            self:ResetData()

        end )
    end )

    self:NetworkVarNotify( "FadeBehindWalls", function()
        if not IsValid( self ) then return end
        if not self.actualSound then return end
        self:destroySound()

        timer.Simple( 0.1, function()
            if not IsValid( self ) then return end
            self:setupSound( self.ThinkInterval )
            self:ResetData()

        end )
    end )

    -- wiremod
    self:NetworkVarNotify( "IsOn", function()
        if not IsValid( self ) then return end
        if not self.actualSound then return end

        self:StopOurSound()

        timer.Simple( 0.1, function()
            if not IsValid( self ) then return end
            self:setupSound( self.ThinkInterval )
            self:ResetData()

        end )
    end )

    self:NetworkVarNotify( "Decibels", function()
        if not IsValid( self ) then return end
        if not self.actualSound then return end
        self:destroySound()

        timer.Simple( 0.1, function()
            if not IsValid( self ) then return end
            self:setupSound( self.ThinkInterval )
            self:ResetData()

        end )
    end )

    self:NetworkVarNotify( "SoundPath", function()
        if not IsValid( self ) then return end
        if not self.actualSound then return end
        self:destroySound()

        timer.Simple( 0.1, function()
            if not IsValid( self ) then return end
            self:setupSound( self.ThinkInterval )
            self:ResetData()

        end )
    end )

    self:NetworkVarNotify( "DSP", function()
        if not IsValid( self ) then return end
        if not self.actualSound then return end
        self:destroySound()

        timer.Simple( 0.1, function()
            if not IsValid( self ) then return end
            self:setupSound( self.ThinkInterval )
            self:ResetData()

        end )
    end )

    self:NetworkVarNotify( "MaxPlayCount", function()
        if not IsValid( self ) then return end
        if not self.actualSound then return end
        self:destroySound()

        timer.Simple( 0.1, function()
            if not IsValid( self ) then return end
            self:setupSound( self.ThinkInterval )
            self:ResetData()

        end )
    end )

    if SERVER then
        local vec = Vector( 1, 1, 1 )
        vec:Random( 1, 0 )
        vec:Normalize()
        self:SetDebugColor( vec )
        self:DoColor()

        self:SetSoundPath( "ambient/atmosphere/elev_shaft1.wav" )

        self:SetDistance( 1000 )
        self:SetVolume( 1 )
        self:SetPitch( 100 )
        self:SetDecibels( 75 ) -- SNDLVL_NORM
        self:SetDSP( 0 )
        self:SetMaxPlayCount( 0 )

        self:SetIsAmbient( true )
        self:SetFadeOut( true )
        self:SetFadeBehindWalls( true )
        self:SetIsOn( true )

    end
end

function ENT:ResetData()
    if not CLIENT then return end
    self.playedCount = 0

end

function ENT:OnDuplicated()
    if not CLIENT then return end
    self:ResetData()

end

function ENT:Initialize()
    if SERVER then
        self:SetModel( self.Model )

        self:SetMaterial( self.Material )
        self:SetNoDraw( false )
        self:DrawShadow( false )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_WORLD )

        CAMPAIGN_ENTS.EasyFreeze( self )
        CAMPAIGN_ENTS.doFadeDistance( self, 5000 )

        if WireLib then
            self.Inputs = WireLib.CreateSpecialInputs( self, { "On", "SoundPath" }, { "NORMAL", "STRING" } )

        end
    end
    if CLIENT then
        self:DoCircle()
        self:ResetData()

    end
    self:DoColor()

end

function ENT:TriggerInput( iname, value )
    if iname == "On" then
        if value >= 1 then
            self:SetIsOn( true )

        else
            self:SetIsOn( false )

        end
    elseif iname == "SoundPath" then
        self:SetSoundPath( value )

    end
end

function ENT:Draw()
    self:DrawModel()

end

function ENT:DoColor()
    if not CLIENT then return end
    col = self:GetDebugColor():ToColor()
    self:SetColor( col )
    self.circle:SetColor( col )

end

function ENT:DoCircle()
    local circle = ClientsideModel( "models/hunter/tubes/tube2x2x025.mdl", RENDERGROUP_OPAQUE )
    circle:SetMaterial( "lights/white001" )
    circle:SetPos( self:GetPos() )
    circle:SetParent( self )
    self.circle = circle

end

function ENT:OnRemove()
    if not CLIENT then return end
    self:destroySound()
    self.circle:Remove()

end

local vec2kUp = Vector( 0, 0, 2000 )

function ENT:Think()
    if not CLIENT then return end
    local ply = LocalPlayer()
    local cur = UnPredictedCurTime()
    local interval = self.ThinkInterval
    local nextAction = ply.nextSoundscapeActionOverride or self.nextAction or 0
    if nextAction > cur then return end

    ply.nextSoundscapeActionOverride = nil
    self.nextAction = cur + interval

    local myDist = self:GetDistance()
    local distSqr = self:GetPos():DistToSqr( ply:GetPos() ) -- this will happen alot so its sqr
    local withinDistance = distSqr < myDist^2
    local circle = self.circle

    if not IsValid( circle ) then
        self:DoCircle()

    else
        local scale = self:GetDistance() / circle:GetModelRadius()
        local oldScale = circle.oldScale or 0
        if scale ~= oldScale then
            circle.oldScale = scale
            local matrix = Matrix()
            matrix:Scale( Vector( scale, scale, 0.1 ) )
            circle:EnableMatrix( "RenderMultiply", matrix )

        end
    end

    local maxCount = self:GetMaxPlayCount()
    local aboveMax = maxCount > 0 and self.playedCount >= maxCount

    if not self.playing then -- not playing sound
        if withinDistance and self:GetIsOn() then
            if self:GetIsAmbient() and self:conflictingSoundsCount( ply ) >= 1 then
                self:DoSoundListThink( ply, nil )
                return

            end
            self.playing = true
            self:DoSoundListThink( ply, true )

        end
    elseif self.playing then -- already playing sound
        if not withinDistance or not self:GetIsOn() then
            self.playing = false
            self:DoSoundListThink( ply, false )

            if self.actualSound and self.actualSound:IsPlaying() and not aboveMax then
                self:StopOurSound()
                ply.nextSoundscapeActionOverride = CurTime() + interval

            end
        else
            -- check if we are under the sky
            local nextSkyTrace = self.nextSkyTrace or 0
            if self:GetFadeBehindWalls() and nextSkyTrace < cur then
                nextSkyTrace = cur + 5
                local skyTraceData = {}
                skyTraceData.filter = { self }
                skyTraceData.mask = MASK_SHOT
                skyTraceData.start = self:GetPos()
                skyTraceData.endpos = skyTraceData.start + vec2kUp
                local res = util.TraceLine( skyTraceData )
                local noHit = not res.HitSky and not res.Hit
                self.underSky = res.HitSky or noHit

            end

            local validSound = false
            if self.actualSound ~= nil then
                validSound = self.actualSound:IsPlaying()

            end

            if not validSound and not aboveMax then
                self.soundSetup = true
                self.playedCount = self.playedCount + 1
                self:setupSound( interval )

            elseif not aboveMax then
                self:manageSound( ply, interval )

            end
        end
    end

    if self:GetColor() ~= self:GetDebugColor():ToColor() then
        self:DoColor()

    end
    self:debugVisThink()

end

function ENT:setupSound( interval )
    if not self:GetIsOn() then return end

    local soundSource = self
    local ply = LocalPlayer()
    if self:GetIsAmbient() then
        soundSource = ply

    end
    if self.actualSound then
        self.actualSound:Stop()

    end

    local soundPathToPlay
    local pitch = self:GetPitch()
    local sounds = string.Explode( " ", self:GetSoundPath() )

    if #sounds > 1 then
        table.Shuffle( sounds )
        local lastSound = self.lastSoundPathPlayed
        for _ = 1, #sounds do
            soundPathToPlay = table.remove( sounds, 1 )
            soundPathToPlay = string.Trim( soundPathToPlay )
            if soundPathToPlay ~= lastSound then
                break

            end
        end

        self.lastSoundPathPlayed = soundPathToPlay

        local div = pitch / 100
        local donePlaying = SoundDuration( soundPathToPlay )
        local timerName = "campaignents " .. self:GetCreationID() .. "stopPlaying"

        local resetTime = donePlaying / div
        resetTime = resetTime + ( resetTime * math.Rand( 1, 2 ) )

        timer.Remove( timerName )
        timer.Create( timerName, resetTime, 1, function()
            if not IsValid( self ) then return end
            if not self.actualSound then return end
            self:destroySound()
            self.actualSound = nil

        end )
    else
        soundPathToPlay = sounds[1]
        soundPathToPlay = string.Trim( soundPathToPlay )

    end

    self.actualSound = CreateSound( soundSource, soundPathToPlay, CLocalPlayerFilter )
    self.actualPathPlaying = soundPathToPlay
    self:ResetSoundStats()
    self.actualSound:SetDSP( self:GetDSP() )
    self.actualSound:SetSoundLevel( self:GetDecibels() )
    self.actualSound:PlayEx( 0, pitch )

    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        if not IsValid( ply ) then return end
        self:manageSound( ply, interval )

    end )
end

function ENT:ActualPathPlayed()
    if self.actualPathPlaying then
        return self.actualPathPlaying

    else
        return self:GetSoundPath()

    end
end

function ENT:manageSound( listener, interval )
    if not self.actualSound then return end
    local listenerUnderSky = false

    -- by default, 'ambient' sounds need 2 things to play at full volume
    -- 1, they need to be in a large space, or under the skybox
    -- 2, they need the player to either
        -- A, have direct line of sight to the soundscape
        -- B, be in a large space, or under skybox

    if self.underSky then
        local filter = { listener }
        table.Add( filter, listener:GetChildren() )

        local skyTraceData = {}
        skyTraceData.filter = filter
        skyTraceData.mask = MASK_SHOT
        skyTraceData.start = listener:GetPos()
        skyTraceData.endpos = skyTraceData.start + vec2kUp

        local res = util.TraceLine( skyTraceData )
        local noHit = not res.HitSky and not res.Hit
        listenerUnderSky = res.HitSky or noHit

    end

    local volMul = 0.2

    if self:GetFadeBehindWalls() then
        local canSee = PosCanSee( self:GetPos(), listener:GetShootPos(), { self, listener } )
        local bothUnderSky = self.underSky and listenerUnderSky
        if canSee or bothUnderSky then
            volMul = 1

        end
    else
        volMul = 1

    end
    local volume = self:GetVolume() * volMul
    if self.soundVolume ~= volume then
        self.soundVolume = volume
        self.actualSound:ChangeVolume( volume, interval * 0.95 )

    end
    if self.soundPitch ~= self:GetPitch() then
        self.soundPitch = self:GetPitch()
        self.actualSound:ChangePitch( self:GetPitch() )

    end
end

function ENT:DoSoundListThink( ply, transition )
    if not self:GetIsAmbient() then return end
    if not IsValid( ply ) then return end
    local path = self:ActualPathPlayed()

    ply.soundsPlaying = ply.soundsPlaying or {}
    local conflictingSounds = ply.soundsPlaying[ path ] or {}
    local toRemove

    if transition == true then
        table.insert( conflictingSounds, self )

    elseif transition == false then
        toRemove = self

    end

    -- this is terrible code but it only runs on transition and it means this is foolproof
    local alreadyExists = {}
    local removedProgress = 0
    local I = 1
    while I <= table.Count( conflictingSounds ) and I < 5000 do
        local soundOrigin = conflictingSounds[I]
        if not IsValid( soundOrigin ) or ( toRemove and soundOrigin == toRemove ) or alreadyExists[ soundOrigin:EntIndex() ] then
            table.remove( conflictingSounds, I )
            if removedProgress ~= I then
                removedProgress = I
                continue

            end
        elseif IsValid( soundOrigin ) then
            alreadyExists[ soundOrigin:EntIndex() ] = true

        end
        I = I + 1

    end
    ply.soundsPlaying[ path ] = conflictingSounds

end

function ENT:WeAreTheBestSound( ply )
    if not self:GetIsAmbient() then return nil end
    local conflictingSounds = ply.soundsPlaying[ self:ActualPathPlayed() ]
    if #conflictingSounds > 1 then
        local toSort = table.Copy( conflictingSounds )
        local plysPos = ply:GetPos()
        table.sort( toSort, function( a, b )
            local aDist = a:GetPos():DistToSqr( plysPos )
            local bDist = b:GetPos():DistToSqr( plysPos )
            if aDist < bDist then return true end
            return false

        end )
        if toSort[1] == self then return true end
        return false

    end
    return true

end

function ENT:conflictingSoundsCount( ply )
    if not ply.soundsPlaying then return 0 end
    local conflictingSounds = ply.soundsPlaying[ self:ActualPathPlayed() ]
    if not conflictingSounds then return 0 end
    return #conflictingSounds

end

function ENT:ResetSoundStats()
    self.soundVolume    = nil
    self.soundPitch     = nil

end

function ENT:StopOurSound()
    if not self.GetFadeOut or self:GetFadeOut() == true then
        self.actualSound:FadeOut( self.ThinkInterval * 0.95 )

    else
        self.actualSound:Stop()

    end
end

function ENT:destroySound()
    if not self.actualSound then return end
    self:DoSoundListThink( LocalPlayer(), false )
    self.actualSound:Stop()

end

function ENT:debugVisThink()
    if not CLIENT then return end
    if self:IsDormant() then return end
    local inDevMode = CAMPAIGN_ENTS.IsEditing()
    if self:GetNoDraw() == true then -- not drawing
        if inDevMode then
            self:Reveal()

        end
    elseif self:GetNoDraw() == false then -- drawing
        if not inDevMode then
            self:Hide()

        end
    end
end

function ENT:Hide()
    self:SetNoDraw( true )
    self.circle:SetNoDraw( true )
end

function ENT:Reveal()
    self:SetNoDraw( false )
    self.circle:SetNoDraw( false )
end