do
    local MOTIF_COLOR = Color( 188, 86, 83, 255 )

    local theme = STheme.New( {
        frameTitleBar = MOTIF_COLOR,
        buttonPress = MOTIF_COLOR,
        entryHighlight = MOTIF_COLOR
    } )

    function CLoadout.ApplyTheme( panel )
        STheme.Apply( theme, panel )
    end
end

local ApplyTheme = CLoadout.ApplyTheme
local LangPhrase = language.GetPhrase

function CLoadout:GetWeaponIcon( class )
    if file.Exists( "materials/entities/" .. class .. ".png", "GAME" ) then
        return "entities/" .. class .. ".png"
    end

    if file.Exists( "materials/vgui/entities/" .. class .. ".vtf", "GAME" ) then
        return "vgui/entities/" .. class
    end

    if file.Exists( "materials/vgui/entities/" .. class .. ".vmt", "GAME" ) then
        return "vgui/entities/" .. class
    end
end

function CLoadout:UpdateLists()
    if IsValid( self.listAvailable ) then
        self:UpdateAvailableList()
    end

    if IsValid( self.listLoadoutItems ) then
        self:UpdateLoadoutList()
    end
end

function CLoadout:ShowPanel()
    if not self.loadouts then
        CLoadout.PrintF( "Too early! The addon is not prepared!" )

        return
    end

    if not self.categories then
        self:InitRegistry()
    end

    if IsValid( self.frame ) then
        self.frame:Close()
        self.frame = nil

        return
    end

    local frameW = math.max( ScrW() * 0.6, 820 )
    local frameH = math.max( ScrH() * 0.6, 500 )

    frameW = math.Clamp( frameW, 600, ScrW() )
    frameH = math.Clamp( frameH, 400, ScrH() )

    local frame = vgui.Create( "DFrame" )
    frame:SetTitle( LangPhrase( "cloadout.hint_usage" ) )
    frame:SetPos( 0, 0 )
    frame:SetSize( frameW, frameH )
    frame:SetSizable( true )
    frame:SetDraggable( true )
    frame:SetDeleteOnClose( true )
    frame:SetScreenLock( true )
    frame:SetMinWidth( 600 )
    frame:SetMinHeight( 400 )
    frame:Center()
    frame:MakePopup()

    self.frame = frame
    ApplyTheme( frame )

    frame._maximized = false
    frame.btnMaxim:SetDisabled( false )

    frame.btnClose.DoClick = function()
        local items = self.loadouts[self.loadoutIndex].items

        if #items > self:GetWeaponLimit() then
            Derma_Message( "#cloadout.hint_too_many", "#cloadout.title", "#cloadout.ok" )
        else
            frame:Close()
        end
    end

    frame.OnClose = function()
        if IsValid( self.ammoFrame ) then
            self.ammoFrame:Close()
        end

        self:Save()
        self:Apply()
    end

    frame.OnFocusChanged = function( _, gained )
        if gained and IsValid( self.ammoFrame ) then
            self.ammoFrame:Close()
        end
    end

    local div

    frame.btnMaxim.DoClick = function()
        if frame._maximized then
            frame:SetSize( frame._oldDimensions[1], frame._oldDimensions[2] )
            frame:Center()

            frame._maximized = false
            frame._oldDimensions = nil
        else
            frame._maximized = true
            frame._oldDimensions = { frame:GetWide(), frame:GetTall() }

            frame:SetPos( 0, 0 )
            frame:SetSize( ScrW(), ScrH() )
        end

        frame:SetDraggable( not frame._maximized )
        frame:SetSizable( not frame._maximized )
        div:SetLeftWidth( frame:GetWide() * 0.56 )
    end

    local leftPanel = vgui.Create( "DPanel", frame )
    local rightPanel = vgui.Create( "DPanel", frame )

    local function PaintBackground( _, sw, sh )
        surface.SetDrawColor( 32, 32, 32, 255 )
        surface.DrawRect( 0, 0, sw, sh )
    end

    leftPanel.Paint = PaintBackground
    rightPanel.Paint = PaintBackground

    div = vgui.Create( "DHorizontalDivider", frame )
    div:Dock( FILL )
    div:SetLeft( leftPanel )
    div:SetRight( rightPanel )
    div:SetDividerWidth( 4 )
    div:SetLeftMin( 200 )
    div:SetRightMin( 200 )
    div:SetLeftWidth( frameW * 0.56 )

    ----- Left panel stuff -----

    -- Category combo
    self.comboCategory = vgui.Create( "DComboBox", leftPanel )
    self.comboCategory:SetFont( "Trebuchet24" )
    self.comboCategory:SetSortItems( false )
    self.comboCategory:SetTall( 30 )
    self.comboCategory:Dock( TOP )
    self.comboCategory:DockMargin( 2, 2, 2, 2 )

    ApplyTheme( self.comboCategory )

    self.comboCategory:SetTextColor( Color( 150, 255, 150 ) )
    self.comboCategory:AddChoice( LangPhrase( "cloadout.available_weapons" ), nil, true )
    self.categoryFilter = nil

    for _, name in ipairs( self.categories ) do
        self.comboCategory:AddChoice( name )
    end

    self.comboCategory.OnSelect = function( _, index )
        -- wtf, sometimes "index" is a string
        index = tonumber( index ) - 1

        if index == 0 then
            self.categoryFilter = nil
        else
            self.categoryFilter = self.categories[index]
        end

        self:UpdateLists()
    end

    -- Search box
    local entrySearch = vgui.Create( "DTextEntry", leftPanel )
    entrySearch:SetFont( "ChatFont" )
    entrySearch:SetMaximumCharCount( 64 )
    entrySearch:SetTabbingDisabled( true )
    entrySearch:SetPlaceholderText( LangPhrase( "cloadout.search" ) )
    entrySearch:SetTall( 38 )
    entrySearch:Dock( BOTTOM )

    ApplyTheme( entrySearch )
    self.filter = ""

    entrySearch.OnChange = function( s )
        self.filter = string.lower( string.Trim( s:GetText() ) )
        self:UpdateAvailableList()
    end

    -- Available weapons list
    self.scrollAvailable = vgui.Create( "DScrollPanel", leftPanel )
    self.scrollAvailable:Dock( FILL )

    ApplyTheme( self.scrollAvailable )

    self.listAvailable = vgui.Create( "DIconLayout", self.scrollAvailable )
    self.listAvailable:Dock( FILL )
    self.listAvailable:DockMargin( 0, 0, 0, 0 )
    self.listAvailable:SetSpaceX( 4 )
    self.listAvailable:SetSpaceY( 4 )

    ----- Right panel stuff -----

    local panelOptions = vgui.Create( "DPanel", rightPanel )
    panelOptions:SetTall( 32 )
    panelOptions:Dock( TOP )
    panelOptions:DockPadding( 2, 2, 2, 2 )
    panelOptions:SetPaintBackground( false )

    local buttonCopy = vgui.Create( "DButton", panelOptions )
    buttonCopy:SetText( "" )
    buttonCopy:SetImage( "icon16/brick_go.png" )
    buttonCopy:SetTooltip( LangPhrase( "cloadout.copy_inventory" ) )
    buttonCopy:SetWide( 24 )
    buttonCopy:Dock( RIGHT )

    ApplyTheme( buttonCopy )

    buttonCopy.DoClick = function()
        Derma_Query(
            LangPhrase( "cloadout.copy_confirm" ),
            LangPhrase( "cloadout.copy_inventory" ),
            LangPhrase( "cloadout.yes" ),
            function()
                self:AddInventoryWeapons()
            end,
            LangPhrase( "cloadout.no" )
        )
    end

    local buttonRename = vgui.Create( "DButton", panelOptions )
    buttonRename:SetText( "" )
    buttonRename:SetImage( "icon16/brick_edit.png" )
    buttonRename:SetTooltip( LangPhrase( "cloadout.rename" ) )
    buttonRename:SetWide( 24 )
    buttonRename:Dock( RIGHT )

    ApplyTheme( buttonRename )

    buttonRename.DoClick = function()
        local loadoutName = self.loadouts[self.loadoutIndex].name
        local helpText = string.format( LangPhrase( "cloadout.rename_help" ), loadoutName )

        Derma_StringRequest(
            LangPhrase( "cloadout.rename" ),
            helpText,
            loadoutName,
            function( name )
                name = string.Trim( name )

                if string.len( name ) == 0 then
                    Derma_Message(
                        LangPhrase( "cloadout.rename_err_empty" ),
                        LangPhrase( "cloadout.rename_err" ),
                        LangPhrase( "cloadout.ok" )
                    )

                elseif self:FindLoadoutByName( name ) then
                    Derma_Message(
                        string.format( LangPhrase( "cloadout.rename_err_exists" ), name ),
                        LangPhrase( "cloadout.rename_err" ),
                        LangPhrase( "cloadout.ok" )
                    )

                else
                    self.loadouts[self.loadoutIndex].name = name
                    self:Save()
                    self:UpdateLoadoutList()
                end
            end,
            nil,
            LangPhrase( "cloadout.rename" )
        )
    end

    local buttonRemove = vgui.Create( "DButton", panelOptions )
    buttonRemove:SetText( "" )
    buttonRemove:SetImage( "icon16/delete.png" )
    buttonRemove:SetTooltip( LangPhrase( "cloadout.remove" ) )
    buttonRemove:SetWide( 24 )
    buttonRemove:Dock( RIGHT )

    ApplyTheme( buttonRemove )

    buttonRemove.DoClick = function()
        local loadoutName = self.loadouts[self.loadoutIndex].name
        local helpText = string.format( LangPhrase( "cloadout.remove_confirm" ), loadoutName )

        Derma_Query(
            helpText,
            LangPhrase( "cloadout.remove" ),
            LangPhrase( "cloadout.yes" ),
            function()
                self:DeleteLoadout( self.loadoutIndex )
                self:Save()
            end,
            LangPhrase( "cloadout.no" )
        )
    end

    local buttonNew = vgui.Create( "DButton", panelOptions )
    buttonNew:SetText( "" )
    buttonNew:SetImage( "icon16/add.png" )
    buttonNew:SetTooltip( LangPhrase( "cloadout.new" ) )
    buttonNew:SetWide( 24 )
    buttonNew:Dock( RIGHT )

    ApplyTheme( buttonNew )

    buttonNew.DoClick = function()
        -- Ask for a name for the new loadout
        Derma_StringRequest(
            LangPhrase( "cloadout.new" ),
            LangPhrase( "cloadout.new_help" ),
            "",
            function( name )
                name = string.Trim( name )

                if string.len( name ) == 0 then
                    Derma_Message(
                        LangPhrase( "cloadout.rename_err_empty" ),
                        LangPhrase( "cloadout.rename_err" ),
                        LangPhrase( "cloadout.ok" )
                    )

                elseif self:FindLoadoutByName( name ) then
                    Derma_Message(
                        string.format( LangPhrase( "cloadout.rename_err_exists" ), name ),
                        LangPhrase( "cloadout.rename_err" ),
                        LangPhrase( "cloadout.ok" )
                    )

                else
                    self.loadoutIndex = self:CreateLoadout( name )
                    self:Save()
                    self:UpdateLists()
                end
            end,
            nil,
            LangPhrase( "cloadout.new" )
        )
    end

    self.comboLoadouts = vgui.Create( "DComboBox", panelOptions )
    self.comboLoadouts:SetFont( "Trebuchet24" )
    self.comboLoadouts:SetSortItems( false )
    self.comboLoadouts:Dock( FILL )

    ApplyTheme( self.comboLoadouts )
    self.comboLoadouts:SetTextColor( Color( 193, 202, 255 ) )

    self.comboLoadouts.Paint = function( _, sw, sh )
        surface.SetDrawColor( 0, 0, 0, 240 )
        surface.DrawRect( 0, 0, sw, sh )
    end

    self.comboLoadouts.OnSelect = function( s, index )
        if s._blockCallback then return end

        -- wtf, sometimes "index" is a string
        self.loadoutIndex = tonumber( index )
        self.hintedMissingWeapons = nil
        self:UpdateLists()
    end

    local panelToggle = vgui.Create( "DPanel", rightPanel )
    panelToggle:SetTall( 52 )
    panelToggle:Dock( BOTTOM )
    panelToggle:DockPadding( 8, 8, 8, 8 )
    panelToggle._animState = self.enabled and 1 or 0

    panelToggle.Paint = function( s, sw, sh )
        s._animState = Lerp( FrameTime() * 10, s._animState, self.enabled and 1 or 0 )

        surface.SetDrawColor( 50 + 50 * ( 1 - s._animState ), 50 + 50 * s._animState, 50 )
        surface.DrawRect( 0, 0, sw, sh )
    end

    local checkEnable = vgui.Create( "DButton", panelToggle )
    checkEnable:SetText( "" )
    checkEnable:Dock( FILL )
    checkEnable._highlightState = 1
    checkEnable._label = LangPhrase( "cloadout.enable" )
    checkEnable._help = LangPhrase( "cloadout.hint_ammo" )

    checkEnable.DoClick = function()
        self.enabled = not self.enabled
    end

    checkEnable.Paint = function( s, sw, sh )
        local offset = 32

        if s.Hovered then
            s._highlightState = 0.1
            offset = 0
        end

        if s._highlightState > 0 then
            s._highlightState = s._highlightState - FrameTime() * 1.5
            offset = offset * s._highlightState

            DisableClipping( true )
            surface.SetDrawColor( 255, 255, 255, 150 * s._highlightState )
            surface.DrawRect( -offset, -offset, sw + ( offset * 2 ), sh + ( offset * 2 ) )
            DisableClipping( false )
        end

        local size = 16
        local x, y = 4, ( sh * 0.5 ) - ( size * 0.5 )

        surface.SetDrawColor( 32, 32, 32, 255 )
        surface.DrawRect( x, y, size, size )

        surface.SetDrawColor( 0, 150, 0, 255 * panelToggle._animState )
        surface.DrawRect( x + 2, y + 2, size - 4, size - 4 )

        draw.SimpleText( s._label, "Trebuchet18", x + 22, sh * 0.3, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
        draw.SimpleText( s._help, "DefaultSmall", x + 22, sh * 0.7, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
    end

    self.labelCount = vgui.Create( "DLabel", panelToggle )
    self.labelCount:SetText( "0/0" )
    self.labelCount:Dock( RIGHT )

    -- Loadout weapons list
    self.scrollLoadoutItems = vgui.Create( "DScrollPanel", rightPanel )
    self.scrollLoadoutItems:Dock( FILL )

    ApplyTheme( self.scrollLoadoutItems )

    self.listLoadoutItems = vgui.Create( "DIconLayout", self.scrollLoadoutItems )
    self.listLoadoutItems:Dock( FILL )
    self.listLoadoutItems:DockMargin( 0, 0, 0, 0 )
    self.listLoadoutItems:SetSpaceX( 4 )
    self.listLoadoutItems:SetSpaceY( 4 )

    self:UpdateLists()
end

-- Update the list of all available weapons.
function CLoadout:UpdateAvailableList()
    self.listAvailable:Clear()

    local inLoadout = {}

    for _, item in ipairs( self.loadouts[self.loadoutIndex].items ) do
        inLoadout[item[1]] = true
    end

    for class, _ in SortedPairsByMemberValue( self.weaponRegistry, "name" ) do
        if not inLoadout[class] then
            self:CreateAvailableWeaponIcon( class )
        end
    end

    self.listAvailable:InvalidateLayout( true )

    -- This needs to be called next frame, otherwise it can cause a glitch
    timer.Simple( 0, function()
        if IsValid( self.scrollAvailable ) then
            self.scrollAvailable:InvalidateLayout()
        end
    end )
end

-- Update the list of weapons on the loadout.
function CLoadout:UpdateLoadoutList()
    -- Make sure the "OnSelect" callback does nothing
    -- while we add stuff (to prevent infinite loops)
    self.comboLoadouts._blockCallback = true
    self.comboLoadouts:Clear()

    -- Update the loadout selection box
    for index, loadout in ipairs( self.loadouts ) do
        self.comboLoadouts:AddChoice( loadout.name, nil, index == self.loadoutIndex )
    end

    self.comboLoadouts._blockCallback = nil
    self.listLoadoutItems:Clear()

    local items = self.loadouts[self.loadoutIndex].items
    local preferred = self.loadouts[self.loadoutIndex].preferred

    for index, item in ipairs( items ) do
        local class = item[1]
        local icon = self.listLoadoutItems:Add( "CLoadoutWeaponIcon" )

        icon:SetWeaponClass( class )
        icon._itemIndex = index

        icon.DoClick = function()
            self:RemoveWeapon( index )
            self:UpdateLists()
        end

        if preferred == class then
            icon:SetFavorite( true )
            icon:SetTooltip( LangPhrase( "cloadout.favorite_weapon" ) )
        end

        local regWeapon = self.weaponRegistry[class]

        if not regWeapon then
            if not self.hintedMissingWeapons then
                self.hintedMissingWeapons = true
                Derma_Message(
                    LangPhrase( "cloadout.missing_weapons_help" ),
                    LangPhrase( "cloadout.missing_weapons" ),
                    LangPhrase( "cloadout.ok" )
                )
            end

            icon:SetWeaponName( class )
            icon:SetMaterial( "icon16/cancel.png" )

            continue
        end

        icon:SetWeaponName( regWeapon.name )

        if regWeapon.adminOnly then
            icon:SetAdminOnly( true )
        end

        if not regWeapon.noPrimary then
            icon.Primary = item[2]
        end

        if not regWeapon.noSecondary then
            icon.Secondary = item[3]
        end

        if class == self.reopenMenuForClass then
            self.reopenMenuForClass = nil
            self:OpenMenuForIcon( icon )
        end
    end

    self.labelCount:SetTextColor( #items > self:GetWeaponLimit() and Color( 255, 50, 50 ) or color_white )
    self.labelCount:SetText( string.format( "%d/%d", #items, self:GetWeaponLimit() ) )
    self.labelCount:SizeToContents()

    self.listLoadoutItems:InvalidateLayout( true )
    self.scrollLoadoutItems:InvalidateLayout()
end

-- Open a separate frame with weapon options related to this icon.
function CLoadout:OpenMenuForIcon( icon )
    if IsValid( self.ammoFrame ) then
        self.ammoFrame:Close()
    end

    local class = icon.WeaponClass
    local item = self.loadouts[self.loadoutIndex].items[icon._itemIndex]

    local ammoFrame = vgui.Create( "DFrame" )
    ammoFrame:SetSize( 500, 168 )
    ammoFrame:SetTitle( icon.WeaponName )
    ammoFrame:SetDraggable( false )
    ammoFrame:SetBackgroundBlur( true )
    ammoFrame:Center()
    ammoFrame:MakePopup()

    self.ammoFrame = ammoFrame
    ApplyTheme( ammoFrame )

    local preview = ammoFrame:Add( "CLoadoutWeaponIcon" )
    preview:SetWeaponName( icon.WeaponName )
    preview:SetWeaponClass( class )
    preview:SetFavorite( icon:GetFavorite() )
    preview:SetEnabled( false )
    preview:Dock( LEFT )

    local container = ammoFrame:Add( "DPanel" )
    container:Dock( FILL )
    container:DockPadding( 8, 8, 8, 8 )

    ApplyTheme( container )

    if item then
        local btnPrefer = container:Add( "DButton" )
        btnPrefer:SetIcon( "icon16/award_star_gold_3.png" )
        btnPrefer:Dock( TOP )

        ApplyTheme( btnPrefer )

        if icon:GetFavorite() then
            btnPrefer:SetText( LangPhrase( "cloadout.favorite_weapon" ) )
            btnPrefer:SetEnabled( false )
        else
            btnPrefer:SetText( LangPhrase( "cloadout.set_favorite_weapon" ) )

            btnPrefer.DoClick = function()
                self.reopenMenuForClass = class
                self:PreferWeapon( class )
            end
        end
    end

    local btnCopy = container:Add( "DButton" )
    btnCopy:SetText( LangPhrase( "cloadout.copy_to_clipboard" ) )
    btnCopy:Dock( TOP )

    ApplyTheme( btnCopy )

    btnCopy.DoClick = function()
        SetClipboardText( class )
    end

    local regWeapon = self.weaponRegistry[class]
    if not regWeapon or not item then return end

    local function CreateSlider( label, value, max )
        local slider = container:Add( "DNumSlider" )
        slider:SetMin( 0 )
        slider:SetMax( max )
        slider:SetDecimals( 0 )
        slider:SetDefaultValue( 0 )
        slider:SetValue( value )
        slider:SetText( label )
        slider:Dock( TOP )
        slider:DockMargin( 0, 4, 10, 0 )
        slider.Label:SetTextColor( Color( 0, 0, 0 ) )

        ApplyTheme( slider )

        return slider
    end

    local maxPrimary, maxSecondary = self:GetAmmoLimits()

    if not regWeapon.noPrimary then
        local sliderPrimary = CreateSlider(
            LangPhrase( "cloadout.ammo_primary" ),
            item[2],
            maxPrimary
        )

        sliderPrimary.OnValueChanged = function( _, value )
            value = math.Round( value )
            item[2] = value
            icon.Primary = value
        end
    end

    if not regWeapon.noSecondary then
        local sliderSecondary = CreateSlider(
            LangPhrase( "cloadout.ammo_secondary" ),
            item[2],
            maxSecondary
        )

        sliderSecondary.OnValueChanged = function( _, value )
            value = math.Round( value )
            item[3] = value
            icon.Secondary = value
        end
    end
end

-- Create a weapon icon for the available weapons list.
function CLoadout:CreateAvailableWeaponIcon( class )
    local weapon = self.weaponRegistry[class]
    if not weapon then return end

    -- Dont list weapons that dont match the category filter
    if self.categoryFilter and weapon.category ~= self.categoryFilter then return end

    -- Dont list weapons that dont match the search filter
    if self.filter ~= "" then
        local foundClass = string.find( class, self.filter, 1, true )
        local foundName = string.find( string.lower( weapon.name ), self.filter, 1, true )
        if not foundClass and not foundName then return end
    end

    local localPly = LocalPlayer()

    weapon.blacklisted = self:IsBlacklisted( localPly, class )

    local icon = self.listAvailable:Add( "CLoadoutWeaponIcon" )
    icon:SetWeaponName( weapon.name )
    icon:SetWeaponClass( class )

    if weapon.blacklisted then
        icon:SetBlacklisted( true )
        icon:SetTooltip( LangPhrase( "cloadout.weapon_unavailable" ) )
    end

    if weapon.adminOnly then
        icon:SetAdminOnly( true )
    end

    icon.DoClick = function()
        if weapon.adminOnly and not localPly:IsAdmin() then
            Derma_Message(
                LangPhrase( "cloadout.admin_only" ),
                LangPhrase( "cloadout.weapon_restricted" ),
                LangPhrase( "cloadout.ok" )
            )

        elseif weapon.blacklisted then
            Derma_Message(
                LangPhrase( "cloadout.weapon_unavailable" ),
                LangPhrase( "cloadout.weapon_restricted" ),
                LangPhrase( "cloadout.ok" )
            )

        else
            self:AddWeapon( class )
            self:UpdateLoadoutList()
            icon:Remove()
        end
    end

    icon.OpenMenu = function()
        local menu = DermaMenu()

        menu:AddOption(
            LangPhrase( "cloadout.copy_to_clipboard" ),
            function() SetClipboardText( class ) end
        )

        menu:Open()
    end
end
