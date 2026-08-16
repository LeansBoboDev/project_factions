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

local _originalOnCommandEntered = ISChat.onCommandEntered

ISChat.onCommandEntered = function(self)
    local input = ISChat.instance.textEntry:getText()
    print("[SafehousePlus-DBG] onCommandEntered fired. input=" .. tostring(input))

    if input and luautils.stringStarts(input, "/") then
        local parts = {}
        for word in input:sub(2):gmatch("%S+") do
            table.insert(parts, word)
        end
        local cmd = parts[1] and parts[1]:lower()
        print("[SafehousePlus-DBG] cmd=" .. tostring(cmd))

        if cmd == "sethome" then
            if not getSandboxBool("SafehousePlus.EnableSetHome") then
                chatMsg(getText("IGUI_SafehousePlus_Disabled"))
                ISChat.instance.textEntry:setText("")
                ISChat.instance:unfocus()
                return
            end
            sendClientCommand("SafehousePlus", "setHome", {})
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
            sendClientCommand("SafehousePlus", "goHome", {})
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

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "SafehousePlus" then return end

    if command == "message" then
        chatMsg(args.text or "")

    elseif command == "teleport" then
        local player = getPlayer()
        if player then
            player:setX(args.x)
            player:setY(args.y)
            player:setZ(args.z or 0)
        end
        if args.text and args.text ~= "" then
            chatMsg(args.text)
        end
    end
end)
