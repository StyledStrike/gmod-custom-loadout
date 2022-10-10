local langGet = language.GetPhrase

function CLoadout:GetWeaponIcon(class)
	if file.Exists('materials/entities/' .. class .. '.png', 'GAME') then
		return 'entities/' .. class .. '.png'
	end

	if file.Exists('materials/vgui/entities/' .. class .. '.vtf', 'GAME') then
		return 'vgui/entities/' .. class
	end
end

function CLoadout:ShowWeaponOptions(class, can_prefer, index)
	local menu = DermaMenu()
	menu:AddOption(langGet('cloadout.copy_to_clipboard'), function() SetClipboardText(class) end)

	if can_prefer then
		menu:AddOption(langGet('cloadout.set_favorite_weapon'), function()
			self:PreferWeapon(class)
		end):SetIcon('icon16/award_star_gold_3.png')
	end

	if not index then
		menu:Open()
		return
	end

	local item = self.loadouts[self.loadout_index].items[index]
	local reg_weapon = self.weapon_registry[item[1]]

	if not reg_weapon then
		menu:Open()
		return
	end

	local function AddAmmoSlider(field_index, field_name, label, current_value, max)
		menu:AddSpacer()

		local pnl_ammo = vgui.Create('DPanel', menu)
		pnl_ammo:SetBackgroundColor(Color(0,0,0,200))
		pnl_ammo:DockPadding(8, -4, -22, 0)

		local slid_ammo = vgui.Create('DNumSlider', pnl_ammo)
		slid_ammo:SetMin(1)
		slid_ammo:SetMax(max)
		slid_ammo:SetDecimals(0)
		slid_ammo:SetDefaultValue(16)
		slid_ammo:SetValue(current_value)
		slid_ammo:SetText(label)
		slid_ammo:Dock(TOP)
		slid_ammo:DockMargin(0, 0, 10, 0)
		slid_ammo.Label:SetTextColor(Color(255,255,255))

		slid_ammo.OnValueChanged = function(_, value)
			value = math.Round(value)
			item[field_index] = value
			self.icons_list[index][field_name] = value
		end
	end

	local max_primary, max_secondary = self:GetAmmoLimits()

	if not reg_weapon.no_primary then
		AddAmmoSlider(2, 'Primary', langGet('cloadout.ammo_primary'), item[2], max_primary)
	end

	if not reg_weapon.no_secondary then
		AddAmmoSlider(3, 'Secondary', langGet('cloadout.ammo_secondary'), item[3], max_secondary)
	end

	menu:Open()
end

function CLoadout:UpdateLists()
	if IsValid(self.list_available) then
		self:UpdateAvailableList()
	end

	if IsValid(self.list_loadout) then
		self:UpdateLoadoutList()
	end
end

-- updates the list of available weapons
function CLoadout:UpdateAvailableList()
	for _, v in ipairs(self.list_available:GetChildren()) do
		v:Remove()
	end

	local existing_items = self.loadouts[self.loadout_index].items
	local local_ply = LocalPlayer()

	local function IsOnLoadout(class)
		for _, item in ipairs(existing_items) do
			if item[1] == class then return true end
		end
	end

	for class, v in SortedPairsByMemberValue(self.weapon_registry, 'name') do
		-- dont list weapons that are on the loadout already
		if IsOnLoadout(class) then continue end

		-- dont list weapons that dont match the search filter
		if self.filter ~= '' then
			local found = string.find(string.lower(v.name), self.filter, 1, true)
			if not found then continue end
		end

		v.blacklisted = self:IsBlacklisted(local_ply, class)

		local icon = self.list_available:Add('CLoadoutWeaponIcon')
		icon:SetName(v.name)

		if v.blacklisted then
			icon:SetBlacklisted(true)
			icon:SetTooltip(langGet('cloadout.weapon_unavailable'))
		end

		if v.admin_only then
			icon:SetAdminOnly(true)
		end

		local icon_path = self:GetWeaponIcon(class)
		if icon_path then
			icon:SetMaterial(icon_path)
		end

		icon.DoClick = function()
			if v.admin_only and not local_ply:IsAdmin() then
				Derma_Message(langGet('cloadout.admin_only'), langGet('cloadout.weapon_restricted'), langGet('cloadout.ok'))

			elseif v.blacklisted then
				Derma_Message(langGet('cloadout.weapon_unavailable'), langGet('cloadout.weapon_restricted'), langGet('cloadout.ok'))

			else
				self:AddWeapon(class)
			end
		end

		icon.OpenMenu = function()
			self:ShowWeaponOptions(class)
		end
	end

	-- has to be done in this order to prevent a glitch
	self.list_available:InvalidateLayout(true)
	self.scr_available:InvalidateLayout()
