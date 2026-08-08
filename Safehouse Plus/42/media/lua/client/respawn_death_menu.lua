local enableRespawnOption = getSandboxOptions():getOptionByName("SafehousePlus.EnableRespawnMechanic")
if not enableRespawnOption or not enableRespawnOption:getValue() then return end

-- Default Functions
local CoopMapSpawnSelect_clickNext = CoopMapSpawnSelect.clickNext;
local ISPostDeathUI_render = ISPostDeathUI.render;
local ISPostDeathUI_onRespawn = ISPostDeathUI.onRespawn;

-- Spam server check
local alreadyChecked = false;

function ISPostDeathUI:render(...)
    local cooldownOption = getSandboxOptions():getOptionByName("SafehousePlus.RespawnCooldown")
    local seconds = (self.timeOfDeath + (cooldownOption and cooldownOption:getValue() or 0) + 4) -
        getTimestamp();
    self.buttonQuit:setTitle(getText("IGUI_Respawn_DeathUI_Respawn") .. ((seconds > 0) and (" " .. seconds .. "") or ""));
    self.buttonQuit:setEnable(seconds <= 0);
    ISPostDeathUI_render(self, ...);

    -- Save player for later
    self.player = getSpecificPlayer(self.playerIndex);
    -- Ask the server if hes can spawn in the bed
    if (seconds <= 5 and not alreadyChecked) then
        alreadyChecked = true;
        -- Disabled for now, need to rework factions first
        -- local coords = getPlayerRespawn(self.player);
        -- sendClientCommand("ServerRespawn", "canSpawn", {
        --     x = coords.x,
        --     y = coords.y,
        --     z = coords.z,
        -- });
    end
end

-- This is a button "NEW CHARACTER" on death screen
function ISPostDeathUI:onRespawn(...)
    alreadyChecked = false;
    self.buttonQuit.AutoRespawn = true;
    ISPostDeathUI_onRespawn(self, ...);
end

-- Bypass CoopCharacterCreation entirely and respawn directly.
-- region: { name, region = { points = { unemployed = { {posX,posY,posZ} } } } } or nil (skip teleport)
local function bypassCharacterCreation(CCC, playerIndex, region)
    -- Tell server the spawn location so loadRespawnLocation can teleport there
    if region then
        sendClientCommand("SafehousePlusRespawn", "setRespawnRegion", region);
    end

    -- Remove CCC UI and restore game UI
    CCC:removeFromUIManager();
    CoopCharacterCreation.setVisibleAllUI(true);
    CoopCharacterCreation.instance = nil;

    if ISPostDeathUI.instance[playerIndex] then
        ISPostDeathUI.instance[playerIndex]:removeFromUIManager();
        ISPostDeathUI.instance[playerIndex] = nil;
    end

    if not CCC.joypadData then
        setPlayerMouse(nil);
    else
        local controller = CCC.joypadData.controller;
        local joypadData = JoypadState.joypads[playerIndex + 1];
        JoypadState.players[playerIndex + 1] = joypadData;
        joypadData.player = playerIndex;
        joypadData:setController(controller);
        joypadData:setActive(true);
        local username = (isClient() and playerIndex > 0) and CoopUserName.instance:getUserName() or nil;
        setPlayerJoypad(playerIndex, CCC.joypadIndex, nil, username);
        CCC.joypadData.focus = nil;
        CCC.joypadData.lastfocus = nil;
        CCC.joypadData.prevfocus = nil;
        CCC.joypadData.prevprevfocus = nil;
    end

    local function receiveRespawnStats(module, command, arguments)
        if module == "SafehousePlusRespawn" and command == "receiveRespawnStats" then
            Events.OnServerCommand.Remove(receiveRespawnStats);
            if not arguments then return end;
            DebugPrintSafehousePlus("[Respawn] receiveRespawnStats received on client");
            UnsafeLocallyUpdate(arguments);
        end
    end
    Events.OnServerCommand.Add(receiveRespawnStats);
    SafehousePlusPendingLoad = true;
    DebugPrintSafehousePlus("[Respawn] Bypassed character creation, awaiting player spawn...");
