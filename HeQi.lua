module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--贺琪
Heqi = sgs.General(extension, "heqi", "shu", 5)

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