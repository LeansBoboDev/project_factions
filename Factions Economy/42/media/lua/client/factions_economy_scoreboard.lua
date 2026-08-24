-- ============================================================
-- Currency Scoreboard — User Panel integration
-- ============================================================

local FONT_HGT_SMALL    = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM   = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT        = FONT_HGT_SMALL + 6

-- ============================================================
-- FactionsEconomyScoreboard panel
-- ============================================================

FactionsEconomyScoreboard = ISPanel:derive("FactionsEconomyScoreboard")

function FactionsEconomyScoreboard:initialise()
    ISPanel.initialise(self)
    local btnWid = 120

    self.closeBtn = ISButton:new(
        UI_BORDER_SPACING + 1,
        self:getHeight() - UI_BORDER_SPACING - BUTTON_HGT - 1,
        btnWid, BUTTON_HGT,
        getText("IGUI_CraftUI_Close"), self, FactionsEconomyScoreboard.onClick)
    self.closeBtn.internal   = "CLOSE"
    self.closeBtn.anchorTop  = false
    self.closeBtn.anchorBottom = true
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self.closeBtn:enableCancelColor()
    self:addChild(self.closeBtn)

    self.refreshBtn = ISButton:new(
        self:getWidth() - btnWid - UI_BORDER_SPACING - 1,
        self.closeBtn.y,
        btnWid, BUTTON_HGT,
        getText("IGUI_Reload"), self, FactionsEconomyScoreboard.onClick)
    self.refreshBtn.internal    = "REFRESH"
    self.refreshBtn.anchorTop   = false
    self.refreshBtn.anchorBottom = true
    self.refreshBtn:initialise()
    self.refreshBtn:instantiate()
    self.refreshBtn.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.refreshBtn)

    local listY = UI_BORDER_SPACING * 2 + FONT_HGT_MEDIUM + 1
    self.list = ISScrollingListBox:new(
        UI_BORDER_SPACING + 1, listY,
        self.width  - (UI_BORDER_SPACING + 1) * 2,
        self.height - UI_BORDER_SPACING * 2 - BUTTON_HGT - listY - 1)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight  = BUTTON_HGT
    self.list.selected    = 0
    self.list.joypadParent = self
    self.list.font        = UIFont.NewSmall
    self.list.doDrawItem  = self.drawItem
    self.list.drawBorder  = true
    self:addChild(self.list)

    sendClientCommand("FactionsEconomyCurrency", "getScoreboard", {})
end

function FactionsEconomyScoreboard:populateList(entries)
    self.list:clear()
    if not entries or #entries == 0 then
        self.list:addItem(getText("IGUI_Economy_Scoreboard_Empty"), {})
        return
    end
    for i, entry in ipairs(entries) do
        self.list:addItem(i, { rank = i, username = entry.username, balance = entry.balance })
    end
end

function FactionsEconomyScoreboard:drawItem(y, item, alt)
    local a = 0.9
    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, a,
        self.borderColor.r, self.borderColor.g, self.borderColor.b)

    if not item.item or not item.item.rank then
        self:drawText(getText("IGUI_Economy_Scoreboard_Empty"),
            10, y + 2, 0.7, 0.7, 0.7, a, self.font)
        return y + self.itemheight
    end

    local rank     = item.item.rank
    local username = item.item.username
    local balance  = tostring(item.item.balance)

    -- Gold / Silver / Bronze for top 3
    local rr, rg, rb = 1, 1, 1
    if     rank == 1 then rr, rg, rb = 1,    0.84, 0
    elseif rank == 2 then rr, rg, rb = 0.75, 0.75, 0.75
    elseif rank == 3 then rr, rg, rb = 0.8,  0.5,  0.2
    end

    local balW = getTextManager():MeasureStringX(self.font, balance)
    self:drawText(string.format("#%d", rank), 10, y + 2, rr, rg, rb, a, self.font)
    self:drawText(username, 55, y + 2, 1, 1, 1, a, self.font)
    self:drawText(balance, self:getWidth() - balW - 10, y + 2, 0.9, 0.85, 0.1, a, self.font)

    return y + self.itemheight
end

function FactionsEconomyScoreboard:prerender()
    self:drawRect(0, 0, self.width, self.height,
        self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height,
        self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local title = getText("IGUI_Economy_Scoreboard_Title")
    self:drawText(title,
        self.width / 2 - getTextManager():MeasureStringX(UIFont.Medium, title) / 2,
        UI_BORDER_SPACING + 1, 1, 1, 1, 1, UIFont.Medium)
end

function FactionsEconomyScoreboard:onClick(button)
    if button.internal == "CLOSE" then
        self:close()
    elseif button.internal == "REFRESH" then
        sendClientCommand("FactionsEconomyCurrency", "getScoreboard", {})
    end
end

function FactionsEconomyScoreboard:close()
    self:setVisible(false)
    self:removeFromUIManager()
    FactionsEconomyScoreboard.instance = nil
end

function FactionsEconomyScoreboard:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor     = {r=0.4, g=0.4, b=0.4, a=1}
    o.backgroundColor = {r=0,   g=0,   b=0,   a=0.8}
    o.width           = width
    o.height          = height
    o.moveWithMouse   = true
    FactionsEconomyScoreboard.instance = o
    return o
end

-- ============================================================
-- Server response handler
-- ============================================================

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "FactionsEconomyCurrency" or command ~= "scoreboardData" then return end
    if FactionsEconomyScoreboard.instance then
        FactionsEconomyScoreboard.instance:populateList(args.entries)
    end
end)

-- ============================================================
-- ISUserPanelUI — inject "Scoreboard" button below Vehicles
-- ============================================================

local _orig_createScoreboard = ISUserPanelUI.create
ISUserPanelUI.create = function(self)
    _orig_createScoreboard(self)

    local insertY = self.cancel.y
    local btnWid  = self.cancel.width

    self.scoreboardBtn = ISButton:new(self.cancel.x, insertY, btnWid, BUTTON_HGT,
        getText("IGUI_Economy_Scoreboard_Button"), self, ISUserPanelUI.onOptionMouseDown)
    self.scoreboardBtn.internal     = "SCOREBOARDPANEL"
    self.scoreboardBtn:initialise()
    self.scoreboardBtn:instantiate()
    self.scoreboardBtn.borderColor  = self.buttonBorderColor
    self:addChild(self.scoreboardBtn)

    self.cancel.y = insertY + BUTTON_HGT + UI_BORDER_SPACING
    self:setHeight(self.cancel.y + BUTTON_HGT + UI_BORDER_SPACING + 1)
end

-- ============================================================
-- ISUserPanelUI — handle button click
-- ============================================================

local _orig_onOptionMouseDownScoreboard = ISUserPanelUI.onOptionMouseDown
ISUserPanelUI.onOptionMouseDown = function(self, button, x, y)
    if button.internal == "SCOREBOARDPANEL" then
        if FactionsEconomyScoreboard.instance then
            FactionsEconomyScoreboard.instance:close()
        end
        local width = 500 + getCore():getOptionFontSizeReal() * 30
        local ui = FactionsEconomyScoreboard:new(
            (getCore():getScreenWidth() - width) / 2,
            getCore():getScreenHeight() / 2 - 225,
            width, 450)
        ui:initialise()
        ui:addToUIManager()
        return
    end
    _orig_onOptionMouseDownScoreboard(self, button, x, y)
end
