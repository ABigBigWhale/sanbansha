
module("extensions.firstTry", package.seeall)

extension = sgs.Package("firstTry")

--Generals
huanglao = sgs.General(extension, "huanglao", "wu", 4)
zhanShen = sgs.General(extension, "zhanShen", "wu", 4)
niBingGe = sgs.General(extension, "niBingGe", "wu", 4)

--[[luaZouWei = sgs.CreateFilterSkill {
	name = "luaZouWei",
	view_filter = function(self, to_select)
		return to_select:isKindOf("Jink")
	end,
	view_as = function(self, card)
		local id = card:getId()
		local suit = card:getSuit()
		local point = card:getNumber()
		local slash = sgs.Sanguosha:cloneCard("fire_slash", suit, point)
		slash:setSkillName(self:objectName())
		local vs_card = sgs.Sanguosha:getWrappedCard(id)
		pattern = sgs.Sanguosha:getCurrentCardUsePattern()
		vs_card:takeOver(slash)
		return vs_card
	end
}--]]

luaZouWei=sgs.CreateFilterSkill{
	name="luaZouWei",
	view_filter=function(self,to_select)
		return to_select:isKindOf("Slash") or to_select:isKindOf("Jink")
	end,
	view_as=function(self,card)
		local ZWcard
		if sgs.Sanguosha:getEngineCard(card:getEffectiveId()):isKindOf("Slash") then
			ZWcard=sgs.Sanguosha:cloneCard("jink",card:getSuit(),card:getNumber())
		end
		if sgs.Sanguosha:getEngineCard(card:getEffectiveId()):isKindOf("Jink") then
			ZWcard=sgs.Sanguosha:cloneCard("fire_slash",card:getSuit(),card:getNumber())
		end
		local acard=sgs.Sanguosha:getWrappedCard(card:getId())
		acard:takeOver(ZWcard)
		acard:setSkillName(self:objectName())
		return acard
	end,
}

luaWeiyongCard = sgs.CreateSkillCard {
	name = "luaWeiyongCard",
	target_fixed = true,
	
	on_use = function(self, room, source)
		local num = source:getLostHp() + 3
		if num > 6 then num = 6 end
		local card_ids = room:getNCards(num)
		room:fillAG(card_ids)
		local getCount = 0
		while (getCount < math.min(3, num)) do
			local card_id = room:askForAG(source, card_ids, false, self:objectName())
			card_ids:removeOne(card_id)
			room:takeAG(source, card_id)
			getCount = getCount + 1
		end
		room:clearAG()
		room:loseHp(source)
	end
}

luaWeiyong = sgs.CreateOneCardViewAsSkill {
	name = "luaWeiyong",
	view_filter = function(self, selected, to_selected)
		return true
	end,

	view_as = function(self, originalCard)
		local skillCard = luaWeiyongCard:clone()
		skillCard:addSubcard(originalCard)
		return skillCard
	end
}

luaDrawAndRec = sgs.CreateTriggerSkill {		--弃牌回血
	name = "luaDrawAndRec",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.CardsMoveOneTime, sgs.EventPhaseStart},
	on_trigger = function(self, event, player, data)
		if event == sgs.EventPhaseStart then
			if player:getPhase() == sgs.Player_Finish then
				local discdnum = player:getMark("yangsheng")
				if discdnum > 2 and player:askForSkillInvoke(self:objectName(), data) then
					local room = player:getRoom()
					local choice = room:askForChoice(player, self:objectName(), "rec1+draw1/2")
					if choice == "rec1" then
						local recoverByOne = sgs.RecoverStruct()
						recoverByOne.recover = (discdnum / 2)
						recoverByOne.who = player
						room:recover(player, recoverByOne)
					else
						player:drawCards(player:getHp())
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


