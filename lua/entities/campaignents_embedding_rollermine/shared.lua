AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "campaignents_empty_turret"

ENT.Category    = "Campaign Entities"
ENT.PrintName   = "Embedding Rolletmine"
ENT.Author      = "straw w wagen"
ENT.Purpose     = "Spawns a rolletmine that hides in stuff."
ENT.Spawnable   = true
ENT.AdminOnly   = false

ENT.ProxyEntClass   = "npc_rollermine"
ENT.EntModifierName = "campaignents_roller_embedder"

local buryCheckDirections = {
    Vector( 0, 0, -1 ),
    Vector( 0, 1, 0 ),
    Vector( 0, -1, 0 ),
    Vector( 1, 0, 0 ),
    Vector( -1, 0, 0 ),

}

-- upon first spawn
function ENT:AdditionalInitialize( proxyEnt )
    local directionFractions = {}
    local traceResults = {}

    for index, dir in pairs( buryCheckDirections ) do
        local trResult = util.QuickTrace( proxyEnt:GetPos(), dir * 1000, proxyEnt )
        if not trResult.Hit then continue end

        local reversedFraction = math.abs( trResult.Fraction - 1 )
        directionFractions[ reversedFraction ] = index
        traceResults[ index ] = trResult

    end

    local bestDirectionKey = directionFractions[ table.maxn( directionFractions ) ]
    local bestResult = traceResults[ bestDirectionKey ]
    local bestDir = buryCheckDirections[ bestDirectionKey ]

    local facingOutwards = -bestDir
    local outwardsAng = facingOutwards:Angle()
    outwardsAng:RotateAroundAxis( facingOutwards, math.random( -180, 180 ) )

    proxyEnt:SetAngles( outwardsAng )
    proxyEnt:SetPos( bestResult.HitPos + bestResult.HitNormal )

    local physObj = proxyEnt:GetPhysicsObject()
    if physObj and physObj.IsValid and physObj:IsValid() then
        physObj:EnableMotion( false )

    end
end

local function Ambush( toApply )
    local enemy = toApply:GetEnemy()

    toApply:SetPos( toApply:GetPos() + toApply:GetForward() * 30 )
    toApply.campaignents_RollerHasAmbushed = true
    toApply.campaignents_RollerWarns = 0

    local unburiedObj = toApply:GetPhysicsObject()
    if unburiedObj and unburiedObj.IsValid and unburiedObj:IsValid() then
        unburiedObj:EnableMotion( true )
        unburiedObj:ApplyForceCenter( toApply:GetForward() * unburiedObj:GetMass() * math.random( 300, 500 ) )

    end

    toApply:EmitSound( "NPC_CombineMine.OpenHooks" )

    if not IsValid( enemy ) then return end

    local done = 0

    local nearStuff = ents.FindInSphere( toApply:GetPos(), 1000 )
    for _, nearThing in ipairs( nearStuff ) do
        if nearThing.campaignents_IsBuriedRoller and not nearThing.campaignents_RollerHasAmbushed and nearThing ~= toApply then
            local visCheck = {
                start = nearThing:GetPos() + nearThing:GetForward() * 30,
                endpos = enemy:GetShootPos(),
                filter = nearThing

            }
            local trResult = util.TraceLine( visCheck )

            local hitEnemy = trResult.Hit and trResult.Entity and trResult.Entity == enemy

            if not trResult.Hit or hitEnemy then
                nearThing.campaignents_RollerForcedAmbush = true
                done = done + 1

            end
        end
    end

    util.ScreenShake( toApply:GetPos(), done, 20, 0.75, 1000 )

end

local distToUnburySqr = 250^2

ENT.ProxyPostSpawnFunc = function( _, toApply, _ )
    toApply:Spawn()

    local physObj = toApply:GetPhysicsObject()
    if physObj and physObj.IsValid and physObj:IsValid() then
        physObj:EnableMotion( false )

    end

    toApply.campaignents_IsBuriedRoller = true
    toApply.campaignents_RollerHasAmbushed = nil
    toApply.campaignents_RollerDoneWarn = nil

    local timerName = "campaignents_buriedroller_unbury" .. toApply:GetCreationID()
    local time = math.Rand( 0.8, 1.3 )
    time = math.Round( time, 2 )

    timer.Create( timerName, time, 0, function()
        if not IsValid( toApply ) then timer.Remove( timerName ) return end

        if toApply.campaignents_RollerHasAmbushed then
            timer.Adjust( timerName, 1, nil, nil )
            if toApply.campaignents_RollerWarns < 3 then
                toApply.campaignents_RollerWarns = toApply.campaignents_RollerWarns + 1
                local pitch = 100 + ( toApply.campaignents_RollerWarns * 10 )
                toApply:EmitSound( "npc/roller/mine/rmine_predetonate.wav", 82, pitch )

            else
                toApply:EmitSound( "npc/roller/mine/rmine_shockvehicle1.wav", 82, math.random( 90, 110 ) )
                local dmgInfo = DamageInfo()
                dmgInfo:SetDamageType( DMG_BLAST )
                dmgInfo:SetDamage( 50 )
                dmgInfo:SetAttacker( game.GetWorld() )
                dmgInfo:SetInflictor( game.GetWorld() )
                toApply:TakeDamageInfo( dmgInfo )

                timer.Remove( timerName )

            end
            return

        end

        if toApply.campaignents_RollerForcedAmbush then
            Ambush( toApply )
            timer.Adjust( timerName, 10 + math.Rand( 0, 1 ), nil, nil )
            return

        end

        local enemy = toApply:GetEnemy()
        if not IsValid( enemy ) then return end

        if not toApply.campaignents_RollerDoneWarn then
            if math.random( 1, 100 ) > 85 then
                toApply:EmitSound( "npc/roller/remote_yes.wav", 85, math.random( 95, 110 ) )
                toApply.campaignents_RollerDoneWarn = true

            -- let them do delayed chirp sometimes
            elseif math.random( 1, 100 ) > 50 then
                toApply.campaignents_RollerDoneWarn = true

            end
        end

        if not toApply.campaignents_RollerSpedUpTimer then
            toApply.campaignents_RollerSpedUpTimer = true
            timer.Adjust( timerName, 0.3, nil, nil )

        end

        local disToTargSqr = enemy:GetPos():DistToSqr( toApply:GetPos() )
        if disToTargSqr < distToUnburySqr then
            Ambush( toApply )
            timer.Adjust( timerName, 10 + math.Rand( 0, 1 ), nil, nil )

        end
    end )
end

duplicator.RegisterEntityModifier( ENT.EntModifierName, ENT.ProxyPostSpawnFunc )