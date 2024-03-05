local WeaponIcon = {}

local iconMaterials = {
    ammo = Material( "icon16/bullet_yellow.png" ),
    adminOnly = Material( "icon16/shield.png" ),
    favorite = Material( "icon16/star.png", "smooth mips" ),
    blacklisted = Material( "icon16/cross.png", "smooth mips" )
}

AccessorFunc( WeaponIcon, "m_bAdminOnly", "AdminOnly" )
AccessorFunc( WeaponIcon, "m_bFavorite", "Favorite" )
AccessorFunc( WeaponIcon, "m_bBlacklisted", "Blacklisted" )

function WeaponIcon:Init()
    self:SetPaintBackground( false )
    self:SetSize( 140, 128 )
    self:SetText( "" )
    self:SetDoubleClickingEnabled( false )

    self.Image = self:Add( "DImage" )
    self.Image:SetPos( 0, 0 )
    self.Image:SetSize( 128, 128 )
    self.Image:SetVisible( false )
    self.Image:SetKeepAspect( false )

    self.WeaponName = ""
    self.WeaponClass = ""
    self.IconPath = nil
    self.LastIconPath = nil

    self.Border = 0
    self.TextColor = Color( 255, 255, 255, 255 )
    self.TextOutlineColor = Color( 0, 0, 0, 255 )
end

function WeaponIcon:SetWeaponName( name )
    self.WeaponName = name
end

function WeaponIcon:SetWeaponClass( class )
    self.WeaponClass = class

    local iconPath = CLoadout:GetWeaponIcon( class )
    if iconPath then
        self:SetMaterial( iconPath )
    end
end

function WeaponIcon:SetMaterial( path )
    self.IconPath = path
end

function WeaponIcon:DoRightClick()
    CLoadout:OpenMenuForIcon( self )
end

function WeaponIcon:DoClick() end
function WeaponIcon:OpenMenu() end
function WeaponIcon:PaintOver() end

function WeaponIcon:Paint( w, h )
    self.Border = self.Depressed and 8 or 0

    if self.IconPath ~= self.LastIconPath then
        self.LastIconPath = self.IconPath

        local path = self.IconPath
        local mat = Material( path )

        if not mat or mat:IsError() then
            path = path:Replace( "entities/", "VGUI/entities/" )
            path = path:Replace( ".png", "" )
            mat = Material( path )
        end

        if mat and not mat:IsError() then
            self.Image:SetMaterial( mat )
        end
    end

    render.PushFilterMag( TEXFILTER.ANISOTROPIC )
    render.PushFilterMin( TEXFILTER.ANISOTROPIC )

    local ok, err = xpcall(
        self.Image.PaintAt,
        debug.traceback,
        self.Image,
        self.Border,
        self.Border,
        w - self.Border * 2,
        h - self.Border * 2
    )

    if not ok then print( err ) end

    render.PopFilterMin()
    render.PopFilterMag()

    if self:IsHovered() or self.Depressed or self:IsChildHovered() then
        surface.SetDrawColor( 255, 255, 255, 255 )
    else
        surface.SetDrawColor( 0, 0, 0, 255 )
    end

    surface.DrawOutlinedRect( 0, 0, w, h, 4 )

    local infoH = 20
    local infoY = h - infoH - 4

    surface.SetDrawColor( 30, 30, 30, 240 )
    surface.DrawRect( 4, infoY, w - 8, infoH )

    draw.SimpleTextOutlined( self.WeaponName, "Default", 8, infoY + infoH * 0.5,
        self.TextColor, 0, 1, 1, self.TextOutlineColor )
    surface.SetDrawColor( 255, 255, 255, 255 )

    local str

    if self.Primary then
        if self.Secondary then
            str = self.Primary .. "/" .. self.Secondary
        else
            str = self.Primary
        end

    elseif self.Secondary then
        str = self.Secondary
    end

    if str then
        surface.SetMaterial( iconMaterials.ammo )
        surface.DrawTexturedRect( w - 18, infoY + 3, 16, 16 )

        draw.SimpleTextOutlined( str, "Default", w - 18, infoY + infoH * 0.5,
            self.TextColor, 2, 1, 1, self.TextOutlineColor )
    end

    local iconX, iconY = w, 4

    if self:GetAdminOnly() then
        iconX = iconX - 22
        surface.SetMaterial( iconMaterials.adminOnly )
        surface.DrawTexturedRect( iconX, iconY, 16, 16 )
    end

    if self:GetFavorite() then
        iconX = iconX - 22
        surface.SetMaterial( iconMaterials.favorite )
        surface.DrawTexturedRect( iconX, iconY, 16, 16 )
    end

    if self:GetBlacklisted() then
        iconX = iconX - 22
        surface.SetMaterial( iconMaterials.blacklisted )
        surface.DrawTexturedRect( iconX, iconY, 16, 16 )
    end
end

vgui.Register( "CLoadoutWeaponIcon", WeaponIcon, "DButton" )
