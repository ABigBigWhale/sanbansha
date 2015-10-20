module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--电教
Dianjiao = sgs.General(extension, "Dianjiao", "shu", 5)

--【极客】每当你造成一点伤害，你可摸一张牌。
San_Jike = sgs.CreateTriggerSkill {
	name = "San_Jike",
	frequency = sgs.Skill_Frequent,
	events = {sgs.Damage},
	on_trigger = function(self, event, player, data)
		local damage = data:toDamage()
		local damageCount = damage.damage
		local room = player:getRoom()
		for i = 1, damageCount, 1 do
			room:drawCards(player, 1)
		end
	end
}

--【超频】限定技，出牌阶段，你可将装备区内的所有牌交给一名其他角色，然后若该角色手牌数大于其体力值，
--		  你对其造成X点伤害（X为其手牌数与体力值之差）

San_Chaopin_VSCard = sgs.CreateSkillCard {
	name = "San_Chaopin_VSCard",
	target_fixed = false,
	will_throw = false,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return sgs.Self:inMyAttackRange(to_select) and
				   to_select:objectName() ~= sgs.Self:objectName()
		end
		return false
	end,
	on_effect = function(self, effect)
		local source = effect.from
		local target = effect.to
		local room = source:getRoom()
		local equips = source:getEquips()
		local ids = sgs.IntList()
		for _, card in sgs.qlist(equips) do
			ids:append(card:getId())
		end
		local give = sgs.CardsMoveStruct()
		give.card_ids = ids
		give.to = target
		give.to_place = sgs.Player_PlaceHand
		room:moveCardsAtomic(give, true)
		if target:isAlive() then
			local num = target:getHandcardNum()
			local targetHp = target:getHp()
			local count = num - targetHp
			if count > 0 then
				local damage = sgs.DamageStruct()
				damage.from = source
				damage.to = target
				damage.damage = count
				damage.nature = sgs.DamageStruct_Normal
				room:damage(damage)
			end
		end
		source:loseMark("@chaopin")
	end
}

San_Chaopin_VS = sgs.CreateZeroCardViewAsSkill {
	name = "San_Chaopin_LM",

	view_as = function(self, cards)
		return San_Chaopin_VSCard:clone()
	end,
	enabled_at_play = function(self, player)
		if player:hasEquip() then
			return player:getMark("@chaopin") > 0
		end
	end
}

San_Chaopin_LM = sgs.CreateTriggerSkill{
	name = "San_Chaopin_LM",
	frequency = sgs.Skill_Limited,
	events = {sgs.GameStart},
	view_as_skill = San_Chaopin_VS,
	on_trigger = function(self, event, player, data)
		player:gainMark("@chaopin")
	end
}

Dianjiao:addSkill(San_Jike)
--Dianjiao:addSkill(San_Chaopin_LM)


sgs.LoadTranslationTable{
	["oldsanbansha"] = "三班杀原型",
	["Dianjiao"] = "冯智浩",
	["&Dianjiao"] = "电教",
	["designer:Dianjiao"] = "刘皓",
	["San_Jike"] = "极客",
	[":San_Jike"] = "每当你造成一点伤害，你可摸一张牌。",
	["San_Chaopin_LM"] = "超频",
	["San_Chaopin_VS"] = "超频",
	["@chaopin"] = "超频",
	[":San_Chaopin_LM"] = "/b限定技/b，出牌阶段，你可将装备区内的所有牌交给一名其他角色，然后若该角色手牌数大于其体力值，你对其造成X点伤害（X为其手牌数与体力值之差）"
}