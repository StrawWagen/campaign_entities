
-- saw this fail for someone i think
hook.Add( "PhysgunPickup", "campaignents_respect_physdisabled", function( _, pickedUp )
    if IsValid( pickedUp ) and pickedUp.PhysgunDisabled then return false end

end )