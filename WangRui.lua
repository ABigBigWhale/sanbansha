module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

Wangrui = sgs.General(extension, "wangrui", "wu", 4)

--【骚睿】出牌阶段限一次，你可展示一名其他角色的一张手牌，若该牌为红桃或草花且该角色判定区内无相应牌，
--		  令其将该牌分别视为【乐不思蜀】或【兵粮寸断】置于其判定区；否则你获得该牌。
Saorui_card = sgs.CreateSkillCard {
	name = "saorui",
	filter = function(self, targets, to_select)
		return #targets < 1 and not to_select:isKongcheng()
	end,
	on_use = function(self, room, source, targets)
		local target = targets[1]
		local room = target:getRoom()
		local card_id = room:askForCardChosen(source, target, "h", "saorui")
		room:showCard(target, card_id)
		local card = sgs.Sanguosha:getCard(card_id)
		local suit = card:getSuit()
		local judge_area = target:getJudgingArea()
		local has_le = false
		local has_bin = false
		for _, cd in sgs.qlist(judge_area) do
			if cd:isKindOf("indulgence") then
				has_le = true
			elseif cd:isKindOf("supply_shortage") then
				has_bin = true
			end
		end

		local vs_card
		if (suit == sgs.Card_Heart and not has_le) or (suit == sgs.Card_Club and not has_bin) then
			if suit == sgs.Card_Heart then
				vs_card = sgs.Sanguosha:cloneCard("indulgence", suit, card:getNumber())
			else
				vs_card = sgs.Sanguosha:cloneCard("supply_shortage", suit, card:getNumber())
			end
			vs_card:addSubcard(card)
			local card_use = sgs.CardUseStruct()
			card_use.from = target
			card_use.to:append(target)
			card_use.card = vs_card
			room:useCard(card_use)
			local move = sgs.CardsMoveStruct()
			move.card_ids:append(card_id)
			move.to = target
			move.to_place = sgs.Player_PlaceJudge
			move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_OVERRIDE, source:objectName(), self:objectName(), nil)
			--room:moveCards(move, true)
		else
			room:obtainCard(source, card_id, true)
		end
	end,
}

Saorui = sgs.CreateZeroCardViewAsSkill {
	name = "saorui",
	view_as = function(self)
		return Saorui_card:clone()
	end,
	enabled_at_play = function(self, player)
		return not player:hasUsed("#saorui")
	end,
}

--【星旺】结束阶段开始时，若你于弃牌阶段弃置了不少于当前体力值的牌，你可选择回复一点体力或摸两张牌。
Xingwang = sgs.CreateTriggerSkill {		--弃牌回血
	name = "Xingwang",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.BeforeCardsMove, sgs.EventPhaseStart},
	on_trigger = function(self, event, player, data)
		if event == sgs.EventPhaseStart then
			if player:getPhase() == sgs.Player_Finish then
				local discdnum = player:getMark("yangsheng")
				if discdnum >= player:getHp() and player:askForSkillInvoke(self:objectName(), data) then
					local room = player:getRoom()
					local choice = room:askForChoice(player, self:objectName(), "rec+draw")
					if choice == "rec" then
						local recoverByOne = sgs.RecoverStruct()
						recoverByOne.recover = 1
						recoverByOne.who = player
						room:recover(player, recoverByOne)
					else
						player:drawCards(2)
					end
				end
			elseif player:getPhase() == sgs.Player_RoundStart then
				player:setMark("yangsheng", 0)
			end
			return false
		elseif player:getPhase() == sgs.Player_Discard then
			local move = data:toMoveOneTime()
			local source = move.from
			if source and source:objectName() == player:objectName() then
				if move.to_place == sgs.Player_DiscardPile then
					for _,id in sgs.qlist(move.card_ids) do
						player:addMark("yangsheng")
					end
				end
			end
		end
		return false
	end
}

Wangrui:addSkill(Saorui)
Wangrui:addSkill(Xingwang)

sgs.LoadTranslationTable {
	["wangrui"] = "王睿",
	["saorui"] = "骚睿",
	[":saorui"] = "出牌阶段限一次，你可展示一名其他角色的一张手牌，若该牌为红桃/草花且该角色判定区内无相应牌，将该牌分别视为【乐不思蜀】/【兵粮寸断】置于其判定区；否则你获得该牌.",
	["Xingwang"] = "星旺",
	[":Xingwang"] = "结束阶段开始时，若你于弃牌阶段弃置了不少于当前体力值的牌，你可选择回复一点体力或摸两张牌。",
	["rec"] = "回复一点体力",
	["draw"] = "摸两张牌"
}