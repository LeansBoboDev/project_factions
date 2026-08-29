require "ISUI/ISPanel"
require "ISUI/ISButton"

local safehouseUI = nil;

local function chatMsg(text)
    if not ISChat or not ISChat.instance then return end
    local mock = {
        getTextWithPrefix = function() return "<RGB:1,1,1>" .. text end,
        getAuthor         = function() return nil end,
    }
    ISChat.addLineInChat(mock, 0)
end

FactionsGUI = ISPanel:derive("FactionsGUI");
FactionsGUI.minimized = true;
FactionsGUI.points = 0;
FactionsGUI.internal = "";

-- Creating the panel the right side of GUI

local panel = ISPanel:derive("FactionsGUIPanel");

function panel:onMouseDown(x, y) -- Overwrite moving
	self.moving = true;
end

function panel:onMouseUp(x, y) -- Overwrite moving
	self.moving = false;
end

function panel:onMouseMoveOutside(dx, dy) -- Overwrite moving
	self.moving = false;
end

-- Creating the badge on the left side of the GUI

Badge = ISPanel:derive("FactionsGUIBadge");

function Badge:initialise() -- Initialization Method
	ISPanel.initialise(self);
end

function Badge:update() -- Updates every ticks
end

function Badge:prerender() -- Before updating the screen render
end

function Badge:render() -- Draw the badge flag texture based on safehouse ownership
	local tex
	if self.team == nil then
		tex = self.freeTex  -- empty safehouse
	elseif self.team then
		tex = self.blueTex  -- your faction
	else
		tex = self.redTex   -- enemy faction
	end
	if tex then
		self:drawTextureScaled(tex, 0, 0, self.width, self.height, self.alpha)
	end
end

function Badge:onMouseMove(dx, dy) -- Overwrite moving
	if self.alpha == 0.75 and FactionsGUI.minimized then
		self.alpha = 1.0;
	end
end

function Badge:onMouseMoveOutside(dx, dy) -- Overwrite moving
	if self.alpha == 1.0 and FactionsGUI.minimized then
		self.alpha = 0.75;
	end
end

function Badge:onMouseUp() -- Overwrite moving
	if FactionsGUI.minimized then
		FactionsGUI.minimized = false;
		self.alpha = 1.0;
	else
		FactionsGUI.minimized = true;
		self:onMouseMove();
	end
end

function Badge:new(x, y) -- Instanciation the Badgez
	-- Getting the Badge image
	local defaultBadge = getTexture("media/ui/flag.png");
	-- Instanciating the panel badge
	local o = ISPanel:new(0, 0, defaultBadge:getWidth(), defaultBadge:getHeight());
	setmetatable(o, self)
	self.__index = self

	-- Setting the Sizee and Position
	o.width = defaultBadge:getWidth();
	o.height = defaultBadge:getHeight();
	o.x = x;
	o.y = y;

	-- Setting the Colors
	o.borderColor = { r = 0, g = 0, b = 0, a = 0 };
	o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 };

	-- Anchoring the Badge
	o.anchorLeft = true;
	o.anchorRight = false;
	o.anchorTop = false;
	o.anchorBottom = true;

	-- Default Textures for Badge (free=empty, blue=friendly, red=enemy)
	o.freeTex = defaultBadge;
	o.blueTex = getTexture("media/ui/blue/fade4.png");
	o.redTex  = getTexture("media/ui/red/fade4.png");
	o.team    = nil; -- nil=empty, true=friendly, false=enemy
	o.noBackground = true;

	-- Default Opacity
	o.alpha = 1.0;
	-- If is minimized changes the opacity to lower
	if FactionsGUI.minimized then
		o.alpha = 0.75;
	end

	return o
end

-- Now we are creating the main GUI

function FactionsGUI:initialise() -- UI initialization
	ISPanel.initialise(self);
end

function FactionsGUI:minimize() -- UI minimize overwrite
	self.panel:setVisible(false);
	self.backgroundColor.a = 0;
	self.borderColor.a = 0;
end

