module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

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

-- *** TODO ***
--【掌击】你的红色“杀”对男性角色造成的伤害+1。


Wangxinxin:addSkill(San_Gehui)

sgs.LoadTranslationTable{
	["Wangxinxin"] = "王昕馨",
	["San_Gehui"] = "歌会",
	[":San_Gehui"] = "出牌阶段结束后，若你无手牌或所有手牌颜色均相同，你可展示之并摸两张牌，然后跳过此回合的弃牌阶段。",
}