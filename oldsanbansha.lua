module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--电教
Dianjiao = sgs.General(extension, "Dianjiao", "shu", 4)

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

----------------------------------------------------------

--陈杨弃
Chenyangqi = sgs.General(extension, "Chenyangqi", "wu", 4)

--【扬弃】准备阶段和结束阶段开始时，你可令一名其他角色交给你X+1张牌（X为你已损失体力值），
--        然后你交给该角色两张牌.

YangqiGiveCard = sgs.CreateSkillCard {
	name = "YangqiGiveCard",
	target_fixed = true,
	filter = false,
	will_throw = false,
	on_use = function(self, room, source)
		local room = source:getRoom()
		local target
		local others = room:getOtherPlayers(player)
		for _, p in sgs.qlist(others) do
			if p:hasFlag("YangqiToGive") then
				target = p
				room:setPlayerFlag(target, "-YangqiToGive")
				break
			end
		end
		room:obtainCard(target, self, false)
	end
}

YangqiGiveVS = sgs.CreateViewAsSkill{
	name = "YangqiGive",
	n = 999,
	view_filter = function(self, selected, to_select)
		return #selected < 2
	end,
	view_as = function(self, cards)
		if #cards == math.min(2, sgs.Self:getHandcardNum()) then
			local card = YangqiGiveCard:clone()
			for _,cd in pairs(cards) do
				card:addSubcard(cd)
			end
			return card
		end
	end,
	enabled_at_play = function(self, player)
		return false
	end,
	enabled_at_response = function(self, player, pattern)
		return pattern == "@@YangqiGive!"
	end,
}


YangqiCard = sgs.CreateSkillCard {
	name = "YangqiCard",
	target_fixed = false,
	will_throw = false,
	filter = function(self, targets, to_select, player)
		return to_select:objectName() ~= player:objectName() and #targets < 1
	end,
	on_use = function(self, room, source, targets)
		local target = targets[1]
		local room = source:getRoom()
		local count = source:getLostHp() + 1
		if not target:isKongcheng() then
			local cards = room:askForExchange(target, self:objectName(), count)
			room:moveCardTo(cards, source, sgs.Player_PlaceHand)
		end
		room:setPlayerFlag(target, "YangqiToGive")
		room:askForUseCard(source, "@@YangqiGive!", "@YangqiGive")
	end
}


YangqiVA = sgs.CreateZeroCardViewAsSkill {
	name = "Yangqi",
	view_as = function(self)
		local skillCard = YangqiCard:clone()
		skillCard:setSkillName(self:objectName())
		return skillCard
	end,
	enabled_at_response = function(self, player, pattern)
		return pattern == "@@Yangqi!"
	end,
	enabled_at_play = function(self, player)
		return false
	end
}


Yangqi = sgs.CreateTriggerSkill {
	name = "Yangqi",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseStart},
	view_as_skill = YangqiVA,
	on_trigger = function(self, event, player, data)
		if player:getPhase() == sgs.Player_Start or
		   player:getPhase() == sgs.Player_Finish then
			local room = player:getRoom()
			if not room:askForSkillInvoke(player, self:objectName()) then
				return false
			end
			room:askForUseCard(player, "@@Yangqi!", "@Yangqi")
		end
		return false
	end
}

XiaochangCard = sgs.CreateSkillCard {
	name = "xiaochangcard",
	target_fixed = true,
	will_throw = true,
	on_use = function(self, room, source, targets)
		if self and self:getSubcards() then
			room:removePlayerMark(source, "xiaochang_use")
			for _, p in sgs.qlist(room:getOtherPlayers(source)) do
				if p:isAlive() then
					room:cardEffect(self, source, p)
				end
			end
		end
	end,
	on_effect = function(self, effect)
		local target = effect.to
		local yangqi = effect.from
		local room = yangqi:getRoom()
		local card_id = self:getSubcards()
		local card = sgs.Sanguosha:getCard(card_id:first())
		local num = card:getNumber()
		if not target:isKongcheng() then
			room:fillAG(card_id, target)
			local data = sgs.QVariant()
			data:setValue(yangqi)
			local discarded = room:askForCard(target, ".|.|.|hand", "xiaochang_prompt", data, sgs.Card_MethodDiscard)
			local discarded_num = discarded:getNumber()
			if discarded_num == num then
				if target:isWounded() then
					local choice = room:askForChoice(target, "xiaochang", "rec+draw3")
					if choice == "rec" then
						room:recover(target, sgs.RecoverStruct(target))
					else
						target:drawCards(3)
					end
				else
					target:drawCards(3)
				end
			else
				yangqi:drawCards(1)
			end
			room:clearAG()
		else
			yangqi:drawCards(1)
		end
	end
}

XiaochangVS = sgs.CreateOneCardViewAsSkill {
	name = "xiaochang",
	view_filter = function(self, to_select)
		return not to_select:isEquipped()
	end,
	view_as = function(self, originalCard)
		local card = XiaochangCard:clone()
		card:addSubcard(originalCard)
		card:setSkillName("xiaochang")
		return card
	end,
	enabled_at_play = function(self, player)
		return player:getMark("@xiaochang") > 0
	end
}

Xiaochang = sgs.CreateTriggerSkill {
	name = "xiaochang",
	frequency = sgs.Skill_Limited,
	events = sgs.GameStart,
	view_as_skill = XiaochangVS,
	on_trigger = function(self, event, player, data)
		player:setMark("@xiaochang", 1)
	end
}

