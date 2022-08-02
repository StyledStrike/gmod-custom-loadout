-- weapons that cant be automatically listed by code
local weaponsList = {
	['weapon_crowbar'] = {name = 'Crowbar'},
	['weapon_stunstick'] = {name = 'Stunstick'},
	['weapon_physcannon'] = {name = 'Gravity Gun'},
	['weapon_physgun'] = {name = 'Physics Gun'},
	['weapon_pistol'] = {name = '9mm Pistol'},
	['weapon_357'] = {name = '.357 Magnum'},
	['weapon_smg1'] = {name = 'SMG'},
	['weapon_ar2'] = {name = 'Pulse-Rifle'},
	['weapon_shotgun'] = {name = 'Shotgun'},
	['weapon_crossbow'] = {name = 'Crossbow'},
	['weapon_frag'] = {name = 'Grenade'},
	['weapon_rpg'] = {name = 'RPG'},
	['weapon_slam'] = {name = 'S.L.A.M'},
	['weapon_bugbait'] = {name = 'Bug Bait'},
	['weapon_alyxgun'] = {name = 'Alyx Gun'},
	['weapon_annabelle'] = {name = 'Annabelle'}
}

-- half life: source (if mounted)
if IsMounted('hl1') then
	weaponsList['weapon_crowbar_hl1'] = {name = 'Crowbar (HL1)'}
	weaponsList['weapon_glock_hl1'] = {name = 'Glock (HL1)'}
	weaponsList['weapon_egon'] = {name = 'Gluon Gun (HL1)'}
	weaponsList['weapon_gauss'] = {name = 'Tau Cannon (HL1)'}
	weaponsList['weapon_357_hl1'] = {name = '.357 Handgun (HL1)'}
	weaponsList['weapon_mp5_hl1'] = {name = 'MP5 (HL1)'}
	weaponsList['weapon_shotgun_hl1'] = {name = 'SPAS-12 (HL1)'}
	weaponsList['weapon_crossbow_hl1'] = {name = 'Crossbow (HL1)'}
	weaponsList['weapon_handgrenade'] = {name = 'Hand Grenade (HL1)'}
	weaponsList['weapon_hornetgun'] = {name = 'Hornet Gun (HL1)'}
	weaponsList['weapon_rpg_hl1'] = {name = 'RPG Launcher (HL1)'}
	weaponsList['weapon_satchel'] = {name = 'Satchel (HL1)'}
	weaponsList['weapon_snark'] = {name = 'Snarks (HL1)'}
	weaponsList['weapon_tripmine'] = {name = 'Tripmine (HL1)'}
end

function CLoadout:GetAmmoLimits()
	local cvarLimitPrimary = GetConVar('custom_loadout_primary_limit')
	local cvarLimitSecondary = GetConVar('custom_loadout_secondary_limit')

	return
		cvarLimitPrimary and cvarLimitPrimary:GetInt() or 5000,
		cvarLimitSecondary and cvarLimitSecondary:GetInt() or 5
end

function CLoadout:FindLoadoutByName(name)
	for k, v in ipairs(self.loadouts) do
		if v.name == name then return k end
	end
end

function CLoadout:CreateLoadout(name, items, preferred)
	return table.insert(self.loadouts, {
		name = isstring(name) and name or 'My Loadout',
		preferred = isstring(preferred) and preferred or '',
		items = (istable(items) and table.IsSequential(items)) and items or {}
	})
end

