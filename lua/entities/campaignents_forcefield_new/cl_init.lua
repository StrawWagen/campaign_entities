include( "shared.lua" )

local material = Material( "effects/combineshield/comshieldwall3" )

function ENT:Initialize()
    self:EnableCustomCollisions( true )

end

local topOffset = Vector( 0, 0, 190 )

function ENT:Draw()
    if self:GetSkin() ~= 0 then return end -- needs to be on!

    local dummyStart = self:GetNWEntity( "dummystart" )
    local dummyEnd = self:GetNWEntity( "dummyend" )
    if not IsValid( dummyStart ) then return end
    if not IsValid( dummyEnd ) then return end

    local startsUp = dummyStart:GetUp()
    local endsUp = dummyEnd:GetUp()


    -- draw fake shield, from start dummy to end dummy.
    local matrix = Matrix()
    -- move to base of shield.
    matrix:Translate( dummyStart:GetPos() + startsUp * -40 )
    -- use shield's angles
    matrix:SetAngles( dummyStart:GetAngles() )

    local startBottom = vector_origin
    local startTop = topOffset
    local endBottom = dummyStart:WorldToLocal( dummyEnd:GetPos() )
    local endTop = dummyStart:WorldToLocal( dummyEnd:GetPos() + endsUp * 190 )
    self:SetRenderBounds( -startsUp * 150, endBottom + startsUp * 150 )

    render.SetMaterial( material )

    cam.PushModelMatrix( matrix )
        self:DrawShield( startBottom, startTop, endBottom, endTop )

    cam.PopModelMatrix()


    -- draw second one, starting from the end dummy, to the start dummy
    matrix = Matrix()
    -- move to base of shield.
    matrix:Translate( dummyEnd:GetPos() + endsUp * -40 )
    matrix:SetAngles( dummyEnd:GetAngles() )

    startBottom = dummyEnd:WorldToLocal( dummyStart:GetPos() )
    startTop = dummyEnd:WorldToLocal( dummyStart:GetPos() + startsUp * 190 )
    endBottom = vector_origin
    endTop = topOffset

    cam.PushModelMatrix( matrix )
        self:DrawShield( endBottom, endTop, startBottom, startTop )

    cam.PopModelMatrix()

end

function ENT:DrawShield( startBottom, startTop, endBottom, endTop )
    mesh.Begin( MATERIAL_TRIANGLES, 2 )
        mesh.Position( startBottom )
        mesh.TexCoord( 0, 0, 0 )
        mesh.AdvanceVertex()

        mesh.Position( startTop )
        mesh.TexCoord( 0, 0, 3 )
        mesh.AdvanceVertex()

        mesh.Position( endTop )
        mesh.TexCoord( 0, 3, 3 )
        mesh.AdvanceVertex()

        mesh.Position( endTop )
        mesh.TexCoord( 0, 3, 3 )
        mesh.AdvanceVertex()

        mesh.Position( endBottom )
        mesh.TexCoord( 0, 3, 0 )
        mesh.AdvanceVertex()

        mesh.Position( startBottom )
        mesh.TexCoord( 0, 0, 0 )
        mesh.AdvanceVertex()

    mesh.End()
end

function ENT:Think()
    local mySkin = self:GetSkin()
    if self.shield_OldSkin == mySkin then return end
    if not self:DoShieldCollisions() then return end -- not ready

    self.shield_OldSkin = mySkin

end