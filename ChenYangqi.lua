module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--陈杨弃
Chenyangqi = sgs.General(extension, "Chenyangqi", "wu", 5)

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