Chenyangqi:addSkill(Yangqi)
Chenyangqi:addSkill(YangqiGiveVS)
Chenyangqi:addSkill(Xiaochang)


sgs.LoadTranslationTable{
	["Chenyangqi"] = "陈杨弃",
	["Yangqi"] = "扬弃",
	["yangqi"] = "扬弃",
	["@Yangqi"] = "扬",
	["@YangqiGive"] = "弃",
	["~Yangqi"] = "请选择一名发动“扬弃”的目标角色令其交给你手牌",
	["~YangqiGive"] = "请选择两张牌（包括装备区内的牌）交给该角色",
	["rec"] = "回复一点体力",
	["draw3"] = "摸三张牌",
	["xiaochang"] = "笑场",
	["xiaochang_prompt"] = "请弃置一张手牌"
}

-----------------------------------------------------------

--张珂
Zhangke = sgs.General(extension, "Zhangke", "wu", 5)

--【刷卷】摸牌阶段开始时，你可放弃摸牌，改为展示牌堆顶的一张牌，若该牌不为红桃牌，你获得之且你可
--		  重复此流程。
San_Shuajuan = sgs.CreateTriggerSkill {
	name = "San_Shuajuan",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseStart},
	on_trigger = function(self, event, player, data)
		if not player then return end
		if player:getPhase() ~= sgs.Player_Draw then return false end

		local room = player:getRoom()
		local activ = false
		while player:askForSkillInvoke(self:objectName()) do
			local ids = room:getNCards(1, false)
			local move = sgs.CardsMoveStruct()
			move.card_ids = ids
			move.to = player
			move.to_place = sgs.Player_PlaceTable
			move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_TURNOVER, player:objectName(), self:objectName(), nil)
			room:moveCardsAtomic(move, true)
			room:getThread():delay(1000)
			local id = ids:at(0)
			local card = sgs.Sanguosha:getCard(id)
			local suit = card:getSuit()
			activ = true
			if suit ~= sgs.Card_Heart then
				player:obtainCard(card)
			else
				room:throwCard(card, nil, nil)
				return true
			end
		end
		return activ
	end
}

Zhangke:addSkill(San_Shuajuan)

sgs.LoadTranslationTable{
	["Zhangke"] = "张珂",
	["&Zhangke"] = "珂霸",
	["San_Shuajuan"] = "刷卷",
	[":San_Shuajuan"] = "摸牌阶段，你可放弃摸牌，改为展示牌堆顶的一张牌，若该牌不为红桃牌，你获得之且你可重复此流程。"
}

---------------------------------------------------------------------------------------------

--毛率宇
Maoshuaiyu = sgs.General(extension, "Maoshuaiyu", "wu", 4)

--【间餐】出牌阶段限两次，你可将一张红桃手牌视作【五谷丰登】使用。锁定技，你响应【五谷丰登】时可额外获得
--		  一张所展示牌。
San_Jiancan_TK = sgs.CreateTriggerSkill {
	name = "#San_Jiancan_TK",
	events = {sgs.CardUsed},
	frequency = sgs.Skill_Compulsory,
	can_trigger = function(self, target)
		return target
	end,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local thread = room:getThread()
		if event == sgs.CardUsed and room:findPlayerBySkillName(self:objectName()) then
			local use = data:toCardUse()
			if use.card:isKindOf("AmazingGrace") then
				local skillowners_count = 0
				local newtargets = sgs.SPlayerList()
				for _,p in sgs.qlist(room:getAllPlayers()) do
					newtargets:append(p)
					if p:hasSkill(self:objectName()) then
						newtargets:append(p)
						skillowners_count = skillowners_count + 1
					end
				end
				local list = room:getNCards(newtargets:length() - skillowners_count)
				room:fillAG(list)
				for _,p in sgs.qlist(room:getAllPlayers()) do
					if list:isEmpty() then
						room:clearAG()
						break
					end
					local new_data = sgs.QVariant()
					local effect = sgs.CardEffectStruct()
					effect.from = use.from
					effect.card = use.card
					effect.to = p
					new_data:setValue(effect)
					room:setTag("SkipGameRule", sgs.QVariant(true))
					if not thread:trigger(sgs.CardEffect, room, p, new_data) then
						room:setTag("SkipGameRule", sgs.QVariant(true))
						if not thread:trigger(sgs.CardEffected, room, p, new_data) then
							if not room:isCanceled(effect) then
								local id = room:askForAG(p, list, false, "amazing_grace")
								room:takeAG(p, id)
								list:removeOne(id)
								if p:hasSkill(self:objectName()) then
									id = room:askForAG(p, list, false, "amazing_grace")
									room:takeAG(p, id)
									list:removeOne(id)
								end
							end
						end
					end
				end
			for _,id in sgs.qlist(list) do
				room:takeAG(NULL, id)
			end
			room:clearAG()
			room:setTag("SkipGameRule", sgs.QVariant(true))
			thread:trigger(sgs.CardFinished, room, player, data)
			return true
			end
		end
	end
}

San_Jiancan_LM = sgs.CreateTriggerSkill {
	name = "#San_Jiancan_LM",
	events = {sgs.CardUsed},
	frequency = sgs.Skill_Compulsory,
	on_trigger = function(self, event, player, data)
		if player:isDead() or not player:hasSkill("San_Jiancan") then return end
		local room = player:getRoom()
		local use = data:toCardUse()
		local card = use.card
		if card:getSkillName() == "San_Jiancan" then
			room:setPlayerFlag(player, "jiancan_used")
		end
		return false
	end
}

