module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--阮老
Ruanlao = sgs.General(extension, "ruanlao", "shu", 3, false)

--【善诫】游戏开始后，每当你未发动此技能获得手牌，你可将一张手牌正面朝上交给一名除来源角色外的其他角色，
--		  若该牌为黑色，你视作对其使用了一张雷属性【杀】；若为红色，你摸一张牌。

RoushanCard = sgs.CreateSkillCard {
	name = "roushancard",
	target_fixed = false,
	will_throw = false,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName() and not to_select:hasFlag("roushan_from")
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		local room = source:getRoom()
		local target = targets[1]
		local card_id = self:getSubcards():first()
		local card = sgs.Sanguosha:getCard(card_id)
		room:obtainCard(target, self, true)
		if card:isBlack() then
			local slash = sgs.Sanguosha:cloneCard("thunder_slash")
			local slash_use = sgs.CardUseStruct()
			slash_use.from = source
			slash_use.to:append(target)
			slash_use.card = slash
			room:useCard(slash_use)
		else
			room:drawCards(source, 1, "roushan")
		end
		room:setPlayerFlag(source, "-roushan_effect")
		for _, p in sgs.qlist(room:getAlivePlayers()) do
			if p:hasFlag("roushan_from") then
				room:setPlayerFlag(p, "-roushan_from")
			end
		end
	end,
}

RoushanVS = sgs.CreateViewAsSkill {
	name = "roushan",
	n = 1,
	view_filter = function(self, selected, to_select)
		return not to_select:isEquipped()
	end,
	view_as = function(self, cards)
		if #cards == 1 then
			local card = RoushanCard:clone()
			card:addSubcard(cards[1])
			card:setSkillName(self:objectName())
			return card
		end
	end,
	enabled_at_response = function(self, player, pattern)
		return pattern == "@@roushan"
	end,
	enabled_at_play = function(self, player)
		return false
	end,
}

Roushan = sgs.CreateTriggerSkill {
	name = "roushan",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.GameStart, sgs.CardsMoveOneTime},
	view_as_skill = RoushanVS,
	on_trigger = function(self, event, player, data)
		if event == sgs.GameStart then return false end
		if not player then return end
		if player:hasFlag("roushan_effect") then return false end
		local room = player:getRoom()

		local move = data:toMoveOneTime()
		if not move.to or move.to:objectName() ~= player:objectName() then return end
		if move.to_place ~= sgs.Player_PlaceHand then return end
		if player:isKongcheng() then return false end

		if not player:askForSkillInvoke(self:objectName()) then return false end
		local others = room:getOtherPlayers(player)
		if move.from then
			local from = move.from
			local others = room:getAlivePlayers()
			for _, p in sgs.qlist(others) do
				if p:objectName() == from:objectName() then
					room:setPlayerFlag(p, "roushan_from")
					break
				end
			end
		end
		room:setPlayerFlag(player, "roushan_effect")
		room:askForUseCard(player, "@@roushan", "@roushan_invoke")
	end,
}

--【愠恼】每当你受到一点伤害，你可令伤害来源摸一张牌然后交给你一张手牌。
Yunnao = sgs.CreateTriggerSkill{
	name = "yunnao",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.Damaged},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local damage = data:toDamage()
		local source = damage.from
		if source then
			if source:objectName() ~= player:objectName() then
				local count = damage.damage
				for i=1, count, 1 do
					if room:askForSkillInvoke(player, self:objectName(), data) then
						room:drawCards(source, 1)
						local card = room:askForExchange(source, self:objectName(), 1, false, "yunnao_give", false)
						room:moveCardTo(card, player, sgs.Player_PlaceHand)
					end
				end
			end
		end
	end
}


Ruanlao:addSkill(Roushan)
Ruanlao:addSkill(Yunnao)

sgs.LoadTranslationTable {
	["ruanlao"] = "阮老",
	["roushan"] = "善诫",
	[":roushan"] = "游戏开始后，每当你因未发动此技能而获得手牌，你可将一张手牌正面朝上交给一名除来源角色外的其他角色，若该牌为黑色，你视作对其使用了一张雷属性【杀】；若为红色，你摸一张牌。",
	["yunnao"] = "愠恼",
	[":yunnao"] = "每当你受到一点伤害，你可令伤害来源摸一张牌然后交给你一张手牌。",
	["@roushan_invoke"] = "请选择要交给目标角色的一张手牌，若为黑色视作对其使用了一张雷属性【杀】；若为红色，你摸一张牌。",
	["yunnao_give"] = "请选择一张交给阮老的手牌"
}