if not getSandboxOptions():getOptionByName("SafehousePlus.EnableSafehouseCreateKey"):getValue() then return end

local UI_BORDER_SPACING = 10

local function chatMsg(text)
    if not ISChat or not ISChat.instance then return end
    local mock = {
        getTextWithPrefix = function() return "<RGB:1,1,1>" .. text end,
        getAuthor         = function() return nil end,
    }
    ISChat.addLineInChat(mock, 0)
end

-- Scans all safehouse tiles looking for a door with a valid keyId.
-- Returns the keyId or nil if no locked door was found.
local function findKeyIdInSafehouse(safehouse)
    local x0 = safehouse:getX()
    local y0 = safehouse:getY()
    local w = safehouse:getW()
    local h = safehouse:getH()
    local cell = getCell()
    for z = 0, 1 do
        for dx = 0, w - 1 do
            for dy = 0, h - 1 do
                local sq = cell:getGridSquare(x0 + dx, y0 + dy, z)
                if sq then
                    local objs = sq:getObjects()
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if instanceof(obj, 'IsoDoor') then
                            local keyId = obj:getKeyId()
                            if keyId and keyId ~= -1 then
                                return keyId
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function createKeyInInventory(player, keycode)
    local doorkey = player:getInventory():AddItem('Base.Key1')
    doorkey:setKeyId(keycode)
    doorkey:setName('SafeHouse #' .. keycode)
    chatMsg(getText("IGUI_Door_Key_Created"))
end

local function onCreateKeyClick(ui, button)
    local player = ui.player
    local keyId = findKeyIdInSafehouse(ui.safehouse)
    if not keyId then
        chatMsg(getText("IGUI_Door_Key_Not_Created"))
        return
    end
    if FactionsEconomyCompatibility then
        sendClientCommand(player, "FactionsEconomyCurrency", "requestCreateKey", { keycode = keyId })
    else
        createKeyInInventory(player, keyId)
    end
end

-- Note: the OnServerCommand listener for confirmCreateKey / denyCreateKey is already
-- registered by create_key.lua (same sandbox guard), so we do not duplicate it here.

local function buildCreateKeyTitle()
    local label = getText("IGUI_Door_Create_Key")
    if not FactionsEconomyCompatibility then return label end
    local opt = getSandboxOptions():getOptionByName("FactionsEconomy.CreateKeyCost")
    if not opt then return label end
    return label .. " " .. tostring(opt:getValue())
end

local _origInitialise = ISSafehouseUI.initialise
ISSafehouseUI.initialise = function(self)
    _origInitialise(self)

    local fontHgt = getTextManager():getFontHeight(UIFont.Small)
    local btnHgt = fontHgt + 6

    self.createKeySafehouse = ISButton:new(
        self.releaseSafehouse:getRight() + 5,
        self.releaseSafehouse.y,
        70, btnHgt,
        getText("IGUI_Door_Create_Key"),
        self, onCreateKeyClick
    )
    self.createKeySafehouse.internal = "CREATEKEY"
    self.createKeySafehouse:initialise()
    self.createKeySafehouse:instantiate()
    self.createKeySafehouse.borderColor = self.buttonBorderColor
    self.createKeySafehouse:setWidthToTitle(70)
    self:addChild(self.createKeySafehouse)
    self.createKeySafehouse:setVisible(false)
end

local _origUpdateButtons = ISSafehouseUI.updateButtons
ISSafehouseUI.updateButtons = function(self)
    _origUpdateButtons(self)
    if not self.createKeySafehouse then return end

    local username = self.player:getUsername()
    local isOwner = self:isOwner()
    local isMember = self.safehouse:getPlayers():contains(username)
    self.createKeySafehouse:setVisible(isOwner or isMember)
    self.createKeySafehouse:setTitle(buildCreateKeyTitle())
    self.createKeySafehouse:setWidthToTitle(70)

    -- Position: after redeemSafehouse (Economy) if visible, else after releaseSafehouse, else left edge
    if self.redeemSafehouse and self.redeemSafehouse:isVisible() then
        self.createKeySafehouse:setX(self.redeemSafehouse:getRight() + 5)
    elseif self.releaseSafehouse:isVisible() then
        self.createKeySafehouse:setX(self.releaseSafehouse:getRight() + 5)
    else
        self.createKeySafehouse:setX(UI_BORDER_SPACING + 1)
    end
end