San_Jiancan_VA = sgs.CreateViewAsSkill {
	name = "San_Jiancan",
	n = 1,
	view_filter = function(self, selected, to_select)
		return not to_select:isEquipped() and to_select:isRed()
	end,
	view_as = function(self, cards)
		if #cards == 1 then
			local card = cards[1]
			local id = card:getId()
			local va_card = sgs.Sanguosha:cloneCard("AmazingGrace", card:getSuit(), card:getNumber())
			va_card:addSubcard(id)
			va_card:setSkillName(self:objectName())
			return va_card
		end
	end,
	enabled_at_play = function(self, player)
		return (not player:isKongcheng()) and (not player:hasFlag("jiancan_used"))
	end
}

Maoshuaiyu:addSkill(San_Jiancan_VA)
Maoshuaiyu:addSkill(San_Jiancan_LM)
Maoshuaiyu:addSkill(San_Jiancan_TK)

sgs.LoadTranslationTable{
	["Maoshuaiyu"] = "毛率宇",
	["&Maoshuaiyu"] = "毛毛",
	["San_Jiancan"] = "间餐",
	[":San_Jiancan"] = "出牌阶段限一次，你可将一张红色手牌视作【五谷丰登】使用。锁定技，你响应【五谷丰登】时额外获得一张所展示牌。"
}

---------------------------------------------------------------------------------------

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
	[":San_Huobao"] = "每当你受到【杀】或【决斗】造成的伤害，你可视作对该牌使用者使用了一张相同的牌。",
	["San_Yajian"] = "牙尖",
	[":San_Yajian"] = "出牌阶段限一次，你可弃置一张手牌，并令任意两名角色拼点，视作赢的一方对没赢的一方使用了一张【杀】，然后你获得双方的拼点牌。"
}

--------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------

--程老
Chenglao = sgs.General(extension, "Chenglao", "qun", 3, false)

--【听写】出牌阶段限一次，你可将一张手牌暗置于你的武将牌上，再指定至多两名其他角色各打出一张手牌，然后
--		  你弃置该牌，每有一名角色未能打出你弃置牌类型的牌，你对其造成一点伤害，否则你回复一点体力并令
--		  其摸两张牌。
TingxieCard = sgs.CreateSkillCard {
	name = "TingxieCard",
	target_fixed = false,
	filter = function(self, targets, to_select)
		return #targets < 2 and to_select:objectName() ~= sgs.Self:objectName()
	end,
	feasible = function(self, targets)
		return #targets > 0
	end,
	will_throw = false,
	on_use = function(self, room, source, targets)
		local id = self:getSubcards():first()
		local card  = sgs.Sanguosha:getCard(id)
		local room = source:getRoom()
		source:addToPile("Tingxie", id, false)
		local corr = {false, false, false}
		for i = 1, #targets, 1  do
			if not targets[i]:isKongcheng() then
				local data = sgs.QVariant()
				data:setValue(source)
				local cardA = room:askForCard(targets[i], ".|.|.|hand", "@Tingxie-discard", data, sgs.Card_MethodResponse, source, false)
				if cardA and cardA:getType() == card:getType() then
					corr[i] = true
				end
			end
		end
		room:throwCard(id, source, source)
		for i = 1, #targets, 1 do
			if corr[i] then
				local rec = sgs.RecoverStruct()
				rec.who = source
				room:recover(source, rec)
				room:drawCards(targets[i], 2, "Tingxie")
			else
				local dam = sgs.DamageStruct()
				dam.from = source
				dam.to = targets[i]
				dam.reson = "Tingxie"
				room:damage(dam)
			end
		end
	end
}

Tingxie = sgs.CreateViewAsSkill {
	name = "Tingxie",
	n = 1,
	view_filter = function(self, selected, to_select)
		return not to_select:isEquipped()
	end,
	view_as = function(self, cards)
		if #cards == 1 then
			local originalCard = cards[1]
			local card = TingxieCard:clone()
			card:addSubcard(originalCard)
			card:setSkillName("Tingxie")
			return card
		end
	end,
	enabled_at_play = function(self, player)
		return not player:hasUsed("#TingxieCard")
	end,
}

Chenglao:addSkill(Tingxie)

--【肃静】锁定技，你的回合内，其他角色视为无技能。

