function CLoadout:InitRegistry()
    local registry = {}
    local categories = {}

    for _, v in pairs( list.Get( "Weapon" ) ) do
        if not v.ClassName or not v.Spawnable then continue end

        local cat = v.Category or "-"

        if not isstring( cat ) then
            cat = tostring( cat )
        end

        categories[cat] = true

        registry[v.ClassName] = {
            adminOnly = v.AdminOnly,
            name = ( v.PrintName and v.PrintName ~= "" ) and v.PrintName or v.ClassName,
            category = cat
        }

        if v.Primary and not v.Primary.ClipSize then
            registry[v.ClassName].noPrimary = true
        end

        if v.Secondary and not v.Secondary.ClipSize then
            registry[v.ClassName].noSecondary = true
        end
    end

    self.categories = table.GetKeys( categories )
    self.weaponRegistry = registry

    table.sort( self.categories )
end

function CLoadout:GetAmmoLimits()
    local cvarPrimaryLimit = GetConVar( "custom_loadout_primary_limit" )
    local cvarSecondaryLimit = GetConVar( "custom_loadout_secondary_limit" )

    return
        cvarPrimaryLimit and cvarPrimaryLimit:GetInt() or 5000,
        cvarSecondaryLimit and cvarSecondaryLimit:GetInt() or 50
end

function CLoadout:FindLoadoutByName( name )
    for k, v in ipairs( self.loadouts ) do
        if v.name == name then return k end
    end
end

function CLoadout:CreateLoadout( name, items, preferred )
    local loadout = {
        name = "My Loadout",
        items = {}
    }

    if name and isstring( name ) then
        loadout.name = name
    end

    if preferred and isstring( preferred ) then
        loadout.preferred = preferred
    end

    if istable( items ) and table.IsSequential( items ) then
        for _, item in ipairs( items ) do
            loadout.items[#loadout.items + 1] = {
                item[1],                    -- class
                tonumber( item[2] ) or 0,   -- primary ammo
                tonumber( item[3] ) or 0    -- secondary ammo
            }
        end
    end

    return table.insert( self.loadouts, loadout )
end

function CLoadout:DeleteLoadout( index )
    table.remove( self.loadouts, index )

    if #self.loadouts == 0 then
        self:CreateLoadout()
    end

    self.loadoutIndex = #self.loadouts
    self:UpdateLists()
end

