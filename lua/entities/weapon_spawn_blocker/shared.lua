
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

function ENT:SetupDataTables()
    local i = 1
    self:NetworkVar( "Bool",    0, "WeaponsPersistOnDeath", { KeyName = "deathpersist",             Edit = { order = i + 1, type = "Bool" } } )
    self:NetworkVar( "Bool",    1, "JustStripWeapons",      { KeyName = "juststripweapons",         Edit = { order = i + 1, type = "Bool" } } )
    self:NetworkVar( "Bool",    2, "JustBlockSpawning",     { KeyName = "justblockspawning",        Edit = { order = i + 1, type = "Bool" } } )
    self:NetworkVar( "Bool",    3, "StripAmmoOnSaveLoad",   { KeyName = "stripammoonsaveload",      Edit = { order = i + 1, type = "Bool" } } )
    if SERVER then
        self:NetworkVarNotify( "JustStripWeapons", function( _, _, _, new )
            if new and self:GetJustBlockSpawning() then
                self:SetJustBlockSpawning( false )

            end
        end )
        self:NetworkVarNotify( "JustBlockSpawning", function( _, _, _, new )
            if new and self:GetJustStripWeapons() then
                self:SetJustStripWeapons( false )

            end
        end )

        self:SetWeaponsPersistOnDeath( true )
        self:SetJustStripWeapons( false )
        self:SetJustBlockSpawning( false )
        self:SetStripAmmoOnSaveLoad( true )

    end
end

function ENT:Initialize()
    if SERVER then
        self:SetModel( self.Model )
        self:DrawShadow( false )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_NONE )

        CAMPAIGN_ENTS.EasyFreeze( self )

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:BlockerSetup()
            self:NextThink( CurTime() + 0.05 )

        end )
    end
end
if not SERVER then return end

local STRAW_WeaponBlocker

local function ActiveBlocker()
    if not IsValid( STRAW_WeaponBlocker ) then return end
    if not CAMPAIGN_ENTS.EnabledAi() then return end
    return true

end

local function BlockerStopsSpawning()
    if not IsValid( STRAW_WeaponBlocker ) then return end
    if STRAW_WeaponBlocker.GetJustStripWeapons and STRAW_WeaponBlocker:GetJustStripWeapons() then return end

    return true

end

function ENT:BlockerStripsWeapons()
    if self.GetJustStripWeapons and self:GetJustStripWeapons() then return true end
    if self.GetJustBlockSpawning and self:GetJustBlockSpawning() then return end
    return true

end

function ENT:OnDuplicated()
    self.duplicatedIn = true
    local saveLoaderOverride = CAMPAIGN_ENTS.weaponSpawnBlockerDontStrip or 0
    if not CAMPAIGN_ENTS.IsFreeMode() and self:GetStripAmmoOnSaveLoad() and self:BlockerStripsWeapons() and saveLoaderOverride < CurTime() then
        for _, ply in player.Iterator() do
            ply:RemoveAllAmmo()

        end
    end
end

local nextWeaponSpawnBlockerMessage = 0
function ENT:BlockerSetup()
    STRAW_WeaponBlocker = CAMPAIGN_ENTS.EnsureOnlyOneExists( self )

    if self.duplicatedIn then return end
    if nextWeaponSpawnBlockerMessage > CurTime() then return end
    if CAMPAIGN_ENTS.EnabledAi() then
        local MSG = "Weapon spawn blocker: Disable AI to enable debug mode \nThis message will not appear when duped in."
        CAMPAIGN_ENTS.MessageOwner( self, MSG )
        nextWeaponSpawnBlockerMessage = CurTime() + 25

    elseif not CAMPAIGN_ENTS.EnabledAi() then
        local MSG = "Weapon spawn blocker: Check my context menu option!"
        CAMPAIGN_ENTS.MessageOwner( self, MSG )
        nextWeaponSpawnBlockerMessage = CurTime() + 25

    end
end

local function stripPlysWeps( ply )
    ply:StripWeapons()

end

local function getLoadouts( ply )
    local loadouts = ply.campaignents_WepBlockLoadouts
    if loadouts then return loadouts end

    ply.campaignents_WepBlockLoadouts = {}
    return ply.campaignents_WepBlockLoadouts

end

local function newLoadout()
    return { wepsIndex = {}, weps = {}, active = nil }

end


function ENT:IsLoadout( ply, name )
    local loadouts = getLoadouts( ply )
    if loadouts[name] then return true end
    return false

end

function ENT:WipeLoadout( ply, name )
    local loadouts = getLoadouts( ply )
    loadouts[name] = nil

end

function ENT:StoreLoadout( ply, name )
    local loadouts = getLoadouts( ply )
    local curr = loadouts[name]
    if not curr then
        curr = newLoadout()
        loadouts[name] = curr

    end

    for _, weap in ipairs( ply:GetWeapons() ) do
        table.insert( curr.weps, weap:GetClass() )

    end

    if IsValid( ply:GetActiveWeapon() ) then
        curr.active = ply:GetActiveWeapon():GetClass()

    end

end

function ENT:AddToLoadout( ply, name, class )
    local loadouts = getLoadouts( ply )
    local curr = loadouts[name]
    if not curr then
        curr = newLoadout()
        loadouts[name] = curr

    end

    if curr.wepsIndex[class] then return end

    curr.wepsIndex[class] = true
    table.insert( curr.weps, class )

end

