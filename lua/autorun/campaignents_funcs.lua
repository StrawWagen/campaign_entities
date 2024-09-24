AddCSLuaFile( "autorun/client/campaignents_clientfuncs.lua" )
AddCSLuaFile()

CAMPAIGN_ENTS = CAMPAIGN_ENTS or {}

local aiVar = GetConVar( "ai_disabled" )
local nextCache = 0
local cached = false
local CurTime = CurTime

function CAMPAIGN_ENTS.EnabledAi()
    local cur = CurTime()
    if nextCache > cur then
        return cached

    end
    nextCache = cur + 0.05
    cached = aiVar:GetInt() == 0
    return cached

end

local ignorePly = GetConVar( "ai_ignoreplayers" )

function CAMPAIGN_ENTS.IgnoringPlayers()
    return ignorePly:GetInt() == 1

end

--[[
local noclipCached
local noclipNextCache = 0
function CAMPAIGN_ENTS.IsAPlayerInNoclip()
    if not noclipCached or noclipNextCache < CurTime() then
        noclipNextCache = CurTime() + 0.1
        noclipCached = false
        for _, ply in ipairs( player.GetAll() ) do
            if ply:CAMPAIGN_ENTS.IsInNoclip() then
                noclipCached = true
                break

            end
        end
    end
    return noclipCached

end
--]]

local meta = FindMetaTable( "Player" )
function meta:campaignents_IsInNoclip()
    local moveType = self:GetMoveType()
    if moveType ~= MOVETYPE_NOCLIP then return end
    if self:InVehicle() then return end
    return true

end

local doFadeDist = CreateConVar( "campaignents_sv_fadeents", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Enable/disable the fadeout on laggy Campaign Entities?" )

function CAMPAIGN_ENTS.doFadeDistance( ent, dist )
    if not doFadeDist:GetBool() then return end

    ent:SetKeyValue( "fademindist", dist )
    ent:SetKeyValue( "fademaxdist", dist + ( dist / 10 ) )

end


function CAMPAIGN_ENTS.captureGoalID( self )
    if not self.GetGoalID then return end
    local simpleCollider = util.QuickTrace( self:GetPos(), vector_up * 1, self )

    local theHit = simpleCollider.Entity

    local radius = 15
    if self:GetGoalID() == -1 then
        radius = 100

    end

    if not IsValid( theHit ) then
        local stuff = ents.FindInSphere( self:GetPos(), radius )
        for _, thing in ipairs( stuff ) do
            if thing ~= self and thing.GetGoalID then
                theHit = thing

            end
        end
    end

    if not IsValid( theHit ) then return end
    if not theHit.GetGoalID then return end

    local dist = theHit:GetPos():Distance( self:GetPos() )

    if dist > 15 and self:GetGoalID() == -1 and theHit:GetGoalID() == -1 then return end

    if self:GetGoalID() == -1 and theHit:GetGoalID() == -1 then
        local occupiedGoalIds = {}
        for _, curr in ents.Iterator() do
            if curr.GetGoalID and curr:GetGoalID() ~= -1 then
                occupiedGoalIds[curr:GetGoalID()] = true

            end
        end

        local randId = nil
        -- if this fails 1000 times then sorry you're screwed
        for _ = 1, 1000 do
            if randId and not occupiedGoalIds[randid] then break end
            randId = math.random( 1, 10000 )

        end

        self:SetGoalID( randId )
        theHit:SetGoalID( randId )
        self:EmitSound( "buttons/button24.wav" )

    elseif self:GetGoalID() ~= theHit:GetGoalID() then
        self:SetGoalID( theHit:GetGoalID() )
        self:EmitSound( "buttons/button24.wav" )

    end
end

function CAMPAIGN_ENTS.GetOwner( ent )
    local owner
    if CPPI and ent.CPPIGetOwner then
        owner = ent:CPPIGetOwner()

    end
    if not IsValid( owner ) and IsValid( ent:GetCreator() ) then
        owner = ent:GetCreator()

    end
    if not IsValid( owner ) and IsValid( ent:GetOwner() ) then
        owner = ent:GetOwner()

    end
    if not IsValid( owner ) then
        owner = nil

    end
    return owner

end


local doHints = CreateConVar( "campaignents_sv_hints", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Enable/disable the campaign entity hints?" )

function CAMPAIGN_ENTS.MessageOwner( ent, message )
    if not doHints:GetBool() then return end

    local owner = CAMPAIGN_ENTS.GetOwner( ent )

    -- check if player, GetOwner is used all over, eg, headcrab shot off of a zombie
    if IsValid( owner ) and owner.PrintMessage then
        owner:PrintMessage( HUD_PRINTTALK, message )
        return

    end
    -- leave poor dedicated servers alone :(
    if game.IsDedicated() then return end

    PrintMessage( HUD_PRINTTALK, message )

end

function CAMPAIGN_ENTS.EasyFreeze( ent )
    local phys = ent:GetPhysicsObject()
    if phys:IsValid() then
        -- stop annoying bouncing off plug, when plugged after spawning!
        phys:EnableMotion( false )

    end
end

function CAMPAIGN_ENTS.filterAllPlayers()
    local filterAllPlayers = RecipientFilter()
    filterAllPlayers:AddAllPlayers()
    return filterAllPlayers

end

local thatExists = {}

function CAMPAIGN_ENTS.EnsureOnlyOneExists( ent )
    if not IsValid( ent ) then return end
    local class = ent:GetClass()
    local occupier = thatExists[ class ]
    if IsValid( occupier ) then
        if occupier == ent then ErrorNoHaltWithStack() end 
        occupier.campaignents_Overriden = true
        SafeRemoveEntity( occupier )

    end
    thatExists[ class ] = ent
    return ent

end

function CAMPAIGN_ENTS.OneThatExists( class )
    return thatExists[ class ]

end

    