function FactionsGUI:update() -- UI every tick overwrite
	-- Check if player exist, fix for UI errors in respawn
	if not self.player then
		self.player = getPlayer();
		-- Disable UI
		UnloadUI()
		return
	end

	-- Minimization check
	if FactionsGUI.minimized and self.panel:getIsVisible() then          -- check the variable is set to be minimized
		self:minimize();
	elseif not FactionsGUI.minimized and not self.panel:getIsVisible() then -- otherwises show up again
		self.panel:setVisible(true);
		self.borderColor.a = 0.1;
		self.panel.backgroundColor.a = 0;
		self:onMouseMove();
	end

	self:updateButtons();
end

function FactionsGUI:updateButtons() -- Update dynamically the buttons based in self parameters
	local faction = Faction.getPlayerFaction(getPlayer())

	-- Reload the entire GUI if faction status changed (e.g. player just created/left a faction)
	if faction ~= self.faction then
		UnloadUI()
		return
	end

	local safehouse = SafeHouse.getSafeHouse(self.player:getSquare());

	-- Reload if safehouse presence changed (e.g. just claimed or someone else claimed)
	if safehouse ~= self.safehouse then
		UnloadUI()
		return
	end

	if not faction then
		self.button:setEnable(false);
		self.button:setTooltip(getText("UI_Text_SafehouseWithoutFaction"))
		FactionsGUI.internal = "";
		return;
	end

	if safehouse then
		if safehouse:playerAllowed(self.player) then
			FactionsGUI.internal = "View";
			self.button:setEnable(true);
			return;
		else
			self.button:setEnable(false);
			FactionsGUI.internal = "";
			return;
		end
	end

	local safehouseUnavailableReason = SafeHouse.canBeSafehouse(self.player:getSquare(), self.player);
	if safehouseUnavailableReason ~= "" then
		-- Faction members can claim multiple safehouses (server enforces points limit),
		-- so strip the vanilla "already have a safehouse" line from the reason for them.
		local faction = GetPlayerFaction(self.player:getUsername())
		if faction then
			local alreadyHave = getText("IGUI_Safehouse_AlreadyHaveSafehouse")
			safehouseUnavailableReason = safehouseUnavailableReason:gsub(alreadyHave .. "\n", "")
			safehouseUnavailableReason = safehouseUnavailableReason:gsub(alreadyHave, "")
		end
		if safehouseUnavailableReason:gsub("%s", "") ~= "" then
			self.button:setEnable(false);
			self.button:setTooltip(safehouseUnavailableReason);
			FactionsGUI.internal = "Capture_Spawn";
			return;
		end
	end

	self.someoneInside = IsSomeoneInside(self.player:getSquare(), self.faction, self.floors);

	local playerFaction = GetPlayerFaction(self.player:getUsername())
	local usedPoints = playerFaction and GetFactionUsedPoints(playerFaction) or 0
	local available = FactionsGUI.points - usedPoints
	local pointsEnough = tonumber(available) >= tonumber(self.price);

	if self.someoneInside then
		self.button:setEnable(false);
		self.button:setTooltip(getText("IGUI_Safehouse_SomeoneInside"));
		FactionsGUI.internal = "";
		return;
	elseif pointsEnough then
		self.button:setEnable(true);
		self.button:setTooltip(getText("UI_Text_SafehousePointsAvailable", self.price, available));
		FactionsGUI.internal = "Capture_Empty";
		return;
	else
		self.button:setEnable(false);
		self.button:setTooltip(getText("UI_Text_SafehouseNotEnoughPoints", available, self.price))
		FactionsGUI.internal = "";
		return;
	end
end