function ENT:RestoreLoadout( ply, name )
    local loadouts = getLoadouts( ply )
    local curr = loadouts[name]
    ply.campaignents_LastSetLoadout = name

    if not curr then return end

    if table.Count( curr.weps ) <= 0 then return end
    for _, wepClass in ipairs( curr.weps ) do
        local given = ply:Give( wepClass, true )
        if given and given.GetMaxClip1 then
            given:SetClip1( given:GetMaxClip1() )

        end
    end

    if not curr.active then return end
    local active = curr.active
    timer.Simple( 0, function()
        if not IsValid( ply ) then return end
        ply:SelectWeapon( active )

    end )
end

function ENT:ManagePlysWeapons( ply, isActive )
    if not IsValid( ply ) then return end
    if not ply:Alive() then return end

    local inNoclip = ply:campaignents_IsInNoclip()
    local enabled = isActive and not ( inNoclip or CAMPAIGN_ENTS.IsFreeMode() )

    -- make sure its not nil
    enabled = enabled or false

    if self.GetJustStripWeapons and self:GetJustStripWeapons() then
        -- take weps away
        if enabled == true and ply.campaignents_LastSetLoadout ~= "playing" then
            -- store the default weapons
            self:StoreLoadout( ply, "building" )
            stripPlysWeps( ply )

            self:RestoreLoadout( ply, "playing" )

        -- they noclipped, give back old weapons
        elseif enabled == false and self:IsLoadout( ply, "building" ) and ply.campaignents_LastSetLoadout ~= "building" then
            self:StoreLoadout( ply, "playing" )
            stripPlysWeps( ply )

            self:RestoreLoadout( ply, "building" )
            self:WipeLoadout( ply, "building" )

        end
        return

    elseif self:GetJustBlockSpawning() then
        return

    end

    ply.campaignents_WeapBlockerHandling = true -- HACK
    if enabled == true and ply.campaignents_LastSetLoadout ~= "playing" then
        self:StoreLoadout( ply, "building" )
        stripPlysWeps( ply )
        self:RestoreLoadout( ply, "playing" )

    elseif enabled == false and ply.campaignents_LastSetLoadout ~= "building" then
        self:RestoreLoadout( ply, "building" )
        self:WipeLoadout( ply, "building" )

    end
    ply.campaignents_WeapBlockerHandling = nil

end

hook.Add( "campaignents_OnPlayerEnterGenericNoclip", "weapon_spawn_blocker", function( ply )
    local isActive = ActiveBlocker()
    if not isActive then return end
    STRAW_WeaponBlocker:ManagePlysWeapons( ply, isActive )

end )

hook.Add( "campaignents_OnPlayerExitGenericNoclip", "weapon_spawn_blocker", function( ply )
    local isActive = ActiveBlocker()
    if not isActive then return end
    STRAW_WeaponBlocker:ManagePlysWeapons( ply, isActive )

end )

function ENT:Think()
    local isActive = ActiveBlocker()
    local plys = player.GetAll()
    for _, ply in ipairs( plys ) do
        self:ManagePlysWeapons( ply, isActive )

    end
    self:NextThink( CurTime() + 1 )
    return true

end

function ENT:OnRemove()
    if self.campaignents_Overriden then return end
    for _, ply in ipairs( player.GetAll() ) do
        if ply.campaignents_LastSetLoadout ~= "building" then
            self:RestoreLoadout( ply, "building" )

        end
        --print( ply )
        ply.campaignents_BlockerHasPickedUpWeaps = nil
        ply.campaignents_BlockerPickedUpWeaps = nil
        ply.campaignents_LastSetLoadout = nil
        ply.campaignents_WepBlockLoadouts = nil

    end
end

local function swepGiveThink( ply, _, _ )
    if not ActiveBlocker() then return nil end
    if not BlockerStopsSpawning() then return nil end
    if ply:campaignents_IsInNoclip() then return nil end
    if ( ply.nextDenySound or 0 ) > CurTime() then return false end
    ply.nextDenySound = CurTime() + engine.TickInterval()
    -- AAAAAAAAAA
    -- sorry just scared myself with this terrible code
    ply:SendLua( "LocalPlayer():EmitSound( 'common/wpn_denyselect.wav' )" )
    return false

end

hook.Add( "PlayerGiveSWEP", "weapon_blocker_giveswep", swepGiveThink )

hook.Add( "PlayerSpawnSWEP", "weapon_blocker_spawnswep", swepGiveThink )

hook.Add( "PlayerDeath", "weapon_blocker_died", function( died )
    if not ActiveBlocker() then return end
    if not STRAW_WeaponBlocker:GetWeaponsPersistOnDeath() then
        STRAW_WeaponBlocker:WipeLoadout( died, "playing" )

    end
    if not BlockerStopsSpawning() then return end
end )

hook.Add( "PlayerSpawn", "weapon_blocker_plyrespawn", function( ply, _ )
    if not ActiveBlocker() then return end
    ply.campaignents_LastSetLoadout = "building"
    if not BlockerStopsSpawning() then return end
    timer.Simple( 0.05, function()
        if not IsValid( ply ) then return end
        if not ply:Alive() then return end
        STRAW_WeaponBlocker:NextThink( CurTime() )

    end )
end )


hook.Add( "PlayerCanPickupWeapon", "weapon_blocker_validpickupweapon", function( ply, weap )
    if not ActiveBlocker() then return end
    if not IsValid( ply ) then return end

    if STRAW_WeaponBlocker:GetJustBlockSpawning() then return end
    if ply.campaignents_WeapBlockerHandling then return end -- within ManagePlysWeapons

    local class = weap:GetClass()

    STRAW_WeaponBlocker:AddToLoadout( ply, ply.campaignents_LastSetLoadout, class )

end )
