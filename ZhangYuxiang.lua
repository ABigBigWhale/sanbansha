module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--张宇翔
Zhangyuxiang = sgs.General(extension, "Zhangyuxiang", "qun", 4, true)

--【打呼】出牌阶段开始时，若你的武将牌上没有牌，你可以弃置或两张手牌将一名男性角色一个区域（手
--		  牌区，装备区，判定区）的所有牌置于你的武将牌上，称为“呼”。该角色受到伤害时，若
--		  你有“呼”，其选择：1.获得所有“呼”；2.获得你对应区域的所有牌，然后令你获得所有“呼”。

DahuCard = sgs.CreateSkillCard {
	name = "DahuCard",
	target_fixed = true,
	will_throw = true,
	on_use = function(self, room, source)
		local others = room:getAlivePlayers()
		local splayer = room:findPlayerBySkillName("Dahu")
		local target
		for _, p in sgs.qlist(others) do
			if p:getMark("DahuTarget") > 0 then
				target = p
				break
			end
		end
		---------
		-- look for valid options on target player
		if target then
			local choices = ""
			if not target:isKongcheng() then
				choices = "hands"
			end
			if target:hasEquip() then
				if choices == "" then
					choices = "equips"
				else
					choices = choices.."+".."equips"
				end
			end
			local judges = target:getJudgingArea()
			if judges:length() > 0 then
				if choices == "" then
					choices = "judges"
				else
					choices = choices.."+".."judges"
				end
			end
			local choice = ""
			if not string.find(choices, "+") then
				choice = choices
			else
				choice = room:askForChoice(splayer, self:objectName(), choices)
			end
			---------
			local ids = sgs.IntList()
			if choice == "hands" then
				local handcards = target:getHandcards()
				for _, hc in sgs.qlist(handcards) do
					ids:append(hc:getId())
				end
			elseif choice == "equips" then
				local equips = target:getEquips()
				for _, eq in sgs.qlist(equips) do
					ids:append(eq:getId())
				end
			else
				for _, jc in sgs.qlist(judges) do
					ids:append(jc:getId())
				end
			end
			splayer:addToPile("hu", ids, true)
			room:setTag("DahuArea", sgs.QVariant(choice))
		end
	end
}

DahuVS = sgs.CreateViewAsSkill {
	name = "Dahu",
	n = 2,
	view_filter = function(self, selected, to_select)
		
		-- *** DELETED THE "2 HANDCARDS" OPTION

		--[[
		if #selected > 0 then
			if selected[1]:isKindOf("EquipCard") then
				return false
			else
				return not to_select:isKindOf("EquipCard")
			end
		end]]
		

		return to_select:isKindOf("EquipCard") and not table.getn(selected) >= 1;
	end,
	view_as = function(self, cards)
		if #cards > 0 then
			local skillCard = DahuCard:clone()
			for _, card in pairs(cards) do
				skillCard:addSubcard(card)
			end
			skillCard:setSkillName(self:objectName())
			return skillCard
		end
	end,
	enabled_at_play = function(self, player)
		return false
	end,
	enabled_at_response = function(self, player, pattern)
		return pattern == "@@usedahu"
	end,
}

