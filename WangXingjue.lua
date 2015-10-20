module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--珏爷
Jueye = sgs.General(extension, "jueye", "qun", 8)

--【饕餮】锁定技，回合结束时，若你于该回合未受到过【桃】或【酒】的效果，你失去一点体力。
Taotie = sgs.CreateTriggerSkill {
	name = "taotie",
	frequency = sgs.Skill_Compulsory,
	events = {sgs.CardEffected, sgs.EventPhaseChanging},
	on_trigger = function(self, event, player, data)
		if not player or not player:isAlive() then return end
		local room = player:getRoom()

		if event == sgs.CardEffected then
			if player:getPhase() == sgs.Player_NotActive then return end
			local effect = data:toCardEffect()
			local card = effect.card
			if not card:isKindOf("Peach") or card:isKindOf("Analeptic") then return end
			if player:getMark(self:objectName()) == 0 then
				room:setPlayerMark(player, self:objectName(), 1)
			end
		else
			local change = data:toPhaseChange()
			if change.to == sgs.Player_NotActive then
				if player:getMark(self:objectName()) == 0 then
					room:loseHp(player)
				else
					room:setPlayerMark(player, self:objectName(), 0)
				end
			end
		end
		return false
	end,
}

--【弹速】出牌阶段限一次，令一名角色摸X张牌（X为你已损失体力值），再减一点体力上限并令其展示手牌，然
--		  后你选择一种颜色，获得其中所有该颜色的牌。

TansuDummy = sgs.CreateSkillCard {
	name = "tansu_dummy"
}

TansuCard = sgs.CreateSkillCard {
	name = "tansucard",
	will_throw = false,
	target_fixed = false,
	filter = function(self, targets, to_select)
		return to_select:objectName() ~= sgs.Self:objectName() and #targets < 1
	end,
	on_effect = function(self, effect)
		local source = effect.from
		local target = effect.to
		local room = source:getRoom()
		room:drawCards(target, source:getLostHp())
		room:loseMaxHp(source)
		room:showAllCards(target)
		local choice = room:askForChoice(source, "tansu_prompt", "red+black")
		local cards = target:getHandcards()
		local dummy = TansuDummy:clone()
		for _, cd in sgs.qlist(cards) do
			if (choice == "red" and cd:isRed())
			   or (choice == "black" and cd:isBlack()) then
				dummy:addSubcard(cd)
			end
		end
		room:obtainCard(source, dummy)
	end
}

Tansu = sgs.CreateViewAsSkill {
	name = "tansu",
	n = 0,
	view_filter = function(self, selected, to_select)
		return false
	end,
	view_as = function(self, cards)
		local card = TansuCard:clone()
		card:setSkillName(self:objectName())
		return card
	end,
	enabled_at_play = function(self, player)
		return not player:hasUsed("#tansucard")
	end
}

--【夺桃】你处于濒死状态求桃结束后，若你当前体力值为零，你可观看一名其他角色的手牌，然后弃置其中一半的牌
--	     （向上取整），你每以此法弃置一张【桃】或【酒】，你使用之。
Duotao = sgs.CreateTriggerSkill {
	name = "duotao",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.AskForPeachesDone},
	on_trigger = function(self, event, player, data)
		if not player or not player:isAlive() then return end
		if player:getHp() > 0 then return false end

		local room = player:getRoom()
		if not room:askForSkillInvoke(player, self:objectName()) then return false end
		targets = room:getOtherPlayers(player)
		local target = room:askForPlayerChosen(player, targets, self:objectName(), "duotao_prompt", false, true)
		local ids = target:handCards()
		local num = (target:getHandcardNum() + 1) / 2
		room:fillAG(ids, player)
		for i = 1, num, 1 do
			local chosen_id = room:askForAG(player, ids, false, self:objectName())
			room:takeAG(nil, chosen_id)
			ids:removeOne(chosen_id)
			local chosen = sgs.Sanguosha:getCard(chosen_id)
			if chosen:isKindOf("Peach") or chosen:isKindOf("Analeptic") then
				room:useCard(sgs.CardUseStruct(chosen, player, player))
			end
			room:throwCard(chosen, target, player)
		end
		room:clearAG()
	end
}

Jueye:addSkill(Taotie)
Jueye:addSkill(Tansu)
Jueye:addSkill(Duotao)

sgs.LoadTranslationTable {
	["jueye"] = "王星珏",
	["tansu"] = "弹速",
	[":tansu"] = "出牌阶段限一次，你可减一点体力上限，令一名角色摸X张牌（X为你已损失体力值）并展示所有手牌，然后你选择一种颜色，获得其中所有该颜色的牌。",
	["taotie"] = "饕餮",
	[":taptie"] = "锁定技，回合结束时，若你于该回合未受到过【桃】或【酒】的效果，你失去一点体力。",
	["tansu_prompt"] = "请选择获得牌颜色",
	["duotao"] = "夺桃",
	[":duotao"] = "你处于濒死状态求桃结束后，若你当前体力值为零，你可观看一名其他角色的手牌，然后弃置其中一半的牌（向上取整），你每以此法弃置一张【桃】或【酒】，视作你使用之",
	["duotao_prompt"] = "请选择一名角色成为你偷桃的目标",
}