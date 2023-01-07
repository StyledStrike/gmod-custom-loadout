--[[
    Developers! If you want to blacklist/hide weapons, check the README here:
    https://github.com/StyledStrike/gmod-custom-loadout
]]

CLoadout = {}

function CLoadout.PrintF( str, ... )
    MsgC( Color( 255, 94, 0 ), "[Custom Loadout] ", Color( 255, 255, 255 ), string.format( str, ... ), "\n" )
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

    AddCSLuaFile( "custom_loadout/cl_main.lua" )
    AddCSLuaFile( "custom_loadout/cl_ui.lua" )

    resource.AddSingleFile( "resource/localization/en/custom_loadout.properties" )
    resource.AddSingleFile( "resource/localization/fr/custom_loadout.properties" )
    resource.AddSingleFile( "resource/localization/pt-br/custom_loadout.properties" )
    resource.AddSingleFile( "resource/localization/ru/custom_loadout.properties" )
end

if CLIENT then
    include( "custom_loadout/cl_main.lua" )
    include( "custom_loadout/cl_ui.lua" )
end
