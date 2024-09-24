CAMPAIGN_ENTS = CAMPAIGN_ENTS or {}

function CAMPAIGN_ENTS.CanBeUgly()
    local ply = LocalPlayer()
    if IsValid( ply:GetActiveWeapon() ) and string.find( LocalPlayer():GetActiveWeapon():GetClass(), "camera" ) then return false end
    return true

end

local cachedIsEditing = nil
local nextCache = 0
local CurTime = CurTime

function CAMPAIGN_ENTS.IsEditing()
    if nextCache > CurTime() then return cachedIsEditing end
    nextCache = CurTime() + 0.01

    local ply = LocalPlayer()
    local moveType = ply:GetMoveType()
    if moveType ~= MOVETYPE_NOCLIP then     cachedIsEditing = nil return end
    if ply:InVehicle() then                 cachedIsEditing = nil return end
    if not CAMPAIGN_ENTS.CanBeUgly() then        cachedIsEditing = nil return end

    cachedIsEditing = true
    return true

end

function CAMPAIGN_ENTS.DoBeamColor( self )
    if not self.GetGoalID then return end
    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        local val = self:GetGoalID() * 4
        local r = ( val % 255 )
        local g = ( ( val + 85 ) % 255 )
        local b = ( ( val + 170 ) % 255 )

        self.nextNPCGoalCheck = 0
        self.GoalLinkColor = Color( r, g, b )

    end )
end