end

-- updates the list of weapons on the loadout
function CLoadout:UpdateLoadoutList()
	-- make sure the "OnSelect" callback does nothing
	-- while we add stuff (to prevent infinite loops)
	self.combo_loadouts._block_callback = true
	self.combo_loadouts:Clear()

	-- update the loadout selection box
	for index, loadout in ipairs(self.loadouts) do
		self.combo_loadouts:AddChoice(loadout.name, nil, index == self.loadout_index)
	end

	self.combo_loadouts._block_callback = nil

	-- update the items list
	self.icons_list = {}

	for _, v in ipairs(self.list_loadout:GetChildren()) do
		v:Remove()
	end

	local items = self.loadouts[self.loadout_index].items
	local preferred = self.loadouts[self.loadout_index].preferred

	for index, item in ipairs(items) do
		local class = item[1]
		local icon = self.list_loadout:Add('CLoadoutWeaponIcon')

		self.icons_list[index] = icon

		icon.DoClick = function()
			self:RemoveWeapon(index)
		end

		if preferred == class then
			icon:SetFavorite(true)
			icon:SetTooltip(langGet('cloadout.favorite_weapon'))
		end

		local reg_weapon = self.weapon_registry[class]

		if not reg_weapon then
			if not self.tip_missing_weapons then
				self.tip_missing_weapons = true
				Derma_Message(langGet('cloadout.missing_weapons_help'), langGet('cloadout.missing_weapons'), langGet('cloadout.ok'))
			end

			icon:SetName(class)
			icon:SetMaterial('icon16/cancel.png')

			continue
		end

		icon:SetName(reg_weapon.name)

		local icon_path = self:GetWeaponIcon(class)
		if icon_path then
			icon:SetMaterial(icon_path)
		end

		if reg_weapon.admin_only then
			icon:SetAdminOnly(true)
		end

		if not reg_weapon.no_primary then
			icon.Primary = item[2]
		end

		if not reg_weapon.no_secondary then
			icon.Secondary = item[3]
		end

		icon.OpenMenu = function()
			CLoadout:ShowWeaponOptions(class, preferred ~= class, index)
		end
	end

	self.list_loadout:InvalidateLayout(true)
	self.src_loadout:InvalidateLayout()
end