luaQiangSha = sgs.CreateTriggerSkill {
	name = "luaQiangSha",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.SlashMissed},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		if not player:askForSkillInvoke(self:objectName()) then
			return false
		end
		local card_ids = room:getNCards(player:getHp())
		room:fillAG(card_ids)
		while (not card_ids:isEmpty()) do
			local card_id = room:askForAG(player, card_ids, false, self:objectName())
			card_ids:removeOne(card_id)
			local card = sgs.Sanguosha:getCard(card_id)
			local point = card:getNumber()
			room:takeAG(player, card_id)
			local removelist = {}
			for _,id in sgs.qlist(card_ids) do
				local c = sgs.Sanguosha:getCard(id)
				if c:getNumber() == point then
					room:takeAG(nil, c:getId())
					table.insert(removelist, id)
				end
			end
			if #removelist > 0 then
				for _,id in ipairs(removelist) do
					if card_ids:contains(id) then
						card_ids:removeOne(id)
					end
				end
			end
		end
		room:clearAG()
		return true
	end
}

luaJingJiu_Card = sgs.CreateSkillCard {
	name = "JingJiu_Card",
	target_fixed = false,
	will_throw = true,
	filter = function(self, targets, to_select)
		return #targets == 0
	end,
	on_effect = function(self, effect)
		local count = self:subcardsLength()
		local source = effect.from
		local dest = effect.to
		local room = source:getRoom()
		room:drawCards(source, count)
		room:drawCards(dest, count)
	end
}

luaJingJiu = sgs.CreateViewAsSkill {
	name = "luaJingJiu",
	n = 999,
	view_filter = function(self, selected, to_select)
		return to_select:getType() == "analeptic" or to_select:getType() ~= "basic" and not to_select:isEquipped()
	end,
	view_as = function(self, cards)
		if #cards > 0 then
			local skCard = luaJingJiu_Card:clone()
			for _,card in pairs(cards) do
				skCard:addSubcard(card)
			end
			skCard:setSkillName(self:objectName())
			return skCard
		end
	end
}

--needs modify
jiuxian = sgs.CreateViewAsSkill {			--非基本牌手牌视作【酒】
	name = "jiuxian",
	n = 1,
	view_filter = function(self, selected, to_select)
		return to_select:getType() ~= "basic" and not to_select:isEquipped() --非基本手牌
	end,

	view_as = function(self, cards)
		if #cards == 1 then
			local card = cards[1]
			local new_card =sgs.Sanguosha:cloneCard("analeptic", card:getSuit(), card:getNumber())
			new_card:addSubcard(card:getId())
			new_card:setSkillName(self:objectName())
			return new_card
		end
	end,

	enabled_at_response = function(self, player, pattern)	--允许回合外使用
		return pattern == "analeptic"
	end
}

--luaJingJiu = sgs.Create

luaSaTuo = sgs.CreateTriggerSkill {			--随机摸牌
	name = "luaSaTuo",
	frequency = sgs.Skill_Frequency,
	events = {sgs.DrawNCards},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		if room:askForSkillInvoke(player, "luaSaTuo", data) then
			local count = data:toInt() + math.random(-1,3) + (5 - player:getHp())
			data:setValue(count)
		end
	end
}

luaYiXing = sgs.CreateTriggerSkill {		--濒死变华佗
	name = "luaYiXing",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.Dying},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		if room:askForSkillInvoke(player, "luaYiXing", data) then
			room:changeHero(player, "huatuo", false, true, false, true)
		end
	end
}

luaXiongJin = sgs.CreateMaxCardsSkill {		--加手牌上限
	name = "luaXiongJin",
	extra_func = function(self, target)
		if target:hasSkill("luaXiongJin") then
			return target:getHp()
		end
	end
}

luaSuZui = sgs.CreateTriggerSkill {			--被闪掉体力
	name = "luaSuZui",
	frequency = sgs.Skill_Compulsory,
	events = {sgs.SlashMissed},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		room:loseHp(player)
	end
}

luaHuanJi = sgs.CreateTriggerSkill {		--造成伤害可回其血扣上限
	name = "luaHuanJi",
	frequency = sgs.NotFrequent,
	events = {sgs.Damage},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		if room:askForSkillInvoke(player, "luaHuanJi", data) then
			local damage = data:toDamage()
			local victim = damage.to
			local theRecover = sgs.RecoverStruct()
			theRecover.recover = 2
			theRecover.who = player
			room:recover(victim, theRecover)
			room:loseMaxHp(victim)
		end
	end
}

