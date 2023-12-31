local _LocalPlayer = LocalPlayer

function campaignents_CanBeUgly()
    local ply = _LocalPlayer()
    if IsValid( ply:GetActiveWeapon() ) and string.find( _LocalPlayer():GetActiveWeapon():GetClass(), "camera" ) then return false end
    return true

end

local cachedIsEditing = nil
local nextCache = 0
local _CurTime = CurTime

function campaignents_IsEditing()
    if nextCache > _CurTime() then return cachedIsEditing end
    nextCache = _CurTime() + 0.01

    local ply = _LocalPlayer()
    local moveType = ply:GetMoveType()
    if moveType ~= MOVETYPE_NOCLIP then     cachedIsEditing = nil return end
    if ply:InVehicle() then                 cachedIsEditing = nil return end
    if not campaignents_CanBeUgly() then        cachedIsEditing = nil return end

    cachedIsEditing = true
    return true

end

function campaignents_DoBeamColor( self )
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