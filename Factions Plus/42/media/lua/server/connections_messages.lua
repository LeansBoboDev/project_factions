if isClient() and not FactionsIsSinglePlayer then return end;

local ticksToDetectPlayers = getSandboxOptions():getOptionByName("FactionsPlus.MessagesCheckPerTick"):getValue();
local actualTicks = 0;

local function sendMessageToAllPlayers(message, _playerUsername)
    local onlinePlayers = getOnlinePlayers();

    -- Swiping all online players
    for i = 0, onlinePlayers:size() - 1 do
        local selectedPlayer = onlinePlayers:get(i);
        sendServerCommand(selectedPlayer, "ConnectionMessages", message, { playerUsername = _playerUsername });
    end

    if message == "playerconnected" then
        DebugPrintFactionsPlus(_playerUsername .. " connected");
    elseif message == "playerdisconnected" then
        DebugPrintFactionsPlus(_playerUsername .. " disconnected");
    elseif message == "playerdied" then
        DebugPrintFactionsPlus(_playerUsername .. " dead");
    end
end

-- Death message
if getSandboxOptions():getOptionByName("FactionsPlus.EnablePlayerDeathMessages"):getValue() then
    local function OnPlayerDeath(player) sendMessageToAllPlayers("playerdead", player) end

    Events.OnPlayerDeath.Add(OnPlayerDeath);
end

-- Stores any old online players, is a List<string> with the username
local previousOnlinePlayers = {};
local lastTimeSeconds = 0;

-- Player message handler
if getSandboxOptions():getOptionByName("FactionsPlus.EnablePlayerJoinMessages"):getValue() or getSandboxOptions():getOptionByName("FactionsPlus.EnablePlayerLeaveMessages"):getValue() then
    Events.OnTick.Add(function()
        -- Tickrate detection
        if actualTicks < ticksToDetectPlayers then
            actualTicks = actualTicks + 1;
            return;
        end
        actualTicks = 0;

        -- Check if server was freeze (no players)
        local actualTime = getTimestamp() + 0 * 3600;
        if actualTime > lastTimeSeconds + 15 then
            DebugPrintFactionsPlus("server was freezed, resetting variables");
            -- Resetting players
            previousOnlinePlayers = {}
        end

        -- Getting online players
        local onlinePlayers = getOnlinePlayers();

        -- Detecting disconnected players
        -- Iterating over previousOnlinePlayers
        for i = 1, #previousOnlinePlayers do
            local selectedPreviousPlayer = previousOnlinePlayers[i];
            local isDisconnected = true;
            -- Iterating over onlinePlayers
            for j = 0, onlinePlayers:size() - 1 do
                local selectedPlayer = onlinePlayers:get(j);
                -- Checking if player is still online
                if selectedPlayer:getUsername() == selectedPreviousPlayer then
                    isDisconnected = false;
                    break;
                end
            end
            -- Checking if player disconnected
            if isDisconnected then
                -- Sending a message to all players about the disconnected player
                if getSandboxOptions():getOptionByName("FactionsPlus.EnablePlayerLeaveMessages"):getValue() then
                    sendMessageToAllPlayers("playerdisconnected", selectedPreviousPlayer);
                end
                -- Removing the player from the previousOnlinePlayers table
                table.remove(previousOnlinePlayers, i);
                i = i - 1; -- Adjusting index due to table.remove
            end
        end

        -- Detecting new players
        -- Iterating over onlinePlayers
        for i = 0, onlinePlayers:size() - 1 do
            local selectedPlayer = onlinePlayers:get(i);
            local isNew = true;
            -- Iterating over previousOnlinePlayers
            for j = 1, #previousOnlinePlayers do
                local selectedPreviousPlayer = previousOnlinePlayers[j];
                -- Checking if the previous player is already added
                if selectedPlayer:getUsername() == selectedPreviousPlayer then
                    isNew = false;
                    break;
                end
            end
            -- Checking if the player is new
            if isNew then
                -- Adding it to the previous players
                table.insert(previousOnlinePlayers, selectedPlayer:getUsername());
                -- Sending a message to all players about the new connected player
                if getSandboxOptions():getOptionByName("FactionsPlus.EnablePlayerJoinMessages"):getValue() then
                    sendMessageToAllPlayers("playerconnected", selectedPlayer:getUsername());
                end
            end
        end

        -- Adding actual seconds on the lastTimeSeconds
        lastTimeSeconds = getTimestamp() + 0 * 3600;
    end)
end
