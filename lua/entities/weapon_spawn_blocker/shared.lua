
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Weapon Spawn Blocker"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Strips and then maintains weapons as people pick them up"
ENT.Spawnable    = true
ENT.AdminOnly    = true
ENT.Editable = true
ENT.Model = "models/maxofs2d/cube_tool.mdl"
ENT.Material = "phoenix_storms/cube"

local function ActiveBlocker()
    if not IsValid( STRAW_WeaponBlocker ) then return end
    if not campaignents_EnabledAi() then return end
    return true
end

function ENT:SetupDataTables()
    self:NetworkVar( "Bool",    0, "WeaponsPersistOnDeath",    { KeyName = "deathpersist",    Edit = { type = "Bool" } } )
    if SERVER then
        self:SetWeaponsPersistOnDeath( true )
    end
end

function ENT:OnDuplicated()
    self.duplicatedIn = true
end

function ENT:Initialize()
    if SERVER then
        self:SetModel( self.Model )
        self:SetNoDraw( false )
        self:DrawShadow( false )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_NONE )

        timer.Simple( 0, function()
            self:BlockerSetup()
        end )
    end
end

function ENT:TryToPrintOwnerMessage( MSG )
    local done = nil
    if CPPI then
        local owner = self:CPPIGetOwner()
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

function ENT:BeginOverriding( ent )
    local theirWeapons = ent:GetWeapons()
    for _, weap in ipairs( theirWeapons ) do
        if not ent.weaponBlockerAcquiredWeapons[weap:GetClass()] then
            SafeRemoveEntity( weap )

        end
    end
end

function ENT:EnsureOnlyOneExists()
    if IsValid( STRAW_WeaponBlocker ) and STRAW_WeaponBlocker ~= self then
        STRAW_WeaponBlocker.overRidden = true
        SafeRemoveEntity( STRAW_WeaponBlocker )

    end
    STRAW_WeaponBlocker = self

end

local nextWeaponSpawnBlockerMessage = 0
function ENT:BlockerSetup()
    self:EnsureOnlyOneExists()
    if ActiveBlocker() then
        for _, currentplayer in pairs( player.GetAll() ) do
            currentplayer.weaponBlockerAcquiredWeapons = currentplayer.weaponBlockerAcquiredWeapons or {}
            self:BeginOverriding( currentplayer )
        end
    end
    if self.duplicatedIn then return end
    if nextWeaponSpawnBlockerMessage > CurTime() then return end
    if campaignents_EnabledAi() then
        local MSG = "Weapon spawn blocker: Disable AI to enable debug mode \nThis message will not appear when duped in."
        self:TryToPrintOwnerMessage( MSG )
        nextWeaponSpawnBlockerMessage = CurTime() + 25

    elseif not campaignents_EnabledAi() then
        local MSG = "Weapon spawn blocker: Check my context menu option!"
        self:TryToPrintOwnerMessage( MSG )
        nextWeaponSpawnBlockerMessage = CurTime() + 25

    end
end

function ENT:OnRemove()
    if self.overRidden then return end
    for _, currPly in ipairs( player.GetAll() ) do
        if ActiveBlocker() then
            self:RemovePlyWeapons( currPly )
            self:GivePlyWeapons( currPly, currPly.weaponBlockerSpawnLoadout )

        end
        currPly.weaponBlockerAcquiredWeapons = {}
        currPly.weaponBlockerPlayerIsDead = nil

    end
end

function ENT:Think()
    if not SERVER then return end
    if ActiveBlocker() ~= self.Enabled and self.ToggleSetup then
        for _, ply in ipairs( player.GetAll() ) do
            self:RemovePlyWeapons( ply )
            if not self.Enabled then
                self:GivePlyWeapons( ply, ply.weaponBlockerAcquiredWeapons )

            elseif self.Enabled then
                self:GivePlyWeapons( ply, ply.weaponBlockerSpawnLoadout )

            end
        end
    end
    self.ToggleSetup = true
    self.Enabled = ActiveBlocker()

end

function ENT:RemovePlyWeapons( ply )
    local theirWeapons = ply:GetWeapons()
    if not istable( theirWeapons ) then return end
    if table.Count( theirWeapons ) <= 0 then return end
    for _, currWeap in ipairs( theirWeapons ) do
        SafeRemoveEntity( currWeap )

    end
end

function ENT:GivePlyWeapons( ply, weaps )
    if not istable( weaps ) then return end
    if table.Count( weaps ) <= 0 then return end
    for acquiredWeap, _ in pairs( weaps ) do
        ply:Give( acquiredWeap )

    end
end

local function swepGiveThink( ply, _, _ )
    if not ActiveBlocker() then return nil end
    if ( ply.nextDenySound or 0 ) > CurTime() then return false end
    ply.nextDenySound = CurTime() + engine.TickInterval()
    ply:SendLua( "LocalPlayer():EmitSound( 'common/wpn_denyselect.wav' )" )
    return false

end

hook.Add( "PlayerGiveSWEP", "weapon_blocker_giveswep", swepGiveThink )

hook.Add( "PlayerSpawnSWEP", "weapon_blocker_spawnswep", swepGiveThink )


hook.Add( "PlayerDeath", "weapon_blocker_recordnotalive", function( ply )
    if not IsValid( STRAW_WeaponBlocker ) then return end
    ply.weaponBlockerSpawnLoadout = nil
    ply.weaponBlockerPlayerIsDead = true

end )

hook.Add( "PlayerSpawn", "weapon_blocker_plyrespawn", function( ply, _ )
    -- code worth hating
    timer.Simple( engine.TickInterval(), function()
        if not IsValid( ply ) then return end
        if not ply:Alive() then return end
        if ActiveBlocker() then
            STRAW_WeaponBlocker:RemovePlyWeapons( ply )
        end

        timer.Simple( engine.TickInterval(), function()
            if not IsValid( ply ) then return end
            if not ply:Alive() then return end
            if ActiveBlocker() then
                if STRAW_WeaponBlocker:GetWeaponsPersistOnDeath() then
                    STRAW_WeaponBlocker:GivePlyWeapons( ply, ply.weaponBlockerAcquiredWeapons )
                else
                    ply.weaponBlockerAcquiredWeapons = {}
                end
            end

            ply.weaponBlockerPlayerIsDead = nil

        end )
    end )
end )


hook.Add( "PlayerCanPickupWeapon", "weapon_blocker_validpickupweapon", function( ply, weap )
    if not IsValid( STRAW_WeaponBlocker ) then return nil end
    local class = weap:GetClass()
    if not ply.weaponBlockerAcquiredWeapons then ply.weaponBlockerAcquiredWeapons = {} end
    if ply.weaponBlockerPlayerIsDead then
        if not ply.weaponBlockerSpawnLoadout then ply.weaponBlockerSpawnLoadout = {} end
        ply.weaponBlockerSpawnLoadout[class] = true
    elseif not ply.weaponBlockerAcquiredWeapons[class] then
        ply.weaponBlockerAcquiredWeapons[class] = true
    end
end )
