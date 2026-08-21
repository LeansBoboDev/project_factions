require "ISUI/ISPanel"
require "ISUI/ISButton"

local safehouseUI = nil;

FactionsGUI = ISPanel:derive("FactionsGUI");
FactionsGUI.minimized = true;

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

	-- Default Textures for Badge
	o.freeTex = defaultBadge;
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
	if not faction then
		self.button:setEnable(false);
		self.button:setTooltip(getText("UI_Text_SafehouseWithoutFaction"))
		self.internal = "";
		return;
	end

	local safehouse = SafeHouse.getSafeHouse(self.player:getSquare());
	if safehouse then
		if safehouse:playerAllowed(self.player) then
			self.internal = "View";
			self.button:setEnable(true);
			return;
		else
			self.button:setEnable(false);
			self.internal = "";
			return;
		end
	end

	local safehouseUnavailableReason = SafeHouse.canBeSafehouse(self.player:getSquare(), self.player);
	if safehouseUnavailableReason ~= "" then
		self.button:setEnable(false);
		self.button:setTooltip(safehouseUnavailableReason);
		self.internal = "Capture_Spawn";
		return;
	end

	-- Update the self someone inside
	self.someoneInside = IsSomeoneInside(self.player:getSquare(), self.faction, self.floors);

	-- Get available points
	local available = FactionsGUI.points -
		GetFactionUsedPoints(GetPlayerFaction(self.player:getUsername()));
	local pointsEnough = tonumber(available) >= tonumber(self.price);
	-- Check if someone is inside and is enabled
	if self.someoneInside then
		-- Set to false, because someone is inside and you cannot capture a safehouse with someone inside... dummy
		self.button:setEnable(false);
		self.button:setTooltip(getText("IGUI_Safehouse_SomeoneInside"));
		self.internal = "";
		return;
	elseif pointsEnough then -- Check if have points enough for capturing
		self.button:setEnable(true);
		self.button:setTooltip(getText("UI_Text_SafehousePointsAvailable", self.price, available));
		self.internal = "Capture_Empty";
		return;
	else -- Not enough points
		self.button:setEnable(false);
		self.button:setTooltip(getText("UI_Text_SafehouseNotEnoughPoints", available, self.price))
		self.internal = "";
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
	self.price = GetSafehouseCost(self.player:getBuilding());

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

function FactionsGUI:new(titleText, factionText, buttonText, faction) -- Instanciate the FactionsGUI
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
			getPlayer():Say(getText("UI_Text_SafehouseNoPoints"))
		elseif result == "Safehouse already claimed" then
			getPlayer():Say(getText("UI_Text_SafehouseEmpty"))
		end
	elseif module == "Factions" and command == "receivePoints" then
		local result = arguments[1]

		FactionsGUI.points = result
	end
end

Events.OnServerCommand.Add(OnServerCommand)
