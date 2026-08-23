-- Vehicle Claim List — User Panel integration
-- Lists the player's claimed vehicles and allows unclaiming from the panel.

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6

-- Resolves the human-readable vehicle name from a stored model key or legacy full name.
-- Stored value may be "CarModelKey", "Base.CarModelKey" (legacy), or "Vehicle #N".
local function vehicleDisplayName(storedName)
    if not storedName then return "Vehicle" end
    local key = storedName:match("%.(.+)$") or storedName
    return getTextOrNull("IGUI_VehicleName" .. key) or key
end

-- ============================================================
-- FactionsPlusVehicleList panel
-- ============================================================

FactionsPlusVehicleList = ISPanel:derive("FactionsPlusVehicleList")

function FactionsPlusVehicleList:initialise()
    ISPanel.initialise(self)
    local btnWid = 120

    self.closeBtn = ISButton:new(UI_BORDER_SPACING + 1, self:getHeight() - UI_BORDER_SPACING - BUTTON_HGT - 1,
        btnWid, BUTTON_HGT, getText("IGUI_CraftUI_Close"), self, FactionsPlusVehicleList.onClick)
    self.closeBtn.internal = "CLOSE"
    self.closeBtn.anchorTop = false
    self.closeBtn.anchorBottom = true
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self.closeBtn:enableCancelColor()
    self:addChild(self.closeBtn)

    self.viewBtn = ISButton:new(self:getWidth() - btnWid - UI_BORDER_SPACING - 1, self.closeBtn.y,
        btnWid, BUTTON_HGT, getText("IGUI_PlayerStats_View"), self, FactionsPlusVehicleList.onClick)
    self.viewBtn.internal = "VIEW"
    self.viewBtn.anchorTop = false
    self.viewBtn.anchorBottom = true
    self.viewBtn:initialise()
    self.viewBtn:instantiate()
    self.viewBtn.borderColor = {r=1, g=1, b=1, a=0.1}
    self.viewBtn.enable = false
    self:addChild(self.viewBtn)

    local listY = UI_BORDER_SPACING * 2 + FONT_HGT_MEDIUM + 1
    self.list = ISScrollingListBox:new(UI_BORDER_SPACING + 1, listY,
        self.width - (UI_BORDER_SPACING + 1) * 2,
        self.height - UI_BORDER_SPACING * 2 - BUTTON_HGT - listY - 1)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = BUTTON_HGT
    self.list.selected = 0
    self.list.joypadParent = self
    self.list.font = UIFont.NewSmall
    self.list.doDrawItem = self.drawItem
    self.list.drawBorder = true
    self:addChild(self.list)

    sendClientCommand("FactionsPlusVehicle", "getMyVehicles", {})
end

function FactionsPlusVehicleList:populateList(vehicleList)
    self.list:clear()
    self.viewBtn.enable = false
    self.selectedVehicle = nil
    if vehicleList then
        for _, v in ipairs(vehicleList) do
            self.list:addItem(vehicleDisplayName(v.name), v)
        end
    end
end

function FactionsPlusVehicleList:drawItem(y, item, alt)
    local a = 0.9
    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, a,
        self.borderColor.r, self.borderColor.g, self.borderColor.b)
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
        self.parent.viewBtn.enable = true
        self.parent.selectedVehicle = item.item
    end
    local memberCount = item.item.members and #item.item.members or 0
    local label = vehicleDisplayName(item.item.name)
    if memberCount > 0 then
        label = label .. "  (" .. memberCount .. " " .. getText("IGUI_FactionsPlus_Vehicle_Members") .. ")"
    end
    self:drawText(label, 10, y + 2, 1, 1, 1, a, self.font)
    return y + self.itemheight
end