function CLoadout:Apply()
    local data = { enabled = false }

    if self.enabled then
        local loadout = self.loadouts[self.loadoutIndex]

        data.enabled = true
        data.items = loadout.items
        data.preferred = loadout.preferred
    end

    data = util.Compress( util.TableToJSON( data ) )

    if not data then
        CLoadout.PrintF( "Failed to compress the loadout data!" )

        return
    end

    net.Start( "cloadout.apply", false )
    net.WriteData( data, #data )
    net.SendToServer()
end

function CLoadout:Save()
    file.Write(
        "custom_loadout.txt",
        util.TableToJSON( {
            enabled = self.enabled,
            loadouts = self.loadouts,
            loadout_index = self.loadoutIndex
        } )
    )
end

function CLoadout:AddWeapon( class )
    local items = self.loadouts[self.loadoutIndex].items

    if #items < self:GetWeaponLimit() then
        table.insert( items, { class, 200, 1 } )
        self:UpdateLists()
    else
        Derma_Message( "#cloadout.weapon_limit", "#cloadout.title", "#cloadout.ok" )
    end
end

function CLoadout:AddInventoryWeapons()
    local items = self.loadouts[self.loadoutIndex].items

    -- find which classes are already in this loadout
    local alreadyInLoadout = {}

    for _, v in ipairs( items ) do
        alreadyInLoadout[v[1]] = true
    end

    -- add inventory weapons, except the ones already on the loadout
    local weaponsList = LocalPlayer():GetWeapons()

    for _, v in ipairs( weaponsList ) do
        local class = ( v.GetClass and v:GetClass() ) or v.ClassName

        if not alreadyInLoadout[class] then
            table.insert(
                self.loadouts[self.loadoutIndex].items,
                { class, 200, 1 }
            )
        end
    end

    self:UpdateLists()
end

function CLoadout:RemoveWeapon( index )
    table.remove( self.loadouts[self.loadoutIndex].items, index )
    self:UpdateLists()
end

function CLoadout:PreferWeapon( class )
    self.loadouts[self.loadoutIndex].preferred = class
    self:UpdateLoadoutList()
    self:Save()
end

function CLoadout:Init()
    -- search filter
    self.filter = ""

    -- settings
    self.enabled = false
    self.loadoutIndex = 1
    self.loadouts = {}

    -- cleanup on autorefresh
    if IsValid( self.frame ) then
        self.frame:Close()
        self.frame = nil
    end

    self:InitRegistry()
    self:Load()

    if #self.loadouts == 0 then
        self:CreateLoadout()
    end

    self:Apply()
end

function CLoadout:Load()
    if not file.Exists( "custom_loadout.txt", "DATA" ) then return end

    local data = file.Read( "custom_loadout.txt", "DATA" )
    if not data or data == "" then
        Loadout.PrintF( "No Custom Loadout data on disk." )
        return
    end

    data = util.JSONToTable( data )

    if not data then
        Loadout.PrintF( "Failed to parse the loadout data!" )
        return
    end

    if data.enabled then
        self.enabled = true
    end

    if data.loadout_index then
        self.loadoutIndex = tonumber( data.loadout_index ) or 1
    end

    if istable( data.loadouts ) and table.IsSequential( data.loadouts ) then
        for _, v in ipairs( data.loadouts ) do
            self:CreateLoadout( v.name, v.items, v.preferred )
        end
    end
end

-- late init (to make sure all weapons have been registered)
hook.Add( "InitPostEntity", "CLoadout_Initialize", function()
    hook.Remove( "InitPostEntity", "CLoadout_Initialize" )

    -- on rare occasions it just didnt work
    -- if called right at InitPostEntity
    timer.Simple( 1, function() CLoadout:Init() end )
end )

hook.Add( "OnPlayerChat", "CLoadout_ChatCommand", function( ply, text )
    if ply ~= LocalPlayer() then return end
    if text[1] ~= "!" then return end

    if string.lower( string.Trim( text ) ) == "!loadout" then
        CLoadout:ShowPanel()
    end
end )

concommand.Add(
    "custom_loadout_open",
    function() CLoadout:ShowPanel() end,
    nil,
    "Opens the loadout customization window."
)

-- convert old save files to the new format
do
    local data = file.Read( "sanct_loadout.txt", "DATA" )
    if not data or data == "" then return end

    data = util.JSONToTable( data )

    if not data then
        Loadout.PrintF( "Failed to parse old loadout data!" )

        return
    end

    local newData = {
        enabled = false,
        loadoutIndex = 1,
        loadouts = {}
    }

    if data.enabled then
        newData.enabled = true
    end

    if istable( data.loadouts ) and table.IsSequential( data.loadouts ) then
        for _, v in ipairs( data.loadouts ) do
            local loadout = {
                name = "My Loadout",
                items = {}
            }

            if v.name and isstring( v.name ) then
                loadout.name = v.name
            end

            if v.preferred and isstring( v.preferred ) then
                loadout.preferred = v.preferred
            end

            if istable( v.items ) and table.IsSequential( v.items ) then
                for _, class in ipairs( v.items ) do
                    loadout.items[#loadout.items + 1] = {
                        class, 200, 1
                    }
                end
            end

            table.insert( newData.loadouts, loadout )
        end
    end

    -- very old format (which only had a single loadout)
    if istable( data.items ) and table.IsSequential( data.items ) then
        local loadout = {
            name = "Old Loadout",
            items = {}
        }

        if data.preferred and isstring( data.preferred ) then
            loadout.preferred = data.preferred
        end

        for _, class in ipairs( data.items ) do
            loadout.items[#loadout.items + 1] = {
                class, 200, 1
            }
        end

        table.insert( newData.loadouts, loadout )
    end

    CLoadout.PrintF( "Converted old loadout data to the new format." )

    file.Write( "custom_loadout.txt", util.TableToJSON( newData ) )
    file.Delete( "sanct_loadout.txt" )
end
