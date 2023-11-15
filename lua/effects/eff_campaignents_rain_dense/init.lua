local flatten = Vector( 1, 1, 0.05 )
local up = Vector( 0,0,1 )
local math_random = math.random

function EFFECT:Init( data )
    self.Ent = data:GetEntity()
    self.Scale = data:GetScale() or 25
    if self.Scale <= 0 then return end

    local ply = self.Ent
    local entsPos = ply:GetPos()
    local vOffset = entsPos + ply:GetVelocity() * 1.8
    local emitter = ParticleEmitter( vOffset )
    local darkness

    local scale = self.Scale
    local maxDrops = 50 * scale
    local doneCount = 0
    local done = 0
    local attemptLimit = 10000

    local upDist = 3000
    local minDist = 1000

    if ply and ply.campaignEnts_NearestSkyPos then
        distToSkyPos = ply.campaignEnts_NearestSkyPos:Distance( entsPos )

        upDist = math.Clamp( distToSkyPos, minDist, 6000 )

    end

    while doneCount < maxDrops and done < attemptLimit do

        done = done + 1

        local itsDist = math_random( 2000 / scale, 8000 / scale )

        local upComp = up * ( upDist + -500 )
        local randomComp = VectorRand() * flatten
        randomComp:Normalize()
        randomComp = randomComp * itsDist

        local particleOffset = upComp + randomComp
        local particlePos = vOffset + particleOffset

        local contents = util.PointContents( particlePos )
        if bit.bor( contents, CONTENTS_SOLID ) ~= 1 then continue end

        if not darkness then
            darkness = math.Clamp( render.GetLightColor( particlePos ):Length() + 0.30, 0.25, 0.75 )

        end

        local particleTex = "particle/raindrop-multi2_campaignents.vtf"
        local startSize = 400
        local endSize = 400
        local alpha = 100
        local speedScale = 1
        local lifetime = 10

        local isAMasker = false -- mask the circle of raindrops above ply a bit

        if itsDist > 5000 / scale then
            particleTex = "particle/particle_smokegrenade1"
            lifetime = 20
            alpha = 80
            speedScale = 0.5
            startSize = 1000
            endSize = 1500

            isAMasker = scale >= 1.5 and math_random( 0, 100 ) >= 75

        end


        local dropDir = -up
        if isAMasker then
            particlePos = particlePos + ( -up * 500 )
            alpha = 255
            speedScale = 0.15
            dropDir = VectorRand() * flatten
            dropDir:Normalize()

        end

        local rollparticle = emitter:Add( particleTex, particlePos )

        local vel = ( dropDir * math_random( 900, 1300 ) * scale * speedScale )
        vel = vel + ( VectorRand() * 10 )

        rollparticle:SetVelocity( vel )

        rollparticle:SetDieTime( lifetime + math.Rand( -5, 5 ) )
        rollparticle:SetColor( 0, 200 * darkness, 200 * darkness )
        rollparticle:SetStartAlpha( alpha )
        rollparticle:SetEndAlpha( alpha )
        rollparticle:SetStartSize( startSize )
        rollparticle:SetEndSize( endSize )

        rollparticle:SetCollide( true )
        rollparticle:SetCollideCallback( function( part, _, _ )
            part:SetDieTime( 0 )
            part:SetCollide( false )

        end )

        doneCount = doneCount + 1

    end
    emitter:Finish()


end

function EFFECT:Think()
    return false

end