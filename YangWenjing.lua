module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--杨文靖
Yangwenjing = sgs.General(extension, "Yangwenjing", "wei", 3, false)

--【火爆】每当你受到【杀】或【决斗】造成的伤害，你可视作对该牌使用者使用了一张相同的牌。
San_Huobao = sgs.CreateTriggerSkill{
	name = "San_Huobao",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.Damaged},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local damage = data:toDamage()
		local card = damage.card
		local victim = damage.to
		local target = damage.from

		--player:drawCards(1)

		if victim:objectName() ~= player:objectName() then return end
		if target:objectName() == player:objectName() then return false end
		if not card:isKindOf("Slash") and not card:isKindOf("Duel") then return end
		if not target:isAlive() then return false end

		local id = card:getEffectiveId()
		if room:getCardPlace(id) == sgs.Player_PlaceTable then
			local card_data = sgs.QVariant()
			card_data:setValue(card)
			if room:askForSkillInvoke(player, self:objectName(), card_data) then
				local use = sgs.CardUseStruct()
				use.card = card
				use.from = player
				use.to:append(target)
				room:useCard(use)
			end
		elseif card:isVirtualCard() then
			local card_data = sgs.QVariant()
			if card:isKindOf("Slash") then
				local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
				card_data:setValue(slash)
				if room:askForSkillInvoke(player, self:objectName(), card_data) then
					slash:setSkillName(self:objectName())
					local use = sgs.CardUseStruct()
					use.card = slash
					use.from = player
					use.to:append(target)
					room:useCard(use)
				end
			elseif card:isKindOf("Duel") then
				local duel = sgs.Sanguosha:cloneCard("Duel", sgs.Card_NoSuit, 0)
				card_data:setValue(duel)
				if room:askForSkillInvoke(player, self:objectName(), card_data) then
					duel:setSkillName(self:objectName())
					local use = sgs.CardUseStruct()
					use.card = duel
					use.from = player
					use.to:append(target)
					room:useCard(use)
				end
			end
		end
	end
}

--【牙尖】出牌阶段限一次，你可令任意两名角色拼点，视作赢的一方对没赢的一方使用了一张【杀】，
--	 	  然后你获得双方的拼点牌。
San_Yajian_CD = sgs.CreateSkillCard {
	name = "San_Yajian",
	target_fixed = false,
	will_throw = true,
	filter = function(self, targets, to_select)
		return not to_select:isKongcheng() and #targets < 2
	end,
	feasible = function(self, targets)
		return #targets == 2
	end,
	on_use = function(self, room, source, targets)
		targets[1]:pindian(targets[2], "San_Yajian", nil)
	end
}

San_Yajian_VA = sgs.CreateViewAsSkill{
	name = "San_Yajian",
	n = 1,
	view_filter = function(self, selected, to_select)
		return not to_select:isEquipped()
	end,
	view_as = function(self, cards)
		if #cards == 1 then
			local card = San_Yajian_CD:clone()
			card:addSubcard(cards[1])
			card:setSkillName(self:objectName())
			return card
		end
	end,
	enabled_at_play = function(self, player)
		return not player:hasUsed("#San_Yajian")
	end
}

San_Yajian_PD = sgs.CreateTriggerSkill{
	name = "#San_Yajian_PD",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.Pindian},
	view_as_skill = San_Yajian_VA,
	on_trigger = function(self, event, player, data)
		local pindian = data:toPindian()
		if pindian.reason == "San_Yajian" then
			local card_1 = pindian.from_card
			local card_2 = pindian.to_card
			local fromNumber = card_1:getNumber()
			local toNumber = card_2:getNumber()
			if fromNumber ~= toNumber then
				local winner
				local loser
				if fromNumber > toNumber then
					winner = pindian.from
					loser = pindian.to
				else
					winner = pindian.to
					loser = pindian.from
				end
				if winner:canSlash(loser, nil, false) then
					local room = player:getRoom()
					local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
					slash:setSkillName("San_Yajian")
					local card_use = sgs.CardUseStruct()
					card_use.from = winner
					card_use.to:append(loser)
					card_use.card = slash
					room:useCard(card_use, false)
				end
			end
			local room = player:getRoom()
			local yang = room:findPlayerBySkillName("San_Yajian")
			if card_1 then
				yang:obtainCard(card_1)
			end
			if card_2 then
				yang:obtainCard(card_2)
			end
		end
		return false
	end,
	can_trigger = function(self, target)
		return target
	end,
	--priority = -1
}

Yangwenjing:addSkill(San_Huobao)
Yangwenjing:addSkill(San_Yajian_VA)
Yangwenjing:addSkill(San_Yajian_PD)


sgs.LoadTranslationTable{
	["Yangwenjing"] = "杨文靖",
	["San_Huobao"] = "火爆",
	[":San_Huobao"] = "每当你受到【杀】或【决斗】造成的伤害后，你可视作对该牌使用者使用了一张相同的牌。",
	["San_Yajian"] = "八卦",
	[":San_Yajian"] = "出牌阶段限一次，你可弃置一张手牌，并令任意两名角色拼点，视作赢的一方对没赢的一方使用了一张【杀】，然后你获得双方的拼点牌。"
}