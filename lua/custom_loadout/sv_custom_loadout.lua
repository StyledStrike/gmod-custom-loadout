util.AddNetworkString('CLoadout.Apply')

local cvarLimitPrimary = CreateConVar('custom_loadout_primary_limit', '5000', bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY),
	'[Custom Loadout] Limits how much primary ammo is given to players.', 0, 9999)

local cvarLimitSecondary = CreateConVar('custom_loadout_secondary_limit', '50', bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY),
	'[Custom Loadout] Limits how much secondary ammo is given to players.', 0, 9999)

-- store player loadouts
CLoadout.cache = {}

function CLoadout:IsAvailableFor(ply)
	-- builderx compatibility
	if ply.GetBuild and ply:GetBuild() then
		return false, 'Your loadout will be applied once you leave build mode.'
	end

	return true
end

function CLoadout:GiveAmmoToAllWeapons(ply)
	if not IsValid(ply) then return end

	ply:StripAmmo()

	local primaryAmount = cvarLimitPrimary:GetInt()
	local secondaryAmount = cvarLimitSecondary:GetInt()

	if self.cache[ply:SteamID()] then
		primaryAmount = math.Clamp(self.cache[ply:SteamID()].ammo1, 0, cvarLimitPrimary:GetInt())
		secondaryAmount = math.Clamp(self.cache[ply:SteamID()].ammo2, 0, cvarLimitSecondary:GetInt())
	end

	for _, v in ipairs(ply:GetWeapons()) do
		if IsValid(v) then
			if primaryAmount > 0 and v:GetPrimaryAmmoType() ~= -1 then
				ply:GiveAmmo(primaryAmount, v:GetPrimaryAmmoType())
			end

			if secondaryAmount > 0 and v:GetSecondaryAmmoType() ~= -1 then
				ply:GiveAmmo(secondaryAmount, v:GetSecondaryAmmoType())
			end
		end
	end
end

function CLoadout:GiveWeapons(ply)
	if not IsValid(ply) or ply:Health() <= 0 then return end

	ply:StripWeapons()

	local cache = self.cache[ply:SteamID()]
	local items = cache.items

	if #items == 0 then return end

	local preferredWeapon

	for _, class in ipairs(items) do
		local swep = list.Get('Weapon')[class]
		if not swep then continue end

		-- dont give admin-only weapons if ply is not a admin (duh)
		if (swep.AdminOnly or not swep.Spawnable) and not ply:IsAdmin() then continue end

		-- sandbox compatibility (yeah...)
		if not gamemode.Call('PlayerGiveSWEP', ply, class, swep) then continue end

		if self:IsBlacklisted(ply, class) then continue end

		local success = pcall(ply.Give, ply, swep.ClassName)

		-- if giving the weapon was successful, and
		-- this is the prefered weapon by this ply...
		if success and cache.preferred == swep.ClassName then
			-- remember it
			preferredWeapon = swep.ClassName
		end
	end

	-- if the prefered weapon was given...
	if preferredWeapon then
		ply:SelectWeapon(preferredWeapon)
	end

	self:GiveAmmoToAllWeapons(ply)
end

function CLoadout:Apply(ply)
	if not self:IsAvailableFor(ply) then return end

	local steamId = ply:SteamID()

	-- timers were used here just to override other addon's shenanigans

	if self.cache[steamId] and self.cache[steamId].enabled then
		timer.Simple(0.1, function()
			CLoadout:GiveWeapons(ply)
		end)

		return true
	else
		timer.Simple(0.1, function()
			CLoadout:GiveAmmoToAllWeapons(ply)
		end)
	end
end

function CLoadout:ReceiveData(len, ply)
	local data = net.ReadData(len)
	data = util.Decompress(data)

	if not data or data == '' then return end

	local steamId = ply:SteamID()
	local loadout = util.JSONToTable(data)

	if not loadout then
		CLoadout.PrintF('Failed to parse %s\'s loadout!', ply:Nick())

		return
	end

	self.cache[steamId] = {
		enabled = loadout.enabled,
		preferred = loadout.preferred,
		items = {},

		ammo1 = tonumber(loadout.ammo1) or cvarLimitPrimary:GetInt(),
		ammo2 = tonumber(loadout.ammo2) or cvarLimitSecondary:GetInt()
	}

	-- no need to go further if the loadout isnt enabled
	if not loadout.enabled then return end

	-- filter inexistent weapons
	for _, class in ipairs(loadout.items) do
		local swep = list.Get('Weapon')[class]

		if swep then
			table.insert(self.cache[steamId].items, class)
		end
	end

	local canUse, reason = self:IsAvailableFor(ply)

	if not canUse then
		ply:ChatPrint('[Custom Loadout] ' .. reason)

		return
	end

	self:GiveWeapons(ply)
end

-- remove the loadout from cache when players leave
hook.Add('PlayerDisconnected', 'CLoadout_ClearCache', function(ply)
	if not ply:IsBot() and CLoadout.cache[ply:SteamID()] then
		CLoadout.cache[ply:SteamID()] = nil
	end
end)

-- apply the loadout
hook.Add('PlayerLoadout', 'CLoadout_ApplyLoadout', function(ply)
	return CLoadout:Apply(ply)
end)

-- apply the loadout when leaving build mode (builderx)
hook.Add('builderx.mode.onswitch', 'CLoadout_ApplyLoadoutOnExitBuild', function(ply, bIsBuild)
	if not bIsBuild then
		CLoadout:Apply(ply)
	end
end)

net.Receive('CLoadout.Apply', function(len, ply)
	CLoadout:ReceiveData(len, ply)
end)