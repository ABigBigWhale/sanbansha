module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--赵西航
Zhaoxihang = sgs.General(extension, "Zhaoxihang", "wu", 5, true)

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
	[":Boming"] = "摸牌阶段开始时，你可将摸牌数改为你当前手牌数，然后若你手牌数大于手牌上限数，你指定一名其他角色依次弃置你手牌至其数量等于你的手牌上限数。",
	[":Heima"] = "锁定技，若你已受伤，你的手牌上限为你的体力上限 + 你已损失体力值。",
}