Sujing = sgs.CreateTriggerSkill {
	name = "Sujing",
	frequency = sgs.Skill_Compulsory,
	events = {sgs.EventPhaseChanging, sgs.Death},
	can_trigger = function(self, target)
		return target
	end,
	on_trigger = function(self, event, player, data)
		if not player then return end
		local room = player:getRoom()
		local splayer = room:findPlayerBySkillName(self:objectName())
		local change = data:toPhaseChange()
		local others = room:getOtherPlayers(splayer)

		if event == sgs.EventPhaseChanging and
		   player:objectName() == splayer:objectName() then

			if change.to == sgs.Player_RoundStart then

				--get player skills
				for _, p in sgs.qlist(others) do
					if p:getMark(self:objectName()) == 0 then
						local skill_list = p:getVisibleSkillList()
						local player_string = p:objectName()
						local skill_string = ""
						for _, sk in sgs.qlist(skill_list) do
							if sk:getLocation() == sgs.Skill_Right then
								if skill_string == "" then
									skill_string = sk:objectName()
								else
									skill_string = skill_string.."+"..sk:objectName()
								end
							else
								skill_list:removeOne(sk)
							end
						end
						room:setPlayerMark(p, self:objectName(), 1)
						room:setTag(self:objectName()..":"..p:objectName(), sgs.QVariant(skill_string))
						--detach skills
						for _, sk in sgs.qlist(skill_list) do
							room:detachSkillFromPlayer(p, sk:objectName())
						end
					end
				end

			elseif change.to == sgs.Player_NotActive then
				--return skills
				for _, p in sgs.qlist(others) do
					if p:isAlive() then
						if p:getMark(self:objectName()) == 1 then
							local tag = p:getTag(self:objectName()..":"..p:objectName())
							if tag then
								local skills = tag:toString():split("+")
								room:removeTag(self:objectName()..":"..p:objectName())
								if skills ~= "" then
									for i = 1, #skills, 1 do
										local skill_name = skills[i]
										room:attachSkillToPlayer(p, "shuishou")
										room:attachSkillToPlayer(p, skill_name)
										room:removePlayerMark(p, self:objectName())
									end
								end
							end
						end
					end
				end

			elseif event == sgs.Death then
				--when death
				local death = data:toDeath()
				local victim = death.who
				--self dies
				if victim:objectName() == splayer:objectName() then
					for _, p in sgs.qlist(others) do
						if p:isAlive() then
							if p:getMark(self:objectName()) == 1 then
								local tag = p:getTag(self:objectName()..":"..p:objectName())
								if tag then
									local skills = tag:toString():split("+")
									room:removeTag(self:objectName()..":"..p:objectName())
									if skills ~= "" then
										for i = 1, #skills, 1 do
											local skill_name = skills[i]
											room:attachSkillToPlayer(p, skill_name)
											room:removePlayerMark(p, self:objectName())
										end
									end
								end
							end
						end
					end
				--others die
				elseif victim:getMark(self:objectName()) == 1 then
					local tag = p:getTag(self:objectName()..":"..p:objectName())
					if tag then
						local skills = tag:toString():split("+")
						room:removeTag(self:objectName()..":"..p:objectName())
						if skills ~= "" then
							for i = 1, #skills, 1 do
								local skill_name = skills[i]
								room:attachSkillToPlayer(p, skill_name)
								room:removePlayerMark(p, self:objectName())
							end
						end
					end
				end
			end
		end
	end,
}

--Chenglao:addSkill(Sujing)

sgs.LoadTranslationTable{
	["Chenglao"] = "程老",
	["Tingxie"] = "听写",
	["@Tingxie-discard"] = "请提交一张听写的答案。",
	["~Tingxie-discard"] = "选择一张手牌->点击确定",
	["Sujing"] = "肃静",
	[":Tingxie"] = "出牌阶段限一次，你可将一张手牌暗置于你的武将牌上，再指定至多两名其他角色各打出一张手牌，然后你弃置该牌，每有一名角色未能打出你弃置牌类型的牌，你对其造成一点伤害，否则你回复一点体力并令其摸两张牌。",
}

---------------------------------------------------------------------------------

--王欣馨
Wangxinxin = sgs.General(extension, "Wangxinxin", "wu", 3, false)

--【歌会】出牌阶段结束后，若你无手牌或所有手牌颜色均相同，你可展示之并摸两张牌，然后跳过此回合的弃牌阶段。
San_Gehui = sgs.CreateTriggerSkill {
	name = "San_Gehui",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseChanging},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local change = data:toPhaseChange()
		if change.to ~= sgs.Player_Discard then return false end

		local same_color = true
		if not player:isKongcheng() then
			local cards = player:getHandcards()
			local color = cards:first():isBlack()
			for _,card in sgs.qlist(cards) do
				if card:isBlack() ~= color then
					same_color = false
					break
				end
			end
		end

		if same_color then
			if player:askForSkillInvoke(self:objectName()) then
				room:showAllCards(player)
				player:drawCards(2)
				player:skip(sgs.Player_Discard)
			end
		end
	end
}

--【掌击】你的回合外，每当你失去牌，你可弃置一张黑色牌并选择攻击范围内的一名男性角色，对其造成一点伤害。


Wangxinxin:addSkill(San_Gehui)

sgs.LoadTranslationTable{
	["Wangxinxin"] = "王昕馨",
	["San_Gehui"] = "歌会",
	[":San_Gehui"] = "出牌阶段结束后，若你无手牌或所有手牌颜色均相同，你可展示之并摸两张牌，然后跳过此回合的弃牌阶段。",
}

---------------------------------------------------------------------------------

--刘洪宇
Liuhongyu = sgs.General(extension, "Liuhongyu", "qun", 3, true)

--【好人】出牌阶段对每名角色限一次，你可指定一名角色并弃置一张黑色手牌，令其摸两张牌。

--【演技】回合结束时，你可指定一名

--【推倒】每当一名角色恢复一点体力后，你可弃置一张装备牌令其失去1点体力。

---------------------------------------------------------------------------------

--宋劲坤
Songjingkun = sgs.General(extension, "Songjingkun", "qun", 4, true)


--【阖棺】其他角色弃牌阶段开始时，你可将一张装备牌交给该角色并令其使用之，然后令其摸两张牌，若如此做，该角色于
--		  此阶段每弃置一张与该装备牌相同颜色的手牌，你对其造成一点伤害，直至其进入濒死状态。

