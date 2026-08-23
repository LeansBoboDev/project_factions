-- Vehicle Claim View — detailed panel for a single claimed vehicle.
-- Shows owner, member list, and lets the owner add/remove members or unclaim.

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6

local function vehicleDisplayName(storedName)
    if not storedName then return "Vehicle" end
    local key = storedName:match("%.(.+)$") or storedName
    return getTextOrNull("IGUI_VehicleName" .. key) or key
end

FactionsPlusVehicleUI = ISPanel:derive("FactionsPlusVehicleUI")

function FactionsPlusVehicleUI:initialise()
    ISPanel.initialise(self)
    local btnWid = 120
    local isOwner = self.vehicle.owner == self.player:getUsername()

    -- Owner row
    local ownerLblY = FONT_HGT_MEDIUM + UI_BORDER_SPACING * 2 + 1
    local ownerLbl = ISLabel:new(UI_BORDER_SPACING + 1, ownerLblY, FONT_HGT_SMALL,
        getText("IGUI_FactionsPlus_Vehicle_Owner"), 1, 1, 1, 1, UIFont.Small, true)
    ownerLbl:initialise()
    ownerLbl:instantiate()
    self:addChild(ownerLbl)

    self.ownerValue = ISLabel:new(ownerLbl:getRight() + UI_BORDER_SPACING, ownerLblY, FONT_HGT_SMALL,
        self.vehicle.owner or "", 0.6, 0.6, 0.8, 1.0, UIFont.Small, true)
    self.ownerValue:initialise()
    self.ownerValue:instantiate()
    self:addChild(self.ownerValue)

    -- Members label
    local membersLblY = ownerLblY + FONT_HGT_SMALL + UI_BORDER_SPACING
    local membersLbl = ISLabel:new(UI_BORDER_SPACING + 1, membersLblY, FONT_HGT_SMALL,
        getText("IGUI_FactionsPlus_Vehicle_MembersLabel"), 1, 1, 1, 1, UIFont.Small, true)
    membersLbl:initialise()
    membersLbl:instantiate()
    self:addChild(membersLbl)

    -- Member list
    local listY = membersLblY + FONT_HGT_SMALL + UI_BORDER_SPACING / 2
    local listHeight = BUTTON_HGT * 7
    self.memberList = ISScrollingListBox:new(UI_BORDER_SPACING + 1, listY,
        self.width - (UI_BORDER_SPACING + 1) * 2, listHeight)
    self.memberList:initialise()
    self.memberList:instantiate()
    self.memberList.itemheight = BUTTON_HGT
    self.memberList.selected = 0
    self.memberList.joypadParent = self
    self.memberList.font = UIFont.NewSmall
    self.memberList.doDrawItem = self.drawMember
    self.memberList.drawBorder = true
    self:addChild(self.memberList)

    -- Add / Remove Member buttons
    local memberBtnY = listY + listHeight + UI_BORDER_SPACING
    self.addMemberBtn = ISButton:new(UI_BORDER_SPACING + 1, memberBtnY, btnWid, BUTTON_HGT,
        getText("IGUI_FactionsPlus_Vehicle_AddMember"), self, FactionsPlusVehicleUI.onClick)
    self.addMemberBtn.internal = "ADDMEMBER"
    self.addMemberBtn:initialise()
    self.addMemberBtn:instantiate()
    self.addMemberBtn.borderColor = self.buttonBorderColor
    self.addMemberBtn.enable = isOwner
    self:addChild(self.addMemberBtn)

    self.removeMemberBtn = ISButton:new(self.width - btnWid - UI_BORDER_SPACING - 1, memberBtnY, btnWid, BUTTON_HGT,
        getText("IGUI_FactionsPlus_Vehicle_RemoveMember"), self, FactionsPlusVehicleUI.onClick)
    self.removeMemberBtn.internal = "REMOVEMEMBER"
    self.removeMemberBtn:initialise()
    self.removeMemberBtn:instantiate()
    self.removeMemberBtn.borderColor = self.buttonBorderColor
    self.removeMemberBtn.enable = false
    self:addChild(self.removeMemberBtn)

    -- Unclaim (left) + Close (right)
    local bottomBtnY = memberBtnY + BUTTON_HGT + UI_BORDER_SPACING
    self.unclaimBtn = ISButton:new(UI_BORDER_SPACING + 1, bottomBtnY, btnWid, BUTTON_HGT,
        getText("IGUI_FactionsPlus_Vehicle_UnclaimOption"), self, FactionsPlusVehicleUI.onClick)
    self.unclaimBtn.internal = "UNCLAIM"
    self.unclaimBtn:initialise()
    self.unclaimBtn:instantiate()
    self.unclaimBtn:enableCancelColor()
    self.unclaimBtn.enable = isOwner
    self:addChild(self.unclaimBtn)

    self.closeBtn = ISButton:new(self.width - btnWid - UI_BORDER_SPACING - 1, bottomBtnY, btnWid, BUTTON_HGT,
        getText("IGUI_CraftUI_Close"), self, FactionsPlusVehicleUI.onClick)
    self.closeBtn.internal = "CLOSE"
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self:addChild(self.closeBtn)

    self:setHeight(bottomBtnY + BUTTON_HGT + UI_BORDER_SPACING + 1)
    self:populateList()
end

