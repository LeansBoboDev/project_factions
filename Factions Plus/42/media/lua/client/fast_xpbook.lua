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
