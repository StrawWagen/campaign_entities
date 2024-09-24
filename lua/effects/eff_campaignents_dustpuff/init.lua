local flatten = Vector( 1, 1, 0.4 )

local function baseOffset()
    local vec = VectorRand() * flatten * math.random( 50, 150 )
    return vec

end


function EFFECT:Init( data )
    local vOffset = data:GetOrigin()
    self.Normal = data:GetNormal()
    self.Position = vOffset
    self.Scale = data:GetScale() or 25
    self.ParticleCount = self.Scale
    if self.Scale <= 0 then return end
    local emitter = ParticleEmitter( data:GetOrigin() )
    local lifetime = 25

    local fps = 1 / FrameTime()
    local particleScale = 1
    local cheap

    -- try and conserve fps a lil bit
    if fps <= 30 then
        cheap = true
        self.ParticleCount = self.Scale * 0.25
        particleScale = particleScale * 1.75

    elseif fps <= 60 then
        self.ParticleCount = self.Scale * 0.75
        particleScale = particleScale * 1.25

    end

    for _ = 1, self.ParticleCount do
        local rollparticle = emitter:Add( "particle/particle_smokegrenade1", vOffset )
        rollparticle:SetPos( vOffset + baseOffset() )
        rollparticle:SetDieTime( lifetime + math.Rand( -5, 5 ) )
        rollparticle:SetColor( 250, 255, 220 )
        rollparticle:SetStartAlpha( 255 )
        rollparticle:SetEndAlpha( 0 )
        rollparticle:SetStartSize( 50 * particleScale )
        rollparticle:SetEndSize( 500 * particleScale )
        rollparticle:SetRoll( math.Rand( -360, 360 ) )
        rollparticle:SetRollDelta( math.Rand( -0.1, 0.1 ) )
        rollparticle:SetAirResistance( 10 )
        rollparticle:SetCollide( false )

        if not cheap then
            local vel = ( ( self.Normal * 0.5 ) + VectorRand() )
            vel = vel * flatten * math.random( 50, 160 )
            vel.z = math.Clamp( vel.z, 10, math.huge )
            rollparticle:SetVelocity( vel )
            rollparticle:SetGravity( Vector( 0, 0, 0 ) )

        end
    end

    emitter:Finish()

end

function EFFECT:Render()
end