function CLoadout:ShowPanel()
	if IsValid(self.frame) then
		self.frame:Close()
		self.frame = nil
		return
	end

	local frame_w = math.max(ScrW() * 0.6, 820)
	local frame_h = math.max(ScrH() * 0.6, 500)

	frame_w = math.Clamp(frame_w, 600, ScrW())
	frame_h = math.Clamp(frame_h, 400, ScrH())

	local frame = vgui.Create('DFrame')
	frame:SetTitle(langGet('cloadout.hint_usage'))
	frame:SetPos(0, 0)
	frame:SetSize(frame_w, frame_h)
	frame:SetSizable(true)
	frame:SetDraggable(true)
	frame:SetDeleteOnClose(true)
	frame:SetScreenLock(true)
	frame:SetMinWidth(600)
	frame:SetMinHeight(400)
	frame:Center()
	frame:MakePopup()

	frame._maximized = false
	frame.btnMaxim:SetDisabled(false)
	self.frame = frame

	frame.OnClose = function()
		self:Save()
		self:Apply()
	end

	local left_panel = vgui.Create('DPanel', frame)
	local right_panel = vgui.Create('DPanel', frame)

	local function PaintBackground(_, sw, sh)
		surface.SetDrawColor(32, 32, 32, 255)
		surface.DrawRect(0, 0, sw, sh)
	end

	left_panel.Paint = PaintBackground
	right_panel.Paint = PaintBackground

	local div = vgui.Create('DHorizontalDivider', frame)
	div:Dock(FILL)
	div:SetLeft(left_panel)
	div:SetRight(right_panel)
	div:SetDividerWidth(4)
	div:SetLeftMin(200)
	div:SetRightMin(200)
	div:SetLeftWidth(frame_w * 0.56)

	frame.btnMaxim.DoClick = function()
		if frame._maximized then
			frame:SetSize(frame._original_dimensions[1], frame._original_dimensions[2])
			frame:Center()
			frame._maximized = false
			frame._original_dimensions = nil
		else
			frame._maximized = true
			frame._original_dimensions = { frame:GetWide(), frame:GetTall() }
			frame:SetPos(0, 0)
			frame:SetSize(ScrW(), ScrH())
		end

		frame:SetDraggable(not frame._maximized)
		frame:SetSizable(not frame._maximized)
		div:SetLeftWidth(frame:GetWide() * 0.56)
	end

	----- LEFT PANEL STUFF

	local label_avail = vgui.Create('DLabel', left_panel)
	label_avail:SetText(langGet('cloadout.available_weapons'))
	label_avail:SetFont('Trebuchet24')
	label_avail:SetTextColor(Color(150, 255, 150))
	label_avail:Dock(TOP)
	label_avail:DockMargin(4, 2, 0, 2)

	local search_entry = vgui.Create('DTextEntry', left_panel)
	search_entry:SetFont('ChatFont')
	search_entry:SetMaximumCharCount(64)
	search_entry:SetTabbingDisabled(true)
	search_entry:SetPlaceholderText(langGet('cloadout.search'))
	search_entry:SetTall(38)
	search_entry:Dock(BOTTOM)

	search_entry.OnChange = function(s)
		self.filter = string.lower( string.Trim(s:GetText()) )
		self:UpdateAvailableList()
	end

	-- available weapons list
	self.scr_available = vgui.Create('DScrollPanel', left_panel)
	self.scr_available:Dock(FILL)

	self.list_available = vgui.Create('DIconLayout', self.scr_available)
	self.list_available:Dock(FILL)
	self.list_available:DockMargin(0, 0, 0, 0)
	self.list_available:SetSpaceX(4)
	self.list_available:SetSpaceY(4)

	----- RIGHT PANEL STUFF

	local panel_options = vgui.Create('DPanel', right_panel)
	panel_options:SetTall(32)
	panel_options:Dock(TOP)
	panel_options:DockPadding(2, 2, 2, 2)
	panel_options:SetPaintBackground(false)

	local button_rename = vgui.Create('DButton', panel_options)
	button_rename:SetText('')
	button_rename:SetImage('icon16/brick_edit.png')
	button_rename:SetTooltip(langGet('cloadout.rename'))
	button_rename:SetWide(24)
	button_rename:Dock(RIGHT)

	button_rename.DoClick = function()
		local loadout_name = self.loadouts[self.loadout_index].name
		local help_text = string.format(langGet('cloadout.rename_help'), loadout_name)

		Derma_StringRequest(langGet('cloadout.rename'), help_text, loadout_name, function(name)
			name = string.Trim(name)

			if string.len(name) == 0 then
				Derma_Message(langGet('cloadout.rename_err_empty'), langGet('cloadout.rename_err'), langGet('cloadout.ok'))

			elseif self:FindLoadoutByName(name) then
				Derma_Message(string.format(langGet('cloadout.rename_err_exists'), name), langGet('cloadout.rename_err'), langGet('cloadout.ok'))

			else
				self.loadouts[self.loadout_index].name = name
				self:Save()
				self:UpdateLoadoutList()
			end
		end, nil, 'Rename')
	end

	local button_remove = vgui.Create('DButton', panel_options)
	button_remove:SetText('')
	button_remove:SetImage('icon16/delete.png')
	button_remove:SetTooltip(langGet('cloadout.remove'))
	button_remove:SetWide(24)
	button_remove:Dock(RIGHT)

	button_remove.DoClick = function()
		local loadout_name = self.loadouts[self.loadout_index].name
		local help_text = string.format(langGet('cloadout.remove_confirm'), loadout_name)

		Derma_Query(help_text, langGet('cloadout.remove'), langGet('cloadout.yes'), function()
			self:DeleteLoadout(self.loadout_index)
			self:Save()
		end, langGet('cloadout.no'))
	end

	local button_new = vgui.Create('DButton', panel_options)
	button_new:SetText('')
	button_new:SetImage('icon16/add.png')
	button_new:SetTooltip(langGet('cloadout.new'))
	button_new:SetWide(24)
	button_new:Dock(RIGHT)

	button_new.DoClick = function()
		-- ask for a name for the new loadout
		Derma_StringRequest(langGet('cloadout.new'), langGet('cloadout.new_help'), '', function(name)
			name = string.Trim(name)

			if string.len(name) == 0 then
				Derma_Message(langGet('cloadout.rename_err_empty'), langGet('cloadout.rename_err'), langGet('cloadout.ok'))

			elseif self:FindLoadoutByName(name) then
				Derma_Message(string.format(langGet('cloadout.rename_err_exists'), name), langGet('cloadout.rename_err'), langGet('cloadout.ok'))

			else
				self.loadout_index = self:CreateLoadout(name)
				self:Save()
				self:UpdateLists()
			end
		end, nil, langGet('cloadout.new'))
	end

	self.combo_loadouts = vgui.Create('DComboBox', panel_options)
	self.combo_loadouts:SetFont('Trebuchet24')
	self.combo_loadouts:SetSortItems(false)
	self.combo_loadouts:Dock(FILL)
	self.combo_loadouts:SetTextColor(Color(193, 202, 255))

	self.combo_loadouts.Paint = function(_, sw, sh)
		surface.SetDrawColor(0, 0, 0, 240)
		surface.DrawRect(0, 0, sw, sh)
	end

	self.combo_loadouts.OnSelect = function(s, index)
		if s._block_callback then return end

		-- wtf, sometimes OnSelect's "index" is a string
		self.loadout_index = tonumber(index)
		self.tip_missing_weapons = nil
		self:UpdateLists()
	end

	local panel_toggle = vgui.Create('DPanel', right_panel)
	panel_toggle:SetTall(52)
	panel_toggle:Dock(BOTTOM)
	panel_toggle:DockPadding(8, 8, 8, 8)
	panel_toggle._anim_state = self.enabled and 1 or 0

	panel_toggle.Paint = function(s, sw, sh)
		s._anim_state = Lerp(FrameTime() * 10, s._anim_state, self.enabled and 1 or 0)

		surface.SetDrawColor(50 + 50 * (1 - s._anim_state), 50 + 50 * s._anim_state, 50)
		surface.DrawRect(0, 0, sw, sh)
	end

	local check_enable = vgui.Create('DButton', panel_toggle)
	check_enable:SetText('')
	check_enable:Dock(FILL)
	check_enable._highlight_state = 1
	check_enable._text = langGet('cloadout.enable')
	check_enable._help = langGet('cloadout.hint_ammo')

	check_enable.DoClick = function()
		self.enabled = not self.enabled
	end

	check_enable.Paint = function(s, sw, sh)
		local offset = 32

		if s.Hovered then
			s._highlight_state = 0.1
			offset = 0
		end

		if s._highlight_state > 0 then
			s._highlight_state = s._highlight_state - FrameTime() * 1.5
			offset = offset * s._highlight_state

			DisableClipping(true)
			surface.SetDrawColor(255, 255, 255, 150 * s._highlight_state)
			surface.DrawRect(-offset, -offset, sw + (offset * 2), sh + (offset * 2))
			DisableClipping(false)
		end

		local size = 16
		local x, y = 4, (sh * 0.5) - (size * 0.5)

		surface.SetDrawColor(32, 32, 32, 255)
		surface.DrawRect(x, y, size, size)

		surface.SetDrawColor(0, 150, 0, 255 * panel_toggle._anim_state)
		surface.DrawRect(x + 2, y + 2, size - 4, size - 4)

		draw.SimpleText(s._text, 'Trebuchet18', x + 22, sh * 0.3, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(s._help, 'DefaultSmall', x + 22, sh * 0.7, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- loadout weapons list
	self.src_loadout = vgui.Create('DScrollPanel', right_panel)
	self.src_loadout:Dock(FILL)

	self.list_loadout = vgui.Create('DIconLayout', self.src_loadout)
	self.list_loadout:Dock(FILL)
	self.list_loadout:DockMargin(0, 0, 0, 0)
	self.list_loadout:SetSpaceX(4)
	self.list_loadout:SetSpaceY(4)

	self:UpdateLists()
end

if engine.ActiveGamemode() == 'sandbox' then
	list.Set('DesktopWindows', 'CLoadoutDesktopIcon', {
		title = langGet('cloadout.title'),
		icon = 'entities/weapon_smg1.png',
		init = function() CLoadout:ShowPanel() end
	})
end

-- custom content icon panel
do
	local WeaponIcon = {}

	local mat_icon_ammo = Material('icon16/bullet_yellow.png')
	local mat_icon_adminonly = Material('icon16/shield.png')
	local mat_icon_favorite = Material('icon16/star.png', 'smooth mips')
	local mat_icon_blacklisted = Material('icon16/cross.png', 'smooth mips')

	AccessorFunc(WeaponIcon, 'm_bAdminOnly', 'AdminOnly')
	AccessorFunc(WeaponIcon, 'm_bFavorite', 'Favorite')
	AccessorFunc(WeaponIcon, 'm_bBlacklisted', 'Blacklisted')

	function WeaponIcon:Init()
		self:SetPaintBackground(false)
		self:SetSize(140, 128)
		self:SetText('')
		self:SetDoubleClickingEnabled(false)

		self.Image = self:Add('DImage')
		self.Image:SetPos(0, 0)
		self.Image:SetSize(128, 128)
		self.Image:SetVisible(false)
		self.Image:SetKeepAspect(false)

		self.Name = ''
		self.Border = 0
		self.TextColor = Color(255, 255, 255, 255)
		self.TextOutlineColor = Color(0, 0, 0, 255)
	end

	function WeaponIcon:SetName(name)
		self.Name = name
	end

	function WeaponIcon:SetMaterial(name)
		self.m_MaterialName = name

		local mat = Material(name)

		-- Look for the old style material
		if not mat or mat:IsError() then
			name = name:Replace('entities/', 'VGUI/entities/')
			name = name:Replace('.png', '')
			mat = Material(name)
		end

		-- Couldn't find any material.. just return
		if not mat or mat:IsError() then return end

		self.Image:SetMaterial(mat)
	end

	function WeaponIcon:DoRightClick()
		self:OpenMenu()
	end

	function WeaponIcon:DoClick() end
	function WeaponIcon:OpenMenu() end
	function WeaponIcon:PaintOver() end

	function WeaponIcon:Paint(w, h)
		self.Border = self.Depressed and 8 or 0

		render.PushFilterMag(TEXFILTER.ANISOTROPIC)
		render.PushFilterMin(TEXFILTER.ANISOTROPIC)

		self.Image:PaintAt(self.Border, self.Border, w - self.Border * 2, h - self.Border * 2)

		render.PopFilterMin()
		render.PopFilterMag()

		if self:IsHovered() or self.Depressed or self:IsChildHovered() then
			surface.SetDrawColor(255, 255, 255, 255)
		else
			surface.SetDrawColor(0, 0, 0, 255)
		end

		surface.DrawOutlinedRect(0, 0, w, h, 4)

		local info_h = 20
		local info_y = h - info_h - 4

		surface.SetDrawColor(30, 30, 30, 240)
		surface.DrawRect(4, info_y, w - 8, info_h)

		draw.SimpleTextOutlined(self.Name, 'Default', 8, info_y + info_h * 0.5,
			self.TextColor, 0, 1, 1, self.TextOutlineColor)
		surface.SetDrawColor(255, 255, 255, 255)

		local str

		if self.Primary then
			if self.Secondary then
				str = self.Primary .. '/' .. self.Secondary
			else
				str = self.Primary
			end

		elseif self.Secondary then
			str = self.Secondary
		end

		if str then
			surface.SetMaterial(mat_icon_ammo)
			surface.DrawTexturedRect(w - 18, info_y + 3, 16, 16)

			draw.SimpleTextOutlined(str, 'Default', w - 18, info_y + info_h * 0.5,
				self.TextColor, 2, 1, 1, self.TextOutlineColor)
		end

		local icon_x, icon_y = w, 4

		if self:GetAdminOnly() then
			icon_x = icon_x - 22
			surface.SetMaterial(mat_icon_adminonly)
			surface.DrawTexturedRect(icon_x, icon_y, 16, 16)
		end

		if self:GetFavorite() then
			icon_x = icon_x - 22
			surface.SetMaterial(mat_icon_favorite)
			surface.DrawTexturedRect(icon_x, icon_y, 16, 16)
		end

		if self:GetBlacklisted() then
			icon_x = icon_x - 22
			surface.SetMaterial(mat_icon_blacklisted)
			surface.DrawTexturedRect(icon_x, icon_y, 16, 16)
		end
	end

	vgui.Register('CLoadoutWeaponIcon', WeaponIcon, 'DButton')
end