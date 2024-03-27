AddCSLuaFile( "autorun/client/campaignents_clientfuncs.lua" )
AddCSLuaFile()

local aiVar = GetConVar( "ai_disabled" )

function campaignents_EnabledAi()
    return aiVar:GetInt() == 0

end

local ignorePly = GetConVar( "ai_ignoreplayers" )

function campaignents_IgnoringPlayers()
    return ignorePly:GetInt() == 1

end

--[[
local noclipCached
local noclipNextCache = 0
function campaignents_IsAPlayerInNoclip()
    if not noclipCached or noclipNextCache < CurTime() then
        noclipNextCache = CurTime() + 0.1
        noclipCached = false
        for _, ply in ipairs( player.GetAll() ) do
            if ply:CampaignEnts_IsInNoclip() then
                noclipCached = true
                break

            end
        end
    end
    return noclipCached

end
--]]

local meta = FindMetaTable( "Player" )
function meta:CampaignEnts_IsInNoclip()
    local moveType = self:GetMoveType()
    if moveType ~= MOVETYPE_NOCLIP then return end
    if self:InVehicle() then return end
    return true

end

local doFadeDist = CreateConVar( "campaignents_sv_fadeents", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Enable/disable the fadeout on laggy Campaign Entities?" )

function campaignents_doFadeDistance( ent, dist )
    if not doFadeDist:GetBool() then return end

    ent:SetKeyValue( "fademindist", dist )
    ent:SetKeyValue( "fademaxdist", dist + ( dist / 10 ) )

end


function campaignents_captureGoalID( self )
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
        local randId = math.random( 1, 1000 )
        self:SetGoalID( randId )
        theHit:SetGoalID( randId )
        self:EmitSound( "buttons/button24.wav" )

    elseif self:GetGoalID() ~= theHit:GetGoalID() then
        self:SetGoalID( theHit:GetGoalID() )
        self:EmitSound( "buttons/button24.wav" )

    end
end

local doHints = CreateConVar( "campaignents_sv_hints", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Enable/disable the campaign entity hints?" )

function campaignents_MessageOwner( ent, message )
    if not doHints:GetBool() then return end

    local owner
    if CPPI then
        owner = ent:CPPIGetOwner()

    end
    if not IsValid( owner ) and IsValid( ent:GetCreator() ) then
        owner = ent:GetCreator()

    end
    if not IsValid( owner ) and IsValid( ent:GetOwner() ) then
        owner = ent:GetOwner()

    end
    -- check if player, GetOwner is used all over, eg, headcrab shot off of a zombie
    if IsValid( owner ) and owner.PrintMessage then
        owner:PrintMessage( HUD_PRINTTALK, message )
        return

    end
    -- leave poor dedicated servers alone :(
    if game.IsDedicated() then return end

    PrintMessage( HUD_PRINTTALK, message )

end

function campaignEnts_EasyFreeze( ent )
    local phys = ent:GetPhysicsObject()
    if phys:IsValid() then
        -- stop annoying bouncing off plug, when plugged after spawning!
        phys:EnableMotion( false )

    end
end