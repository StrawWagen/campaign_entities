
-- dont even think this is necessary anymore
hook.Add( "OnEntityCreated", "campaignents_genericfixes", function( ent )
    local class = ent:GetClass()
    if class == "gmod_wire_trigger_entity" then
        ent.DoNotDuplicate = true

    end
end )

hook.Add( "PhysgunPickup", "campaignents_respect_physdisabled", function( _, pickedUp )
    if IsValid( pickedUp ) and pickedUp.PhysgunDisabled then return false end

end )