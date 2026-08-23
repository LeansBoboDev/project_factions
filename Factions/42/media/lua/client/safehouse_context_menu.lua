-- Removes the vanilla "notAvailable" block on the Claim Safehouse context menu
-- for faction members. The Java code in ISWorldObjectContextMenuLogic marks the
-- option unavailable when the player already owns a safehouse. The server-side
-- java patch + OnSafehouseClaimed enforces the real limit (points), so the
-- client-side block just prevents the packet from being sent.
--
-- OnFillWorldObjectContextMenu won't work here because it only fires when
-- fetch.safehouseAllowInteract is true (inside an owned safehouse). Instead we
-- wrap createMenu so we can post-process after Java has built the full menu.

local CLAIM_OPTION = getText("ContextMenu_SafehouseClaim")
local ALREADY_HAVE = getText("IGUI_Safehouse_AlreadyHaveSafehouse")

local _createMenu = ISWorldObjectContextMenu.createMenu
ISWorldObjectContextMenu.createMenu = function(player, worldobjects, x, y, test)
    local context = _createMenu(player, worldobjects, x, y, test)

    -- createMenu can return true (early-exit from Java) or a boolean from test mode
    if not context or not context.getOptionFromName then
        return context
    end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return context end

    local faction = GetPlayerFaction(playerObj:getUsername())
    print("[Factions-SCM] player=" .. tostring(playerObj:getUsername()) .. " faction=" .. tostring(faction and faction:getName() or "nil"))

    local option = context:getOptionFromName(CLAIM_OPTION)
    print("[Factions-SCM] option=" .. tostring(option ~= nil) .. " notAvailable=" .. tostring(option and option.notAvailable or "N/A"))

    if option and option.notAvailable then
        local desc = (option.toolTip and option.toolTip.description) or ""
        print("[Factions-SCM] desc=" .. tostring(desc))
        if faction and desc:find(ALREADY_HAVE, 1, true) then
            print("[Factions-SCM] clearing notAvailable")
            option.notAvailable = false
            option.toolTip = nil
        end
    end

    return context
end
