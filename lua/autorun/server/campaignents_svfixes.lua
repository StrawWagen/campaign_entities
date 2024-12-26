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

CAMPAIGN_ENTS.oldGmSave = CAMPAIGN_ENTS.oldGmSave or gmsave.LoadMap

gmsave.LoadMap = function( ... )
    hook.Run( "campaignents_PreLoadSave", ... )
    CAMPAIGN_ENTS.oldGmSave( ... )

end

local wait = 0 -- for preventing reliable buffer overflows

hook.Add( "campaignents_PreLoadSave", "campaignenets_BlockULXPrints", function()
    wait = CurTime() + 1

end )

hook.Add( "LoadGModSave", "campaignenets_BlockULXPrints", function()
    wait = CurTime() + 1

end )

if ulx and ulx.logSpawn and not game.IsDedicated() then -- certified HACK!
    local blockedLogs = 0

    local function printBlockedLogs()
        if blockedLogs >= 2000 then
            local str = "Campaignents: Blocked %s!!!!! ULX log messages on save load, reliable buffer overflow likely averted!"
            str = string.format( str, blockedLogs )
            print( str )

        else
            local str = "Campaignents: Blocked %s ULX log messages on save load."
            str = string.format( str, blockedLogs )
            print( str )

        end
        blockedLogs = 0

    end

    CAMPAIGN_ENTS.oldUlxLogSpawn = CAMPAIGN_ENTS.oldUlxLogSpawn or ulx.logSpawn
    local oldLogSpawn = CAMPAIGN_ENTS.oldUlxLogSpawn

    ulx.logSpawn = function( ... ) -- i HATE reliable buffer overflows....
        if wait > CurTime() then
            if blockedLogs == 0 then
                timer.Create( "campaignents_blockedlogsnotify", 2, 0, function()
                    if wait > CurTime() then return end
                    if blockedLogs == 0 then timer.Remove( "campaignents_blockedlogsnotify" ) return end

                    printBlockedLogs()

                end )
            end

            blockedLogs = blockedLogs + 1
            return

        end
        if blockedLogs > 0 then
            printBlockedLogs()

        end
        oldLogSpawn( ... )

    end
end