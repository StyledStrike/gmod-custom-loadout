# Custom Loadout

A loadout customization addon for Garry's Mod.

[![GLuaLint](https://github.com/StyledStrike/gmod-custom-loadout/actions/workflows/glualint.yml/badge.svg)](https://github.com/FPtje/GLuaFixer)
[![Workshop Page](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-steam-workshop.jross.me%2F2675972006%2Fsubscriptions-text)](https://steamcommunity.com/sharedfiles/filedetails/?id=2675972006)

### Features

* Search weapons by name
* Gives ammo to all weapons
* Supports [URS](https://steamcommunity.com/sharedfiles/filedetails/?id=112423325)
* Supports [WUMA](https://steamcommunity.com/sharedfiles/filedetails/?id=1117436840)
* Supports [Builder-X](https://www.gmodstore.com/market/view/builder-x)
* Server owners can set _global_ ammo limits with `custom_loadout_primary_limit` and `custom_loadout_secondary_limit`
* You can choose which weapon you prefer to hold when the loadout is applied

### Developer Notes

If you want to blacklist weapons, you can either install and use URS/WUMA, or copy the example hook below and modify it as you wish.

```lua
-- Example: Only allow admins to use the Annabelle 
hook.Add('CustomLoadout.IsWeaponBlacklisted', 'cloadout_blacklist_example', function(ply, weaponClass)
    if weaponClass == 'weapon_annabelle' and not ply:IsAdmin() then
        return true
    end
end)
```

Returning `true` prevents the weapon from being given, and also marks them as unavailable on the loadout. Also, keep these in mind:

* URS/WUMA/BuilderX/sandbox's `PlayerGiveSWEP` restrictions still apply even if this hook doesn't block a weapon
* The hook must be added on a shared realm (both on _CLIENT_ and _SERVER_)
* It doesn't work in single player _(so if you need to test it, do it on a local, peer-to-peer or dedicated server instead.)_

You can also override which weapon is preferred by using this hook:

```lua
hook.Add( "CLoadoutOverridePreferredWeapon", "OverridePreferredWeaponExample", function( ply, preferredClass )
    -- With godmode, prefer to use the Physics Gun
    if ply:HasGodMode() then
        return "weapon_physgun"
    end

    -- You can return false instead to disable the automatic selection of
    -- a preferred weapon, allowing you to do custom logic after a loadout is given
    ply:Give( "weapon_physgun" )
    ply:SelectWeapon( "weapon_physgun" )

    return false
end )
```

## Contributing

Please follow the [CFC style guidelines](https://github.com/CFC-Servers/cfc_glua_style_guidelines) before opening pull requests.