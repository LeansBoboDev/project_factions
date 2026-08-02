-- ============================================================
-- ISShop — Shop UI Panel
-- ============================================================

ISShop                = ISPanel:derive("ISShop")
ISShop.BuyType        = {}
ISShop.DrawType       = {}
ISShop.LoadType       = {}
ISShop.PreviewType    = {}

-- ── Font Constants ───────────────────────────────────────────

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE  = getTextManager():getFontHeight(UIFont.Large)
local FONT_SCALE      = FONT_HGT_SMALL / 14

-- ── Server Communication ─────────────────────────────────────

local function onReceiveCurrency(module, command, args)
    if module ~= "FactionsEconomyCurrency" or command ~= "receiveCurrency" then return end
    ISShop.instance.currency = args.balance
    Events.OnServerCommand.Remove(onReceiveCurrency)
    DebugPrintFactionsEconomy(string.format("Currency updated: %d", ISShop.instance.currency))
end

local function onReceiveShopItems(module, command, args)
    if module ~= "FactionsEconomyShop" or command ~= "receiveShopItems" then return end
    Events.OnServerCommand.Remove(onReceiveShopItems)
    DebugPrintFactionsEconomy("Shop items received!")
    ISShop.instance:populateTabs(args)
end

-- ── Tab Population ───────────────────────────────────────────

function ISShop:populateTabs(items)
    DebugPrintFactionsEconomy("POPULATING TABS!")
    for category, entries in pairs(items) do
        DebugPrintFactionsEconomy(string.format("Populating category: %s", category))

        local scrollingList             = ISScrollingListBox:new(1, 0,
            self.tabPanel.width - 2,
            self.tabPanel.height - self.tabPanel.tabHeight)

        scrollingList.itemPadY          = 10 * FONT_SCALE
        scrollingList.itemheight        = FONT_HGT_LARGE + scrollingList.itemPadY * 2 + 1 * FONT_SCALE + FONT_HGT_SMALL
        scrollingList.textureHeight     = scrollingList.itemheight - scrollingList.itemPadY * 2
        scrollingList.mouseoverselected = -1
        scrollingList:initialise()
        scrollingList.doDrawItem = ISShop.doDrawItem

        self.tabPanel:addView(category, scrollingList)

        for index, entry in ipairs(entries) do
            local row    = scrollingList:addItem(entry.type, nil)
            row.type     = entry.type
            row.target   = entry.target
            row.price    = entry.price or 0
            row.rowId    = category
            row.rowIndex = index

            DebugPrintFactionsEconomy(string.format("New item — category: %s, target: %s", category, tostring(row.target)))

            if ISShop.LoadType[entry.type] then
                ISShop.LoadType[entry.type](row, entry)
            else
                row.text = string.format("%s:%s", entry.type, tostring(entry.target))
            end
        end
    end
end

-- ── LoadType Handlers ────────────────────────────────────────

function ISShop.LoadType.ITEM(row, entry)
    row.quantity = entry.quantity or 1
    local item   = getScriptManager():getItem(entry.target)
    if item then
        row.text    = item:getDisplayName()
        row.texture = item:getNormalTexture()
    else
        row.text   = "Unknown"
        row.target = "Base.Axe"
    end
end

function ISShop.LoadType.VEHICLE(row, entry)
    row.text    = getScriptManager():getVehicle(entry.target):getName()
    row.texture = getTexture("Item_CarKey")
end

function ISShop.LoadType.XP(row, entry)
    row.quantity = entry.quantity or 1
    row.text     = string.format("%s XP", entry.target)
    row.texture  = getTexture("media/ui/Moodle_internal_plus_green.png")
end

function ISShop.LoadType.DIV(row, entry)
    row.target = row.target or {}
    if type(entry.target) == "string" then
        row.target = {}
        for text in entry.target:gmatch("([^\n]+)") do
            table.insert(row.target, text)
        end
    end
    local lineCountLarge  = #row.target * (FONT_HGT_LARGE + 1 * FONT_SCALE)
    local lineCountMedium = #row.target * (FONT_HGT_MEDIUM + 1 * FONT_SCALE)
    row.font              = row.height > lineCountLarge and UIFont.Large or
        row.height > lineCountMedium and UIFont.Medium or UIFont.Small
    row.fontHeight        = getTextManager():getFontHeight(row.font)
end

-- ── BuyType Handlers ─────────────────────────────────────────

