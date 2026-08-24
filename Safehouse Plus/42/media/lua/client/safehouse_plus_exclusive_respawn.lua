-- With multiple safehouses (Factions mod), the vanilla respawn tickbox has no exclusivity:
-- a player can enable "Respawn in Safehouse" on every safehouse simultaneously, which
-- causes getNativeSafehouseRegion() to pick the first match arbitrarily.
-- This patch enforces exclusive selection: enabling respawn on one safehouse
-- automatically disables it on all others the player belongs to.

local _orig_onClickRespawn = ISSafehouseUI.onClickRespawn

function ISSafehouseUI:onClickRespawn(clickedOption, enabled)
    if enabled then
        local username = self.player:getUsername()
        for i = 0, SafeHouse.getSafehouseList():size() - 1 do
            local safe = SafeHouse.getSafehouseList():get(i)
            if safe ~= self.safehouse and safe:isRespawnInSafehouse(username) then
                sendSafehouseChangeRespawn(safe, username, false)
            end
        end
    end
    _orig_onClickRespawn(self, clickedOption, enabled)
end
