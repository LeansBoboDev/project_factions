local function getSandboxBool(name)
    local opt = getSandboxOptions():getOptionByName(name)
    return opt and opt:getValue()
end

local function chatMsg(text)
    local mock = {
        getTextWithPrefix = function() return "[SafehousePlus] " .. text end,
        getAuthor         = function() return nil end,
    }
    ISChat.addLineInChat(mock, 0)
end

-- Resolves a translation key sent from the server with getText()
local function resolveKey(key, p1, p2)
    if p2 ~= nil then return getText(key, p1, p2) end
    if p1 ~= nil then return getText(key, p1) end
    return getText(key)
end

-- ── Delayed teleport timed action ─────────────────────────────

local ISPendingTeleport = ISBaseTimedAction:derive("ISPendingTeleport")

function ISPendingTeleport:new(player, dest)
    local o         = ISBaseTimedAction.new(self, player)
    o.dest          = dest
    o.maxTime       = dest.delay * 60
    o.startTime     = os.time()
    o.stopOnWalk    = false
    o.stopOnRun     = false
    o.stopOnAim     = false
    return o
end

-- Cancel if the player moved or took damage
function ISPendingTeleport:isValid()
    if not self.lockX then return true end
    local dx = math.abs(self.character:getX() - self.lockX)
    local dy = math.abs(self.character:getY() - self.lockY)
    if dx > 1.0 or dy > 1.0 then return false end
    local bd = self.character:getBodyDamage()
    if bd and self.startHealth and bd:getHealth() < self.startHealth then return false end
    return true
end

function ISPendingTeleport:start()
    self.lockX       = self.character:getX()
    self.lockY       = self.character:getY()
    self.lockZ       = self.character:getZ()
    local bd = self.character:getBodyDamage()
    self.startHealth = bd and bd:getHealth() or nil
    chatMsg(getText("IGUI_SafehousePlus_TeleportPending", tostring(self.dest.delay)))
end

function ISPendingTeleport:perform()
    sendClientCommand("SafehousePlus", "confirmTeleport", {})
    local p = self.character
    p:setX(self.dest.x)
    p:setY(self.dest.y)
    p:setZ(self.dest.z or 0)
    local text = resolveKey(self.dest.key, self.dest.p1)
    if self.dest.cost and self.dest.cost > 0 then
        text = text .. getText("IGUI_SafehousePlus_CostSuffix", tostring(self.dest.cost))
    end
    chatMsg(text)
    ISBaseTimedAction.perform(self)
end

function ISPendingTeleport:stop()
    chatMsg(getText("IGUI_SafehousePlus_TeleportCancelled"))
end

-- ── Chat command intercept ────────────────────────────────────

local _originalOnCommandEntered = ISChat.onCommandEntered

ISChat.onCommandEntered = function(self)
    local input = ISChat.instance.textEntry:getText()

    if input and luautils.stringStarts(input, "/") then
        local parts = {}
        for word in input:sub(2):gmatch("%S+") do
            table.insert(parts, word)
        end
        local cmd = parts[1] and parts[1]:lower()

        if cmd == "sethome" then
            if not getSandboxBool("SafehousePlus.EnableSetHome") then
                chatMsg(getText("IGUI_SafehousePlus_Disabled"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            local name = parts[2]
            if not name then
                chatMsg(getText("IGUI_SafehousePlus_SetHomeUsage"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            sendClientCommand("SafehousePlus", "setHome", { name = name })
            ISChat.instance.textEntry:setText("")
            ISChat.instance:unfocus()
            return

        elseif cmd == "home" then
            if not getSandboxBool("SafehousePlus.EnableHome") then
                chatMsg(getText("IGUI_SafehousePlus_Disabled"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            local name = parts[2]
            if not name then
                chatMsg(getText("IGUI_SafehousePlus_HomeUsage"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            sendClientCommand("SafehousePlus", "goHome", { name = name })
            ISChat.instance.textEntry:setText("")
            ISChat.instance:unfocus()
            return

        elseif cmd == "homes" then
            if not getSandboxBool("SafehousePlus.EnableListHomes") then
                chatMsg(getText("IGUI_SafehousePlus_Disabled"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            sendClientCommand("SafehousePlus", "listHomes", {})
            ISChat.instance.textEntry:setText("")
            ISChat.instance:unfocus()
            return

        elseif cmd == "delhome" then
            if not getSandboxBool("SafehousePlus.EnableDelHome") then
                chatMsg(getText("IGUI_SafehousePlus_Disabled"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            local name = parts[2]
            if not name then
                chatMsg(getText("IGUI_SafehousePlus_DelHomeUsage"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            sendClientCommand("SafehousePlus", "delHome", { name = name })
            ISChat.instance.textEntry:setText("")
            ISChat.instance:unfocus()
            return

        elseif cmd == "buyhome" then
            if not getSandboxBool("SafehousePlus.EnableBuyHome") then
                chatMsg(getText("IGUI_SafehousePlus_Disabled"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            sendClientCommand("SafehousePlus", "buyHome", {})
            ISChat.instance.textEntry:setText("")
            ISChat.instance:unfocus()
            return

        elseif cmd == "tpa" then
            if not getSandboxBool("SafehousePlus.EnableTpa") then
                chatMsg(getText("IGUI_SafehousePlus_Disabled"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            local target = parts[2]
            if not target then
                chatMsg(getText("IGUI_SafehousePlus_TpaUsage"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            sendClientCommand("SafehousePlus", "tpa", { target = target })
            ISChat.instance.textEntry:setText("")
            ISChat.instance:unfocus()
            return

        elseif cmd == "tpaaccept" then
            if not getSandboxBool("SafehousePlus.EnableTpa") then
                chatMsg(getText("IGUI_SafehousePlus_Disabled"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            sendClientCommand("SafehousePlus", "tpaAccept", {})
            ISChat.instance.textEntry:setText("")
            ISChat.instance:unfocus()
            return
        end
    end

    _originalOnCommandEntered(self)
end

-- ── Server command handler ────────────────────────────────────

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "SafehousePlus" then return end

    if command == "message" then
        local text = resolveKey(args.key, args.p1, args.p2)
        if args.cost and args.cost > 0 then
            text = text .. getText("IGUI_SafehousePlus_CostSuffix", tostring(args.cost))
        end
        chatMsg(text)

    elseif command == "teleport" then
        local player = getPlayer()
        if player then
            player:setX(args.x)
            player:setY(args.y)
            player:setZ(args.z or 0)
        end
        if args.key then
            local text = resolveKey(args.key, args.p1)
            if args.cost and args.cost > 0 then
                text = text .. getText("IGUI_SafehousePlus_CostSuffix", tostring(args.cost))
            end
            chatMsg(text)
        end

    elseif command == "teleportPending" then
        local player = getPlayer()
        if player then
            ISTimedActionQueue.add(ISPendingTeleport:new(player, args))
        end

    elseif command == "homeList" then
        if args.count == 0 then
            chatMsg(getText("IGUI_SafehousePlus_NoHome"))
        else
            local names = {}
            for i = 1, args.count do
                table.insert(names, args.homes[i])
            end
            chatMsg(getText("IGUI_SafehousePlus_HomeList", tostring(args.count), table.concat(names, ", ")))
        end
    end
end)
