# Custom Loadout
A loadout customization addon for Garry's Mod.
[Visit the workshop page here.](https://steamcommunity.com/sharedfiles/filedetails/?id=2675972006)

![Screenshot](https://i.imgur.com/xOT1vVf.png)

### Features

* Search weapons by name
* Gives ammo to all weapons
* Loadout are saved
* Supports [URS](https://steamcommunity.com/sharedfiles/filedetails/?id=112423325)
* Supports [WUMA](https://steamcommunity.com/sharedfiles/filedetails/?id=1117436840)
* Supports [Builder-X](https://www.gmodstore.com/market/view/builder-x)
* Server owners can set _global_ ammo limits with `custom_loadout_primary_limit` and `custom_loadout_secondary_limit`
* You can choose which weapon you prefer to hold when the loadout is applied

![Weapon preference](https://i.imgur.com/nWLbhs6.png)

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