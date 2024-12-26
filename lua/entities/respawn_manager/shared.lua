
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Checkpoint, Dynamic"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Respawns players in places where they were safe."
ENT.Spawnable    = true
ENT.AdminOnly    = true
ENT.Editable = true
ENT.Model = "models/props_combine/breenbust.mdl"
ENT.Material = "editor/orange"

local STRAW_RespawnManager

local function ActiveRespawnManager()
    if not IsValid( STRAW_RespawnManager ) then return end
    return true

end

function ENT:SetupDataTables()
    self:NetworkVar( "Bool",    0, "NeedsArmorIncrease",    { KeyName = "armorrespawn",             Edit = { type = "Bool", category = "SpawnPos Saving", title = "Wait for armor increase?", order = 1 } } )
    self:NetworkVar( "Bool",    1, "NeedsHealthIncrease",   { KeyName = "healthrespawn",            Edit = { type = "Bool", category = "SpawnPos Saving", title = "Wait for health increase?", order = 2 } } )
    self:NetworkVar( "Bool",    2, "NeedsOnGround",         { KeyName = "ongroundrespawn",          Edit = { type = "Bool", category = "SpawnPos Saving", title = "Wait until on ground?", order = 3 } } )
    self:NetworkVar( "Int",     0, "MinHealth",             { KeyName = "minHealth",                Edit = { type = "Int",  category = "SpawnPos Saving", title = "Needed health to save spawnpos.", order = 5, min = 0, max = 100 } } )
    self:NetworkVar( "Bool",    3, "StatsPersist",          { KeyName = "persisthealtharmor",       Edit = { type = "Bool", category = "Respawning", title = "Persist their HP&Armor?", order = 4 } } )
    self:NetworkVar( "Float",   0, "SpawnProtection",       { KeyName = "spawnprotection",          Edit = { type = "Float", category = "Respawning", title = "Spawn protection time.", order = 5, min = 0, max = 5 } } )

    if SERVER then
        self:SetNeedsArmorIncrease( true )
        self:SetNeedsHealthIncrease( true )
        self:SetMinHealth( 50 )
        self:SetNeedsOnGround( true )
        self:SetStatsPersist( true )
        self:SetSpawnProtection( 2 )

    end
end

function ENT:OnDuplicated()
    self.duplicatedIn = true

end

local function wipeStatsFor( ply )
    ply.respawnManagerRespawnPos = nil
    ply.respawnManagerRespawnAngles = nil
    ply.respawnManagerRespawnArmor = nil
    ply.respawnManagerRespawnHealth = nil

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

        CAMPAIGN_ENTS.EasyFreeze( self )

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:BlockerSetup()

        end )
    end
end

function ENT:SavePlyRespawnPos( ply, waitTime )
    local currRespawnPos = ply:GetPos() + Vector( 0,0,10 )
    local currRespawnAngles = ply:LocalEyeAngles()
    local currRespawnArmor = ply:Armor()
    local currRespawnHealth = math.Clamp( ply:Health(), 40, math.huge )
    local startingDeaths = ply:Deaths()

    timer.Simple( waitTime, function()
        if not IsValid( self ) then return end -- we were removed
        if not IsValid( ply ) then return end
        if not ply:Alive() then return end -- they died
        if ply:Deaths() > startingDeaths then return end -- they died and respawned

        local currSpawn = {
            pos = currRespawnPos,
            ang = currRespawnAngles,
            armor = currRespawnArmor,
            health = currRespawnHealth,

        }

        ply.campents_RespawnPositions = ply.campents_RespawnPositions or {}

        wipeStatsFor( ply ) -- force system to get a new respawn pos
        table.insert( ply.campents_RespawnPositions, 1, currSpawn )

    end )

    if IsValid( ply.campaignents_CurrCheckpoint ) and ply.campaignents_CurrCheckpoint:GetCanOverride() then
        ply.campaignents_CurrCheckpoint:unlinkPlayerToMe( ply )

    end
