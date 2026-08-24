if isClient() and not FactionsPlusIsSinglePlayer then return end

local MOTDCache = {}

local function createDefaultFile()
    local writer = getFileWriter("FP/motd.txt", true, false)
    writer:write("<VERSION: 1.0>\r\n")
    writer:write("Welcome\r\n")
    writer:write("<H1> Welcome to the server! <LINE> \r\n")
    writer:write("<SIZE:medium> Edit Zomboid/Lua/FP/motd.txt to customize this message. <LINE> \r\n")
    writer:write("<SIZE:medium> For Portuguese, create Zomboid/Lua/FP/motd_ptbr.txt <LINE> \r\n")
    writer:write("<SIZE:medium> Change the version tag on the first line to refresh the cache. <LINE> \r\n")
    writer:close()
    DebugPrintFactionsPlus("MOTD: created default FP/motd.txt")
end

local function parseFile(filePath)
    local reader = getFileReader(filePath, false)
    if not reader then return nil end

    local version = tostring(reader:readLine())

    if MOTDCache[filePath] and MOTDCache[filePath].version == version then
        reader:close()
        return MOTDCache[filePath]
    end

    local page = { title = {}, size = 1, version = version }

    local tabTitle = reader:readLine()
    page.title[1] = tabTitle and tostring(tabTitle) or "MOTD"

    local buffer = ""
    local line = reader:readLine()
    while line ~= nil do
        if line == "<PAGE>" then
            page[page.size] = buffer
            buffer = ""
            line = reader:readLine()
            if line ~= nil then
                page.size = page.size + 1
                page.title[page.size] = tostring(line)
                line = reader:readLine()
            end
        else
            buffer = buffer .. tostring(line) .. " <LINE> "
            line = reader:readLine()
        end
    end
    page[page.size] = buffer
    reader:close()

    MOTDCache[filePath] = page
    DebugPrintFactionsPlus("MOTD: parsed " .. filePath .. " (version " .. version .. ", " .. page.size .. " page(s))")
    return page
end

local function onClientCommand(module, command, player, args)
    if module ~= "FactionsMOTD" or command ~= "requestMOTD" then return end
    if not getSandboxOptions():getOptionByName("FactionsPlus.EnableMOTD"):getValue() then return end

    local language = tostring(args.language or "EN"):lower()
    DebugPrintFactionsPlus("MOTD: request from " .. tostring(player:getUsername()) .. " (lang=" .. language .. ")")

    -- try language-specific file first, fall back to default
    local page = parseFile("FP/motd_" .. language .. ".txt")
    if not page then
        local reader = getFileReader("FP/motd.txt", false)
        if not reader then
            createDefaultFile()
        else
            reader:close()
        end
        page = parseFile("FP/motd.txt")
    end

    if page then
        sendServerCommand(player, "FactionsMOTD", "receiveMOTD", page)
    end
end

Events.OnClientCommand.Add(onClientCommand)
