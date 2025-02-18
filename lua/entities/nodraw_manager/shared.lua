
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Fade Distance Manager"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Unredners entities until people get near to them"
ENT.Spawnable    = true
ENT.AdminOnly    = true
ENT.Editable = true
ENT.Model = "models/props_lab/monitor02.mdl"
ENT.Material = "models/xqm/squaredmatinverted"

local STRAW_NodrawManager

local function ActiveNodrawManager()
    if not IsValid( STRAW_NodrawManager ) then return end
    if not CAMPAIGN_ENTS.EnabledAi() then return end
    return STRAW_NodrawManager

end

function ENT:SetupDataTables()
    self:NetworkVar( "Int",  1, "NodrawDistance",   { KeyName = "nodrawdistance",  Edit = { type = "Int", title = "Render Distance",   order = 1, min = 0, max = 10000 } } )
    self:NetworkVar( "Int",  2, "MaxRadius",        { KeyName = "madradius",       Edit = { type = "Int", title = "Ent Size To Ignore",order = 2, min = 0, max = 10000 } } )
    self:NetworkVar( "Int",  3, "Rate",             { KeyName = "rate",            Edit = { type = "Int", title = "Rate. Can lag.",    order = 3, min = 1, max = 100 } } )
    self:NetworkVar( "Bool", 4, "PropsOnly",        { KeyName = "propsonly",       Edit = { type = "Bool",title = "Only Affect Props", order = 4 } } )

    if SERVER then
        self:SetMaxRadius( 250 )
        self:SetNodrawDistance( 4000 )
        self:SetRate( 15 )

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
        self:SetMaterial( self.Material )

        CAMPAIGN_ENTS.EasyFreeze( self )

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:SelfSetup()

        end )
    end
end

local nextNodrawMessage = 0
function ENT:SelfSetup()
    STRAW_NodrawManager = CAMPAIGN_ENTS.EnsureOnlyOneExists( self )
    if not ActiveNodrawManager() then return end
    if self.duplicatedIn then return end
    if nextNodrawMessage > CurTime() then return end

    if CAMPAIGN_ENTS.EnabledAi() then
        local MSG = "I make stuff stop rendering for people and work best with a fog editor, distance is configurable. You can also configure the max thing size, so big things don't just dissapear from the skyline!\nThis message will not appear when duped."
        CAMPAIGN_ENTS.MessageOwner( self, MSG )
        nextNodrawMessage = CurTime() + 25

    end
end

local StuffToOperate = {}
local OperateIndex   = 0

function ENT:RefreshTable()
    if self:GetPropsOnly() then
        StuffToOperate = ents.FindByClass( "prop_physics" )

    else
        StuffToOperate = ents.GetAll()

    end
    OperateIndex = 0

end

local function Positions( Players )
    if #Players < 1 then return end
    local Out = {}
    for _, Ply in ipairs( Players ) do
        table.insert( Out, Ply:GetPos() )

    end
    return Out

end

function ENT:Operate( CurrentCount, FixingAllTramsit )
    local Players           = player.GetAll()
    local PlayerPositions   = Positions( Players )
    if not PlayerPositions then return end

    local CheckDistSqr      = self:GetNodrawDistance() ^ 2
    local Start             = OperateIndex
    local End               = math.Clamp( OperateIndex + self:GetRate(), 0, CurrentCount )
    local MaxRadius         = self:GetMaxRadius()
    if FixingAllTramsit then
        End = #StuffToOperate

    end
    for Ind = Start, End do
        self:ManageEntNodraw( StuffToOperate[Ind], Players, PlayerPositions, CheckDistSqr, FixingAllTramsit, MaxRadius )

    end
    OperateIndex = End

end

local function AboveRadius( Thing, Radius )
    if Radius == 0 then return nil end
    if not Thing.GetModelRadius then return nil end
    local ThingRadius = Thing:GetModelRadius() or 0
    if ThingRadius < Radius then return nil end
    return true

end

local classBlacklist = {
    ["func_areaportal"] = true,
    ["func_areaportalwindow"] = true,
    ["env_headcrabcanister"] = true,

}


function ENT:ManageEntNodraw( Thing, Players, PlayerPositions, CheckDistSqr, FixingAllTramsit, Radius )
    if not IsValid( Thing ) then return end
    if not Thing.GetPos then return end -- custom entities????? idfk
    if Thing:GetNoDraw() == true then return end
    if IsValid( Thing:GetParent() ) then return end
    if AboveRadius( Thing, Radius ) then return end
    if classBlacklist[ Thing:GetClass() ] then return end
    self:DoDrawing( Thing, Players, PlayerPositions, CheckDistSqr, FixingAllTramsit )

end

-- fallback!
local recursivePreventExtent = 0

local function RecursiveSetPreventTransmit( Thing, Player, StopTransmitting )
    if not IsValid( Thing ) or not IsValid( Player ) then return end
    if Player == Thing then return end
    if StopTransmitting == Thing:HasPreventTransmitReason( Player, "campents_nodraw_manager" ) then return end
    if recursivePreventExtent > 500 then return end
    recursivePreventExtent = recursivePreventExtent + 1

    if not Thing.UpdateTransmitState or Thing:UpdateTransmitState() ~= TRANSMIT_ALWAYS then
        if StopTransmitting then
            Thing:AddPreventTransmitReason( Player, "campents_nodraw_manager" )

        else
            Thing:RemovePreventTransmitReason( Player, "campents_nodraw_manager" )

        end
    end

    if not isfunction( Thing.GetChildren ) then return end
    local Children = Thing:GetChildren()
    if #Children < 1 then return end
    for _, Child in ipairs( Children ) do
        RecursiveSetPreventTransmit( Child, Player, StopTransmitting )

    end
end

function ENT:DoDrawing( Thing, Players, PlayerPositions, CheckDistSqr, FixingAllTramsit )
    local DrawStates = Thing.NodrawManagerStates or {}
    for PlyInd, Player in ipairs( Players ) do
        local CreationId = Player:GetCreationID()
        local PlyPos = PlayerPositions[ PlyInd ]
        local DistanceSqr = PlyPos:DistToSqr( Thing:GetPos() )
        local WithinDistance = DistanceSqr < CheckDistSqr

        if not DrawStates[ CreationId ] then
            DrawStates[ CreationId ] = Thing:HasPreventTransmitReason( Player, "campents_nodraw_manager" )

        end
        if WithinDistance or FixingAllTramsit then
            if DrawStates[ CreationId ] == true then
                DrawStates[ CreationId ] = false
                recursivePreventExtent = 0
                RecursiveSetPreventTransmit( Thing, Player, false )

            end
        elseif not WithinDistance then
            if DrawStates[ CreationId ] == false then
                DrawStates[ CreationId ] = true
                recursivePreventExtent = 0
                RecursiveSetPreventTransmit( Thing, Player, true )

            end
        end
    end
    Thing.NodrawManagerStates = DrawStates

end

local ThinkInterval = engine.TickInterval()

function ENT:Think()
    if not SERVER then return end
    self:NextThink( CurTime() + ThinkInterval )
    local Count = #StuffToOperate
    if Count <= 0 or OperateIndex >= Count then
        self:RefreshTable()

    else
        self:Operate( Count )

    end
    return true

end

function ENT:OnRemove()
    if not SERVER then return end
    OperateIndex = 0
    self:RefreshTable()
    self:Operate( 0, true )

end