function FactionsGUI:createChildren() -- Overwrite the children creation method
	-- Creating the badge
	local badge = Badge:new(18, 18);
	-- Initializing the badge
	badge:initialise();
	-- Adding it to the Game GUI
	self:addChild(badge);
	self.badge = badge;
	self.badge.team = self.team;

	local offset = (badge:getX() * 2) + badge:getWidth();

	-- Setting the panel size and colors
	self.panel = panel:new(offset, 0, self.width - offset, self.height);
	self.panel.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 };
	self.panel.borderColor = { r = 1, g = 1, b = 1, a = 0.0 };
	-- Initializing the panel
	self.panel:initialise();
	-- Adding it to the Game GUI
	self:addChild(self.panel);

	-- Setting the Size of texts
	local width_title = getTextManager():MeasureStringX(UIFont.NewLarge, self.titleText);
	local height_title = getTextManager():MeasureFont(UIFont.NewLarge);

	local width_faction = getTextManager():MeasureStringX(UIFont.NewMedium, self.factionText);
	local height_faction = getTextManager():MeasureFont(UIFont.NewMedium);

	local width_button = getTextManager():MeasureStringX(UIFont.NewMedium, self.buttonText);
	local height_button = getTextManager():MeasureFont(UIFont.NewMedium);

	-- Creating the Title Text
	local titleLabel = FactionsGUILabel:new((self.panel.width / 2) - (width_title / 2) - 1.5, 18 - 2, width_title,
		height_title,
		self.titleText, 1.0, 1.0, 1.0, 1.0, UIFont.NewLarge)
	-- Initializing
	titleLabel:initialise()
	-- Adding it to the Panel GUI
	self.panel:addChild(titleLabel);
	self.titleLabel = titleLabel;

	-- Creating the Faction Text
	local factionLabel = FactionsGUILabel:new((self.panel.width / 2) - (width_faction / 2) - 1.5, 18 + height_title,
		width_faction, height_faction, self.factionText, 1.0, 1.0, 1.0, 1.0, UIFont.NewMedium)
	-- Initializing
	factionLabel:initialise()
	-- Adding it to the Panel GUI
	self.panel:addChild(factionLabel);
	self.factionLabel = factionLabel;

	-- Creating the Capture Button
	local button = ISButton:new((self.panel.width / 2) - (width_button / 2) - 1.5, self.height - 10 - height_button,
		width_button, height_button, self.buttonText, self, FactionsGUI.onButtonClick)
	-- Initializing the button
	button:initialise()
	-- Adding it to the Panel GUI
	self.panel:addChild(button);
	self.button = button;
	self.button.internal = "";
	-- Update visibility based in the button data
	self.button:setVisible(self.buttonVisible);

	-- Getting the price of the house the player is standing
	local playerBuilding = self.player:getBuilding()
	self.price = GetSafehouseCost(playerBuilding);

	-- If the price is lower than one, set to one
	if self.price < 1 then
		self.price = 1;
	end

	-- Offset for making parent borders visible
	self.panel.y = 2;
	self.panel.width = self.panel:getWidth() - 2;
	self.panel.height = self.panel:getHeight() - 4;

	-- Check if is minimized so the function for minimization is called
	if FactionsGUI.minimized then
		self:minimize();
	end

	self:onMouseMoveOutside();
	self:updateButtons();
end

function FactionsGUI.onButtonClick() -- On the button click
	local internal = FactionsGUI.internal;
	if internal == "View" then       -- View the safehouse button
		if safehouseUI then
			safehouseUI:removeFromUIManager()
		end

		local safehouse = SafeHouse.getSafeHouse(getPlayer():getSquare());
		safehouseUI = ISSafehouseUI:new(getCore():getScreenWidth() / 2 - 250, getCore():getScreenHeight() / 2 - 225, 500,
			450, safehouse, getPlayer());
		safehouseUI:initialise()
		safehouseUI:addToUIManager()
	elseif internal == "Capture_Empty" then -- Capture Residential button
		-- IMPORTANT
		-- You cannot do that on the server side FOR SOME ABNORMOUS REASON
		sendSafehouseClaim(getPlayer():getSquare(), getPlayer(), getPlayer():getUsername());

		-- Ask the server if is valid capturing the safehouse
		sendClientCommand("Factions", "claimSafehouseResponse", nil);
	end
end

function FactionsGUI:onMouseMove(dx, dy) -- Overwrite Mouse
	if self.panel.backgroundColor.a ~= 0.5 and not FactionsGUI.minimized then
		self.backgroundColor.a = 0.4;
		self.panel.backgroundColor.a = 0.5;
		self.titleLabel.a = 1.0;
		self.factionLabel.a = 1.0;
		self.button:setVisible(self.buttonVisible);
	end
	if self.dragging == false then return end
	self.mouseOver = true;
	if self.moving or self.panel.moving then
		self:setX(self.x + dx);
		self:setY(self.y + dy);
	end
