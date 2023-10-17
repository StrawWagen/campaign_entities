AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Save Loader"
ENT.Author      = "straw wage"
ENT.Purpose     = "Loads saves."
ENT.Spawnable   = true
ENT.AdminOnly   = true

ENT.Editable    = true
ENT.DefaultModel = "models/maxofs2d/button_03.mdl"
ENT.campaignents_Usable = true

local function SparkEffect( SparkPos )
    local Sparks = EffectData()
    Sparks:SetOrigin( SparkPos )
    Sparks:SetMagnitude( 2 )
    Sparks:SetScale( 1 )
    Sparks:SetRadius( 6 )
    util.Effect( "Sparks", Sparks )

    sound.Play( "LoudSpark", SparkPos )

end

local function SplodeEffect( SparkPos )
    local Sparks = EffectData()
    Sparks:SetOrigin( SparkPos )
    Sparks:SetMagnitude( 2 )
    Sparks:SetScale( 1 )
    util.Effect( "Explosion", Sparks )

end

function ENT:SetupDataTables()
    self:NetworkVar( "String", 1, "SaveId",     { KeyName = "saveid",        Edit = { order = 1, type = "String" } } )
    self:NetworkVar( "Bool", 1, "Pressed",      { KeyName = "pressed",       Edit = { readonly = true } } )
    self:NetworkVar( "Entity", 1, "Presser",    { KeyName = "presser",       Edit = { readonly = true } } )
    self:NetworkVar( "Float", 1, "PosePos",     { KeyName = "posepos",       Edit = { readonly = true } } )

end

function ENT:Initialize()
    if SERVER then
        self:SetModel( self.DefaultModel )
        self:SetNoDraw( false )
        self:DrawShadow( false )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_WORLD ) -- npcs can see through?
        self:SetUseType( SIMPLE_USE )

        self:GetPhysicsObject():EnableMotion( false )
        self:AddEFlags( EFL_FORCE_CHECK_TRANSMIT )

    end
end

function ENT:Use( presser )
    if not self:CanBePressedBy( presser ) then return end
    self:SetPresser( presser )
    self:SetPressed( not self:GetPressed() )

end

local badSaveIds = {}

if SERVER then
    util.AddNetworkString( "saveentities_failedtoload" )

    -- yarr, net exploit be lyin here....
    -- fixed, always allow one load attempt even if it's a bad save id
    net.Receive( "saveentities_failedtoload", function()
        local triedToLoad = net.ReadEntity()
        badSaveIds[ triedToLoad:GetSaveId() ] = true

    end )

else
    function handleSaveLoadClient( loader )
        steamworks.DownloadUGC( loader:GetSaveId(), function( name )
            if not name or name == "" then
                if not loader then return end
                badSaveIds[ loader:GetSaveId() ] = true
                net.Start( "saveentities_failedtoload", false )
                    net.WriteEntity( loader )
                net.SendToServer()

                return

            end
            RunConsoleCommand( "gm_load", name )

        end )
    end
end

local nextLoad = 0

function ENT:Think()
    -- Update the animation
    if CLIENT then
        -- follow serverside real PosePos
        self:UpdateLever()

        -- command has to be run by admin/host, presser can only be an admin.
        local presser = self:GetPresser()
        local badLoad = self.triedALoad and badSaveIds[ self:GetSaveId() ]
        if nextLoad < CurTime() and self:GetPosePos() == 1 and IsValid( presser ) and presser == LocalPlayer() and not badLoad then
            nextLoad = CurTime() + 1
            self.triedALoad = true

            handleSaveLoadClient( self )

        elseif self:GetPosePos() < 1 then
            self.triedALoad = nil

        end
    else
        -- client will follow this
        local targetPos = 0.0
        if self:GetPressed() then targetPos = 1.0 end

        local posePos = self:GetPosePos()
        posePos = math.Approach( posePos, targetPos, 0.0025 )
        self:SetPosePos( posePos )

        -- do synced effects here
        posePos = math.Round( posePos, 3 )

        -- lever was JUST pulled!
        if posePos == 0.01 and targetPos == 1 then
            self:EmitSound( "plats/elevator_large_start1.wav", 0, 95 )
            self:EmitSound( "plats/hall_elev_move.wav" )

            local presser = self:GetPresser()
            local name = presser:GetClass()
            if presser.Name then
                name = presser:Name()

            end

            PrintMessage( HUD_PRINTCENTER, name .. " Is loading a save..." )

        end

        if posePos == 0.95 and targetPos == 1 then
            -- attempting a load!
            self:EmitSound( "plats/tram_hit1.wav", 0, 85, 1, CHAN_STATIC )

        end

         -- uh oh!
        if posePos >= 1 and targetPos == 1 and badSaveIds[ self:GetSaveId() ] then
            self:SetPressed( false )
            self:StopSound( "plats/hall_elev_move.wav" )

            self:EmitSound( "ambient/machines/spindown.wav", 95, 80, CHAN_STATIC )
            self:EmitSound( "ambient/levels/labs/electric_explosion1.wav", 95, 100, CHAN_STATIC )
            self:EmitSound( "ambient/machines/thumper_shutdown1.wav", 95, 100, CHAN_STATIC )

            SplodeEffect( self:GetPos() )

            PrintMessage( HUD_PRINTCENTER, "Tried to load save that doesn't exist, or is inacessible.\nBother the author of this save, something went wrong!" )

        end

        -- sparks!
        if targetPos == 1 and math.Rand( 0, 1 ) < posePos and math.random( 0, 100 ) > 50 then
            local sparkPos = self:WorldSpaceCenter() + VectorRand() * math.random( 0, 5 )
            SparkEffect( sparkPos )

        end

        -- think fast!
        if posePos ~= targetPos then
            self:NextThink( CurTime() )
            return true

        end
    end
end

-- only admins can press this!
function ENT:CanBePressedBy( presser )
    if not IsValid( presser ) then return end
    if not presser:IsPlayer() then return end

    local id = self:GetSaveId()
    if not isstring( id ) or id == "" then
        presser:PrintMessage( HUD_PRINTCENTER, "No save id!" )
        return

    end
    if not tonumber( id ) then
        presser:PrintMessage( HUD_PRINTCENTER, "Couldn't convert save id into number!" )
        return

    end

    if game.SinglePlayer() then return true end

    local theHost = nil
    for _, ply in ipairs( player.GetAll() ) do
        if ply:IsListenServerHost() then
            theHost = ply
            break

        end
    end

    if theHost then
        if presser == theHost then return true end
        presser:PrintMessage( HUD_PRINTCENTER, "Only the host can load saves!" )

    else
        if presser:IsSuperAdmin() then return true end
        presser:PrintMessage( HUD_PRINTCENTER, "Only superadmins can load saves!" )

    end
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS

end

if not CLIENT then return end

function ENT:UpdateLever()
    -- smooth clientside
    self.PosePosition = self.PosePosition or 0
    self.PosePosition = math.Approach( self.PosePosition, self:GetPosePos(), FrameTime() * 100 )

    self:SetPoseParameter( "switch", self.PosePosition )
    self:InvalidateBoneCache()

end