local function buySinglePlayer(row)
    local player   = getPlayer()
    local category = ShopItems[row.rowId]
    if not category then
        DebugPrintFactionsEconomy(string.format("Category not found: %s, player: %s", tostring(row.rowId),
            player:getUsername()))
        return
    end

    local item = category[row.rowIndex]
    if not item then
        DebugPrintFactionsEconomy(string.format("Item not found at index: %s, player: %s", tostring(row.rowIndex),
            player:getUsername()))
        return
    end

    if item.type ~= "ITEM" then return end

    local username = player:getUsername()
    local balance  = FactionsEconomyCurrencyData[username]

    if not balance then
        DebugPrintFactionsEconomy(string.format("No currency registered for: %s", username))
        return
    end

    if balance < item.price then
        DebugPrintFactionsEconomy(string.format("Not enough currency — %s: %d/%d", username, balance, item.price))
        return
    end

    FactionsEconomyCurrencyData[username] = balance - item.price
    player:getInventory():AddItems(item.target, item.quantity)
    DebugPrintFactionsEconomy(string.format("%s bought %s for %d", username, item.target, item.price))
end

function ISShop.BuyType.ITEM(row)
    if FactionsEconomyIsSinglePlayer then
        buySinglePlayer(row)
    else
        sendClientCommand("FactionsEconomyShop", "buyItem", row)
    end
end

function ISShop.BuyType.VEHICLE(row)
    sendClientCommand("FactionsEconomyShop", "buyVehicle", { row.price, row.target })
end

function ISShop.BuyType.XP(row)
    sendClientCommand("FactionsEconomyShop", "buyXP", { row.price, row.target })
end

-- ── DrawType Handlers ────────────────────────────────────────