HeguanCard = sgs.CreateSkillCard {
	name = "HeguanCard",
	target_fixed = true,
	will_throw = false,
	on_use = function(self, room, source, targets)
		local target = room:getCurrent()
		local splayer = room:findPlayerBySkillName("Heguan")
		target:obtainCard(self)
		local id = self:getSubcards():first()
		local equip = sgs.Sanguosha:getCard(id)
		local useEquip = sgs.CardUseStruct()
		useEquip.card = equip
		useEquip.from = target
		room:useCard(useEquip)
		target:drawCards(2)
		room:setPlayerFlag(target, "HeguanTarget")
		room:setTag("HeguanEquip", sgs.QVariant(id))
	end

}

HeguanVS = sgs.CreateViewAsSkill {
	name = "Heguan",
	n = 1,
	view_filter = function(self, selected, to_select)
		return to_select:isKindOf("EquipCard") and #selected < 1
	end,
	view_as = function(self, cards)
		if #cards == 1 then
			local card = HeguanCard:clone()
			card:addSubcard(cards[1])
			return card
		end
	end,
	enabled_at_play = function(self, player)
		return false
	end,
	enabled_at_response = function(self, player, pattern)
		return pattern == "@@Heguan"
	end
}

Heguan = sgs.CreateTriggerSkill {
	name = "Heguan",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseStart, sgs.BeforeCardsMove, sgs.CardsMoveOneTime, sgs.Dying},
	view_as_skill = HeguanVS,
	can_trigger = function(self, target)
		return true
	end,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local source = room:findPlayerBySkillName(self:objectName())
		if not source then return false end
		local target = room:getCurrent()
		if not target then return end
		local invoke = false
		for _, cd in sgs.qlist(source:getHandcards()) do
			if cd:isKindOf("EquipCard") then
				invoke = true
				break
			end
		end
		if source:hasEquip() then invoke = true end
		if not invoke then return false end

		if event == sgs.EventPhaseStart then
			if player:objectName() ~= source:objectName() then
				if player:getPhase() == sgs.Player_Discard then
					if source:askForSkillInvoke(self:objectName()) then
						room:askForUseCard(source, "@@Heguan", "@heguancard")
					end
				elseif target and target:getPhase() == sgs.Player_Finish and target:hasFlag("HeguanTarget") then
					room:removeTag("HeguanEquip")
					--room:removeTag("HeguanDamage")
					room:setPlayerFlag(target, "-HeguanTarget")
				end
			end
			
		end
		---------
		if event == sgs.BeforeCardsMove then
			if target:getPhase() == sgs.Player_Discard and target:hasFlag("HeguanTarget") then
				local move = data:toMoveOneTime()
				local from = move.from
				if not from then return false end
				if from:objectName() ~= target:objectName() then return false end
				if not move.from_places:contains(sgs.Player_PlaceHand) then return false end
				if move.to_place ~= sgs.Player_DiscardPile then return false end
				local tag = room:getTag("HeguanEquip")
				local equipId = tag:toInt()
				local equipCard = sgs.Sanguosha:getCard(equipId)

				local discard = move.card_ids
				for _, id in sgs.qlist(discard) do
					local cardThrown = sgs.Sanguosha:getCard(id)
					if not target:hasFlag("HeguanTarget") then break end
					if target:getHp() < 1 then break end
					if cardThrown:sameColorWith(equipCard) and not cardThrown:hasFlag("Heguan_used") then
						discard:removeOne(id)
						room:setCardFlag(cardThrown, "Heguan_same")
					end
				end
			end
		end
			--------------
		if event == sgs.CardsMoveOneTime then
			local target = room:getCurrent()
			if target:getPhase() == sgs.Player_Discard and target:hasFlag("HeguanTarget") then
				local move = data:toMoveOneTime()
				local from = move.from
				if not from then return false end
				if from:objectName() ~= target:objectName() then return false end
				if not move.from_places:contains(sgs.Player_PlaceHand) then return false end
				if move.to_place ~= sgs.Player_DiscardPile then return false end

				local damage = sgs.DamageStruct()
				damage.from = source
				damage.to = target
				damage.damage = 1
				
				local cards = move.card_ids
				for _, id in sgs.qlist(cards) do
					local cd = sgs.Sanguosha:getCard(id)
					if cd:hasFlag("Heguan_same") then
						room:damage(damage)
						--source:drawCards(1)
						cd:setFlags("-Heguan_same")
						cd:setFlags("Heguan_used")
					end
					if target:getHp() < 1 then break end
				end
			end
		end
		--------------
		
		if event == sgs.Dying then
			local dying = data:toDying()
			if dying.damage.from:objectName() == source:objectName() and dying.who:hasFlag("HeguanTarget") then
				room:setPlayerFlag(dying.who, "-HeguanTarget")
				room:removeTag("HeguanEquip")
				--room:removeTag("HeguanDamage")
				--source:drawCards(1)
			end
		end
		return false
	end,
}

Songjingkun:addSkill(Heguan)

sgs.LoadTranslationTable{
	["Songjingkun"] = "宋劲坤",
	["Heguan"] = "运球",
	[":Heguan"]= "其他角色弃牌阶段开始时，你可将一张装备牌交给该角色并令其使用之，然后令其摸两张牌，若如此做，该角色于此阶段每有一张与该牌颜色相同的手牌进入弃牌堆，你对其造成一点伤害，直至其进入濒死状态为止。",
	["@Heguan"] = "运球",
	["~Heguan"] = "请选择一张装备牌交给该角色",
	["@heguancard"] = "运球",
	["HeguanCard"] = "运球",
}

-------------------------------------------

--张宇翔
Zhangyuxiang = sgs.General(extension, "Zhangyuxiang", "qun", 3, true)

