
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Command Mandator"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Mandates a console command to a variable when it's pasted in"
ENT.Spawnable    = true
ENT.AdminOnly    = true
ENT.Editable = true
ENT.Model = "models/maxofs2d/cube_tool.mdl"
ENT.Material = "models/xqm/coastertrack/special_station"

local genericBlock = "campaignents_commandmandator_enabled"
local mandatorIsEnabled = CreateConVar( genericBlock, 1, FCVAR_ARCHIVE, "Enable/disable the concommand mandator." )

local dediServersCmdName = "campaignents_commandmandator_dedicatedservers"
local enabledOnDediServers = CreateConVar( dediServersCmdName, 0, FCVAR_ARCHIVE, "Allow the command mandator to work if session is dedicated?" )

function ENT:SetupDataTables()
    self:NetworkVar( "String",    1, "Command",    { KeyName = "Command Name",            Edit = { type = "String" } } )
    self:NetworkVar( "String",    2, "Variable",    { KeyName = "Override Command's var to this value",    Edit = { type = "String" } } )
    if SERVER then
        self:SetVariable( "0" )
        self:SetCommand( "" )

    end
end

function ENT:OnDuplicated()
    self.duplicatedIn = true
    self.overriddenCommand = nil
    self.defaultVariable = nil

end

function ENT:Initialize()
    if SERVER then
        self:SetModel( self.Model )
        self:SetNoDraw( false )
        self:DrawShadow( false )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_NONE )
        self:SetMaterial( self.Material )

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:BlockerSetup()

        end )
    end
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

local occupiedCommands = occupiedCommands or {}

function ENT:OccupyCommand( targetCommand )
    occupiedCommands[targetCommand] = self

end

function ENT:CanOccupyCommand( targetCommand )
    return not IsValid( occupiedCommands[targetCommand] )

end

function ENT:ActiveBlocker()
    local targetCommand = self:GetCommand()
    local cmd = GetConVar( targetCommand )
    local occupying = occupiedCommands[targetCommand] == self
    local canOccupy = self:CanOccupyCommand( targetCommand )
    local valid = cmd ~= nil and ( occupying or canOccupy )
    return valid, cmd, targetCommand, unOccupied

end


function ENT:RestoreCommand()
    local valid = self:ActiveBlocker()
    if not valid then return end
    if not self.overriddenCommand then return end
    if not self.defaultVariable then return end
    RunConsoleCommand( self.overriddenCommand, self.defaultVariable )

end

local blacklistedCommands = {
    [genericBlock] = true,
    [dediServersCmdName] = true,

}

function ENT:MandateThink()
    local valid, cmd, targetCommand = self:ActiveBlocker()
    if blacklistedCommands[ targetCommand ] then
        local MSG = "Command Mandator:  " .. targetCommand .. " Can't be changed by me!"
        self:TryToPrintOwnerMessage( MSG )
        return

    end
    if campaignents_IsFreeMode() then return end
    if not mandatorIsEnabled:GetBool() then return end
    if game.IsDedicated() and not enabledOnDediServers:GetBool() then
        local MSG = "Command Mandator: Functionality is disabled on dedicated servers.\nChange " .. dediServersCmdName .. " to 1, to enable it."
        self:TryToPrintOwnerMessage( MSG )
        return

    end

    local weOccupy = occupiedCommands[targetCommand] == self or self:CanOccupyCommand( targetCommand )
    if valid and weOccupy then
        if self.overriddenCommand ~= targetCommand then
            self.overriddenCommand = targetCommand
            self.defaultVariable = cmd:GetString()

        end
        self:OccupyCommand( targetCommand )
        RunConsoleCommand( targetCommand, self:GetVariable() )

    elseif not weOccupy and not self.duplicatedIn then
        local MSG = "Command Mandator:  " .. targetCommand .. "  Is already overriden!"
        self:TryToPrintOwnerMessage( MSG )

    elseif not valid and targetCommand ~= "" and not self.duplicatedIn then
        local MSG = "Command Mandator:  " .. targetCommand .. "  Is an invalid command!"
        self:TryToPrintOwnerMessage( MSG )

    end
end

local campaignents_nextCommandMandatorMessage = 0
function ENT:BlockerSetup()
    if not IsValid( self ) then return end
    self:MandateThink()
    if self.duplicatedIn then return end
    if campaignents_nextCommandMandatorMessage > CurTime() then return end
    campaignents_nextCommandMandatorMessage = CurTime() + 30
    local MSG = "Command Mandator: Check my context menu options! \nThis message will not appear when duped in."
    self:TryToPrintOwnerMessage( MSG )

end

function ENT:OnRemove()
    if not SERVER then return end
    self:RestoreCommand()

end