end

-- Returns the native PZ safehouse spawn region if the player has one configured, else nil.
local function getNativeSafehouseRegion()
    if not isClient() then return nil end
    if not getServerOptions():getBoolean("SafehouseAllowRespawn") then return nil end
    local username = getClientUsername()
    for i = 0, SafeHouse.getSafehouseList():size() - 1 do
        local safe = SafeHouse.getSafehouseList():get(i)
        if safe:isRespawnInSafehouse(username) and
           (safe:getPlayers():contains(username) or safe:getOwner() == username) then
            return {
                name = getText("UI_mapspawn_Safehouse"),
                region = {
                    points = {
                        unemployed = {
                            { posX = safe:getX() + (safe:getH() / 2),
                              posY = safe:getY() + (safe:getW() / 2),
                              posZ = 0 }
                        }
                    }
                }
            }
        end
    end
    return nil
end

-- When "RESPAWN" button is clicked on death screen
function ISPostDeathUI:onQuitToDesktop(...)
    alreadyChecked = false;
    self.buttonQuit.AutoRespawn = true;
    ISPostDeathUI_onRespawn(self, ...);
    local CCC = CoopCharacterCreation.instance;
    if (not CCC) then return end;

    -- Rename "NEXT" button to "RESPAWN"
    CCC.mapSpawnSelect.nextButton:setTitle(getText("IGUI_Respawn_CCC_Respawn"));

    -- Native PZ "Respawn in Safehouse" — bypass character creation and go directly
    local safehouseRegion = getNativeSafehouseRegion()
    if safehouseRegion then
        DebugPrintSafehousePlus("[Respawn] Native safehouse respawn detected, bypassing character creation");
        bypassCharacterCreation(CCC, self.playerIndex, safehouseRegion);
        return;
    end

    -- Mod's own "EnableSafehouseRespawn" option (bed/custom respawn point)
    local respawnOption = getSandboxOptions():getOptionByName("SafehousePlus.EnableSafehouseRespawn")
    if respawnOption and respawnOption:getValue() then
        local function receiveRespawn(module, command, arguments)
            if module == "SafehousePlusRespawn" and command == "receiveRespawn" then
                Events.OnServerCommand.Remove(receiveRespawn);

                if not arguments then
                    return;
                end

                local coords = arguments;
                local isRespawn = (coords.x ~= nil) and (coords.y ~= nil) and (coords.z ~= nil);

                if isRespawn then
                    -- Create respawn points
                    local item = {
                        name = getText("IGUI_Respawn_Bed"),
                        region = nil,
                        dir = "",
                        worldimage = nil,
                        desc = getText("IGUI_Respawn_In_Bed")
                    }

                    -- Add respawn in bed as new option
                    CCC.mapSpawnSelect.listbox:insertItem(0, item.name, item);
                    -- Disable zoom for the spawn in bed
                    CCC.mapSpawnSelect.listbox.items[1].item.zoomS = 0;
                    -- Auto-select "Respawn in Bed" and skip the spawn selection screen
                    CCC.mapSpawnSelect.listbox.selected = 1;
                    CCC.mapSpawnSelect:clickNext();
                end;
            end
        end
        if SafehousePlusIsSinglePlayer then
            receiveRespawn("SafehousePlusRespawn", "receiveRespawn", GetPlayerRespawn(getPlayer()));
        else
            Events.OnServerCommand.Add(receiveRespawn);
        end
    end
end

