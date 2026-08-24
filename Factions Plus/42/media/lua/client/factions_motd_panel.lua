require "ISUI/ISPanel"
require "ISUI/ISRichTextPanel"
require "ISUI/ISButton"

-- Extends ISRichTextPanel to support the <SPACE> tag for explicit spacing
FactionsMOTDRichText = ISRichTextPanel:derive("FactionsMOTDRichText")

function FactionsMOTDRichText:processCommand(command, x, y, lineImageHeight, lineHeight)
    if command == "SPACE" then
        if x > 0 then
            x = x + getTextManager():MeasureStringX(self.font, " ") + 4
        end
        return x, y, lineImageHeight
    end
    return ISRichTextPanel.processCommand(self, command, x, y, lineImageHeight, lineHeight)
end

function FactionsMOTDRichText:new(x, y, w, h)
    local o = ISRichTextPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    return o
end

FactionsMOTDPanel = ISPanel:derive("FactionsMOTDPanel")

function FactionsMOTDPanel:initialise()
    ISPanel.initialise(self)
end

function FactionsMOTDPanel:createChildren()
    self.tabs = {}
    for i = 1, 10 do
        local tab = ISButton:new(0, 30, 60, 22, "", self, FactionsMOTDPanel.onTabPressed)
        tab:initialise()
        tab.backgroundColor = {r=0.08, g=0.08, b=0.08, a=1.0}
        tab.borderColor = {r=0.35, g=0.35, b=0.35, a=1.0}
        tab.textColor = {r=1, g=1, b=1, a=0.65}
        tab.internal = i
        tab:setVisible(false)
        self:addChild(tab)
        self.tabs[i] = tab
    end

    self.content = FactionsMOTDRichText:new(10, 58, self.width - 20, self.height - 100)
    self.content:initialise()
    self.content.backgroundColor = {r=0.05, g=0.05, b=0.05, a=1.0}
    self.content.borderColor = {r=0, g=0, b=0, a=0}
    self.content.autosetheight = false
    self.content.clip = true
    self.content.text = ""
    self:addChild(self.content)

    self.closeBtn = ISButton:new(self.width - 85, self.height - 35, 75, 25,
        getText("IGUI_FactionsMOTD_Close"), self, FactionsMOTDPanel.onClose)
    self.closeBtn:initialise()
    self.closeBtn.borderColor = {r=1, g=1, b=1, a=0.5}
    self.closeBtn.textColor = {r=1, g=1, b=1, a=0.9}
    self:addChild(self.closeBtn)
end

function FactionsMOTDPanel:loadData(pageData)
    self.pageData = pageData

    local totalTabWidth = 0
    for i = 1, 10 do
        if i <= pageData.size then
            local title = pageData.title[i] or ("Page " .. i)
            self.tabs[i].title = title
            local w = getTextManager():MeasureStringX(UIFont.Small, title) + 16
            if w < 50 then w = 50 end
            self.tabs[i]:setWidth(w)
            self.tabs[i]:setVisible(true)
            totalTabWidth = totalTabWidth + w
        else
            self.tabs[i]:setVisible(false)
        end
    end

    -- center tabs horizontally
    local spacing = 4
    local totalSpacing = spacing * (pageData.size - 1)
    local startX = (self.width / 2) - ((totalTabWidth + totalSpacing) / 2)
    for i = 1, pageData.size do
        self.tabs[i]:setX(startX)
        startX = startX + self.tabs[i]:getWidth() + spacing
    end

    self:setPage(1)
end

function FactionsMOTDPanel:setPage(index)
    self.selectedPage = index

    for i = 1, (self.pageData and self.pageData.size or 0) do
        if i == index then
            self.tabs[i].backgroundColor = {r=0.22, g=0.22, b=0.22, a=1.0}
            self.tabs[i].textColor = {r=1, g=1, b=1, a=1.0}
        else
            self.tabs[i].backgroundColor = {r=0.08, g=0.08, b=0.08, a=1.0}
            self.tabs[i].textColor = {r=1, g=1, b=1, a=0.65}
        end
    end

    self.content.text = (self.pageData and self.pageData[index]) or ""
    self.content:paginate()
    self.content:setYScroll(0)
end

function FactionsMOTDPanel.onTabPressed(panel, button)
    panel:setPage(button.internal)
end

function FactionsMOTDPanel.onClose(panel, button)
    panel:setVisible(false)
end

function FactionsMOTDPanel:render()
    local title = getText("IGUI_FactionsMOTD_Title")
    self:drawTextCentre(title, self.width / 2, 8, 1, 1, 1, 0.9, UIFont.Medium)
end

function FactionsMOTDPanel:prerender()
    self:drawRect(0, 0, self.width, self.height,
        self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, 0.4, 0.5, 0.5, 0.5)
end

function FactionsMOTDPanel:new()
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local h = sh * 0.8
    local w = h * 1.2
    local x = (sw / 2) - (w / 2)
    local y = (sh / 2) - (h / 2)

    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.backgroundColor = {r=0.12, g=0.12, b=0.12, a=0.97}
    o.borderColor = {r=0.5, g=0.5, b=0.5, a=0.3}
    o.pageData = nil
    o.selectedPage = 1
    return o
end
