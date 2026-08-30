local function isSkillBook(item)
    if not item then return false end
    local skill = item:getSkillTrained()
    return skill and skill ~= ""
end

local originalGetDuration = ISReadABook.getDuration
ISReadABook.getDuration = function(self)
    local time = originalGetDuration(self)
    local options = SandboxVars.FactionsPlus
    if options.EnableFastXPBook and isSkillBook(self.item) then
        time = time * options.XPBookReadMultiplier
    end
    return time
end

local originalIsValid = ISReadABook.isValid
ISReadABook.isValid = function(self)
    if self.item and self.item:getNumberOfPages() > 0 then
        if self.item:getAlreadyReadPages() >= self.item:getNumberOfPages() then
            return false
        end
    end
    return originalIsValid(self)
end

local originalUpdate = ISReadABook.update
ISReadABook.update = function(self)
    originalUpdate(self)
    local options = SandboxVars.FactionsPlus
    if not (options.EnableFastXPBook and isSkillBook(self.item)) then return end
    if self.item:getNumberOfPages() > 0 and
       self.item:getAlreadyReadPages() >= self.item:getNumberOfPages() then
        self:forceStop()
    end
end