end

local nextRespawnMessage = 0
function ENT:BlockerSetup()
    STRAW_RespawnManager = CAMPAIGN_ENTS.EnsureOnlyOneExists( self )

    timer.Simple( 0.1, function()
        if not IsValid( self ) then return end
        for _, currPly in player.Iterator() do
            if currPly:Alive() then
                self:SavePlyRespawnPos( currPly, 0 )

            end
        end
    end )
    timer.Simple( 2, function()
        if not IsValid( self ) then return end
        for _, currPly in player.Iterator() do
            if currPly:Alive() then
                self:SavePlyRespawnPos( currPly, 10 )

            end
        end
    end )
    if self.duplicatedIn then return end
    if nextRespawnMessage > CurTime() then return end

    if CAMPAIGN_ENTS.EnabledAi() then
        local MSG = "Checkpoint, Dynamic: I save respawn positions depending on my context menu options!\nWhen people respawn, I put them at their last respawn position!\nThis message will not appear when duped in."
        CAMPAIGN_ENTS.MessageOwner( self, MSG )
        nextRespawnMessage = CurTime() + 25

    end
end

function ENT:OnRemove()
    for _, ply in player.Iterator() do
        ply.campents_RespawnPositions = nil
        wipeStatsFor( ply )

    end
end

function ENT:ManageRespawnPoint( ply )
    local currArmor         = ply:Armor()
    local oldArmor          = ply.respawnManagerOldSpawnPosArmor or 0
    local increasedArmor    = currArmor > oldArmor
    local currHealth        = ply:Health()
    local oldHealth         = ply.respawnManagerOldSpawnPosHealth or 0
    local increasedHealth   = currHealth > oldHealth
    local onGround          = ply:OnGround()

    local posSaveCriteriaMet = true
    if self:GetNeedsArmorIncrease() and self:GetNeedsHealthIncrease() then
        posSaveCriteriaMet = posSaveCriteriaMet and ( increasedArmor or increasedHealth )

    elseif self:GetNeedsArmorIncrease() then
        posSaveCriteriaMet = posSaveCriteriaMet and increasedArmor

    elseif self:GetNeedsHealthIncrease() then
        posSaveCriteriaMet = posSaveCriteriaMet and increasedHealth

    end
    if self:GetNeedsOnGround() then
        posSaveCriteriaMet = posSaveCriteriaMet and onGround

    end
    if self:GetMinHealth() > 0 then
        posSaveCriteriaMet = posSaveCriteriaMet and ( currHealth >= self:GetMinHealth() )

    end

    local respawning        = ply.respawnManagerPlayerIsDead ~= nil
    local alive             = ply:Alive()
    local validSpawnPosSave = posSaveCriteriaMet and alive and not respawning
    if validSpawnPosSave then
        self:SavePlyRespawnPos( ply, 10 )
        ply.respawnManagerOldSpawnPosArmor = currArmor
        ply.respawnManagerOldSpawnPosHealth = currHealth

    end
    if currArmor < oldArmor then
        ply.respawnManagerOldSpawnPosArmor = currArmor

    end
    if currHealth < oldHealth then
        ply.respawnManagerOldSpawnPosHealth = currHealth

    end
end

function ENT:Think()
    if not SERVER then return end
    self:NextThink( CurTime() + 1 )
    if ActiveRespawnManager() then
        for _, currPly in player.Iterator() do
            if not currPly.respawnManagerPlayerIsDead then
                self:ManageRespawnPoint( currPly )

            end
        end
    end
    return true

end

function ENT:SmartRespawnBail( ply )
    ply:PrintMessage( HUD_PRINTTALK, "Seems like the Dynamic Respawner put you somewhere that got you stuck.\nBAILING!" )

    local positions = ply.campents_RespawnPositions
    if not positions then
        ply:SetPos( ply.respawnManagerBailPos )
        return -- stop

    else
        table.remove( positions, 1 )
        wipeStatsFor( ply ) -- force system to get a new respawn pos
        ply.respawnManagerTimeout = CurTime() + 3
        return true -- keep going

    end
