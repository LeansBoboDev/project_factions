-- ============================================================
-- MainMenu Overwrite - Shop Integration
-- ============================================================

local LABEL_SEPARATOR = 16
local SHOP_WIDTH      = 800
local SHOP_HEIGHT     = 600
local LABEL_PADDING   = 8

-- ── Helpers ─────────────────────────────────────────────────

local function getFontScale()
    return getTextManager():getFontHeight(UIFont.Small) / 14
end
local function getLargeLineHeight()
    return getTextManager():getFontHeight(UIFont.Large) + LABEL_PADDING * 2
end

-- ── Custom Click Handler ─────────────────────────────────────

-- This function opens the shop WITHOUT hiding the main menu.
local function onShopClicked(item, x, y)
    getSoundManager():playUISound("UIActivateMainMenuItem")
    local joypad = JoypadState.getMainMenuJoypad()
    -- Apenas torna a loja visível. NÃO escondemos o bottomPanel aqui.
    MainScreen.instance.shop:setVisible(true, joypad)
end

-- ── Shop UI Factory ─────────────────────────────────────────

local function createShopPanel(parent)
    local scale  = getFontScale()
    local core   = getCore()
    local width  = SHOP_WIDTH * scale
    local height = SHOP_HEIGHT * scale
    local x      = (core:getScreenWidth() - width) / 2
    local y      = (core:getScreenHeight() - height) / 2
    local shop   = ISShop:new(x, y, width, height)
    shop:initialise()
    shop:setVisible(false)
    shop:setAnchorRight(true)
    shop:setAnchorBottom(true)
    parent:addChild(shop)
    DebugPrintFactionsEconomy(string.format(
        "Shop panel created — parent size: %dx%d",
        parent.width, parent.height
    ))
    return shop
end

-- ── Shop Label Factory ───────────────────────────────────────

local function createShopLabel(parent, anchorWidget)
    local lineHgt     = getLargeLineHeight()
    local labelY      = anchorWidget:getBottom() + LABEL_SEPARATOR
    local label       = ISLabel:new(0, labelY, lineHgt,
        getText("IGUI_Shop"), 1, 1, 1, 1, UIFont.Large, true)
    label.internal    = "SHOP"
    label.onMouseDown = onShopClicked -- Usa o handler personalizado
    label:initialise()
    parent:addChild(label)
    -- CRITICAL: Adiciona transição de fade para o efeito de hover
    -- Isso é necessário para que o fundo do botão destaque ao passar o mouse
    label.fade = UITransition.new()
    label.fade:setFadeIn(false)
    label.prerender = MainScreen.prerenderBottomPanelLabel
    DebugPrintFactionsEconomy(string.format(
        "Shop label created — labelY: %d, anchorY: %d, lineHgt: %d",
        labelY, anchorWidget:getBottom(), lineHgt
    ))
    return label
end

-- ── MainScreen.instantiate Overwrite ────────────────────────

local oldMainScreen_instantiate = MainScreen.instantiate
function MainScreen:instantiate()
    oldMainScreen_instantiate(self)
    -- Se estiver no jogo (Pause Menu), adiciona o botão
    if not self.inGame then return end
    self.shop             = createShopPanel(self)
    self.shopOption       = createShopLabel(self.bottomPanel, self.quitToDesktopOption)

    -- Recalcula a largura máxima para garantir alinhamento correto dos itens
    self.maxMenuItemWidth = 0
    for _, child in pairs(self.bottomPanel:getChildren()) do
        if child.Type == "ISLabel" then
            self.maxMenuItemWidth = math.max(self.maxMenuItemWidth, child:getWidth())
        end
    end
    local logoScale = getCore():getScreenWidth() / 1920
    local tex = self.logoTexture
    local logoWidth = tex:getWidth() * logoScale
    local maxWidth = math.max(logoWidth / 2, self.maxMenuItemWidth)
    for _, child in pairs(self.bottomPanel:getChildren()) do
        if child.Type == "ISLabel" then
            child:setWidth(maxWidth)
        end
    end
    self.bottomPanel:setWidth(maxWidth)
end

-- ── MainScreen.render Overwrite ──────────────────────────────

local oldMainScreen_render = MainScreen.render
function MainScreen:render()
    oldMainScreen_render(self)
    if not self.shopOption then return end
    local newY = self.quitToDesktopOption:getBottom() + LABEL_SEPARATOR
    self.shopOption:setY(newY)
    self.bottomPanel:setHeight(self.shopOption:getBottom())
end
