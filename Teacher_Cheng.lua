module("extensions.oldsanbansha", package.seeall)

extension = sgs.Package("oldsanbansha")

--程老
Chenglao = sgs.General(extension, "Chenglao", "qun", 4, false)

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
-- *** TODO: This skill is not working ***

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
