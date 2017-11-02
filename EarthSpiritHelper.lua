-- =============================================
-- File Name 			 : EarthSpiritHelper.lua
-- Rework From Author    : Eroica
-- Version   			 : 1.3
-- Date      			 : 2017.11.02
-- =============================================

local EarthSpiritHelper = {}
EarthSpiritHelper.optionOverall = Menu.AddOption({"Hero Specific", "Earth Spirit"}, "1. Enable", "Enable this script")
EarthSpiritHelper.optionKick = Menu.AddOption({"Hero Specific", "Earth Spirit"}, "2. Kick Helper", "Auto place stone before kick if needed")
EarthSpiritHelper.optionRoll = Menu.AddOption({"Hero Specific", "Earth Spirit"}, "3. Roll Helper", "Auto place stone before roll if needed")
EarthSpiritHelper.optionPull = Menu.AddOption({"Hero Specific", "Earth Spirit"}, "4. Pull Helper", "Auto place stone before pull to silence enemy")


function EarthSpiritHelper.OnPrepareUnitOrders(orders)
	if not Menu.IsEnabled(EarthSpiritHelper.optionOverall) then return true end
	
	if not orders.ability then return true end
	if not Entity.IsAbility(orders.ability) then return true end
	
	if orders.order == Enum.UnitOrder.DOTA_UNIT_ORDER_TRAIN_ABILITY then return true end
	if not (orders.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION) then return true end
	
	local myHero = Heroes.GetLocal()
	if not myHero or NPC.GetUnitName(myHero) ~= "npc_dota_hero_earth_spirit" then return true end
	if NPC.IsSilenced(myHero) or NPC.IsStunned(myHero) then return true end
	
	local abilityName = Ability.GetName(orders.ability)
	
    if not ( abilityName == "earth_spirit_boulder_smash" or abilityName == "earth_spirit_geomagnetic_grip" or abilityName == "earth_spirit_rolling_boulder") then return true end
	
	local mousePos = Input.GetWorldCursorPos()
	local myMana = NPC.GetMana(myHero)
	local kick = NPC.GetAbility(myHero, "earth_spirit_boulder_smash")
	local pull = NPC.GetAbility(myHero, "earth_spirit_geomagnetic_grip")
	local roll = NPC.GetAbility(myHero, "earth_spirit_rolling_boulder")
	local ult = NPC.GetAbility(myHero, "earth_spirit_magnetize")
	local item_blade_mail = NPC.GetItem(myHero, "item_blade_mail", true)
	local retValue = true
	if Menu.IsEnabled(EarthSpiritHelper.optionOverall) and Menu.IsEnabled(EarthSpiritHelper.optionKick) and Ability.GetName(orders.ability) == "earth_spirit_boulder_smash" and Ability.GetLevel(kick) > 0 then
		retValue = EarthSpiritHelper.KickHelper(myHero)
	end
	
	if Menu.IsEnabled(EarthSpiritHelper.optionOverall) and Menu.IsEnabled(EarthSpiritHelper.optionRoll) and Ability.GetName(orders.ability) == "earth_spirit_rolling_boulder" and Ability.GetLevel(roll) > 0 then
		retValue = EarthSpiritHelper.RollHelper(myHero)
	end
	
	if Menu.IsEnabled(EarthSpiritHelper.optionOverall) and Menu.IsEnabled(EarthSpiritHelper.optionPull) and Ability.GetName(orders.ability) == "earth_spirit_geomagnetic_grip" and Ability.GetLevel(pull) > 0 then
		retValue = EarthSpiritHelper.PullHelper(myHero)	
	end
	
	return retValue
end