end

local vecZero = Vector( 0, 0, 0 )

-- return true to keep thinking
function ENT:SmartRespawnThink( ply )
    if not IsValid( ply ) then return end

    if not ply.respawnManagerRespawnPos then
        local positions = ply.campents_RespawnPositions
        if not positions then return end -- UH OH

        local currData = positions[1]
        if not currData then return end -- uh oh

        ply.respawnManagerRespawnPos = currData.pos
        ply.respawnManagerRespawnAngles = currData.ang
        ply.respawnManagerRespawnArmor = currData.armor
        ply.respawnManagerRespawnHealth = currData.health

    end


    local plyPos = ply:GetPos()
    -- 2d distance, so player can fall down
    local subtractionProduct = plyPos - ply.respawnManagerRespawnPos
    subtractionProduct.z = 0

    local distToIdealSpawnPos = subtractionProduct:Length()
    -- our pos was set!
    if distToIdealSpawnPos < 100 and ply.respawnManagerNeedsStatsSet then
        ply.respawnManagerNeedsStatsSet = nil
        ply:SetEyeAngles( Angle( 0, ply.respawnManagerRespawnAngles[2], 0 ) )

        local protTime = self:GetSpawnProtection()
        if protTime > 0 and not ply:HasGodMode() then
            ply:GodEnable()
            timer.Simple( protTime, function()
                if not IsValid( ply ) then return end
                ply:GodDisable()

            end )
        end

        if self:GetStatsPersist() then
            ply:SetArmor( ply.respawnManagerRespawnArmor )
            ply:SetHealth( ply.respawnManagerRespawnHealth )

        end
    end
    -- success and not stuck!
    if distToIdealSpawnPos < 100 and ply:IsOnGround() then
        ply.respawnManagerRespawnPos = plyPos -- nudge the pos
        return

    end

    if ply.respawnManagerTimeout < CurTime() then return self:SmartRespawnBail( ply ) end -- teleported them somewhere that got them stuck

    if ply:GetMoveType() == MOVETYPE_NOCLIP then return true end -- they noclipped
    if distToIdealSpawnPos >= 100 then
        ply:SetPos( ply.respawnManagerRespawnPos )

    end
    return true

end


function ENT:PlyInitializeRespawn( ply )
    ply.respawnManagerBailPos = ply:GetPos()
    ply.respawnManagerTimeout = CurTime() + 5
    ply.respawnManagerBeingManaged = true
    ply.respawnManagerNeedsStatsSet = true

    local timerName = "STRAW_ply_" .. tostring( ply:GetCreationID() ) .. "respawnmanager"
    timer.Create( timerName, 0.05, 0, function()
        local exit = nil
        if not IsValid( self ) or not IsValid( ply ) then
            exit = true

        elseif not self:SmartRespawnThink( ply ) then
            exit = true

        end
        if exit then
            timer.Stop( timerName )
            if not IsValid( ply ) then return end
            ply.respawnManagerBailPos = nil
            ply.respawnManagerTimeout = nil
            ply.respawnManagerBeingManaged = nil
            ply.respawnManagerPlayerIsDead = nil

        end
    end )
end

hook.Add( "PlayerDeath", "respawn_manager_recordnotalive", function( ply )
    if not ActiveRespawnManager() then return end
    ply.respawnManagerPlayerIsDead = true

end )

hook.Add( "PlayerSpawn", "respawn_manager_plyrespawn", function( ply, _ )
    if not ActiveRespawnManager() then return end
    timer.Simple( 0, function()
        if not IsValid( ply ) then return end
        if not ply.respawnManagerPlayerIsDead then return end
        if not ply:Alive() then return end

        STRAW_RespawnManager:PlyInitializeRespawn( ply )

    end )
end )