function ISShop.DrawType.DIV(self, y, item, alt)
    self:drawRectBorder(0, y, self:getWidth(), item.height, 0.5,
        self.borderColor.r, self.borderColor.g, self.borderColor.b)
    y = y + (item.height - #item.target * item.fontHeight) / 2
    for _, line in ipairs(item.target) do
        self:drawTextCentre(line, self.width / 2, y, 0.7, 0.7, 0.7, 1.0, item.font)
        y = y + item.fontHeight + 1 * FONT_SCALE
    end
end

function ISShop.DrawType.DEFAULT(self, y, item, alt)
    self:drawRectBorder(0, y, self:getWidth(), item.height, 0.5,
        self.borderColor.r, self.borderColor.g, self.borderColor.b)

    local padX    = self.itemPadY
    local itemTop = y + self.itemPadY

    if item.texture then
        self:drawTextureScaledAspect2(item.texture,
            padX, itemTop, self.textureHeight, self.textureHeight, 1, 1, 1, 1)
    end

    local textX = padX + self.itemPadY + self.textureHeight
    local textZ = item.quantity and itemTop or y + (item.height - FONT_HGT_LARGE) / 2

    self:drawText(item.text, textX, textZ, 0.7, 0.7, 0.7, 1.0, self.font)

    if item.quantity then
        local labelW = getTextManager():MeasureStringX(UIFont.Small, "Quantity: ")
        self:drawText("Quantity: ", textX, itemTop + FONT_HGT_LARGE + 1 * FONT_SCALE, 0.7, 0.7, 0.7, 1.0, UIFont.Small)
        self:drawText(tostring(item.quantity), textX + labelW, itemTop + FONT_HGT_LARGE + 1 * FONT_SCALE, 0.7, 0.7, 0.7,
            1.0, UIFont.Small)
    end

    local priceZ = y + (item.height - FONT_HGT_LARGE) / 2
    self:drawText(tostring(item.price), self.width - 75, priceZ, 0.7, 0.7, 0.7, 1.0, self.font)
end

function ISShop:doDrawItem(y, item, alt)
    local drawFn = ISShop.DrawType[item.type] or ISShop.DrawType.DEFAULT
    drawFn(self, y, item, alt)
    return y + item.height
end

-- ── PreviewType Handlers ─────────────────────────────────────

function ISShop.PreviewType.VEHICLE(self)
    if self.preview then
        self.preview:setVisible(false)
        self.preview:removeFromUIManager()
        ISShop.instance.preview = nil
    end

    self.preview = ISUI3DScene:new(self.x + self.width, self.y, 400 * FONT_SCALE, self.height)
    self.preview:initialise()
    self.parent:addChild(self.preview)

    self.preview.onMouseMove = function(scene, dx, dy)
        if scene.mouseDown then
            local vec = scene:getRotation()
            local x   = math.max(-90, math.min(90, vec:x() + dy))
            scene:setRotation(x, vec:y() + dx)
        end
    end

    self.preview.setRotation = function(scene, x, y)
        scene.javaObject:fromLua3("setViewRotation", x, y, 0)
    end

    self.preview.getRotation = function(scene)
        return scene.javaObject:fromLua0("getViewRotation")
    end

    local selectedTarget = self.tabPanel.activeView.view.items[self.tabPanel.activeView.view.mouseoverselected].target
    local java = self.preview.javaObject
    java:fromLua1("setDrawGrid", false)
    java:fromLua1("createVehicle", "vehicle")
    java:fromLua3("setViewRotation", 45 / 2, 45, 0)
    java:fromLua1("setView", "UserDefined")
    java:fromLua2("dragView", 0, 30)
    java:fromLua1("setZoom", 6)
    java:fromLua2("setVehicleScript", "vehicle", selectedTarget)

    local closeBtn = ISButton:new(
        self.preview.width - 15 * FONT_SCALE, 5 * FONT_SCALE,
        10 * FONT_SCALE, 10 * FONT_SCALE,
        nil, self.preview,
        function(btn)
            btn.parent:setVisible(false)
            btn.parent:removeFromUIManager()
            ISShop.instance.preview = nil
        end)
    closeBtn:setDisplayBackground(false)
    closeBtn:setImage(getTexture("media/ui/Dialog_Titlebar_CloseIcon.png"))
    closeBtn:forceImageSize(closeBtn.width, closeBtn.height)
    closeBtn:initialise()
    self.preview:addChild(closeBtn)
    self.preview.closeButton = closeBtn
end

-- ── Visibility & Currency ────────────────────────────────────

function ISShop:refreshCurrency()
    if FactionsEconomyIsSinglePlayer then
        self.currency = FactionsEconomyCurrencyData[getPlayer():getUsername()] or 0
    else
        Events.OnServerCommand.Add(onReceiveCurrency)
        sendClientCommand("FactionsEconomyCurrency", "getCurrency", nil)
    end
end

function ISShop:setVisible(visible)
    if self.javaObject == nil then self:instantiate() end
    self.javaObject:setVisible(visible)
    if self.preview then self.preview:setVisible(visible) end
    if visible then
        self:refreshCurrency()
        self:onReload()
    end
end

-- ── UI Construction ──────────────────────────────────────────

function ISShop:createChildren()
    local padBottom = 10 * FONT_SCALE
    local btnWid    = 125 * FONT_SCALE
    local btnHgt    = FONT_HGT_SMALL + 5 * 2 * FONT_SCALE
    local topZ      = 15 * FONT_SCALE * 2 + FONT_HGT_LARGE + 1

    -- Tab panel
    self.tabPanel   = ISTabPanel:new(0, topZ, self.width, self.height - topZ - padBottom - btnHgt - padBottom)
    self.tabPanel:initialise()
    self.tabPanel.tabFont   = UIFont.Medium
    self.tabPanel.tabHeight = FONT_HGT_MEDIUM + 6
    self.tabPanel.render    = self.tabPanelRender
    self.tabPanel.addView   = self.addView
    self:addChild(self.tabPanel)

    -- Preview button
    local previewX     = self.width - 200 * FONT_SCALE - padBottom * 2
    local btnH         = FONT_HGT_LARGE + 1 * FONT_SCALE + FONT_HGT_SMALL
    self.previewButton = ISButton:new(previewX, 0, 100 * FONT_SCALE, btnH, "PREVIEW", self, ISShop.onPreview)
    self.previewButton:initialise()
    self.previewButton:instantiate()
    self.previewButton.borderColor = self.buttonBorderColor
    self.previewButton.font        = UIFont.Medium
    self.previewButton:setVisible(false)
    self:addChild(self.previewButton)

    -- Buy button
    self.buyButton = ISButton:new(self.width - 100 * FONT_SCALE - padBottom, 0, 100 * FONT_SCALE, btnH,
        getText("IGUI_Buy"), self, ISShop.onBuy)
    self.buyButton:initialise()
    self.buyButton:instantiate()
    self.buyButton.borderColor = self.buttonBorderColor
    self.buyButton.font        = UIFont.Medium
    self.buyButton:setVisible(false)
    self:addChild(self.buyButton)

    -- Cancel button
    self.cancelButton = ISButton:new(
        self.width - padBottom - btnWid, self.height - padBottom - btnHgt, btnWid, btnHgt,
        getText("UI_btn_close"), self, ISShop.close)
    self.cancelButton:initialise()
    self.cancelButton:instantiate()
    self:addChild(self.cancelButton)

    -- Reload button
    self.reloadButton = ISButton:new(
        self.cancelButton.x - padBottom - btnWid, self.cancelButton.y, btnWid, btnHgt,
        getText("IGUI_Reload"), self, ISShop.onReload)
    self.reloadButton:initialise()
    self.reloadButton:instantiate()
    self:addChild(self.reloadButton)
end

-- ── Actions ──────────────────────────────────────────────────

function ISShop:close()
    self:setVisible(false)
end

function ISShop:onReload()
    for _, v in ipairs(self.tabPanel.viewList) do
        self.tabPanel:removeView(v.view)
    end
    if FactionsEconomyIsSinglePlayer then
        self.currency = FactionsEconomyCurrencyData[getPlayer():getUsername()] or 0
        self:populateTabs(ShopItems)
    else
        Events.OnServerCommand.Add(onReceiveShopItems)
        sendClientCommand("FactionsEconomyShop", "getShopItems", nil)
        self:refreshCurrency()
    end
end

function ISShop:onBuy()
    local view = self.tabPanel.activeView.view
    local row  = view.items[view.mouseoverselected]
    if not ISShop.BuyType[row.type] then return end
    ISShop.BuyType[row.type](row)
    self:refreshCurrency()
end

function ISShop:onPreview()
    local view      = self.tabPanel.activeView.view
    local row       = view.items[view.mouseoverselected]
    local previewFn = ISShop.PreviewType[row.type]
    if previewFn then previewFn(self) end
end

-- ── Tab Panel Render ─────────────────────────────────────────

function ISShop:tabPanelRender()
    local inset          = 1
    local x              = inset + self.scrollX
    local widthOfAllTabs = self:getWidthOfAllTabs()
    local overflowLeft   = self.scrollX < 0
    local overflowRight  = x + widthOfAllTabs > self.width

    if widthOfAllTabs > self.width then
        self:setStencilRect(0, 0, self.width, self.tabHeight)
    end

    for i, viewObject in ipairs(self.viewList) do
        local tabWidth = self.equalTabWidth and self.maxLength or viewObject.tabWidth
        if viewObject == self.activeView then
            self:drawRect(x, 0, tabWidth, self.tabHeight, 1, 0.4, 0.4, 0.4)
        else
            self:drawRect(x + tabWidth, 0, 1, self.tabHeight, 1, 0.4, 0.4, 0.4)
            local hovered = self:getMouseY() >= 0 and self:getMouseY() < self.tabHeight
                and self:isMouseOver() and self:getTabIndexAtX(self:getMouseX()) == i
            viewObject.fade:setFadeIn(hovered)
            viewObject.fade:update()
            self:drawRect(x, 0, tabWidth, self.tabHeight, 0.2 * viewObject.fade:fraction(), 1, 1, 1)
        end
        self:drawTextCentre(viewObject.name, x + (tabWidth / 2), 3, 1, 1, 1, 1, self.tabFont)
        x = x + tabWidth
    end

    self:drawRect(0, self.tabHeight - 1, self.width, 1, 1, 0.4, 0.4, 0.4)

    local butPadX = 3
    if overflowLeft then
        local tex    = getTexture("media/ui/ArrowLeft.png")
        local butWid = tex:getWidthOrig() + butPadX * 2
        self:drawRect(inset, 0, butWid, self.tabHeight - 1, 1, 0, 0, 0)
        self:drawRectBorder(inset, -1, butWid, self.tabHeight + 1, 1, 0.4, 0.4, 0.4)
        self:drawTexture(tex, inset + butPadX, (self.tabHeight - tex:getHeightOrig()) / 2, 1, 1, 1, 1)
    end

    if overflowRight then
        local tex    = getTexture("media/ui/ArrowRight.png")
        local butWid = tex:getWidthOrig() + butPadX * 2
        self:drawRect(self.width - inset - butWid, 0, butWid, self.tabHeight - 1, 1, 0, 0, 0)
        self:drawRectBorder(self.width - inset - butWid, -1, butWid, self.tabHeight + 1, 1, 0.4, 0.4, 0.4)
        self:drawTexture(tex, self.width - butWid + butPadX, (self.tabHeight - tex:getHeightOrig()) / 2, 1, 1, 1, 1)
    end

    if widthOfAllTabs > self.width then self:clearStencilRect() end
    self:drawRect(0, self.height, self.width, 1, 1, 0.4, 0.4, 0.4)
end

function ISShop:addView(name, view)
    local viewObject    = {}
    viewObject.id       = #self.viewList + 1
    viewObject.name     = getText("IGUI_Shop_" .. name)
    viewObject.view     = view
    viewObject.tabWidth = getTextManager():MeasureStringX(self.tabFont, getText("IGUI_Shop_" .. name)) + self.tabPadX
    viewObject.fade     = UITransition.new()
    table.insert(self.viewList, viewObject)
    view:setY(self.tabHeight)
    self:addChild(view)
    view.parent = self
    if #self.viewList == 1 then
        view:setVisible(true)
        self.activeView = viewObject
        self.maxLength  = viewObject.tabWidth
    else
        view:setVisible(false)
        if viewObject.tabWidth > self.maxLength then
            self.maxLength = viewObject.tabWidth
        end
    end
end

-- ── Render ───────────────────────────────────────────────────

function ISShop:render()
    local z = 15 * FONT_SCALE
    self:drawText(self.title, 10 * FONT_SCALE, z, 1, 1, 1, 1, UIFont.Large)
    z                = z + FONT_HGT_LARGE + z

    -- Avatar + currency display
    local avatarSize = FONT_HGT_LARGE
    local avatarX    = self.width - 10 * FONT_SCALE - avatarSize
    local avatarY    = (z - avatarSize) / 2
    self:drawTextureScaledAspect2(getSteamAvatarFromUsername(getPlayer():getUsername()),
        avatarX, avatarY, avatarSize, avatarSize, 1, 1, 1, 1)

    local balanceStr = tostring(self.currency)
    local balanceW   = getTextManager():MeasureStringX(UIFont.Medium, balanceStr)
    local availableW = getTextManager():MeasureStringX(UIFont.Medium, self.available)
    local midY       = (z - FONT_HGT_MEDIUM) / 2
    local balanceX   = avatarX - 3 * FONT_SCALE - balanceW
    local availableX = balanceX - 5 * FONT_SCALE - availableW

    self:drawText(self.available, availableX, midY, 1, 1, 1, 1, UIFont.Medium)
    self:drawText(balanceStr, balanceX, midY, 1, 1, 1, 1, UIFont.Medium)
    self:drawRect(0, z, self.width, 1, 1, 0.4, 0.4, 0.4)
    self:drawText(self.serverMsg, 10 * FONT_SCALE, self.tabPanel:getBottom() + 1 + 10 * FONT_SCALE, 1, 1, 1, 1,
        UIFont.Medium)

    -- Buy / Preview buttons
    local view = self.tabPanel.activeView
    if not view then return end
    view = view.view
    if view.mouseoverselected == -1 then
        self.buyButton:setVisible(false)
        self.previewButton:setVisible(false)
        return
    end

    local row  = view.items[view.mouseoverselected]
    local btnY = (view.mouseoverselected - 1) * view.itemheight
        + view:getYScroll() + view.itemPadY + view.y + view.parent.y

    if ISShop.BuyType[row.type] then
        self.buyButton:setY(btnY)
        self.buyButton:setVisible(true)
        self.buyButton:setEnable(self.currency >= row.price)
    else
        self.buyButton:setVisible(false)
    end

    if ISShop.PreviewType[row.type] then
        self.previewButton:setY(btnY)
        self.previewButton:setVisible(true)
    else
        self.previewButton:setVisible(false)
    end
end

-- ── Constructor ──────────────────────────────────────────────

function ISShop:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index        = self
    o.variableColor     = { r = 0.9, g = 0.55, b = 0.1, a = 1 }
    o.borderColor       = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.backgroundColor   = { r = 0, g = 0, b = 0, a = 0.8 }
    o.buttonBorderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    o.title             = getText("IGUI_Shop")
    o.available         = getText("IGUI_Shop_Available")
    o.serverMsg         = getText("IGUI_Shop_Message")
    o.currency          = 0
    ISShop.instance     = o
    return o
end
