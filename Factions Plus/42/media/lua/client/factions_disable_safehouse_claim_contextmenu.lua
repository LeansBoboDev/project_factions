-- Removes the vanilla "Claim Safehouse" context-menu entry so players are
-- forced to use the faction badge UI instead. The entry is injected by Java
-- inside ISWorldObjectContextMenuLogic.createMenuEntries, so we can only strip
-- it after the fact by wrapping the top-level createMenu function.

local _orig_createMenu = ISWorldObjectContextMenu.createMenu

ISWorldObjectContextMenu.createMenu = function(player, worldobjects, x, y, test)
    local context = _orig_createMenu(player, worldobjects, x, y, test)
    if context then
        context:removeOptionByName(getText("ContextMenu_SafehouseClaim"))
    end
    return context
end