function EarthSpiritHelper.KickHelper(myHero)
	if not myHero then return end

	local kick = NPC.GetAbility(myHero, "earth_spirit_boulder_smash")
	
	if Ability.GetLevel(kick) <= 0 or not Ability.IsCastable(kick, NPC.GetMana(myHero)) then
		return
	end

	local pos = Input.GetWorldCursorPos()
	local origin = Entity.GetAbsOrigin(myHero)
	local kick_pos = origin + (pos - origin):Normalized():Scaled(100)

	if not EarthSpiritHelper.HasStoneInRadius(myHero, kick_pos, 160) and not EarthSpiritHelper.HasStoneInRadius(myHero, origin, 200) then
		local stone = NPC.GetAbility(myHero, "earth_spirit_stone_caller")
		if stone and Ability.IsCastable(stone, 0) then
			Ability.CastPosition(stone, origin)
		end
	end
	
	if (pos - origin):Length() > 1800 then 
		pos = origin + (pos - origin):Normalized():Scaled(1800) 
	end
	
	EarthSpiritHelper.Kicked = true
	EarthSpiritHelper.KickTime = GameRules.GetGameTime()
	return Ability.CastPosition(kick, pos)
end

function EarthSpiritHelper.PullHelper(myHero)
	if not myHero then return end
  
	local pos = Input.GetWorldCursorPos()
	local myMana = NPC.GetMana(myHero)

	local stone = NPC.GetAbility(myHero, "earth_spirit_stone_caller")
	if not stone or not Ability.IsCastable(stone, 0) then return end
  
	local pull = NPC.GetAbility(myHero, "earth_spirit_geomagnetic_grip")
	if Ability.GetLevel(pull) <= 0 or not Ability.IsCastable(pull, myMana) then 
		return 
	end

	local radius = 200
	local range = 1100

	if not EarthSpiritHelper.HasStoneInRadius(myHero, pos, radius) then
		local stone = NPC.GetAbility(myHero, "earth_spirit_stone_caller")
		if stone and Ability.IsCastable(stone, 0) then
			Ability.CastPosition(stone, pos)
		end
	end
	
	

	local dis = (Entity.GetAbsOrigin(myHero) - pos):Length()
	if dis > range then
		return
	end

	EarthSpiritHelper.Pulled = true
	EarthSpiritHelper.PullTime = GameRules.GetGameTime()
	
	return Ability.CastPosition(pull, pos)
end

function EarthSpiritHelper.RollHelper(myHero)
	if not myHero then return end
  
    local roll = NPC.GetAbility(myHero, "earth_spirit_rolling_boulder")
	if Ability.GetLevel(roll) <= 0 or not Ability.IsCastable(roll, NPC.GetMana(myHero)) then
		return
	end

	local stone = NPC.GetAbility(myHero, "earth_spirit_stone_caller")
	if not stone or not Ability.IsCastable(stone, 0) then 
		return
	end

	local mod = NPC.GetModifier(myHero, "modifier_earth_spirit_stone_caller_charge_counter")
	if not mod or Modifier.GetStackCount(mod) <= 0 then 
        return
	end

	local pos = Input.GetWorldCursorPos()
	local origin = Entity.GetAbsOrigin(myHero)
	local dis = (origin - pos):Length()

	local default_distance = 801
	
	if not EarthSpiritHelper.HasStoneBetween(myHero, origin, pos) and dis >= default_distance then
		local place_pos = origin + (pos - origin):Normalized():Scaled(100)
		Ability.CastPosition(stone, place_pos)
		
	end
	
	
	return Ability.CastPosition(roll, pos)
end


function EarthSpiritHelper.HasStoneInRadius(myHero, pos, radius)
	if not pos or not radius then return false end

	local unitsAround = NPCs.InRadius(pos, radius, Entity.GetTeamNum(myHero), Enum.TeamType.TEAM_FRIEND)
	for i, npc in ipairs(unitsAround) do
        if npc and NPC.GetUnitName(npc) == "npc_dota_earth_spirit_stone" then
            return true
        end
    end
	
	return false
end

function EarthSpiritHelper.HasStoneBetween(myHero, pos1, pos2)
	if not myHero or not pos1 or not pos2 then return false end

	local radius = 150
	local dir = (pos2 - pos1):Normalized():Scaled(radius)
	local dis = (pos2 - pos1):Length()
	local num = math.floor(dis/radius)

	for i = 1, num do
		local mid = pos1 + dir:Scaled(i)
		if EarthSpiritHelper.HasStoneInRadius(myHero, mid, radius) then
		return true
		end
	end

	return false
end

return EarthSpiritHelper