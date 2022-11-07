function CLoadout:InitRegistry()
	-- weapons that cant be automatically listed by code
	local registry = {
		['weapon_crowbar'] = {name = 'Crowbar', no_primary = true, no_secondary = true},
		['weapon_stunstick'] = {name = 'Stunstick', no_primary = true, no_secondary = true},
		['weapon_physcannon'] = {name = 'Gravity Gun', no_primary = true, no_secondary = true},
		['weapon_physgun'] = {name = 'Physics Gun', no_primary = true, no_secondary = true},
		['weapon_pistol'] = {name = '9mm Pistol', no_secondary = true},
		['weapon_357'] = {name = '.357 Magnum', no_secondary = true},
		['weapon_smg1'] = {name = 'SMG'},
		['weapon_ar2'] = {name = 'Pulse-Rifle'},
		['weapon_shotgun'] = {name = 'Shotgun', no_secondary = true},
		['weapon_crossbow'] = {name = 'Crossbow', no_secondary = true},
		['weapon_frag'] = {name = 'Grenade', no_secondary = true},
		['weapon_rpg'] = {name = 'RPG', no_secondary = true},
		['weapon_slam'] = {name = 'S.L.A.M', no_primary = true},
		['weapon_bugbait'] = {name = 'Bug Bait', no_primary = true, no_secondary = true},
		['weapon_alyxgun'] = {name = 'Alyx Gun'},
		['weapon_annabelle'] = {name = 'Annabelle'}
	}

	-- half life: source (if mounted)
	if IsMounted('hl1') or IsMounted('hl1mp') then
		registry['weapon_crowbar_hl1'] = {name = 'Crowbar (HL1)', no_primary = true, no_secondary = true}
		registry['weapon_glock_hl1'] = {name = 'Glock (HL1)', no_secondary = true}
		registry['weapon_egon'] = {name = 'Gluon Gun (HL1)', no_secondary = true}
		registry['weapon_gauss'] = {name = 'Tau Cannon (HL1)', no_secondary = true}
		registry['weapon_357_hl1'] = {name = '.357 Handgun (HL1)', no_secondary = true}
		registry['weapon_mp5_hl1'] = {name = 'MP5 (HL1)'}
		registry['weapon_shotgun_hl1'] = {name = 'SPAS-12 (HL1)', no_secondary = true}
		registry['weapon_crossbow_hl1'] = {name = 'Crossbow (HL1)', no_secondary = true}
		registry['weapon_handgrenade'] = {name = 'Hand Grenade (HL1)', no_secondary = true}
		registry['weapon_hornetgun'] = {name = 'Hornet Gun (HL1)'}
		registry['weapon_rpg_hl1'] = {name = 'RPG Launcher (HL1)'}
		registry['weapon_satchel'] = {name = 'Satchel (HL1)', no_secondary = true}
		registry['weapon_snark'] = {name = 'Snarks (HL1)', no_secondary = true}
		registry['weapon_tripmine'] = {name = 'Tripmine (HL1)', no_secondary = true}
	end

	-- add scripted weapons (aka SWEPs) to our registry
	-- (note: "engine" weapons arent listed here,
	-- so we had to manually add them earlier)
	for _, v in pairs(weapons.GetList()) do
		if not v.ClassName then continue end
		--if not v.Spawnable then continue end

		-- dont list 'base' class weapons
		if string.find(v.ClassName, '_base', 1, true) then continue end

		registry[v.ClassName] = {
			admin_only = v.AdminOnly,
			name = (v.PrintName and v.PrintName ~= '') and v.PrintName or v.ClassName
		}

		if v.Primary and not v.Primary.ClipSize then
			registry[v.ClassName].no_primary = true
		end

		if v.Secondary and not v.Secondary.ClipSize then
			registry[v.ClassName].no_secondary = true
		end
	end

	self.weapon_registry = registry
end

function CLoadout:GetAmmoLimits()
	local cvar_primary_limit = GetConVar('custom_loadout_primary_limit')
	local cvar_secondary_limit = GetConVar('custom_loadout_secondary_limit')

	return
		cvar_primary_limit and cvar_primary_limit:GetInt() or 5000,
		cvar_secondary_limit and cvar_secondary_limit:GetInt() or 50
end

function CLoadout:FindLoadoutByName(name)
	for k, v in ipairs(self.loadouts) do
		if v.name == name then return k end
	end
end

function CLoadout:CreateLoadout(name, items, preferred)
	local loadout = {
		name = 'My Loadout',
		items = {}
	}

	if name and isstring(name) then
		loadout.name = name
	end

	if preferred and isstring(preferred) then
		loadout.preferred = preferred
	end

	if istable(items) and table.IsSequential(items) then
		for _, item in ipairs(items) do
			loadout.items[#loadout.items + 1] = {
				item[1], tonumber(item[2]) or 0, tonumber(item[3]) or 0
			}
		end
	end

	return table.insert(self.loadouts, loadout)