--【打呼】出牌阶段开始时，若你的武将牌上没有牌，你可以弃置一张装备牌或两张手牌将一名男性角色一个区域（手
--		  牌区，装备区，判定区）的所有牌置于你的武将牌上，称为“呼”。该角色受到伤害或其下个回合结束时，若
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
		if #selected > 0 then
			if selected[1]:isKindOf("EquipCard") then
				return false
			else
				return not to_select:isKindOf("EquipCard")
			end
		end
		return true
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
			local available = false
			if event == sgs.EventPhaseChanging then
				--if player:objectName() == dudu:objectName() then return end
				local change = data:toPhaseChange()
				local nextphase = change.to
				if nextphase ~= sgs.Player_NotActive then return end
				if player:getMark("DahuTarget") == 0 then return end
				available = true
			else
				local damage = data:toDamage()
				--if player:objectName() == dudu:objectName() then return end
				if damage.to:objectName() ~= player:objectName() then return end
				if player:getMark("DahuTarget") == 0 then return end
				available = true
			end

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
		end
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
	[":Dahu"] = "出牌阶段开始时，若你的武将牌上没有牌，你可以弃置一张装备牌或两张手牌将一名男性角色一个区域（手牌区，装备区，判定区）的所有牌置于你的武将牌上，称为“呼”。该角色受到伤害或其下个回合结束时，选择：1.获得所有“呼”；2.获得你对应区域的所有牌，然后令你获得所有“呼”。",
	["DahuInvoke"] = "请选择一个目标角色发动“打呼”",
	["@dahuuse"] = "请弃置一张装备牌或两张手牌",
	["~dahuuse"] = "（判定区、装备区、手牌区）",
	["hu"] = "呼",
	["hands"] = "手牌区",
	["equips"] = "装备区",
	["judges"] = "判定区",
	["Qingge"] = "情歌",
}

-----------------------------------------------

--赵西航
Zhaoxihang = sgs.General(extension, "Zhaoxihang", "wu", 4, true)

--【搏命】摸牌阶段开始时，你可放弃摸牌，并摸数量等同于你当前手牌数的牌，然后若你手牌数大于手牌上限数，你指定一名其
--		  他角色依次弃置你手牌至其数量等于你的手牌上限数。
Boming = sgs.CreateTriggerSkill {
	name = "Boming",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseStart},
	on_trigger = function(self, event, player, data)
		if player:getPhase() ~= sgs.Player_Draw then return end
		if player:isSkipped(sgs.Player_Draw) then return end
		if player:isKongcheng() then return false end
		if not player:askForSkillInvoke(self:objectName()) then return false end
		local room = player:getRoom()
		room:drawCards(player, player:getHandcardNum(), self:objectName())
		local target
		if player:getHandcardNum() > player:getMaxCards() then
			target = room:askForPlayerChosen(player, room:getOtherPlayers(player), self:objectName())
		end
		while player:getHandcardNum() > player:getMaxCards() do
			local id = room:askForCardChosen(target, player, "h", self:objectName())
			local card = sgs.Sanguosha:getCard(id)
			if not target:isJilei(card) then
				room:throwCard(card, player, target)
			end
		end
		return true
	end,
}

--【黑马】锁定技，若你已受伤，你的手牌上限为你的体力上限+你已损失体力值
Heima = sgs.CreateMaxCardsSkill{
	name = "Heima",
	extra_func = function(self, target)
		if target:isWounded() and target:hasSkill(self:objectName()) then
			return 2 * target:getLostHp()
		end
	end
}

Zhaoxihang:addSkill(Boming)
Zhaoxihang:addSkill(Heima)

sgs.LoadTranslationTable{
	["Zhaoxihang"] = "赵西航",
	["Boming"] = "搏命",
	["Heima"] = "黑马",
	[":Boming"] = "摸牌阶段开始时，你可放弃摸牌，并摸数量等同于你当前手牌数的牌，然后若你手牌数大于手牌上限数，你指定一名其他角色依次弃置你手牌至其数量等于你的手牌上限数。",
	[":Heima"] = "锁定技，若你已受伤，你的手牌上限为你的体力上限+你已损失体力值",
}

-----------------------------------------------

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


-------------------------

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
	[":roushan"] = "游戏开始后，每当你未发动此技能获得手牌，你可将一张手牌正面朝上交给一名除来源角色外的其他角色，若该牌为黑色，你视作对其使用了一张雷属性【杀】；若为红色，你摸一张牌。",
	["yunnao"] = "愠恼",
	[":yunnao"] = "每当你受到一点伤害，你可令伤害来源摸一张牌然后交给你一张手牌。",
	["@roushan_invoke"] = "请选择要交给目标角色的一张手牌，若为黑色视作对其使用了一张雷属性【杀】；若为红色，你摸一张牌。",
	["yunnao_give"] = "请选择一张交给阮老的手牌"
}

---------------------------

--贺琪
Heqi = sgs.General(extension, "heqi", "shu", 4)

--【压制】每当你对一名角色使用的【杀】被【闪】抵消，你可展示牌堆顶的三张牌并获得其中一张牌，然后若该牌为【杀】，你对目标角色使用之。
YazhiDummy = sgs.CreateSkillCard {
	name = "yazhidummy"
}

