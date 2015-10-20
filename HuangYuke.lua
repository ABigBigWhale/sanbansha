module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--黄雨可
Huangyuke = sgs.General(extension, "Huangyuke", "wu", 3, true)

--【歌喉】当一名角色进入濒死状态时，你可弃置其两张牌令其回复至1体力，或若其没有手牌，你可杀死该角色。
Gehou = sgs.CreateTriggerSkill {
	name = "Gehou",
	events = {sgs.Dying},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local dying = data:toDying()
		local target = dying.who

		if target:getHp() > 0 then return end

		local canRec = false
		local canKill = false

		if target:getHandcardNum() + target:getEquips():length() >= 2 then
			canRec = true
		end
		if target:isKongcheng() then
			canKill = true
		end

		if not canRec and not canKill then return false end
		if not player:askForSkillInvoke(self:objectName()) then return false end

		if canRec and canKill then
			local choice = room:askForChoice(player, self:objectName(), "heal+kill")
			if choice == "heal" then
				canKill = false
			elseif choice == "kill" then
				canRec = false
			end
		end
		if canRec then
			local hp = target:getHp()
			local rec = 1 - hp
			local thrown = 0
			while target:getHp() <= 0 and rec > 0 do
				local id = room:askForCardChosen(player, target, "he", self:objectName())
				local card = sgs.Sanguosha:getCard(id)
				if not target:isJilei(card) then
					room:throwCard(card, target)
				end
				thrown = thrown + 1
				if thrown == 2 then
					local recover = sgs.RecoverStruct()
					recover.recover = rec
					recover.who = player
					room:recover(target, recover)
				end
			end
			return target:getHp() > 0
		end
		if canKill then
			local death = sgs.DamageStruct()
			death.card = nil
			death.from = player
			death.to = target
			room:killPlayer(target, death)
			return not target:isAlive()
		end
		return false
	end
}

--【水手】出牌阶段限一次，你可以收回你于该阶段上一张进入弃牌堆的牌（同时进入则一起收回）。

ShuishouCard = sgs.CreateSkillCard {
	name = "ShuishouCard",
	target_fixed = true,
	will_throw = true,
	on_use = function(self, room, source, targets)
		if source:isAlive() then
			local room = source:getRoom()
			local tag = room:getTag("ShuishouTag")

			if tag then
				local str = tag:toString()
				local toGet = tag:toString():split("+")
				room:removeTag("ShuishouTag")
				local toGetList = sgs.IntList()

				for i = 1, #toGet, 1 do
					local card_data = toGet[i]

					if card_data ~= nil then
						if card_data ~= "" then
							local card_id = tonumber(card_data)
							toGetList:append(card_id)
						end
					end
				end

				if toGetList:length() > 0 then
					local cardMove = sgs.CardsMoveStruct()
					cardMove.to = source
					cardMove.to_place = sgs.Player_PlaceHand
					cardMove.card_ids = toGetList
					room:moveCardsAtomic(cardMove, true)
					room:setPlayerFlag(source, "-shou")
				end
			end
		end
	end,
}

Shuishou = sgs.CreateZeroCardViewAsSkill {
	name = "Shuishou",
	view_filter = function(self, to_select)
		return false
	end,
	view_as = function(self)
		local skillCard = ShuishouCard:clone()
		skillCard:setSkillName(self:objectName())
		return skillCard
	end,
	enabled_at_play = function(self, player)
		return not player:hasUsed("#ShuishouCard") and player:hasFlag("shou")
	end
}


ShuishouRC = sgs.CreateTriggerSkill {
	name = "#Shuishou",
	events = {sgs.CardsMoveOneTime},
	on_trigger = function(self, event, player, data)
		if player:getPhase() ~= sgs.Player_Play then return end
		local room = player:getRoom()
		local move = data:toMoveOneTime()
		if move.from:objectName() ~= player:objectName() then return false end
		if player:hasUsed("#ShuishouCard") then return false end

		if move.to_place == sgs.Player_DiscardPile then
			room:setPlayerFlag(player, "shou")
			local cardStr = ""
			local card_ids = sgs.IntList()
			for _, id in sgs.qlist(move.card_ids) do
				if id ~= -1 then
					if cardStr == "" then
						cardStr = tostring(id)
					else
						cardStr = cardStr.."+"..tostring(id)
					end
				end
			end
			room:setTag("ShuishouTag", sgs.QVariant(cardStr))
		end

		return false
	end
}

Huangyuke:addSkill(Shuishou)
Huangyuke:addSkill(ShuishouRC)
extension:insertRelatedSkills("Shuishou", "#Shuishou")
Huangyuke:addSkill(Gehou)

sgs.LoadTranslationTable{
	["Huangyuke"] = "黄雨可",
	["Gehou"] = "歌喉",
	[":Gehou"] = "当一名角色进入濒死状态时，你可弃置其两张牌令其回复至1体力，若其没有手牌，你可令其直接死亡。",
	["Shuishou"] = "水手",
	["shuishou"] = "水手",
	[":Shuishou"] = "出牌阶段限一次，你可以收回你于该阶段上一张进入弃牌堆的牌（同时进入则一起收回）。",
	["heal"] = "弃置该角色两张牌并令其回复至1体力",
	["kill"] = "杀死该角色",
	["$Gehou1"] = "砰！",
}