end

function CLoadout:DeleteLoadout(index)
	table.remove(self.loadouts, index)

	if #self.loadouts == 0 then
		self:CreateLoadout()
	end

	self.loadout_index = #self.loadouts
	self:UpdateLists()
end

function CLoadout:Apply()
	local data = { enabled = false }

	if self.enabled then
		local loadout = self.loadouts[self.loadout_index]

		data.enabled = true
		data.items = loadout.items
		data.preferred = loadout.preferred
	end

	data = util.Compress( util.TableToJSON(data) )

	if not data then
		CLoadout.PrintF('Failed to compress the loadout data!')

		return
	end

	net.Start('cloadout.apply', false)
	net.WriteData(data, #data)
	net.SendToServer()
end

function CLoadout:Save()
	file.Write('custom_loadout.txt', util.TableToJSON({
		enabled = self.enabled,
		loadouts = self.loadouts,
		loadout_index = self.loadout_index
	}))
end

function CLoadout:AddWeapon(class)
	table.insert(self.loadouts[self.loadout_index].items, {
		class, 200, 1
	})

	self:UpdateLists()
end

function CLoadout:RemoveWeapon(index)
	table.remove(self.loadouts[self.loadout_index].items, index)
	self:UpdateLists()
end

function CLoadout:PreferWeapon(class)
	self.loadouts[self.loadout_index].preferred = class
	self:UpdateLoadoutList()
	self:Save()
end

function CLoadout:Init()
	-- search filter
	self.filter = ''

	-- settings
	self.enabled = false
	self.loadout_index = 1
	self.loadouts = {}

	-- cleanup on autorefresh
	if IsValid(self.frame) then
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
	if not file.Exists('custom_loadout.txt', 'DATA') then return end

	local data = file.Read('custom_loadout.txt', 'DATA')
	if not data or data == '' then
		Loadout.PrintF('No Custom Loadout data on disk.')
		return
	end

	data = util.JSONToTable(data)

	if not data then
		Loadout.PrintF('Failed to parse the loadout data!')
		return
	end

	if data.enabled then
		self.enabled = true
	end

	if data.loadout_index then
		self.loadout_index = tonumber(data.loadout_index) or 1
	end

	if istable(data.loadouts) and table.IsSequential(data.loadouts) then
		for _, v in ipairs(data.loadouts) do
			self:CreateLoadout(v.name, v.items, v.preferred)
		end
	end
end

-- late init (to make sure all weapons are "ready")
hook.Add('InitPostEntity', 'CLoadout_Initialize', function()
	hook.Remove('InitPostEntity', 'CLoadout_Initialize')

	-- on rare occasions it just didnt work if called right at InitPostEntity
	timer.Simple(1, function() CLoadout:Init() end)
end)

concommand.Add('custom_loadout_open', function()
	CLoadout:ShowPanel()
end, nil, 'Opens the loadout customization window.')

-- convert old save files to the new format
do
	local data = file.Read('sanct_loadout.txt', 'DATA')
	if not data or data == '' then return end

	data = util.JSONToTable(data)

	if not data then
		Loadout.PrintF('Failed to parse old loadout data!')

		return
	end

	local new_data = {
		enabled = false,
		loadout_index = 1,
		loadouts = {}
	}

	if data.enabled then
		new_data.enabled = true
	end

	if istable(data.loadouts) and table.IsSequential(data.loadouts) then
		for _, v in ipairs(data.loadouts) do
			local loadout = {
				name = 'My Loadout',
				items = {}
			}

			if v.name and isstring(v.name) then
				loadout.name = v.name
			end

			if v.preferred and isstring(v.preferred) then
				loadout.preferred = v.preferred
			end

			if istable(v.items) and table.IsSequential(v.items) then
				for _, class in ipairs(v.items) do
					loadout.items[#loadout.items + 1] = {
						class, 200, 1
					}
				end
			end

			table.insert(new_data.loadouts, loadout)
		end
	end

	-- very old format
	if istable(data.items) and table.IsSequential(data.items) then
		local loadout = {
			name = 'Old Loadout',
			items = {}
		}

		if data.preferred and isstring(data.preferred) then
			loadout.preferred = data.preferred
		end

		for _, class in ipairs(data.items) do
			loadout.items[#loadout.items + 1] = {
				class, 200, 1
			}
		end

		table.insert(new_data.loadouts, loadout)
	end

	CLoadout.PrintF('Converted old loadout data to the new format.')

	file.Write('custom_loadout.txt', util.TableToJSON(new_data))
	file.Delete('sanct_loadout.txt')
end