luaLieDou = sgs.CreateViewAsSkill {			--任意两张手牌视作决斗
	name = "luaLieDou",
	n = 2,
	view_filter = function(self, selected, to_selected)
		return true
	end,
	view_as = function(self, cards)
		if #cards < 2 then return nil
		elseif #cards == 2 then
			local card = cards[1]	--takes the first card among the two as the card used
			local suit = card:getSuit()
			local point = card:getNumber()
			local id = card:getId()
			local cast = sgs.Sanguosha:cloneCard("duel", suit, point) --create a virtual "duel"
			cast:addSubcard(id)
			cast:setSkillName("luaLieDou")
			return cast
		end
	end,
}

--结束阶段开始时，你可以令一名角色摸一张牌并展示之。若此牌为装备牌，该角色回复1点体力，然后使用之。
sjzhiyan = sgs.CreateTriggerSkill{
	name = "sjzhiyan",
	events = {sgs.EventPhaseStart},

	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		if player:getPhase() == sgs.Player_Finish then
			if player:askForSkillInvoke(self:objectName()) then
				local target = room:askForPlayerChosen(player, room:getAllPlayers(), self:objectName())
				local card = room:peek()
				target:drawCards(1)
				room:showCard(target, card:getId())
				if card:isKindOf("EquipCard") then
					local recover = sgs.RecoverStruct()
					recover.who = player
					room:recover(target, recover)
					local use = sgs.CardUseStruct()
					use.card = card
					use.from = target
					room:useCard(use)
				end
			end
		end
	end,
}

--【阖棺】其他角色的弃牌阶段开始时，你可将一张装备牌交给该角色并令其使用之，若如此做，
--该阶段结束后，你对其造成X点伤害（X为该角色于该阶段所弃牌中与该牌颜色相同的牌张数）。

luaHeguan = sgs.CreateTriggerSkill {
	name = "luaHeguan_DM",
	frequency = sgs.Skill_Frequent,
	events = {sgs.CardsMoveOneTime},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local source = room:findPlayerBySkillName(self:objectName())
		local current = room:getCurrent()
		if current:getPhase() == sgs.Player_Discard then
			local move = data:toMoveOneTime()
			local from = move.from
			local red = 0
			--if source and source:objectName() ~= current:objectName() then				
				if move.to_place == sgs.Player_DiscardPile then
					for _,id in sgs.qlist(move.card_ids) do
						local c = sgs.Sanguosha:getCard(id)
						if c:isRed() then
							red = red + 1
						end
					end
					current:setMark("@heguan", red)
				end
			--end
		--[[elseif current:getPhase() == sgs.Player_Finish then
			local count = current:getMark("heguan")
			--local tag = getTag("heguan_count")
			--local count = tag:toInt()
			if count > 0 then
				if source:askForSkillInvoke(self:objectName(), data) then						
					local makeDamage = sgs.DamageStruct()
					makeDamage.from = source
					makeDamage.to = current
					makeDamage.damage = count
					makeDamage.nature = sgs.DamageStruct_Normal
					room:damage(makeDamage)
				end
			end
			current:loseAllMark("heguan")--]]
		end
		return false
	end
}

luaHeguan_DM = sgs.CreateTriggerSkill {
	name = "luaHeguan_DM",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseStart},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local source = room:findPlayerBySkillName(self:objectName())
        local current = room:getCurrent()
		if current:getPhase() == sgs.Player_Finish then
			local count = current:getMark("@heguan")
			--local tag = getTag("heguan_count")
			--local count = tag:toInt()
			if count > 0 then
				if source:askForSkillInvoke(self:objectName(), data) then						
					local makeDamage = sgs.DamageStruct()
					makeDamage.from = source
					makeDamage.to = current
					makeDamage.damage = count
					makeDamage.nature = sgs.DamageStruct_Normal
					room:damage(makeDamage)
				end
				current:loseAllMark("@heguan")
			end			
		end
		return false
	end
}