function FactionsPlusVehicleUI:populateList()
    self.memberList:clear()
    self.selectedMember = nil
    self.removeMemberBtn.enable = false
    if self.vehicle.members then
        for _, m in ipairs(self.vehicle.members) do
            self.memberList:addItem(m, m)
        end
    end
end

function FactionsPlusVehicleUI:drawMember(y, item, alt)
    local a = 0.9
    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, a,
        self.borderColor.r, self.borderColor.g, self.borderColor.b)
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
        local isOwner = self.parent.vehicle.owner == self.parent.player:getUsername()
        self.parent.removeMemberBtn.enable = isOwner
        self.parent.selectedMember = item.item
    end
    self:drawText(item.item, 10, y + 2, 1, 1, 1, a, self.font)
    return y + self.itemheight
end

function FactionsPlusVehicleUI:prerender()
    self:drawRect(0, 0, self.width, self.height,
        self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height,
        self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local displayName = vehicleDisplayName(self.vehicle.name)
    self:drawText(displayName,
        self.width / 2 - getTextManager():MeasureStringX(UIFont.Medium, displayName) / 2,
        UI_BORDER_SPACING + 1, 1, 1, 1, 1, UIFont.Medium)
end

function FactionsPlusVehicleUI:onClick(button)
    if button.internal == "CLOSE" then
        self:close()
    elseif button.internal == "ADDMEMBER" then
        local modal = ISTextBox:new(
            getCore():getScreenWidth() / 2 - 140,
            getCore():getScreenHeight() / 2 - 90,
            280, 180,
            getText("IGUI_FactionsPlus_Vehicle_AddMemberPrompt"), "", nil,
            FactionsPlusVehicleUI.onAddMemberConfirm)
        modal:initialise()
        modal:addToUIManager()
        modal.vehicleUI = self
    elseif button.internal == "REMOVEMEMBER" and self.selectedMember then
        local modal = ISModalDialog:new(0, 0, 350, 150,
            getText("IGUI_FactionsPlus_Vehicle_RemoveConfirm", self.selectedMember),
            true, nil, FactionsPlusVehicleUI.onRemoveMemberConfirm)
        modal:initialise()
        modal:addToUIManager()
        modal.moveWithMouse = true
        modal.vehicleUI = self
    elseif button.internal == "UNCLAIM" then
        local modal = ISModalDialog:new(0, 0, 350, 150,
            getText("IGUI_FactionsPlus_Vehicle_UnclaimConfirm"),
            true, nil, FactionsPlusVehicleUI.onUnclaimConfirm)
        modal:initialise()
        modal:addToUIManager()
        modal.moveWithMouse = true
        modal.vehicleUI = self
    end
end

-- PZ calls modal callbacks as onclick(target, button, ...) — target is the 7th param of :new().
-- We pass nil as target, so the first arg here is nil and button is the second.

function FactionsPlusVehicleUI.onAddMemberConfirm(target, button)
    if button.internal == "OK" then
        local username = button.parent.entry:getText()
        if username and username ~= "" then
            sendClientCommand("FactionsPlusVehicle", "addMemberByKeyId", {
                keyId    = button.parent.vehicleUI.vehicle.keyId,
                username = username,
            })
        end
    end
end

function FactionsPlusVehicleUI.onRemoveMemberConfirm(target, button)
    if button.internal == "YES" then
        local ui = button.parent.vehicleUI
        sendClientCommand("FactionsPlusVehicle", "removeMemberByKeyId", {
            keyId    = ui.vehicle.keyId,
            username = ui.selectedMember,
        })
    end
end

function FactionsPlusVehicleUI.onUnclaimConfirm(target, button)
    if button.internal == "YES" then
        sendClientCommand("FactionsPlusVehicle", "unclaimByKeyId", {
            keyId = button.parent.vehicleUI.vehicle.keyId,
        })
        button.parent.vehicleUI:close()
    end
end

function FactionsPlusVehicleUI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    FactionsPlusVehicleUI.instance = nil
end

function FactionsPlusVehicleUI:new(x, y, width, height, vehicle, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor       = {r=0.4, g=0.4, b=0.4, a=1}
    o.backgroundColor   = {r=0,   g=0,   b=0,   a=0.8}
    o.buttonBorderColor = {r=0.7, g=0.7, b=0.7, a=0.5}
    o.width    = width
    o.height   = height
    o.player   = player
    o.vehicle  = vehicle   -- { keyId, name, members, owner }
    o.selectedMember = nil
    o.moveWithMouse = true
    FactionsPlusVehicleUI.instance = o
    return o
end

-- ============================================================
-- Server response handlers
-- ============================================================

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "FactionsPlusVehicle" then return end
    local ui = FactionsPlusVehicleUI.instance
    if not ui then return end

    if command == "claimSync" and args.keyId == ui.vehicle.keyId then
        ui.vehicle.members = args.claim.Members or {}
        ui:populateList()
    elseif command == "unclaimSync" and args.keyId == ui.vehicle.keyId then
        ui:close()
    elseif command == "myVehiclesList" then
        for _, v in ipairs(args.vehicles or {}) do
            if v.keyId == ui.vehicle.keyId then
                ui.vehicle.members = v.members or {}
                ui:populateList()
                return
            end
        end
        -- Vehicle no longer in the list — unclaim completed.
        ui:close()
    end
end)
