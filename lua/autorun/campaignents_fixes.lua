
-- saw this fail for someone i think
hook.Add( "PhysgunPickup", "campaignents_respect_physdisabled", function( _, pickedUp )
    if IsValid( pickedUp ) and pickedUp.PhysgunDisabled then return false end

end )

local function fixAnglesOf( toFix )
    timer.Simple( 0, function()
        if not IsValid( toFix ) then return end
        local oldAng = toFix:GetAngles()
        oldAng[1] = math.Round( oldAng[1] )
        oldAng[2] = math.Round( oldAng[2] )
        oldAng[3] = math.Round( oldAng[3] )

        toFix:SetAngles( oldAng )
        toFix:EmitSound( "buttons/lightswitch2.wav", 75, 90, 0.1 )

    end )
end

-- round angles of things that are shift-frozen, got sick of doing this EVERY TIME with precision alignment
hook.Add( "OnPhysgunFreeze", "campaignents_roundangs_onfreeze", function( _, _, frozen, ply )
    if not ply:KeyDown( IN_SPEED ) then return end

    fixAnglesOf( frozen )

end )