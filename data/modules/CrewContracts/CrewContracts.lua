-- Copyright © 2013 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

-- This module allows the player to hire crew members through BB adverts
-- on stations, and handles periodic events such as their wages.

-- Get the translator function
local t = Translate:GetTranslator()

-- The contract for a crew member is a table containing their weekly wage,
-- the date that they should next be paid and the amount outstanding if
-- the player has been unable to pay them.
--
-- contract = {
--   wage = 0,
--   payday = 0,
--   outstanding = 0,
-- }

local boostCrewSkills = function (crewMember)
	-- Each week, there's a small chance that a crew member gets better
	-- at each skill, due to the experience of working on the ship.
	local attribute = {
		'engineering',
		'piloting',
		'navigation',
		'sensors',
	}
	for i = 1,#attribute do
		-- Test with a penalty of four, to slow down their growth.
		-- The best get better more quickly using this technique.
		if crewMember:TestRoll(attribute[i],-4) then
			crewMember[attribute] = crewMember[attribute]+1
		end
	end
end

local scheduleWages = function (crewMember)
	-- Must have a contract to be treated like crew
	if not crewMember.contract then return end

	local payWages
	payWages = function ()
		local contract = crewMember.contract
		-- Check if crew member has been dismissed
		if not contract then return end

		if Game.player:GetMoney() > contract.wage then
			Game.player:AddMoney(0 - contract.wage)
		else
			contract.outstanding = contract.outstanding + contract.wage
		end
		
		-- Attempt to pay off any arrears
		local arrears = math.min(Game.player:GetMoney(),contract.outstanding)
		Game.player:AddMoney(0 - arrears)
		contract.outstanding = contract.outstanding - arrears

		-- The crew gain experience each week, and might get better
		boostCrewSkills(crewMember)

		-- Schedule the next pay day, if there is one.
		if contract.payday then
			contract.payday = contract.payday + 604800 -- a week of seconds
			Timer:CallAt(contract.payday,payWages)
		end
	end

	Timer:CallAt(crewMember.contract.payday,payWages)
end

-- This gets run just after crew are restored from a saved game
Event.Register('crewAvailable',function()
	-- scheduleWages() for everybody
	for crewMember in Game.player:EachCrewMember() do
		scheduleWages(crewMember)
	end
end)

-- This gets run whenever a crew member joins a ship
Event.Register('onJoinCrew',function(ship, crewMember)
	if ship:IsPlayer() then
		scheduleWages(crewMember)
	end
end)

-- This gets run whenever a crew member leaves a ship
Event.Register('onLeaveCrew',function(ship, crewMember)
	if ship:IsPlayer() and crewMember.contract then
		crewMember.contract.payday = nil
	end
end)
