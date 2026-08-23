-- Player safehouse list panel for User Panel (replaces single-safehouse view)
-- Opened when clicking "Safehouse" in the Client/User Panel button

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6

FactionsPlayerSafehousesList = ISPanel:derive("FactionsPlayerSafehousesList")

function FactionsPlayerSafehousesList:initialise()
    ISPanel.initialise(self)
    local btnWid = 100

    self.closeBtn = ISButton:new(UI_BORDER_SPACING+1, self:getHeight() - UI_BORDER_SPACING - BUTTON_HGT - 1, btnWid, BUTTON_HGT, getText("IGUI_CraftUI_Close"), self, FactionsPlayerSafehousesList.onClick)
    self.closeBtn.internal = "CLOSE"
    self.closeBtn.anchorTop = false
    self.closeBtn.anchorBottom = true
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self.closeBtn:enableCancelColor()
    self:addChild(self.closeBtn)

    self.viewBtn = ISButton:new(self:getWidth() - btnWid - UI_BORDER_SPACING - 1, self.closeBtn.y, btnWid, BUTTON_HGT, getText("IGUI_PlayerStats_View"), self, FactionsPlayerSafehousesList.onClick)
    self.viewBtn.internal = "VIEW"
    self.viewBtn.anchorTop = false
    self.viewBtn.anchorBottom = true
    self.viewBtn:initialise()
    self.viewBtn:instantiate()
    self.viewBtn.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.viewBtn)
    self.viewBtn.enable = false

    local listY = UI_BORDER_SPACING*2 + FONT_HGT_MEDIUM + 1
    self.list = ISScrollingListBox:new(UI_BORDER_SPACING+1, listY, self.width - (UI_BORDER_SPACING+1)*2, self.height - UI_BORDER_SPACING*2 - BUTTON_HGT - listY - 1)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = BUTTON_HGT
    self.list.selected = 0
    self.list.joypadParent = self
    self.list.font = UIFont.NewSmall
    self.list.doDrawItem = self.drawItem
    self.list.drawBorder = true
    self:addChild(self.list)

    self:populateList()
end

function FactionsPlayerSafehousesList:populateList()
    self.list:clear()
    self.viewBtn.enable = false
    self.selectedSafehouse = nil
    local username = self.player:getUsername()
    for i = 0, SafeHouse.getSafehouseList():size()-1 do
        local safe = SafeHouse.getSafehouseList():get(i)
        if safe:getOwner() == username or safe:getPlayers():contains(username) then
            self.list:addItem(safe:getTitle(), safe)
        end
    end
end

function FactionsPlayerSafehousesList:drawItem(y, item, alt)
    local a = 0.9
    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
        self.parent.viewBtn.enable = true
        self.parent.selectedSafehouse = item.item
    end
    local playerCount = item.item:getPlayers():size() + 1
    self:drawText(item.item:getTitle() .. " - " .. getText("IGUI_FactionUI_FactionsListPlayers", playerCount, item.item:getOwner()), 10, y + 2, 1, 1, 1, a, self.font)
    return y + self.itemheight
end

function FactionsPlayerSafehousesList:prerender()
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local title = getText("IGUI_SafehouseUI_Safehouse")
    self:drawText(title, self.width/2 - getTextManager():MeasureStringX(UIFont.Medium, title)/2, UI_BORDER_SPACING+1, 1,1,1,1, UIFont.Medium)
end

function FactionsPlayerSafehousesList:onClick(button)
    if button.internal == "CLOSE" then
        self:close()
    elseif button.internal == "VIEW" and self.selectedSafehouse then
        local width = 500 + getCore():getOptionFontSizeReal() * 30
        local ui = ISSafehouseUI:new((getCore():getScreenWidth()-width)/2, getCore():getScreenHeight()/2 - 225, width, 450, self.selectedSafehouse, self.player)
        ui:initialise()
        ui:addToUIManager()
    end
end

function FactionsPlayerSafehousesList:close()
    self:setVisible(false)
    self:removeFromUIManager()
    FactionsPlayerSafehousesList.instance = nil
end

function FactionsPlayerSafehousesList:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.width = width
    o.height = height
    o.player = player
    o.selectedSafehouse = nil
    o.moveWithMouse = true
    FactionsPlayerSafehousesList.instance = o
    return o
end

function FactionsPlayerSafehousesList.OnSafehousesChanged()
    if FactionsPlayerSafehousesList.instance then
        FactionsPlayerSafehousesList.instance:populateList()
    end
end

Events.OnSafehousesChanged.Add(FactionsPlayerSafehousesList.OnSafehousesChanged)

-- Patch ISUserPanelUI: rename "Safehouse" button to "Safehouses"
local _orig_create = ISUserPanelUI.create
ISUserPanelUI.create = function(self)
    _orig_create(self)
    if self.safehouseBtn then
        self.safehouseBtn.title = getText("IGUI_SafehouseUI_Safehouse") .. "s"
    end
end

-- Patch ISUserPanelUI: open the list instead of a single safehouse
local _orig_onOptionMouseDown = ISUserPanelUI.onOptionMouseDown
ISUserPanelUI.onOptionMouseDown = function(self, button, x, y)
    if button.internal == "SAFEHOUSEPANEL" then
        if FactionsPlayerSafehousesList.instance then
            FactionsPlayerSafehousesList.instance:close()
        end
        local width = 500 + getCore():getOptionFontSizeReal() * 30
        local ui = FactionsPlayerSafehousesList:new(
            (getCore():getScreenWidth()-width)/2,
            getCore():getScreenHeight()/2 - 225,
            width, 450, self.player
        )
        ui:initialise()
        ui:addToUIManager()
        return
    end
    _orig_onOptionMouseDown(self, button, x, y)
end

