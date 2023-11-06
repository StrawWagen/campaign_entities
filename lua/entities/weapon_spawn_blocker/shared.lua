
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
    self:NetworkVar( "Bool",    0, "WeaponsPersistOnDeath",    { KeyName = "deathpersist",    Edit = { type = "Bool" } } )
    if SERVER then
        self:SetWeaponsPersistOnDeath( true )
    end
end

function ENT:Initialize()
    if SERVER then
        self.overRidden = nil
        self.Enabled = nil
        self.OldEnabled = nil
        self:SetModel( self.Model )
        self:SetNoDraw( false )
        self:DrawShadow( false )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_NONE )

        timer.Simple( 0, function()
            self:BlockerSetup()
            self:NextThink( CurTime() + 0.05 )

        end )
    end
end
if not SERVER then return end

local STRAW_WeaponBlocker

local function ActiveBlocker()
    if not IsValid( STRAW_WeaponBlocker ) then return end
    if not campaignents_EnabledAi() then return end
    return true

end

function ENT:OnDuplicated()
    self.duplicatedIn = true

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

local nextWeaponSpawnBlockerMessage = 0
function ENT:BlockerSetup()
    self:EnsureOnlyOneExists()
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

function ENT:EnsureOnlyOneExists()
    if IsValid( STRAW_WeaponBlocker ) and STRAW_WeaponBlocker ~= self then
        STRAW_WeaponBlocker.overRidden = true
        SafeRemoveEntity( STRAW_WeaponBlocker )

    end
    STRAW_WeaponBlocker = self

end

-- save "building" loadout, eg, physgun, toolgun
function ENT:StoreOldLoadout( ply )
    ply.campaignEnts_OldLoadout = {}
    for _, weap in ipairs( ply:GetWeapons() ) do
        table.insert( ply.campaignEnts_OldLoadout, weap:GetClass() )

    end
    if not IsValid( ply:GetActiveWeapon() ) then return end
    ply.campaignEnts_OldActiveWeapon = ply:GetActiveWeapon():GetClass()

end

-- restore "building" loadout, eg physgun, toolgun
function ENT:RestoreOldLoadout( ply )
    if ply.campaignEnts_OldLoadout then
        ply:StripWeapons()
        self:GivePlyWeapons( ply, ply.campaignEnts_OldLoadout, true )

        timer.Simple( 0, function()
            if not IsValid( ply ) then return end
            if not ply.campaignEnts_OldActiveWeapon then return end
            ply:SelectWeapon( ply.campaignEnts_OldActiveWeapon )
            ply.campaignEnts_OldActiveWeapon = nil

        end )
    end
    ply.campaignEnts_WeapBlockerEnabled = nil
    ply.campaignEnts_OldLoadout = nil

end

-- give tbl of weap classes
function ENT:GivePlyWeapons( ply, weaps, blockAmmo )
    if not istable( weaps ) then return end
    if table.Count( weaps ) <= 0 then return end
    for _, wepClass in ipairs( weaps ) do
        ply:Give( wepClass, blockAmmo )

    end
end

function ENT:ManagePlysWeapons( ply )
    if not IsValid( ply ) then return end
    if not ply:Alive() then return end
    local inNoclip = ply:CampaignEnts_IsInNoclip()
    local enabled = self.Enabled and not inNoclip and not campaignents_IsFreeMode()

    if enabled == nil then enabled = false end

    local plysWeapStatus = ply.campaignEnts_WeapBlockerEnabled
    if enabled ~= plysWeapStatus then
        ply.campaignEnts_WeapBlockerHandling = true -- HACK
        if enabled == true then
            -- setup this ply!
            if not ply.campaignEnts_OldLoadout then
                self:StoreOldLoadout( ply )
                ply:StripWeapons()

            end
            -- they died
            if ply.campaignEnts_NeedsLoadoutRefresh then
                ply:StripWeapons()
                if self:GetWeaponsPersistOnDeath() then
                    self:GivePlyWeapons( ply, ply.campaignEnts_BlockerPickedUpWeaps, false )

                end
                ply.campaignEnts_NeedsLoadoutRefresh = nil

            -- they exited noclip
            else
                ply:StripWeapons()
                self:GivePlyWeapons( ply, ply.campaignEnts_BlockerPickedUpWeaps, false )

            end
        elseif enabled ~= true then
            self:RestoreOldLoadout( ply )

        end
        ply.campaignEnts_WeapBlockerHandling = nil
        ply.campaignEnts_WeapBlockerEnabled = enabled

    end
end


function ENT:Think()
    self.Enabled = ActiveBlocker()
    local plys = player.GetAll()
    for _, ply in ipairs( plys ) do
        self:ManagePlysWeapons( ply )

    end
    self:NextThink( CurTime() + 1 )
    return true

end

function ENT:OnRemove()
    if self.overRidden then return end
    for _, ply in ipairs( player.GetAll() ) do
        self:RestoreOldLoadout( ply )
        --print( ply )
        ply.campaignEnts_BlockerHasPickedUpWeaps = nil
        ply.campaignEnts_BlockerPickedUpWeaps = nil

    end
end

local function swepGiveThink( ply, _, _ )
    if not ActiveBlocker() then return nil end
    if ( ply.nextDenySound or 0 ) > CurTime() then return false end
    ply.nextDenySound = CurTime() + engine.TickInterval()
    -- AAAAAAAAAA
    ply:SendLua( "LocalPlayer():EmitSound( 'common/wpn_denyselect.wav' )" )
    return false

end

hook.Add( "PlayerGiveSWEP", "weapon_blocker_giveswep", swepGiveThink )

hook.Add( "PlayerSpawnSWEP", "weapon_blocker_spawnswep", swepGiveThink )

hook.Add( "PlayerDeath", "weapon_blocker_plydeath", function( ply )
    if not ActiveBlocker() then return end
    ply.campaignEnts_WeapBlockerEnabled = nil
    ply.campaignEnts_WeapBlockerHandlingRespawn = true

end )

hook.Add( "PlayerSpawn", "weapon_blocker_plyrespawn", function( ply, _ )
    if not ActiveBlocker() then return end
    ply.campaignEnts_NeedsLoadoutRefresh = true
    timer.Simple( 0.1, function()
        if not IsValid( ply ) then return end
        if not ply:Alive() then return end
        ply.campaignEnts_WeapBlockerHandlingRespawn = nil
        STRAW_WeaponBlocker:NextThink( CurTime() )

    end )
end )


hook.Add( "PlayerCanPickupWeapon", "weapon_blocker_validpickupweapon", function( ply, weap )
    if not ActiveBlocker() then return end

    if ply.campaignEnts_WeapBlockerHandling then return end -- within ManagePlysWeapons
    if ply.campaignEnts_WeapBlockerHandlingRespawn then return end

    if not ply.campaignEnts_BlockerHasPickedUpWeaps then ply.campaignEnts_BlockerHasPickedUpWeaps = {} end
    if not ply.campaignEnts_BlockerPickedUpWeaps then ply.campaignEnts_BlockerPickedUpWeaps = {} end

    local class = weap:GetClass()
    if not ply.campaignEnts_BlockerHasPickedUpWeaps[class] then
        --print( "pickup " .. class )
        ply.campaignEnts_BlockerHasPickedUpWeaps[class] = true
        table.insert( ply.campaignEnts_BlockerPickedUpWeaps, class )

    end
end )
