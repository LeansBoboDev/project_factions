-- ============================================================
-- Redeem Safehouse — ISSafehouseUI Button
-- ============================================================

local UI_BORDER_SPACING = 10
local safehousePendingCurrency = nil

function FactionsEconomySetSafehousePendingCurrency(amount)
    safehousePendingCurrency = amount
end

local function buildButtonTitle()
    if safehousePendingCurrency == nil then
        return getText("ContextMenu_Redeem")
    end
    return getText("ContextMenu_Redeem") .. " " .. safehousePendingCurrency
end

local function onRedeemClick(ui, button)
    local username = ui.player:getUsername()
    DebugPrintFactionsEconomy(string.format("[RedeemSafehouse] %s sending redeemSafehouse to server", username))
    safehousePendingCurrency = nil
    sendClientCommand(ui.player, "FactionsEconomyCurrency", "redeemSafehouseCurrency", {})
end

local _origInitialise = ISSafehouseUI.initialise
ISSafehouseUI.initialise = function(self)
    _origInitialise(self)

    local fontHgt = getTextManager():getFontHeight(UIFont.Small)
    local btnHgt = fontHgt + 6

    self.redeemSafehouse = ISButton:new(
        self.releaseSafehouse:getRight() + 5,
        self.releaseSafehouse.y,
        70, btnHgt,
        getText("ContextMenu_RedeemSafehouse"),
        self, onRedeemClick
    )
    self.redeemSafehouse.internal = "REDEEMCURRENCY"
    self.redeemSafehouse:initialise()
    self.redeemSafehouse:instantiate()
    self.redeemSafehouse.borderColor = self.buttonBorderColor
    self.redeemSafehouse:setWidthToTitle(70)
    self:addChild(self.redeemSafehouse)
    self.redeemSafehouse:setVisible(false)
    self.safehouseCurrencyRequested = false
end

local _origUpdateButtons = ISSafehouseUI.updateButtons
ISSafehouseUI.updateButtons = function(self)
    _origUpdateButtons(self)
    if not self.redeemSafehouse then return end

    local username = self.player:getUsername()
    local isOwner = self:isOwner()
    local isMember = self.safehouse:getPlayers():contains(username)
    local isVisible = isOwner or isMember
    self.redeemSafehouse:setVisible(isVisible)

    if isVisible and not self.safehouseCurrencyRequested then
        self.safehouseCurrencyRequested = true
        safehousePendingCurrency = nil
        sendClientCommand(self.player, "FactionsEconomyCurrency", "getSafehouseCurrency", {
            safehouseId = self.safehouse:getOnlineID()
        })
    end

    self.redeemSafehouse:setTitle(buildButtonTitle())
    self.redeemSafehouse:setWidthToTitle(70)

    if self.releaseSafehouse:isVisible() then
        self.redeemSafehouse:setX(self.releaseSafehouse:getRight() + 5)
    else
        self.redeemSafehouse:setX(UI_BORDER_SPACING + 1)
    end
end
