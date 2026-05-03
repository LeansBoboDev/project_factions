-- ============================================================
-- Fast Sleep — Client Side
-- ============================================================

if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastSleep"):getValue() then return end


local player

local accumulator = 0
local function OnTick()
	local delta = GameTime.getInstance():getRealworldSecondsSinceLastUpdate()
	accumulator = accumulator + delta

	if accumulator < 1.0 then return end
	accumulator = 0

	if player:isAsleep() then
		local stats = player:getStats()

		local fatigueReducer = getSandboxOptions():getOptionByName("FactionsPlus.SleepFatigueReducer"):getValue() / 100
		local enduranceIncreaser = getSandboxOptions():getOptionByName("FactionsPlus.SleepEnduranceReceive"):getValue() /
			100

		stats:remove(CharacterStat.FATIGUE, fatigueReducer)
		sendPlayerStat(player, CharacterStat.FATIGUE)

		stats:add(CharacterStat.ENDURANCE, enduranceIncreaser)
		sendPlayerStat(player, CharacterStat.ENDURANCE)

		local currentFatigue = stats:get(CharacterStat.FATIGUE)
		local currentEndurance = stats:get(CharacterStat.ENDURANCE)

		if currentFatigue <= 0 then
			getSleepingEvent():wakeUp(player)
		end

		DebugPrintFactionsPlus(string.format(
			"[FastSleep] fatigue=%.4f endurance=%.4f",
			currentFatigue,
			currentEndurance
		))
	else
		Events.OnTick.Remove(OnTick)
	end
end

local oldOnSleepWalkToComplete = ISWorldObjectContextMenu.onSleepWalkToComplete
function ISWorldObjectContextMenu.onSleepWalkToComplete(playerId, bed)
	oldOnSleepWalkToComplete(playerId, bed)

	local playerObj = getSpecificPlayer(playerId)
	if not playerObj or not playerObj:isAsleep() then return end

	player = playerObj
	Events.OnTick.Add(OnTick)
end
