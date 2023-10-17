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
    if self.Scale <= 0 then return end
    local emitter = ParticleEmitter( data:GetOrigin() )
    local lifetime = 25

    for _ = 1, self.Scale do
        local rollparticle = emitter:Add( "particle/particle_smokegrenade1", vOffset )
        rollparticle:SetPos( vOffset + baseOffset() )
        local vel = ( ( self.Normal * 0.5 ) + VectorRand() )
        vel = vel * flatten * math.random( 50, 160 )
        vel.z = math.Clamp( vel.z, 10, math.huge )
        rollparticle:SetVelocity( vel )
        rollparticle:SetDieTime( lifetime + math.Rand( -5, 5 ) )
        rollparticle:SetColor( 250, 255, 220 )
        rollparticle:SetStartAlpha( 255 )
        rollparticle:SetEndAlpha( 0 )
        rollparticle:SetStartSize( 50 )
        rollparticle:SetEndSize( 500 )
        rollparticle:SetRoll( math.Rand( -360, 360 ) )
        rollparticle:SetRollDelta( math.Rand( -0.1, 0.1 ) )
        rollparticle:SetAirResistance( 10 )
        rollparticle:SetGravity( Vector( 0, 0, 0 ) )
        rollparticle:SetCollide( false )

    end

    emitter:Finish()

end

function EFFECT:Render()
end
