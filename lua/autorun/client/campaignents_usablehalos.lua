local doHalos = CreateClientConVar( "cl_campaignents_halos", 1, true, false, "Do halos over usable entities?" )
local haloR = CreateClientConVar( "cl_campaignents_halo_r", 0, true, false, "Red component of saveent's halo color." )
local haloG = CreateClientConVar( "cl_campaignents_halo_g", 0, true, false, "Green component of saveent's halo color." )
local haloB = CreateClientConVar( "cl_campaignents_halo_b", 255, true, false, "Blue component of saveent's halo color." )

local theColor = Color( 0, 0, 0 )
local nextCheck = 0

local _CurTime = CurTime

local function haloColor()
    if nextCheck > _CurTime() then return theColor end
    nextCheck = nextCheck + 1

    theColor.r, theColor.g, theColor.b = haloR:GetInt(), haloG:GetInt(), haloB:GetInt()

    return theColor

end

local _LocalPlayer = LocalPlayer
local _IsValid = IsValid
local disSqr = 150^2

hook.Add( "PreDrawHalos", "saveentities_usablehalos", function()
    if not doHalos:GetBool() then return end
    if _LocalPlayer():Health() <= 0 then return end
    local tr = _LocalPlayer():GetEyeTrace()
    local ent = tr.Entity

    if not _IsValid( ent ) then return end
    if tr.HitWorld then return end
    if not ent.campaignents_Usable then return end
    if _LocalPlayer():GetShootPos():DistToSqr( tr.HitPos ) > disSqr then return end
    if not CAMPAIGN_ENTS.CanBeUgly() then return end

    halo.Add( { ent }, haloColor() )

end )