function FactionsPlusVehicleList:prerender()
    self:drawRect(0, 0, self.width, self.height,
        self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height,
        self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local title = getText("IGUI_FactionsPlus_Vehicle_ListTitle")
    self:drawText(title,
        self.width / 2 - getTextManager():MeasureStringX(UIFont.Medium, title) / 2,
        UI_BORDER_SPACING + 1, 1, 1, 1, 1, UIFont.Medium)
end

function FactionsPlusVehicleList:onClick(button)
    if button.internal == "CLOSE" then
        self:close()
    elseif button.internal == "VIEW" and self.selectedVehicle then
        if FactionsPlusVehicleUI and FactionsPlusVehicleUI.instance then
            FactionsPlusVehicleUI.instance:close()
        end
        local width = 500 + getCore():getOptionFontSizeReal() * 30
        local ui = FactionsPlusVehicleUI:new(
            (getCore():getScreenWidth() - width) / 2,
            getCore():getScreenHeight() / 2 - 200,
            width, 450, self.selectedVehicle, self.player)
        ui:initialise()
        ui:addToUIManager()
    end
end

function FactionsPlusVehicleList:close()
    self:setVisible(false)
    self:removeFromUIManager()
    FactionsPlusVehicleList.instance = nil
end

function FactionsPlusVehicleList:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor     = {r=0.4, g=0.4, b=0.4, a=1}
    o.backgroundColor = {r=0,   g=0,   b=0,   a=0.8}
    o.width  = width
    o.height = height
    o.player = player
    o.selectedVehicle = nil
    o.moveWithMouse = true
    FactionsPlusVehicleList.instance = o
    return o
end

-- ============================================================
-- Server response handler
-- ============================================================

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "FactionsPlusVehicle" or command ~= "myVehiclesList" then return end
    if FactionsPlusVehicleList.instance then
        FactionsPlusVehicleList.instance:populateList(args.vehicles)
    end
end)

-- ============================================================
-- ISUserPanelUI — inject "Vehicles" button
-- ============================================================

local _orig_createVehicles = ISUserPanelUI.create
ISUserPanelUI.create = function(self)
    _orig_createVehicles(self)

    local ok, enabled = pcall(function()
        return getSandboxOptions():getOptionByName("FactionsPlus.EnableVehicleClaim"):getValue()
    end)
    if not ok or not enabled then return end

    -- Insert button just above the cancel button, then push cancel down.
    local insertY = self.cancel.y
    local btnWid  = self.cancel.width

    self.vehicleClaimBtn = ISButton:new(self.cancel.x, insertY, btnWid, BUTTON_HGT,
        getText("IGUI_FactionsPlus_Vehicle_ButtonLabel"), self, ISUserPanelUI.onOptionMouseDown)
    self.vehicleClaimBtn.internal = "VEHICLECLAIMPANEL"
    self.vehicleClaimBtn:initialise()
    self.vehicleClaimBtn:instantiate()
    self.vehicleClaimBtn.borderColor = self.buttonBorderColor
    self:addChild(self.vehicleClaimBtn)

    self.cancel.y = insertY + BUTTON_HGT + UI_BORDER_SPACING
    self:setHeight(self.cancel.y + BUTTON_HGT + UI_BORDER_SPACING + 1)
end

-- ============================================================
-- ISUserPanelUI — handle button click
-- ============================================================

local _orig_onOptionMouseDownVehicles = ISUserPanelUI.onOptionMouseDown
ISUserPanelUI.onOptionMouseDown = function(self, button, x, y)
    if button.internal == "VEHICLECLAIMPANEL" then
        if FactionsPlusVehicleList.instance then
            FactionsPlusVehicleList.instance:close()
        end
        local width = 500 + getCore():getOptionFontSizeReal() * 30
        local ui = FactionsPlusVehicleList:new(
            (getCore():getScreenWidth() - width) / 2,
            getCore():getScreenHeight() / 2 - 225,
            width, 450, self.player)
        ui:initialise()
        ui:addToUIManager()
        return
    end
    _orig_onOptionMouseDownVehicles(self, button, x, y)
end
