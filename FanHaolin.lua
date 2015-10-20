--范豪麟
Fanhaolin = sgs.General(extension, "fanhaolin", "shu", 4)

module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--【豪食】每当你受到一次【桃】的效果，该【桃】进入弃牌堆时你可将该牌置于武将牌上，称为“饭”。出牌阶段限一次，你可弃置一张“饭”并选择：1.回复一点体力；2.本回合内使用的【杀】伤害+1.

FanHaoshi = sgs.CreateTriggerSkill {
	name = "#fanhaoshi",
	frequency = sgs.Skill_NotFrequent,
	view_as_skill = FanHaoshi_VS,
	events = {sgs.CardEffected, sgs.CardsMoveOneTime, sgs.DamageCaused},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		if not player:isAlive() then return end
		
		if event == sgs.CardEffected then
			local effect = data:toCardEffect()
			local peach = effect.card
			if peach:isVirtualCard() or not peach:isKindOf("Peach") then return end
			room:setCardFlag(peach, "haoshi_peach")
		end
		
		if event == sgs.CardsMoveOneTime then
			local move = data:toMoveOneTime()
			local card = sgs.Sanguosha:getCard(move.card_ids:first())
			if not card:hasFlag("haoshi_peach") then return end
			if move.from and move.to_place == sgs.Player_DiscardPile then
				if room:askForSkillInvoke(player, self:objectName(), data) then
					player:addToPile("fan", card)
				end
				card:setFlags("-haoshi_peach")
			end
		end
		
		if event == sgs.DamageCaused then
			if not player:hasFlag("haoshi_effected") then return end
			local damage = data:toDamage()
			local victim = damage.to
			local slash = damage.card
			
			if not slash or not slash:isKindOf("Slash") then return false end
			if not victim or not victim:isAlive() then return end
			
			damage.damage = damage.damage + 1
			data:setValue(damage)
		end
		
		return false
	end
}

FanHaoshi_VS = sgs.CreateViewAsSkill {
	name = "fanhaoshi",
	n = 0,
	view_as = function(self, player)
		return FanHaoshiCard:clone()
	end,
	enabled_at_play = function(self, player)
		return not player:hasUsed("#FanHaoshiCard")
	end
}

FanHaoshiCard = sgs.CreateSkillCard {
	name = "FanHaoshiCard",
	target_fixed = true,
	will_throw = true,
	on_use = function(self, room, source, targets)
		local fan = source:getPile("fan")
		local count = fan:length()
		local id
		if count == 0 then
			return 
		elseif count == 1 then
			id = fan:first()
		else
			room:fillAG(fan, source)
			id = room:askForAG(source, fan, false, self:objectName())
			source:invoke("clearAG")
			if id == -1 then
				return
			end
		end
		local choice = room:askForChoice(source, "fanhaoshi", "rec+dmgboost")
		if choice == "rec" then
			room:recover(source, sgs.RecoverStruct())
		elseif choice == "dmgboost" then
			room:setPlayerFlag(source, "haoshi_effected")
		end
		room:throwCard(id, player)
	end
}

Fanhaolin:addSkill(FanHaoshi)
Fanhaolin:addSkill(FanHaoshi_VS)
extension:insertRelatedSkills("#fanhaoshi", "fanhaoshi")

sgs.LoadTranslationTable {
	["fanhaolin"] = "范豪麟",
	["fanhaoshi"] = "豪食",
	[":fanhaoshi"] = "每当你受到一次【桃】的效果，该【桃】进入弃牌堆时你可将该牌置于武将牌上，称为“饭”。出牌阶段限一次，你可弃置一张“饭”并选择：1.回复一点体力；2.本回合内使用的【杀】伤害+1.",
	["fan"] = "饭"
}