Yazhi = sgs.CreateTriggerSkill {
	name = "yazhi",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.SlashMissed},
	on_trigger = function(self, event, player, data)
		if not player then return end
		local room = player:getRoom()
		local effect = data:toSlashEffect()
		local target = effect.to
		if not target:isAlive() then return false end

		if not player:askForSkillInvoke(self:objectName()) then return false end
		local ids = room:getNCards(2, true)
		local move = sgs.CardsMoveStruct()
		move.card_ids = ids
		move.to = player
		move.to_place = sgs.Player_PlaceTable
		move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_TURNOVER, player:objectName(), self:objectName(), nil)
		room:moveCardsAtomic(move, true)
		room:getThread():delay(1000)
		
		room:fillAG(ids, player)
		local get_id = room:askForAG(player, ids, false, self:objectName())
		room:takeAG(player, get_id)
		ids:removeOne(get_id)
		room:takeAG(nil, ids:first())
		room:takeAG(nil, ids:last())
		room:clearAG()
		
		local card = sgs.Sanguosha:getCard(get_id)
		if card:isKindOf("Slash") then
			local useSlash = sgs.CardUseStruct()
			useSlash.from = player
			useSlash.to:append(target)
			useSlash.card = card
			room:useCard(useSlash, true)
		end
		return false
		
		--[[if not slashA and not slashB then
			local dummy = YazhiDummy:clone()
			dummy:addSubcard(idA)
			dummy:addSubcard(idB)
			room:obtainCard(player, dummy, true)
		else
			local useSlash = sgs.CardUseStruct()
			useSlash.from = player
			useSlash.to:append(target)
			if slashA and slashB then
				room:fillAG(ids)
				local chosen = room:askForAG(player, ids, false, self:objectName())
				room:clearAG()
				useSlash.card = sgs.Sanguosha:getCard(chosen)
			elseif slashA then
				useSlash.card = cardA
				room:obtainCard(player, cardB, true)
			else
				useSlash.card = cardB
				room:obtainCard(player, cardA, true)
			end
			room:useCard(useSlash, true)
		end
		return false--]]
	end
}

--【蛮力】每当你使用【杀】对目标角色造成一次伤害时，你可弃置一张与该【杀】相同花色的手牌使该伤害+1.
Manli = sgs.CreateTriggerSkill {
	name = "manli",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.DamageCaused},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local damage = data:toDamage()
		local victim = damage.to
		local slash = damage.card
		
		if not slash or not slash:isKindOf("Slash") then return false end
		if player:isKongcheng() then return false end		
		if not victim or not victim:isAlive() then return end
		
		local suit = slash:getSuit()
		if suit ~= sgs.Card_Spade and suit ~= sgs.Card_Club and suit ~= sgs.Card_Heart and suit ~= sgs.Card_Diamond then return false end
		
		if not room:askForSkillInvoke(player, self:objectName(), data) then return false end		
		local slash_id = slash:getId()
		local id = sgs.IntList()
		id:append(slash_id)
		room:fillAG(id, player)
		local thrown = room:askForCard(player, ".|"..sgs.Card_Suit2String(suit).."|.|hand", "@yazhi_prompt")
		room:clearAG()
		if not thrown then return false end
		
		damage.damage = damage.damage + 1
		data:setValue(damage)
		
		return false
	end,
}

Heqi:addSkill(Manli)
Heqi:addSkill(Yazhi)

sgs.LoadTranslationTable {
	["yazhi"] = "压制",
	[":yazhi"] = "每当你对一名角色使用的【杀】被【闪】抵消，你可展示牌堆顶的两张牌，获得其中不为【杀】的牌，然后若其中有【杀】，对该角色使用其中一张。",
	["manli"] = "蛮力",
	[":manli"] = "每当你使用【杀】对目标角色造成一次伤害时，你可弃置一张与该【杀】相同花色的手牌使该伤害+1.",
	["@yazhi_prompt"] = "请弃置一张与该【杀】花色相同的手牌使其伤害+1",
	["heqi"] = "贺琪",
}


-----------------------

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

Jueye:addSkill(Taotie)
Jueye:addSkill(Tansu)

sgs.LoadTranslationTable {
	["jueye"] = "王星珏",
	["tansu"] = "弹速",
	["taotie"] = "饕餮",
	["tansu_prompt"] = "请选择获得牌颜色",
}


-------------------------------------------

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

--Ruanlao:addSkill(Duotao)

sgs.LoadTranslationTable {
	["duotao"] = "夺桃",
	["duotao_prompt"] = "请选择一名角色成为你偷桃的目标",
}

--------------------------------------------

Wangrui = sgs.General(extension, "wangrui", "wu", 3)

--【骚睿】出牌阶段限一次，你可展示一名其他角色的一张手牌，若该牌为红桃或草花，若该角色判定区内无相应牌，
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
	["Xingwang"] = "星旺",
	["rec"] = "回复一点体力",
	["draw"] = "摸两张牌"
}

---------------------------------------

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

----------------------------------------

--【神算】结束阶段开始时，你可将任意张手牌暗置于武将牌上，称为“算”；准备阶段开始时，你弃置所有“算”；你的回合
--		  外，每当你受到一张【杀】或非延时性锦囊牌的效果，你可弃置武将牌上一张与该牌花色相同的牌，若如此做，
--		  你摸两张牌，然后将该牌的效果转移给其使用者。
Shensuan_Card = sgs.CreateSkillCard {
	name = "shensuan_card",
	target_fixed = true,
	will_throw = false,
	on_use = function(self, room, source, targets)
		local ids = self:getSubcards()
		for _,id in sgs.qlist(ids) do
			source:addToPile("suan", id, false)
		end
	end	
}