function CLoadout:DeleteLoadout(index)
	table.remove(self.loadouts, index)

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

		data.ammo1 = self.ammo1
		data.ammo2 = self.ammo2
	end

	data = util.Compress( util.TableToJSON(data) )

	if not data then
		CLoadout.PrintF('Failed to compress the loadout data!')

		return
	end

	net.Start('CLoadout.Apply', false)
	net.WriteData(data, #data)
	net.SendToServer()
end

function CLoadout:Save()
	file.Write('sanct_loadout.txt', util.TableToJSON({
		enabled = self.enabled,
		loadouts = self.loadouts,
		loadoutIndex = self.loadoutIndex,

		ammo1 = self.ammo1,
		ammo2 = self.ammo2
	}))
end

function CLoadout:AddWeapon(class)
	table.insert(self.loadouts[self.loadoutIndex].items, class)
	self:UpdateLists()
end

function CLoadout:RemoveWeapon(class)
	local items = self.loadouts[self.loadoutIndex].items

	for k, v in ipairs(items) do
		if v == class then
			table.remove(items, k)
			break
		end
	end

	self:UpdateLists()
end

function CLoadout:GetWeaponIcon(class)
	if file.Exists('materials/entities/' .. class .. '.png', 'GAME') then
		return 'entities/' .. class .. '.png'
	end

	if file.Exists('materials/vgui/entities/' .. class .. '.vtf', 'GAME') then
		return 'vgui/entities/' .. class
	end
end

function CLoadout:PreferWeapon(class)
	self.loadouts[self.loadoutIndex].preferred = class
	self:UpdateLoadoutList()
	self:Save()
end

function CLoadout:ShowWeaponOptions(class, canPrefer)
	local menu = DermaMenu()

	if canPrefer then
		menu:AddOption('Set as prefered weapon', function()
			self:PreferWeapon(class)
		end):SetIcon('icon16/award_star_gold_3.png')
	end

	menu:AddOption('Copy to clipboard', function() SetClipboardText(class) end)
	menu:Open()
end

function CLoadout:UpdateLists()
	if IsValid(self.listAvailable) then
		self:UpdateAvailableList()
	end

	if IsValid(self.listLoadout) then
		self:UpdateLoadoutList()
	end
end

-- updates the list of available weapons
function CLoadout:UpdateAvailableList()
	for _, v in ipairs(self.listAvailable:GetChildren()) do
		v:Remove()
	end

	local existingItems = self.loadouts[self.loadoutIndex].items

	for k, v in SortedPairsByMemberValue(weaponsList, 'name') do
		-- dont list weapons that are on the loadout already
		if table.HasValue(existingItems, k) then continue end

		-- dont list weapons that dont match the search filter
		if self.filter ~= '' then
			local found = string.find(string.lower(v.name), self.filter, 1, true)
			if not found then continue end
		end

		v.blacklisted = self:IsBlacklisted(LocalPlayer(), k)

		local item = self.listAvailable:Add('ContentIcon')
		item:SetName(v.name)

		if v.adminOnly then
			item:SetAdminOnly(true)
		end

		local iconPath = self:GetWeaponIcon(k)
		if iconPath then
			item:SetMaterial(iconPath)
		end

		item.DoClick = function()
			if v.adminOnly and not LocalPlayer():IsAdmin() then
				Derma_Message('This weapon is for admins only.', 'Restricted weapon', 'OK')

			elseif v.blacklisted then
				Derma_Message('This weapon is not available to you.', 'Restricted weapon', 'OK')

			else
				self:AddWeapon(k)
			end
		end

		item.OpenMenu = function()
			self:ShowWeaponOptions(k)
		end

		if v.blacklisted then
			local imgRestricted = vgui.Create('DImage', item)
			imgRestricted:Dock(FILL)
			imgRestricted:DockMargin(16, 16, 16, 16)
			imgRestricted:SetMaterial(Material('icon16/cross.png', 'smooth mips'))
			imgRestricted:SetTooltip('This weapon is not available to you')
		end
	end

	-- has to be done in this order to prevent a glitch
	self.listAvailable:InvalidateLayout(true)
	self.scrlAvailable:InvalidateLayout()
end

-- updates the list of weapons on the loadout
function CLoadout:UpdateLoadoutList()
	-- make sure we dont call the "OnSelect" callback
	-- while doing this (to prevent infinite loops)
	self.comboLoadouts._BlockSelectCallback = true
	self.comboLoadouts:Clear()

	-- update the loadout selection box
	for k, v in ipairs(self.loadouts) do
		self.comboLoadouts:AddChoice(v.name, nil, k == self.loadoutIndex)
	end

	self.comboLoadouts._BlockSelectCallback = nil

	-- update the items list
	for _, v in ipairs(self.listLoadout:GetChildren()) do
		v:Remove()
	end

	local items = self.loadouts[self.loadoutIndex].items
	local preferred = self.loadouts[self.loadoutIndex].preferred

	for _, v in ipairs(items) do
		if not weaponsList[v] then continue end

		local item = self.listLoadout:Add('ContentIcon')
		item:SetName(weaponsList[v].name)
		item:SetSize(128, 128)

		if weaponsList[v].adminOnly then
			item:SetAdminOnly(true)
		end

		local iconPath = self:GetWeaponIcon(v)
		if iconPath then
			item:SetMaterial(iconPath)
		end

		item.DoClick = function()
			self:RemoveWeapon(v)
		end

		item.OpenMenu = function()
			CLoadout:ShowWeaponOptions(v, preferred ~= v)
		end

		if preferred == v then
			local imgPreferred = vgui.Create('DImage', item)
			imgPreferred:SetPos(8, 8)
			imgPreferred:SetSize(24, 24)
			imgPreferred:SetMaterial(Material('icon16/star.png', 'smooth mips'))
			imgPreferred:SetTooltip('This is your preferred weapon')
		end
	end

	self.listLoadout:InvalidateLayout(true)
	self.scrlLoadout:InvalidateLayout()
end

function CLoadout:ShowPanel()
	if IsValid(self.frame) then
		self.frame:Close()
		self.frame = nil
		return
	end

	local frame = vgui.Create('DFrame')
	frame:SetTitle('Click on any weapon to add/remove it from your loadout.')
	frame:SetPos(0, 0)
	frame:SetSize(math.max(ScrW() * 0.6, 820), math.max(ScrH() * 0.6, 500))
	frame:SetSizable(true)
	frame:SetDraggable(true)
	frame:SetDeleteOnClose(true)
	frame:SetScreenLock(true)
	frame:SetMinWidth(820)
	frame:SetMinHeight(500)
	frame:Center()
	frame:MakePopup()

	self.frame = frame

	frame.OnClose = function()
		self:Save()
		self:Apply()
	end

	local lPanel = vgui.Create('DPanel', frame)
	local rPanel = vgui.Create('DPanel', frame)

	local function bgPaint(_, sw, sh)
		surface.SetDrawColor(32, 32, 32, 255)
		surface.DrawRect(0, 0, sw, sh)
	end

	lPanel.Paint = bgPaint
	rPanel.Paint = bgPaint

	local div = vgui.Create('DHorizontalDivider', frame)
	div:Dock(FILL)
	div:SetLeft(lPanel)
	div:SetRight(rPanel)
	div:SetDividerWidth(4)
	div:SetLeftMin(200)
	div:SetRightMin(200)
	div:SetLeftWidth(frame:GetWide() * 0.5)

	----- LEFT PANEL STUFF

	local lblAvailable = vgui.Create('DLabel', lPanel)
	lblAvailable:SetText('Available weapons')
	lblAvailable:SetFont('Trebuchet24')
	lblAvailable:SetTextColor(Color(150, 255, 150))
	lblAvailable:Dock(TOP)
	lblAvailable:DockMargin(4, 2, 0, 2)

	local entrySearch = vgui.Create('DTextEntry', lPanel)
	entrySearch:SetFont('ChatFont')
	entrySearch:SetMaximumCharCount(64)
	entrySearch:SetTabbingDisabled(true)
	entrySearch:SetPlaceholderText('Search...')
	entrySearch:SetTall(38)
	entrySearch:Dock(BOTTOM)

	entrySearch.OnChange = function(s)
		self.filter = string.lower( string.Trim(s:GetText()) )
		self:UpdateLists()
	end

	-- available weapons list
	self.scrlAvailable = vgui.Create('DScrollPanel', lPanel)
	self.scrlAvailable:Dock(FILL)

	self.listAvailable = vgui.Create('DIconLayout', self.scrlAvailable)
	self.listAvailable:Dock(FILL)
	self.listAvailable:DockMargin(0, 0, 0, 0)

	----- RIGHT PANEL STUFF

	local pnlLoadoutOptions = vgui.Create('DPanel', rPanel)
	pnlLoadoutOptions:SetTall(32)
	pnlLoadoutOptions:Dock(TOP)
	pnlLoadoutOptions:DockPadding(2, 2, 2, 2)
	pnlLoadoutOptions:SetPaintBackground(false)

	local btnRename = vgui.Create('DButton', pnlLoadoutOptions)
	btnRename:SetText('')
	btnRename:SetImage('icon16/brick_edit.png')
	btnRename:SetTooltip('Rename loadout')
	btnRename:SetWide(24)
	btnRename:Dock(RIGHT)

	btnRename.DoClick = function()
		local loadoutName = self.loadouts[self.loadoutIndex].name

		Derma_StringRequest('Rename Loadout', 'Give a new name to "' .. loadoutName .. '"', loadoutName, function(name)
			name = string.Trim(name)

			if string.len(name) == 0 then
				Derma_Message('The loadout name cannot be empty.', 'Invalid name', 'OK')

			elseif self:FindLoadoutByName(name) then
				Derma_Message('"' .. name .. '" already exists. Please choose another one.', 'Invalid name', 'OK')

			else
				self.loadouts[self.loadoutIndex].name = name
				self:UpdateLists()
				self:Save()
			end
		end, nil, 'Rename')
	end

	local btnRemove = vgui.Create('DButton', pnlLoadoutOptions)
	btnRemove:SetText('')
	btnRemove:SetImage('icon16/delete.png')
	btnRemove:SetTooltip('Remove loadout')
	btnRemove:SetWide(24)
	btnRemove:Dock(RIGHT)

	btnRemove.DoClick = function()
		local loadoutName = self.loadouts[self.loadoutIndex].name

		Derma_Query('Are you sure you want to delete "' .. loadoutName .. '"?', 'Delete loadout', 'Yes', function()
			self:DeleteLoadout(self.loadoutIndex)
			self:Save()
		end, 'No')
	end

	local btnNew = vgui.Create('DButton', pnlLoadoutOptions)
	btnNew:SetText('')
	btnNew:SetImage('icon16/add.png')
	btnNew:SetTooltip('Create a new loadout')
	btnNew:SetWide(24)
	btnNew:Dock(RIGHT)

	btnNew.DoClick = function()
		-- ask for a name for the new loadout
		Derma_StringRequest('Create Loadout', 'Give a name to your new loadout', '', function(name)
			name = string.Trim(name)

			if string.len(name) == 0 then
				Derma_Message('The loadout name cannot be empty.', 'Invalid name', 'OK')

			elseif self:FindLoadoutByName(name) then
				Derma_Message('"' .. name .. '" already exists. Please choose another one.', 'Invalid name', 'OK')

			else
				self.loadoutIndex = self:CreateLoadout(name)
				self:UpdateLists()
				self:Save()
			end
		end, nil, 'Create')
	end

	self.comboLoadouts = vgui.Create('DComboBox', pnlLoadoutOptions)
	self.comboLoadouts:SetFont('Trebuchet24')
	self.comboLoadouts:SetSortItems(false)
	self.comboLoadouts:Dock(FILL)
	self.comboLoadouts:SetTextColor(Color(193, 202, 255))

	self.comboLoadouts.Paint = function(_, sw, sh)
		surface.SetDrawColor(0, 0, 0, 240)
		surface.DrawRect(0, 0, sw, sh)
	end

	self.comboLoadouts.OnSelect = function(s, index)
		if s._BlockSelectCallback then return end

		self.loadoutIndex = index
		self:UpdateLists()
	end

	local pnlOptions = vgui.Create('DPanel', rPanel)
	pnlOptions:SetTall(114)
	pnlOptions:Dock(BOTTOM)
	pnlOptions:DockPadding(8, 8, 8, 8)
	pnlOptions.animState = self.enabled and 1 or 0

	pnlOptions.Paint = function(s, sw, sh)
		s.animState = Lerp(FrameTime() * 10, s.animState, self.enabled and 1 or 0)

		surface.SetDrawColor(50 + 50 * (1 - s.animState), 50 + 50 * s.animState, 50)
		surface.DrawRect(0, 0, sw, sh)
	end

	local checkEnable = vgui.Create('DButton', pnlOptions)
	checkEnable:SetText('')
	checkEnable:SetTall(38)
	checkEnable:Dock(TOP)
	checkEnable.highlightState = 1

	checkEnable.DoClick = function()
		self.enabled = not self.enabled
	end

	checkEnable.Paint = function(s, sw, sh)
		local offset = 32

		if s.Hovered then
			s.highlightState = 0.1
			offset = 0
		end

		if s.highlightState > 0 then
			s.highlightState = s.highlightState - FrameTime() * 1.5
			offset = offset * s.highlightState

			DisableClipping(true)
			surface.SetDrawColor(255, 255, 255, 150 * s.highlightState)
			surface.DrawRect(-offset, -offset, sw + (offset * 2), sh + (offset * 2))
			DisableClipping(false)
		end

		local size = 16
		local iX, iY = 4, (sh * 0.5) - (size * 0.5)

		surface.SetDrawColor(32, 32, 32, 255)
		surface.DrawRect(iX, iY, size, size)

		surface.SetDrawColor(0, 150, 0, 255 * pnlOptions.animState)
		surface.DrawRect(iX + 2, iY + 2, size - 4, size - 4)

		draw.SimpleText('Enable loadout', 'Trebuchet18', iX + 22, sh * 0.5, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local maxAmmo1, maxAmmo2 = self:GetAmmoLimits()

	local sliderAmmo2 = vgui.Create('DNumSlider', pnlOptions)
	sliderAmmo2:SetText('Secondary ammo')
	sliderAmmo2:SetMin(0)
	sliderAmmo2:SetMax(maxAmmo2)
	sliderAmmo2:SetDecimals(0)
	sliderAmmo2:SetValue(self.ammo2)
	sliderAmmo2:Dock(BOTTOM)

	sliderAmmo2.OnValueChanged = function(_, value)
		self.ammo2 = value
	end

	local sliderAmmo1 = vgui.Create('DNumSlider', pnlOptions)
	sliderAmmo1:SetText('Primary ammo')
	sliderAmmo1:SetMin(0)
	sliderAmmo1:SetMax(maxAmmo1)
	sliderAmmo1:SetDecimals(0)
	sliderAmmo1:SetValue(self.ammo1)
	sliderAmmo1:Dock(BOTTOM)

	sliderAmmo1.OnValueChanged = function(_, value)
		self.ammo1 = value
	end

	-- loadout weapons list
	self.scrlLoadout = vgui.Create('DScrollPanel', rPanel)
	self.scrlLoadout:Dock(FILL)

	self.listLoadout = vgui.Create('DIconLayout', self.scrlLoadout)
	self.listLoadout:Dock(FILL)
	self.listLoadout:DockMargin(0, 0, 0, 0)

	self:UpdateLists()
end

function CLoadout:Init()
	-- search filter
	self.filter = ''

	-- settings
	self.enabled = false
	self.loadoutIndex = 1
	self.loadouts = {}
	self.ammo1 = 5000
	self.ammo2 = 50

	if IsValid(self.frame) then
		self.frame:Close()
		self.frame = nil
	end

	-- add scripted weapons (aka SWEPs)
	-- (note: "engine" weapons arent listed here)
	for _, v in pairs(weapons.GetList()) do
		if not v.ClassName then continue end
		if not v.Spawnable then continue end

		-- dont list 'base' class weapons
		if string.find(v.ClassName, '_base', 1, true) then continue end

		weaponsList[v.ClassName] = {
			adminOnly = v.AdminOnly,
			name = (v.PrintName and v.PrintName ~= '') and v.PrintName or v.ClassName
		}
	end

	-- load settings
	if file.Exists('sanct_loadout.txt', 'DATA') then
		local data = util.JSONToTable( file.Read('sanct_loadout.txt', 'DATA') )
		if data then
			if data.enabled then
				self.enabled = true
			end

			local maxAmmo1, maxAmmo2 = self:GetAmmoLimits()

			if isnumber(data.ammo1) then
				self.ammo1 = math.Clamp(data.ammo1, 0, maxAmmo1)
			end

			if isnumber(data.ammo2) then
				self.ammo2 = math.Clamp(data.ammo2, 0, maxAmmo2)
			end

			if istable(data.loadouts) and table.IsSequential(data.loadouts) then
				for _, v in ipairs(data.loadouts) do
					self:CreateLoadout(v.name, v.items, v.preferred)
				end
			end

			-- backwards compatibility
			if istable(data.items) and table.IsSequential(data.items) then
				self:CreateLoadout(nil, data.items, data.preferred)
			end
		end
	end

	if #self.loadouts == 0 then
		self:CreateLoadout()
	end

	self:Apply()
end

-- late init (to make sure all weapons are "ready")
hook.Add('InitPostEntity', 'CLoadout_Initialize', function()
	hook.Remove('InitPostEntity', 'CLoadout_Initialize')

	-- on rare occasions it just didnt work if called right at InitPostEntity
	timer.Simple(1, function() CLoadout:Init() end)
end)


if engine.ActiveGamemode() == 'sandbox' then
	-- sandbox context menu icon
	list.Set('DesktopWindows', 'CLoadoutDesktopIcon', {
		title = 'Loadout',
		icon = 'entities/weapon_smg1.png',
		init = function() CLoadout:ShowPanel() end
	})
else
	-- for other gamemodes, create a basic
	-- version of the required derma panel

	local ContentIcon = {}

	local matOverlay_Normal = Material('gui/ContentIcon-normal.png')
	local matOverlay_Hovered = Material('gui/ContentIcon-hovered.png')
	local matOverlay_AdminOnly = Material('icon16/shield.png')

	AccessorFunc(ContentIcon, 'm_Color', 'Color')
	AccessorFunc(ContentIcon, 'm_Type', 'ContentType')
	AccessorFunc(ContentIcon, 'm_SpawnName', 'SpawnName')
	AccessorFunc(ContentIcon, 'm_bAdminOnly', 'AdminOnly')

	function ContentIcon:Init()

		self:SetPaintBackground( false )
		self:SetSize( 128, 128 )
		self:SetText('')
		self:SetDoubleClickingEnabled( false )

		self.Image = self:Add('DImage')
		self.Image:SetPos(3, 3)
		self.Image:SetSize(128 - 6, 128 - 6)
		self.Image:SetVisible(false)

		self.Label = self:Add('DLabel')
		self.Label:Dock(BOTTOM)
		self.Label:SetTall(18)
		self.Label:SetContentAlignment(5)
		self.Label:DockMargin(4, 0, 4, 6)
		self.Label:SetTextColor(color_white)
		self.Label:SetExpensiveShadow(1, Color(0, 0, 0, 200))

		self.Border = 0
	end

	function ContentIcon:SetName(name)
		self:SetTooltip(name)
		self.Label:SetText(name)
		self.m_NiceName = name
	end

	function ContentIcon:SetMaterial(name)
		self.m_MaterialName = name

		local mat = Material(name)

		-- Look for the old style material
		if not mat or mat:IsError() then
			name = name:Replace('entities/', 'VGUI/entities/')
			name = name:Replace('.png', '')
			mat = Material(name)
		end

		-- Couldn't find any material.. just return
		if not mat or mat:IsError() then
			return
		end

		self.Image:SetMaterial(mat)
	end

	function ContentIcon:DoRightClick()
		local pCanvas = self:GetSelectionCanvas()

		if IsValid(pCanvas) and pCanvas:NumSelectedChildren() > 0 and self:IsSelected() then
			return hook.Run('SpawnlistOpenGenericMenu', pCanvas)
		end

		self:OpenMenu()
	end

	function ContentIcon:DoClick()
	end

	function ContentIcon:OpenMenu()
	end

	function ContentIcon:Paint(w, h)
		if self.Depressed then
			if self.Border ~= 8 then
				self.Border = 8
			end
		else
			if self.Border ~= 0 then
				self.Border = 0
			end
		end

		render.PushFilterMag(TEXFILTER.ANISOTROPIC)
		render.PushFilterMin(TEXFILTER.ANISOTROPIC)

		self.Image:PaintAt(3 + self.Border, 3 + self.Border, 128 - 8 - self.Border * 2, 128 - 8 - self.Border * 2)

		render.PopFilterMin()
		render.PopFilterMag()

		surface.SetDrawColor(255, 255, 255, 255)

		if self:IsHovered() or self.Depressed or self:IsChildHovered() then
			surface.SetMaterial(matOverlay_Hovered)
			self.Label:Hide()

		else
			surface.SetMaterial(matOverlay_Normal)
			self.Label:Show()
		end

		surface.DrawTexturedRect(self.Border, self.Border, w-self.Border * 2, h-self.Border * 2)

		if self:GetAdminOnly() then
			surface.SetMaterial(matOverlay_AdminOnly)
			surface.DrawTexturedRect(self.Border + 8, self.Border + 8, 16, 16)
		end
	end

	function ContentIcon:PaintOver()
		self:DrawSelections()
	end

	vgui.Register('ContentIcon', ContentIcon, 'DButton')
end

concommand.Add('custom_loadout_refresh', function()
	CLoadout:Init()
end, nil, 'Refreshes the loadout script. Mostly used for testing.')

concommand.Add('custom_loadout_open', function()
	CLoadout:ShowPanel()
end, nil, 'Opens the loadout customization window.')