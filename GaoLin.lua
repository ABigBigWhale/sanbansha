module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--高林
Gaolin = sgs.General(extension, "gaolin", "qun", 4)

--【博识】每当其他角色使用的锦囊牌进入弃牌堆，你可用一张基本牌替换之，若该牌颜色相同，你摸一张牌。
Boshi = sgs.CreateTriggerSkill {
	name = "boshi",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.CardsMoveOneTime},
	can_trigger = function(self, target)
		if target then
			if target:isAlive() and target:hasSkill(self:objectName()) then
				if not target:isKongcheng() and not target:hasFlag("boshi_active") then
					has_card = false
					for _, cd in sgs.qlist(target:getHandcards()) do
						if cd:getTypeId() == sgs.Card_Basic then
							has_card = true
						end
					end
					return has_card
				end
			end
		end
		return false
	end,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local move = data:toMoveOneTime()
		local reason = move.reason.m_reason
		if not move.from or move.from:objectName() == player:objectName() then return end
		if move.to_place ~= sgs.Player_DiscardPile and reason ~= sgs.CardMoveReason_S_REASON_USE then return end
		local ids = move.card_ids
		for _, id in sgs.qlist(ids) do
			local card = sgs.Sanguosha:getCard(id)
			if card:getTypeId() == sgs.Card_Trick and player:askForSkillInvoke(self:objectName()) then
				room:setPlayerFlag(player, "boshi_active")
				local chosen = room:askForCard(player, ".Basic", "@boshi", sgs.QVariant(), sgs.Card_MethodDiscard, nil, false, self:objectName(), false)
				room:setPlayerFlag(player, "-boshi_active")
				if chosen and not chosen:isVirtualCard() then
					player:obtainCard(card)
					if card:sameColorWith(chosen) then
						player:drawCards(1)
					end
				end

			end
		end
	end
}

Gaolin:addSkill(Boshi)

sgs.LoadTranslationTable {
	["gaolin"] = "高林",
	["boshi"] = "博识",
	[":boshi"] = "每当一张非基本牌进入弃牌堆，你可用一张非基本牌手牌替换之，若该牌颜色不同，你摸一张牌。",
	["@boshi"] = "请选择一张用于替换的非基本牌手牌",
}