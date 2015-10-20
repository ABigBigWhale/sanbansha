module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--张作翔
Zhangzuoxiang = sgs.General(extension, "Zhangzuoxiang", "qun", 4, true)

--【导演】其他角色回合开始前，若你武将牌正面朝上且你有手牌，你可将武将牌翻面，然后
--		  你置换该角色此回合判定阶段、摸牌阶段、出牌阶段和弃牌阶段中两者的执行顺序。
Daoyan = sgs.CreateTriggerSkill {
	name = "daoyan",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseEnd},
	can_trigger = function(self, target)
		local room = target:getRoom()
		local zuozuo = room:findPlayerBySkillName(self:objectName())
		return target:objectName() ~= zuozuo:objectName()
	end,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local target = room:getCurrent()
		if target:getPhase() ~= sgs.Player_Start then return end
		local zuozuo = room:findPlayerBySkillName(self:objectName())
		if not zuozuo then return end
		if target:objectName() == zuozuo:objectName() then return false end
		if zuozuo:isKongcheng() or not zuozuo:faceUp() then return false end

		local phases = sgs.PhaseList()
		phases:append(sgs.Player_Discard)
		phases:append(sgs.Player_Play)
		phases:append(sgs.Player_Draw)
		phases:append(sgs.Player_Judge)
		--------
		local data = sgs.QVariant()
		data:setValue(target)
		if not room:askForSkillInvoke(zuozuo, self:objectName(), data) then return false end
		room:setPlayerFlag(target, self:objectName())
		zuozuo:turnOver()

		--[[local choices_A = "judge+draw+play+discard"
		local choice_A = room:askForChoice(zuozuo, self:objectName(), choices_A)
		local choices = {"judge", "draw", "play", "discard"}
		local choices_B = ""
		local a = 0
		for i = 1, #choices, 1 do
			if choices[i] ~= choice_A then
				if choices_B == "" then
					choices_B = choices[i]
				else
					choices_B = choices_B.."+"..choices[i]
				end
			else
				choice_A = choices[i]
				a = i - 1
			end
		end
		local choice_B = room:askForChoice(zuozuo, self:objectName(), choices_B)
		local b = 0
		for i = 1, #choices, 1 do
			if choice_B == choices[i] then
				b = i - 1
			end
		end

		local msg = sgs.LogMessage()
		msg.type = ""..a..b
		msg.to:append(player)
		room:sendLog(msg)

		local p_1 = phases:at(a)
		local p_2 = phases:at(b)
		local pattern = sgs.PhaseList()
		for _, ph in sgs.qlist(phases) do
			if ph ~= p_1 and ph ~= p_2 then
				pattern:prepend(ph)
			elseif ph == p_1 then
				pattern:prepend(p_2)
			elseif ph == p_2 then
				pattern:prepend(p_1)
			end
		end
		target:play(pattern)
		target:setPhase(sgs.Player_Finish)--]]

		return false
	end
}

--【吟诗】其他角色回合结束时，若该角色于此回合内未对你造成伤害且你武将牌背面朝上，你可摸一张牌。
Yinshi = sgs.CreateTriggerSkill {
	name = "yinshi",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseChanging, sgs.Damaged},
	can_trigger = function(self, target)
		return target
	end,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local zuozuo = room:findPlayerBySkillName(self:objectName())
		if not zuozuo then return end

		if event == sgs.EventPhaseChanging then
			if zuozuo:faceUp() then return end
			local change = data:toPhaseChange()
			local phase = change.to
			if phase == sgs.Player_NotActive then
				if not zuozuo:hasFlag(self:objectName()) and zuozuo:askForSkillInvoke(self:objectName()) then
					zuozuo:drawCards(1)
				else
					room:setPlayerFlag(zuozuo, "-"..self:objectName())
				end
			end
		else
			local damage = data:toDamage()
			local from = damage.from
			if damage.to:objectName() == zuozuo:objectName() and from and from:getPhase() ~= sgs.Player_NotActive then
				room:setPlayerFlag(zuozuo, self:objectName())
			end
		end
		return false
	end,
}


Zhangzuoxiang:addSkill(Daoyan)
Zhangzuoxiang:addSkill(Yinshi)

sgs.LoadTranslationTable {
	["Zhangzuoxiang"] = "张作翔",
	["daoyan"] = "导演",
	["yinshi"] = "吟诗"
}