Shensuan_VS = sgs.CreateViewAsSkill {
	name = "#shensuan",
	n = 999,
	view_filter = function(self, selected, to_select)
		return not to_select:isEquipped()
	end,
	view_as = function(self, cards)		
		if #cards > 0 then
			local vs_card = Shensuan_Card:clone()
			for _, cd in pairs(cards) do
				vs_card:addSubcard(cd)
			end
			vs_card:setSkillName(self:objectName())
			return vs_card
		end
	end,
	enabled_at_play = function(self, player)
		return false
	end,
	enabled_at_response = function(self, player, pattern)
		return pattern == "@@Shensuan"
	end
}
--[[
Shensuan_AG_Card = sgs.CreateSkillCard {
	name = "shensuan_ag_card",
	target_fixed = true,
	will_throw = false,
	on_use = function(self, room, source, targets)
		local card_id = self:getSubcards():first()
		for _, id in sgs.qlist(source:handCards()) do
			if sgs.Sanguosha:getCard(id):hasFlag("is_suan") then
				source:addToPile("suan", id, false)
			end
		end
		local reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_REMOVE_FROM_PILE, "", "shensuan", "")
		room:throwCard(sgs.Sanguosha:getCard(card_id), reason, nil)
	end
}

Shensuan_AG = sgs.CreateViewAsSkill {
	name = "#shensuan_ag",
	n = 1,
	view_filter = function(self, selected, to_select)
		return to_select:hasFlag("is_suan") and #selected == 0
	end,
	view_as = function(self, cards)		
		if #cards > 0 then
			local vs_card = Shensuan_Card:clone()
			for _, cd in pairs(cards) do
				vs_card:addSubcard(cd)
			end
			vs_card:setSkillName(self:objectName())
			return vs_card
		end
	end,
	enabled_at_play = function(self, player)
		return false
	end,
	enabled_at_response = function(self, player, pattern)
		return pattern == "@@Shensuan_AG"
	end
}
]]--
Shensuan = sgs.CreateTriggerSkill {
	name = "shensuan",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseStart, sgs.CardEffected},
	view_as_skill = Shensuan_VS,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_REMOVE_FROM_PILE, "", self:objectName(), "")
		if event == sgs.EventPhaseStart then
			if player:getPhase() == sgs.Player_Start then
				local num = player:getPile("suan"):length()
				player:clearOnePrivatePile("suan")
				local target = room:askForPlayerChosen(player, room:getOtherPlayers(player), self:objectName(), "shensuan_prompt", false, true)
				if target:getHandcardNum() <= num then
					room:showAllCards(target)
				elseif num > 0 then
					local hand = target:handCards()
					for i = 1, num, 1 do
						local show_id = hand:first()
						room:showCard(player, show_id)
						hand:removeOne(show_id)
					end
				end
			elseif player:getPhase() == sgs.Player_Finish then
				if not player:isKongcheng() and player:getPile("suan"):length() <= 4 then
					if room:askForSkillInvoke(player, self:objectName()) then
						room:askForUseCard(player, "@@Shensuan", "@Shensuan")
					end
				end
			end			
		else
			if player:getPhase() ~= sgs.Player_NotActive then return end
			local effect = data:toCardEffect()
			local source = effect.from
			local target = effect.to
			local card = effect.card
			if not card or not card:isKindOf("Slash") and not card:isNDTrick() then return end
			if not target or target:objectName() ~= player:objectName() then return end
			if player:getPile("suan"):length() == 0 then return false end
			if not room:askForSkillInvoke(player, self:objectName()) then return false end
			local suan = player:getPile("suan")
			local suit = card:getSuit()
			local diff_ids = sgs.IntList()
			for _, id in sgs.qlist(suan) do
				if sgs.Sanguosha:getCard(id):getSuit() ~= suit then
					diff_ids:append(id)
				end
			end
			if card:isKindOf("AmazingGrace") then
				if diff_ids:length() < suan:length() then
					for _, id in sgs.qlist(suan) do
						if sgs.Sanguosha:getCard(id):getSuit() == suit then
							room:throwCard(sgs.Sanguosha:getCard(id), reason, nil)
							break
						end
					end
				else return
				end
			else
				room:fillAG(suan, player, diff_ids)
				local throw = room:askForAG(player, suan, true, self:objectName())
				room:clearAG()
				if throw == -1 then return false end
				room:throwCard(sgs.Sanguosha:getCard(throw), reason, nil)
			end
			room:drawCards(player, 2)
			if not source or not source:isAlive() then return false end
			effect.to = source
			data:setValue(effect)
		end
		return false
	end,
}

Dianjiao:addSkill(Shensuan)
Dianjiao:addSkill(Shensuan_VS)
extension:insertRelatedSkills("shensuan", "#shensuan")

sgs.LoadTranslationTable {
	["shensuan"] = "神算",
	[":shensuan"] = "结束阶段开始时，你可将任意张手牌暗置于武将牌上，称为“算”；开始阶段开始时，你将所有“算”置入弃牌堆，你的回合外，每当你成为一张【杀】或非延时性锦囊牌的目标，你可弃置一张与该牌花色相同的“算”，若如此做，你摸两张牌，然后将该牌的效果转移给其使用者。",
	["@Shensuan"] = "请选择置于武将牌上的手牌",
	["suan"] = "算",
	["shensuan_prompt"] = "请选择一名角色展示其手牌",
}

-------------------------------------------------------------------------------------

--范豪麟
Fanhaolin = sgs.General(extension, "fanhaolin", "shu", 4)


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




































