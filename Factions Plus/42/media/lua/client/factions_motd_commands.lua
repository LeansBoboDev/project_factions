if FactionsPlusIsSinglePlayer then return end

local motdPanel = nil

local function showMOTD(pageData)
    if motdPanel == nil then
        motdPanel = FactionsMOTDPanel:new()
        motdPanel:initialise()
        motdPanel:addToUIManager()
    end
    motdPanel:loadData(pageData)
    motdPanel:setVisible(true)
    motdPanel:bringToTop()
end

local function onServerCommand(module, command, args)
    if module == "FactionsMOTD" and command == "receiveMOTD" then
        showMOTD(args)
    end
end
Events.OnServerCommand.Add(onServerCommand)

-- Intercept /motd before it reaches the server chat handler
local origOnCommandEntered = ISChat.onCommandEntered
ISChat.onCommandEntered = function(self)
    local input = ISChat.instance.textEntry:getText()
    if input == "/motd" then
        local language = tostring(Translator.getLanguage())
        sendClientCommand(getPlayer(), "FactionsMOTD", "requestMOTD", { language = language })
        ISChat.instance.textEntry:setText("")
        ISChat.instance:unfocus()
        return
    end
    origOnCommandEntered(self)
end
