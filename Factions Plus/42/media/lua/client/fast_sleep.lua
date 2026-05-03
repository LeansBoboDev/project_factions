-- ============================================================
-- Fast Sleep — Client Side
-- ============================================================

if not getSandboxOptions():getOptionByName("FactionsPlus.EnableFastSleep"):getValue() then return end


local sleepData = {}
-- {
--     sleepStart    = timeOfDay when sleep started,
--     originalHours  = original forceWakeUpTime,
--     reducedHours   = reduced forceWakeUpTime,
--     wakeTickDelay = countdown ticks after waking,
--	   wakupTime 	 = timeOfDay when wakeup
--	   hoursLeft     = hours to wake up
-- }

local function OnTick(tick)
	if not sleepData or not sleepData.wakeupTime then return end

	local player = getPlayer()

	if player:isAsleep() then
		local currentTime    = GameTime.getInstance():getTimeOfDay()
		local wakeTime       = player:getForceWakeUpTime()

		-- calcula quanto falta pra acordar (em horas)
		local hoursLeft      = wakeTime >= currentTime
			and (wakeTime - currentTime)
			or (wakeTime + 24 - currentTime)

		-- atualiza estrutura
		sleepData.wakeupTime = wakeTime
		sleepData.hoursLeft  = hoursLeft
	else
		sleepData.wakeTickDelay = sleepData.wakeTickDelay - 1

		-- jogador acordou → parar o tick
		if sleepData.wakeTickDelay <= 0 then
			local original = sleepData.originalHours
			local reduced  = sleepData.reducedHours

			DebugPrintFactionsPlus("[FastSleep] ---- Recovery Start ----")
			DebugPrintFactionsPlus(string.format(
				"[FastSleep] originalHours=%.3f reducedHours=%.3f",
				original or -1, reduced or -1
			))

			-- proteção contra nil / zero
			if not original or original <= 0 then
				DebugPrintFactionsPlus("[FastSleep][ERROR] Invalid originalHours, aborting recovery")
				Events.OnTick.Remove(OnTick)
				sleepData = {}
				return
			end

			-- cálculo principal
			local manualRecovery = 1.0 - (reduced / original)
			manualRecovery = math.max(0.0, math.min(1.0, manualRecovery))

			DebugPrintFactionsPlus(string.format(
				"[FastSleep] manualRecovery=%.4f (%.2f%%)",
				manualRecovery, manualRecovery * 100
			))

			local stats = player:getStats()
			if not stats then
				DebugPrintFactionsPlus("[FastSleep][ERROR] stats is nil")
				Events.OnTick.Remove(OnTick)
				sleepData = {}
				return
			end

			-- valores atuais
			local currentFatigue   = stats:get(CharacterStat.FATIGUE)
			local currentEndurance = stats:get(CharacterStat.ENDURANCE)

			DebugPrintFactionsPlus(string.format(
				"[FastSleep] BEFORE -> fatigue=%.4f endurance=%.4f",
				currentFatigue, currentEndurance
			))

			-- cálculo de recuperação
			local fatigueToRecover   = currentFatigue * manualRecovery
			local enduranceToRecover = (1.0 - currentEndurance) * manualRecovery

			DebugPrintFactionsPlus(string.format(
				"[FastSleep] DELTA -> fatigue=%.4f endurance=+%.4f",
				-fatigueToRecover, enduranceToRecover
			))

			-- aplicar
			stats:remove(CharacterStat.FATIGUE, fatigueToRecover)
			sendPlayerStat(getPlayer(), CharacterStat.FATIGUE)
			stats:add(CharacterStat.ENDURANCE, enduranceToRecover)
			sendPlayerStat(getPlayer(), CharacterStat.ENDURANCE)

			-- valores depois
			local newFatigue   = stats:get(CharacterStat.FATIGUE)
			local newEndurance = stats:get(CharacterStat.ENDURANCE)

			DebugPrintFactionsPlus(string.format(
				"[FastSleep] AFTER  -> fatigue=%.4f endurance=%.4f",
				newFatigue, newEndurance
			))

			-- sanity check
			if newFatigue < 0 or newFatigue > 1 then
				DebugPrintFactionsPlus("[FastSleep][WARN] fatigue out of bounds!")
			end

			if newEndurance < 0 or newEndurance > 1 then
				DebugPrintFactionsPlus("[FastSleep][WARN] endurance out of bounds!")
			end

			DebugPrintFactionsPlus("[FastSleep] ---- Recovery End ----")

			Events.OnTick.Remove(OnTick)
			sleepData = {}
		end
	end
end

local oldOnSleepWalkToComplete = ISWorldObjectContextMenu.onSleepWalkToComplete
function ISWorldObjectContextMenu.onSleepWalkToComplete(player, bed)
	oldOnSleepWalkToComplete(player, bed)

	local playerObj = getSpecificPlayer(player)
	if not playerObj or not playerObj:isAsleep() then return end

	local reducer       = getSandboxOptions():getOptionByName("FactionsPlus.SleepFatigueReducer"):getValue() / 100
	local currentWake   = playerObj:getForceWakeUpTime()
	local currentTime   = GameTime.getInstance():getTimeOfDay()

	local originalHours = currentWake >= currentTime
		and currentWake - currentTime
		or currentWake + 24 - currentTime

	local reducedHours  = originalHours * reducer
	local newWakeTime   = currentTime + reducedHours
	if newWakeTime >= 24 then newWakeTime = newWakeTime - 24 end

	playerObj:setForceWakeUpTime(newWakeTime)

	DebugPrintFactionsPlus(string.format(
		"Sleep reduced — original: %.1fh, reduced: %.1fh, wakeTime: %.2f",
		originalHours, reducedHours, newWakeTime
	))

	sleepData = {
		sleepStart = currentTime,
		originalHours = originalHours,
		reducedHours = reducedHours,
		wakeupTime = newWakeTime,
		wakeTickDelay = 10
	}

	Events.OnTick.Add(OnTick)
end