LuaXLongluo = sgs.CreateTriggerSkill{
	name = "LuaXLongluo",  
	frequency = sgs.Skill_Frequent, 
	events = {sgs.CardsMoveOneTime, sgs.EventPhaseStart},  
	on_trigger = function(self, event, player, data) 
		if event == sgs.EventPhaseStart then
			if player:getPhase() == sgs.Player_Finish then
				local drawnum = player:getMark("longluo")
				if drawnum > 0 and player:askForSkillInvoke(self:objectName(), data) then
					local room = player:getRoom()
					local others = room:getOtherPlayers(player)
					local target = room:askForPlayerChosen(player, others, self:objectName())
					target:drawCards(drawnum)
				end
			elseif player:getPhase() == sgs.Player_RoundStart then
				player:setMark("longluo", 0)
			end
			return false
		elseif player:getPhase() == sgs.Player_Discard then
			local move = data:toMoveOneTime()
			local source = move.from
			if source and source:objectName() == player:objectName() then
				if move.to_place == sgs.Player_DiscardPile then
					for _,id in sgs.qlist(move.card_ids) do
						player:addMark("longluo")
					end
				end
			end
		end
		return false
	end
}

--generals--
--huanglao:addSkill(luaSaTuo)
--huanglao:addSkill(luaYiXing)
--huanglao:addSkill(luaXiongJin)
--huanglao:addSkill(luaHuanJi)
--huanglao:addSkill(luaQiangSha)
--huanglao:addSkill(jiuxian)
--huanglao:addSkill(luaJingJiu)
huanglao:addSkill(luaHeguan_DM)
--huanglao:addSkill(LuaXLongluo)
--zhanShen:addSkill(luaLieDou)
--niBingGe:addSkill(San_Huobao)
--niBingGe:addSkill(San_Huobao)
niBingGe:addSkill(luaQiangSha)
--huanglao:addSkill(luaHeguan)
huanglao:addSkill(luaWeiyong)

--lang--
sgs.LoadTranslationTable{
	["rec1"] = "回复1点体力",
	["draw1/2"] = "摸所弃置张数一半（向下取整）的牌",
	["firstTry"] = "练手",
	["zhanShen"] = "战神",
	["San_Huobao"] = "火爆",
	["niBingGe"] = "倪斌哥",
	["luaGuoRen"] = "过人",
	["&zhanShen"] = "不得了的战神",
	["#zhanShen"] = "我就是吊！",
	["luaLieDou"] = "烈斗",
	["luaHeguan_DM"] = "阖棺",
	["luaQiangSha"] = "强杀",
	["luaDrawAndRec"] = "养星",
	[":luaDrawAndRec"] = "结束阶段开始时，若你于此回合弃牌阶段弃置了不少于三张牌，你可选择：1.回复一点体力；2.摸等同于弃牌数量一半的牌（向下取整）。",
	["LuaXLongluo"] = "笼络",
	[":luaQiangSha"] = "",
	["luaWeiyong"] = "危勇",
	[":luaLieDou"] = "<b>出牌阶段</b>，你可将任意两张手牌当作【决斗】使用",
	["luaZouWei"] = "走位",
	[":luaZouWei"] = "<b>锁定技</b>，你的【闪】均视为火属性【杀】。",
	["designer:zhanShen"] =	"刘皓",
	["huanglao"] = "黄老",
	["&huanglao"] = "黄老",
	["designer:huanglao"] =	"刘皓",
	["luaJingJiu"] = "敬酒",
	[":luaJingJiu"] = "出牌阶段，你可以弃置一张【酒】并指定一名角色，你与其各摸一张牌",
	["luaXiongJin"] = "胸襟",
	[":luaXiongJin"] = "你的手牌上限为你当前体力值的两倍。",
	[":luaHuanJi"] = "每当你对一名角色造成伤害，你可令其回复2点体力，若如此做，其失去1点体力上限",
	["luaHuanJi"] = "缓计",
	["luaSuZui"] = "宿醉",
	[":luaSuZui"] = "<b>锁定技，</b>每当你使用的【杀】被【闪】抵消，你失去一点体力。",
	["luaYiXing"] = "移形",
	[":luaYiXing"] = "当你处于濒死状态时，你可以将武将牌更换为华佗。",
	["jiuxian"] = "酒仙",
	[":jiuxian"] = "你可将一张非基本牌视作【酒】使用或打出。",
	["shentou"] = "神偷",
	[":shentou"] = "你可以将你的梅花手牌当做顺手牵羊使用。",
	["luaSaTuo"] = "洒脱",
	[":luaSaTuo"] = "摸牌阶段，你可以额外摸X张牌(x为-1至3的一个随机整数)",

}