end

function FactionsGUI:onMouseMoveOutside(dx, dy) -- Overwrite Mouse
	if self.panel.backgroundColor.a ~= 0.1 and not FactionsGUI.minimized then
		self.backgroundColor.a = 0.2;
		self.panel.backgroundColor.a = 0.1;
		self.titleLabel.a = 0.5;
		self.factionLabel.a = 0.5;
		self.button:setVisible(false);
	end
	if self.dragging == false then return end
	if not self:getIsVisible() then return end
	self.moving = false;
	ISMouseDrag.dragView = nil;
end

function FactionsGUI:onMouseUp(x, y) -- Overwrite Mouse
	if self.dragging == false then return end
	if not self:getIsVisible() then return end
	self.moving = false;
	if ISMouseDrag.tabPanel then
		ISMouseDrag.tabPanel:onMouseUp(x, y);
	end
	ISMouseDrag.dragView = nil;
end

function FactionsGUI:onMouseDown(x, y) -- Overwrite Mouse
	if self.dragging == false then return end
	if not self:getIsVisible() then return end
	self.downX = x;
	self.downY = y;
	self.moving = true;
end

function FactionsGUI:RestoreLayout(name, layout) -- Overwrite Layout
	ISLayoutManager.DefaultRestoreWindow(self, layout)
end

function FactionsGUI:SaveLayout(name, layout) -- Overwrite Layout Save
	ISLayoutManager.DefaultSaveWindow(self, layout)
end

function FactionsGUI:new(titleText, factionText, buttonText, faction, team) -- Instanciate the FactionsGUI
	-- Creating the object to save the GUI
	local o = {}

	-- Instanciate the Panel
	o = ISPanel:new(0, 0, 0, 0);
	setmetatable(o, self)
	self.__index = self

	-- Instanciating the Size and Position
	o.height = 100;                             -- Size
	o.width = 400;                              -- Size
	o.x = 30;                                   -- Position
	o.y = (getCore():getScreenHeight() - 64 - 65); -- Position

	-- The GUI Color
	o.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.2 };
	o.borderColor = { r = 1, g = 1, b = 1, a = 0.1 };

	-- Default Titles
	o.titleText = titleText or getText("UI_Text_SafehouseEmpty");
	o.factionText = factionText or "";

	-- The player Entity
	local player = getPlayer()      -- Getting entity
	o.player = player;              -- Adding the entity player
	o.username = player:getUsername(); -- Player Username

	-- Adding the player faction to the gui parameter
	o.faction = faction;
	o.team = team; -- nil=empty safehouse, true=friendly, false=enemy

	-- Instanciate Variables
	local square = player:getSquare();
	if o.faction then
		o.owner = o.faction:getOwner();
		o.floors = GetFloorCount(player:getBuilding())
		o.someoneInside = IsSomeoneInside(square, o.faction, o.floors);
	end

	-- Button default text
	o.buttonText = buttonText or getText("UI_Text_SafehouseClaim");
	-- Default button visibility
	o.buttonVisible = true;

	-- Get the player safehouse by position
	o.safehouse = SafeHouse.getSafeHouse(square)

	-- Setting the default variables
	o.timer = FactionsGUI.updateTime;
	o.buttonVisible = true;
	o.timestamp = getTimeInMillis();
	o.dragging = true;
	o.internal = "";

	return o
end

local function OnServerCommand(module, command, arguments)
	if module == "Factions" and command == "claimSafehouseResponse" then
		local result = arguments[1]

		if result == "Success" then
			UnloadUI()
		elseif result == "Not enough points" then
			chatMsg(getText("UI_Text_SafehouseNoPoints"))
		elseif result == "Safehouse already claimed" then
			chatMsg(getText("UI_Text_SafehouseEmpty"))
		end
	elseif module == "Factions" and command == "receivePoints" then
		local result = arguments[1]

		FactionsGUI.points = result
	end
end

Events.OnServerCommand.Add(OnServerCommand)
