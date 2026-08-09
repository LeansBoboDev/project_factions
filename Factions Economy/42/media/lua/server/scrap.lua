-- ============================================================
-- Scrap Recipes — Server Side
-- ============================================================

if isClient() and not FactionsEconomyIsSinglePlayer then return end;

FactionsEconomyScrapRecipe = FactionsEconomyScrapRecipe or {}

FactionsEconomyScrapRecipe.ScrapWeapon = function(craftRecipeData, player)
    print("[ScrapWeapon] OnCreate fired for " .. player:getUsername())

    local consumedItems = craftRecipeData:getAllConsumedItems()
    print("[ScrapWeapon] consumed items count: " .. tostring(consumedItems:size()))

    for i = 0, consumedItems:size() - 1 do
        local weapon = consumedItems:get(i)
        print("[ScrapWeapon] item[" .. i .. "] type=" .. tostring(weapon:getType()) .. " isWeapon=" .. tostring(instanceof(weapon, "HandWeapon")))

        if instanceof(weapon, "HandWeapon") then
            local inventory = player:getInventory()
            local ammoCount = weapon:getCurrentAmmoCount()
            local containsClip = weapon:isContainsClip()
            local magType = weapon:getMagazineType()
            local ammoType = weapon:getAmmoType()

            print(string.format("[ScrapWeapon] weapon=%s ammoCount=%s containsClip=%s magType=%s ammoType=%s",
                weapon:getType(),
                tostring(ammoCount),
                tostring(containsClip),
                tostring(magType),
                tostring(ammoType)))

            -- Weapon has a removable magazine: return it with its ammo intact
            if containsClip then
                print("[ScrapWeapon] has clip — attempting to return magazine")
                if magType then
                    local mag = instanceItem(magType)
                    print("[ScrapWeapon] instanceItem(" .. magType .. ") = " .. tostring(mag))
                    if mag then
                        mag:setCurrentAmmoCount(ammoCount)
                        inventory:AddItem(mag)
                        sendAddItemToContainer(inventory, mag)
                        print(string.format("[ScrapWeapon] returned magazine %s with %d rounds", magType, ammoCount))
                    end
                else
                    print("[ScrapWeapon] magType is nil, cannot return magazine")
                end
            else
                -- No removable magazine (revolver, internal tube, etc): eject loose ammo
                print("[ScrapWeapon] no clip — attempting to eject loose ammo, count=" .. tostring(ammoCount))
                if ammoCount and ammoCount > 0 then
                    if ammoType then
                        local ammoKey = ammoType.getItemKey and ammoType:getItemKey() or tostring(ammoType)
                        print("[ScrapWeapon] ammoKey=" .. tostring(ammoKey))
                        for _ = 1, ammoCount do
                            local bullet = instanceItem(ammoKey)
                            if bullet then
                                inventory:AddItem(bullet)
                                sendAddItemToContainer(inventory, bullet)
                            end
                        end
                        print(string.format("[ScrapWeapon] returned %d x %s", ammoCount, ammoKey))
                    else
                        print("[ScrapWeapon] ammoType is nil, cannot eject bullets")
                    end
                else
                    print("[ScrapWeapon] weapon is empty, nothing to eject")
                end
            end

            -- Return all attached upgrades/parts
            local parts = weapon:getDetachableWeaponParts(player)
            print("[ScrapWeapon] getDetachableWeaponParts() = " .. tostring(parts))
            if parts then
                print("[ScrapWeapon] parts count: " .. tostring(parts:size()))
                for j = 0, parts:size() - 1 do
                    local part = parts:get(j)
                    print("[ScrapWeapon] part[" .. j .. "] = " .. tostring(part))
                    if part then
                        weapon:detachWeaponPart(player, part)
                        inventory:AddItem(part)
                        sendAddItemToContainer(inventory, part)
                        print("[ScrapWeapon] returned part " .. tostring(part:getType()))
                    end
                end
            end
        end
    end

    print("[ScrapWeapon] done")
end