Dahu = sgs.CreateTriggerSkill {
	name = "Dahu",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseStart, sgs.Damaged, sgs.EventPhaseChanging},
	view_as_skill = DahuVS,
	on_trigger = function(self, event, player, data)
		if not player then return end
		if not player:isAlive() then return end
		local room = player:getRoom()
		local dudu = room:findPlayerBySkillName(self:objectName())
		if not dudu then return end

		-- *** CANCELED THE ORIGINAL "PHASECHANGE" CONDITION

		--[[
		if event == sgs.EventPhaseStart then
			if player:getPhase() ~= sgs.Player_Play then return end
			if player:objectName() ~= dudu:objectName() then return end
			if player:getPile("hu"):length() > 0 then return false end
			local can = false
			for _, cd in sgs.qlist(player:getHandcards()) do
				if cd:isKindOf("EquipCard") then
					can = true
					break
				end
			end
			if player:getHandcards():length() < 2 and not (can or player:hasEquip()) then return false end
			if not room:askForSkillInvoke(player, self:objectName()) then return false end

			local all = room:getAlivePlayers()
			for _, p in sgs.qlist(all) do
				if not p or p:isAllNude() or not p:isMale() then
					all:removeOne(p)
				end
			end

			local target = room:askForPlayerChosen(player, all, self:objectName())
			target:addMark("DahuTarget")
			room:askForUseCard(player, "@@usedahu", "@dahuuse")
		else
		--]]
			local available = false
			--[[
			if event == sgs.EventPhaseChanging then
				--if player:objectName() == dudu:objectName() then return end
				local change = data:toPhaseChange()
				local nextphase = change.to
				if nextphase ~= sgs.Player_NotActive then return end
				if player:getMark("DahuTarget") == 0 then return end
				available = true
			else--]]
				local damage = data:toDamage()
				--if player:objectName() == dudu:objectName() then return end
				if damage.to:objectName() ~= player:objectName() then return end
				if player:getMark("DahuTarget") == 0 then return end
				available = true
			--end

			if available then
				room:setPlayerMark(player, "DahuTarget", 0)
				local tag = room:getTag("DahuArea")
				room:removeTag("DahuArea")
				local area = tag:toString()
				local pile = dudu:getPile("hu")
				if pile:length() < 1 then return false end
				local choice = room:askForChoice(player, self:objectName(), "getHu+getDu")
				local list = sgs.IntList()
				local toGet = DahuDummyCard:clone()
				local dudutoGet = DahuDummyCard:clone()
				if choice == "getHu" then
					list = pile
				else
					if area == "hands" then
						list = dudu:handCards()
					elseif area == "equips" then
						local equips = dudu:getEquips()
						for _, eq in sgs.qlist(equips) do
							list:append(eq:getId())
						end
					else
						local judges = dudu:getJudgingArea()
						for _, jc in sgs.qlist(judges) do
							ids:append(jc:getId())
						end
					end
					for _, id in sgs.qlist(pile) do
						dudutoGet:addSubcard(id)
					end
				end
				for _, id in sgs.qlist(list) do
					toGet:addSubcard(id)
				end
				if toGet:subcardsLength() > 0 then
					room:obtainCard(player, toGet)
				end
				if dudutoGet:subcardsLength() > 0 then
					room:obtainCard(dudu, dudutoGet)
				end
			end
		--end
		return false
	end,
	can_trigger = function(self, target)
		return target
	end

}

DahuDummyCard = sgs.CreateSkillCard {
	name = "DahuDummyCard"
}

Zhangyuxiang:addSkill(Dahu)

--【情歌】出牌阶段限一次，你可以选择一张“呼”并指定一名女性角色或自己，若其已受伤，令其回复一点体力并弃置
--		  之，否则令其获得该牌。
QinggeCard = sgs.CreateSkillCard {
	name = "QinggeCard",
	target_fixed = true,
	will_throw = true,
	on_use = function(self, room, source, targets)
		local hu = source:getPile("hu")
		room:fillAG(hu, source)
		local id = room:askForAG(source, hu, false, "Qingge")
		room:clearAG()
		local all = room:getAlivePlayers()
		for _, p in sgs.qlist(all) do
			if p then
				if not (p:isFemale() or p:objectName() == source:objectName()) then
					all:removeOne(p)
				end
			end
		end
		local target
		if all:first():objectName() == source:objectName() and all:length() == 1 then
			target = source
		else
			target = room:askForPlayerChosen(source, all, self:objectName())
		end
		if target:isWounded() then
			room:throwCard(id, source)
			local rec = sgs.RecoverStruct()
			rec.who = source
			rec.recover = 1
			room:recover(target, rec)
		else
			room:obtainCard(target, id)
		end
	end
}

Qingge = sgs.CreateViewAsSkill {
	name = "Qingge",
	n = 0,
	view_as = function(self, cards)
		return QinggeCard:clone()
	end,
	enabled_at_play = function(self, player)
		local hu = player:getPile("hu")
		return hu:length() > 0 and not player:hasUsed("#QinggeCard")
	end
}

Zhangyuxiang:addSkill(Qingge)

sgs.LoadTranslationTable{
	["Zhangyuxiang"] = "张宇翔",
	["Dahu"] = "打呼",
	["dahu"] = "打呼",
	[":Dahu"] = "出牌阶段开始时，若你的武将牌上没有牌，你可以弃置一张装备牌将一名男性角色一个区域（手牌区，装备区，判定区）的所有牌置于你的武将牌上，称为“呼”。该角色受到伤害时，选择：1.获得所有“呼”；2.获得你对应区域的所有牌，然后令你获得所有“呼”。",
	["DahuInvoke"] = "请选择一个目标角色发动“打呼”",
	["@dahuuse"] = "请弃置一张装备牌或两张手牌",
	["~dahuuse"] = "（判定区、装备区、手牌区）",
	["hu"] = "呼",
	["hands"] = "手牌区",
	["equips"] = "装备区",
	["judges"] = "判定区",
	["Qingge"] = "情歌",
	[:"Qingge"] = "出牌阶段限一次，你可以选择一张“呼”并指定一名女性角色或自己，若其已受伤，令其回复一点体力并弃置之，否则令其获得该牌.";
}