-- This will run when "NEXT" ("RESPAWN") is pressed inside spawn selection
function CoopMapSpawnSelect:clickNext(...)
    alreadyChecked = false;
    --Check if it is custom spawn selection made by respawn
    if (not CoopCharacterCreation.instance) then return end;
    local title = self.nextButton:getTitle();
    if (title ~= getText("IGUI_Respawn_CCC_Respawn")) then return CoopMapSpawnSelect_clickNext(self, ...) end;
    local selected = self.listbox.items[self.listbox.selected].item;
    local self = CoopCharacterCreation.instance;

    -- Hide spawn selection screen
    self:removeFromUIManager();
    CoopCharacterCreation.setVisibleAllUI(true);
    CoopCharacterCreation.instance = nil;

    -- Hide death menu screen
    if (ISPostDeathUI.instance[self.playerIndex]) then
        ISPostDeathUI.instance[self.playerIndex]:removeFromUIManager();
        ISPostDeathUI.instance[self.playerIndex] = nil;
    end

    -- If selected respawn then update respawn location
    if (selected.name ~= getText("IGUI_Respawn_Bed")) then
        if SafehousePlusIsSinglePlayer then
            RemovePlayerRespawn(getPlayer());
            SetRespawnRegion(getPlayer(), selected.region);
        else
            sendClientCommand("SafehousePlusRespawn", "setRespawnRegion", selected);
        end
    end

    -- Spawn player for mouse & keyboard
    if (not self.joypadData) then
        setPlayerMouse(nil);
    else --Spawn player for controller
        local controller = self.joypadData.controller;
        local joypadData = JoypadState.joypads[self.playerIndex + 1];
        JoypadState.players[self.playerIndex + 1] = joypadData;
        joypadData.player = self.playerIndex;
        joypadData:setController(controller);
        joypadData:setActive(true);
        local username = nil;

        if (isClient() and self.playerIndex > 0) then
            username = CoopUserName.instance:getUserName();
        end

        setPlayerJoypad(self.playerIndex, self.joypadIndex, nil, username);

        self.joypadData.focus = nil;
        self.joypadData.lastfocus = nil;
        self.joypadData.prevfocus = nil;
        self.joypadData.prevprevfocus = nil;
    end

    if SafehousePlusIsSinglePlayer then
        DebugPrintSafehousePlus("Loading player...");

        -- Load player data
        LoadPlayer(getPlayer());
        local healthOption = getSandboxOptions():getOptionByName("SafehousePlus.HealthOnRespawn")
        SetHealth(getPlayer(), healthOption and healthOption:getValue() or 1);

        -- Teleport player to respawn location
        if (selected.name == getText("IGUI_Respawn_Bed")) then
            LoadRespawnLocation(getPlayer());
        end

        -- Save player respawn location
        SetPlayerRespawn(getPlayer());
    else
        local function receiveRespawnStats(module, command, arguments)
            if module == "SafehousePlusRespawn" and command == "receiveRespawnStats" then
                Events.OnServerCommand.Remove(receiveRespawnStats);
                DebugPrintSafehousePlus("[Respawn] receiveRespawnStats received on client");

                if not arguments then
                    DebugPrintSafehousePlus("[Respawn] ERROR: receiveRespawnStats arguments is nil");
                    return;
                end

                DebugPrintSafehousePlus("[Respawn] Calling UnsafeLocallyUpdate...");
                UnsafeLocallyUpdate(arguments);
                DebugPrintSafehousePlus("[Respawn] UnsafeLocallyUpdate done");
            end
        end
        Events.OnServerCommand.Add(receiveRespawnStats);

        SafehousePlusPendingLoad = true;
        DebugPrintSafehousePlus("[Respawn] Pending load set, awaiting player spawn...");
    end
end

local function onCreatePlayer()
    DebugPrintSafehousePlus("[Respawn] OnCreatePlayer fired, registering spawn watcher");

    local function waitForSpawn()
        if not SafehousePlusPendingLoad then return end;
        if not getPlayer():isPlayerMoving() then return end;

        Events.OnPlayerUpdate.Remove(waitForSpawn);
        SafehousePlusPendingLoad = false;

        DebugPrintSafehousePlus("[Respawn] Player is moving, sending loadPlayer command to server");
        sendClientCommand("SafehousePlusRespawn", "loadPlayer", nil);
    end

    Events.OnPlayerUpdate.Add(waitForSpawn);
end

Events.OnCreatePlayer.Add(onCreatePlayer);
