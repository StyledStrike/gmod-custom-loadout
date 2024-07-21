--[[
    Developers! If you want to blacklist/hide weapons, check the README here:
    https://github.com/StyledStrike/gmod-custom-loadout
]]

CreateConVar(
    "custom_loadout_max_items",
    "40",
    bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ),
    "Limits how many weapons a single loadout can have.",
    0, 100
)

CreateConVar(
    "custom_loadout_primary_limit",
    "5000",
    bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ),
    "Limits how much primary ammo is given to players.",
    0, 9999
)

CreateConVar(
    "custom_loadout_secondary_limit",
    "50",
    bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ),
    "Limits how much secondary ammo is given to players.",
    0, 9999
)

CLoadout = {}

function CLoadout.PrintF( str, ... )
    MsgC( Color( 255, 94, 0 ), "[Custom Loadout] ", Color( 255, 255, 255 ), string.format( str, ... ), "\n" )
end

function CLoadout:GetWeaponLimit()
    if game.SinglePlayer() then return 200 end

    local cvarWeaponLimit = GetConVar( "custom_loadout_max_items" )

    return cvarWeaponLimit and cvarWeaponLimit:GetInt() or 40
end

function CLoadout:IsBlacklisted( ply, class )
    local blacklisted = hook.Run( "CustomLoadout.IsWeaponBlacklisted", ply, class )
    if tobool( blacklisted ) then return true end

    -- URS compatibility
    if URS and URS.Check then
        return URS.Check( ply, "swep", class ) == false
    end

    -- WUMA compatibility
    if WUMA then
        if SERVER then
            return ply:CheckRestriction( "swep", class )
        end

        if CLIENT and WUMA.HasRestriction then
            return WUMA.HasRestriction( ply:GetUserGroup(), "swep", class )
        end
    end

    return false
end

if SERVER then
    include( "custom_loadout/sv_main.lua" )

    AddCSLuaFile( "includes/modules/styled_theme_utils.lua" )

    AddCSLuaFile( "custom_loadout/cl_main.lua" )
    AddCSLuaFile( "custom_loadout/cl_weapon_icon.lua" )
    AddCSLuaFile( "custom_loadout/cl_ui.lua" )
end

if CLIENT then
    require( "styled_theme_utils" )

    include( "custom_loadout/cl_main.lua" )
    include( "custom_loadout/cl_weapon_icon.lua" )
    include( "custom_loadout/cl_ui.lua" )
end
