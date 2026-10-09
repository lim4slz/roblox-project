--[[
	Catalog integrity: every cross-reference between content tables must resolve.
	These tests are what make it safe to add/rename content.
]]

local Shared = require("../harness/Shared")

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local Items = Shared.require("Catalog.Items")
	local Cosmetics = Shared.require("Catalog.Cosmetics")
	local Furniture = Shared.require("Catalog.Furniture")
	local Pets = Shared.require("Catalog.Pets")
	local Titles = Shared.require("Catalog.Titles")
	local Quests = Shared.require("Catalog.Quests")
	local Collections = Shared.require("Catalog.Collections")
	local Npcs = Shared.require("Catalog.Npcs")
	local Areas = Shared.require("Catalog.Areas")
	local Products = Shared.require("Catalog.Products")
	local DailyRewards = Shared.require("Catalog.DailyRewards")
	local Codes = Shared.require("Catalog.Codes")
	local Sounds = Shared.require("Catalog.Sounds")
	local Rarity = Shared.require("Catalog.Rarity")
	local DataSchema = Shared.require("Logic.DataSchema")
	local Tuning = Shared.require("Config.Tuning")
	local Progression = Shared.require("Logic.Progression")

	local function ensure(condition, message)
		if not condition then
			error("Catalog integrity violation: " .. message, 2)
		end
	end

	local function checkReward(reward, context)
		for _, id in reward.Cosmetics or {} do
			ensure(Cosmetics.get(id) ~= nil, tostring(context .. " cosmetic " .. id))
		end
		for _, id in reward.Furniture or {} do
			ensure(Furniture.get(id) ~= nil, tostring(context .. " furniture " .. id))
		end
		for _, id in reward.Pets or {} do
			ensure(Pets.get(id) ~= nil, tostring(context .. " pet " .. id))
		end
		for _, id in reward.Titles or {} do
			ensure(Titles.get(id) ~= nil, tostring(context .. " title " .. id))
		end
		for id, amount in reward.Items or {} do
			ensure(Items.get(id) ~= nil, tostring(context .. " item " .. id))
			expect(amount).toBeGreaterThan(0)
		end
		for _, key in { "Tokens", "Tickets", "XP", "Reputation" } do
			if reward[key] ~= nil then
				expect(reward[key]).toBeGreaterThan(0)
				expect(reward[key] % 1).toBe(0)
			end
		end
	end

	describe("Catalog integrity", function()
		it("uses known rarities and non-empty icons everywhere", function()
			for _, list in { Items.List, Cosmetics.List, Pets.List } do
				for _, def in list do
					ensure(Rarity.get(def.rarity) ~= nil, tostring(def.id))
					expect(#def.icon).toBeGreaterThan(0)
				end
			end
			for _, def in Furniture.List do
				expect(#def.icon).toBeGreaterThan(0)
			end
		end)

		it("has valid fruit variants and fishing pools", function()
			for _, def in Items.List do
				if def.rareVariant then
					expect(Items.get(def.rareVariant) ~= nil).toBe(true)
					expect(def.rareChance).toBeGreaterThan(0)
					expect(def.rareChance).toBeLessThan(1)
				end
				expect(def.sellPrice).toBeGreaterThan(0)
				expect(def.xp).toBeGreaterThan(0)
			end
			for poolId, pool in Items.Pools do
				expect(#pool.entries).toBeGreaterThan(0)
				for _, entry in pool.entries do
					local item = Items.get(entry.item)
					ensure(item ~= nil and item.category == "Fish", "pool " .. poolId .. " has non-fish " .. entry.item)
					expect(entry.weight).toBeGreaterThan(0)
				end
			end
		end)

		it("prices everything that is sold and within the level range", function()
			for _, list in { Cosmetics.List, Furniture.List, Pets.List } do
				for _, def in list do
					if def.source == "Shop" or def.source == "Festival" then
						ensure(def.price ~= nil, tostring(def.id))
						expect(def.price.amount).toBeGreaterThan(0)
						local expected = if def.source == "Festival" then "Tickets" else "Tokens"
						expect(def.price.currency).toBe(expected)
					end
					expect((def.level or 1) <= Progression.MaxLevel).toBe(true)
				end
			end
		end)

		it("makes every non-shop item obtainable through some reward", function()
			local granted = { Cosmetics = {}, Furniture = {}, Pets = {} }
			local function collect(reward)
				for kind in granted do
					for _, id in reward[kind] or {} do
						granted[kind][id] = true
					end
				end
			end
			for _, quest in Quests.Story do
				collect(quest.reward)
			end
			for _, collection in Collections.List do
				collect(collection.reward)
			end
			for _, product in Products.DevProducts do
				collect(product.grant)
			end
			for _, day in DailyRewards.Days do
				if day.cosmetic then
					granted.Cosmetics[day.cosmetic] = true
				end
			end
			-- Pass / subscription perks are granted by the Monetization service.
			granted.Cosmetics.VipGoldTrail = true
			granted.Cosmetics.PlusTrail = true
			for _, def in Cosmetics.List do
				if not def.price then
					ensure(granted.Cosmetics[def.id], "unobtainable cosmetic " .. def.id)
				end
			end
			for _, def in Pets.List do
				if not def.price then
					ensure(granted.Pets[def.id], "unobtainable pet " .. def.id)
				end
			end
		end)

		it("has quests whose prerequisites and references resolve without cycles", function()
			local validTypes = {
				Talk = true,
				Deliver = true,
				Pick = true,
				Catch = true,
				Water = true,
				Postcard = true,
				EnterArea = true,
				BuyFurniture = true,
				PlaceFurniture = true,
				LikeHouse = true,
				Lantern = true,
				Rescue = true,
				PartyActivity = true,
				SellValue = true,
			}
			for _, quest in Quests.Story do
				ensure(Npcs.get(quest.giver) ~= nil, tostring(quest.id))
				for _, required in quest.requires do
					ensure(Quests.get(required) ~= nil, tostring(quest.id))
				end
				expect(#quest.objectives).toBeGreaterThan(0)
				for _, objective in quest.objectives do
					ensure(validTypes[objective.type], tostring(quest.id))
					expect(objective.count).toBeGreaterThan(0)
					if objective.npc then
						ensure(Npcs.get(objective.npc) ~= nil, tostring(quest.id))
					end
					if objective.item then
						ensure(Items.get(objective.item) ~= nil, tostring(quest.id))
					end
					if objective.area then
						ensure(Areas.get(objective.area) ~= nil, tostring(quest.id))
					end
					for itemId in objective.bring or {} do
						ensure(Items.get(itemId) ~= nil, tostring(quest.id))
					end
				end
				checkReward(quest.reward, quest.id)
			end
			-- Depth-first cycle detection
			local visiting, done = {}, {}
			local function visit(id)
				ensure(not visiting[id], "quest prerequisite cycle at " .. id)
				if done[id] then
					return
				end
				visiting[id] = true
				for _, required in Quests.get(id).requires do
					visit(required)
				end
				visiting[id] = nil
				done[id] = true
			end
			for _, quest in Quests.Story do
				visit(quest.id)
			end
			for _, template in Quests.Daily do
				ensure(validTypes[template.type], tostring(template.id))
				expect(template.minCount <= template.maxCount).toBe(true)
				expect(string.find(template.text, "%d", 1, true) ~= nil).toBe(true)
				checkReward(template.reward, template.id)
			end
		end)

		it("keeps the onboarding funnel steps unique and increasing", function()
			local seen = {}
			local last = 1
			for _, quest in Quests.Story do
				if quest.onboardingStep then
					expect(seen[quest.onboardingStep]).toBeNil()
					seen[quest.onboardingStep] = true
					expect(quest.onboardingStep).toBeGreaterThan(last)
					last = quest.onboardingStep
				end
			end
		end)

		it("fills albums with real content", function()
			for _, collection in Collections.List do
				checkReward(collection.reward, collection.id)
				for _, entry in collection.entries do
					if collection.id == "fruits" then
						expect(Items.get(entry.id).category).toBe("Fruit")
					elseif collection.id == "fish" then
						expect(Items.get(entry.id).category).toBe("Fish")
					elseif collection.id == "neighbors" then
						expect(Npcs.get(entry.id) ~= nil).toBe(true)
					elseif collection.id == "postcards" then
						expect(#(entry.hint or "")).toBeGreaterThan(10)
					end
				end
			end
			-- Every fruit and fish appears in its album.
			for _, def in Items.List do
				local album = if def.category == "Fruit" then "fruits" else "fish"
				ensure(Collections.hasEntry(album, def.id), tostring(def.id))
			end
			-- Every NPC is someone you can meet.
			for _, npc in Npcs.List do
				expect(Collections.hasEntry("neighbors", npc.id)).toBe(true)
				expect(Areas.get(npc.area) ~= nil).toBe(true)
				expect(#npc.greetings).toBeGreaterThan(0)
			end
		end)

		it("defines titles with resolvable conditions", function()
			local statKeys = {}
			for _, key in DataSchema.StatKeys do
				statKeys[key] = true
			end
			for _, title in Titles.List do
				local condition = title.condition
				if condition.kind == "Stat" then
					ensure(statKeys[condition.stat], tostring(title.id))
				elseif condition.kind == "Collection" then
					expect(Collections.get(condition.collection) ~= nil).toBe(true)
				elseif condition.kind == "Quest" then
					expect(Quests.get(condition.quest) ~= nil).toBe(true)
				elseif condition.kind == "Pass" then
					expect(Products.getPass(condition.pass) ~= nil).toBe(true)
				end
			end
			expect(Titles.get(Titles.Default) ~= nil).toBe(true)
		end)

		it("defines monetization products that grant real things without randomness", function()
			local keys = {}
			for _, product in Products.DevProducts do
				expect(keys[product.key]).toBeNil()
				keys[product.key] = true
				checkReward(product.grant, product.key)
				if product.oneTime then
					ensure(product.fallbackGrant ~= nil, tostring(product.key))
					checkReward(product.fallbackGrant, product.key)
				end
				expect(product.suggestedPrice).toBeGreaterThan(0)
			end
			for _, pass in Products.Passes do
				expect(#pass.perks).toBeGreaterThan(0)
			end
		end)

		it("has valid daily rewards, codes and sounds", function()
			expect(DailyRewards.Length).toBe(7)
			for _, day in DailyRewards.Days do
				checkReward(day.reward, "day " .. day.day)
				if day.cosmetic then
					expect(Cosmetics.get(day.cosmetic) ~= nil).toBe(true)
				end
			end
			for _, code in Codes.List do
				checkReward(code.reward, code.code)
				expect(Codes.normalize(" " .. string.lower(code.code) .. " ")).toBe(code.code)
			end
			expect(Codes.normalize("bad code!")).toBeNil()
			for name, sound in Sounds.Definitions do
				for _, note in sound.notes do
					ensure(string.match(note.id, "^rbxasset://sounds/") ~= nil, tostring(name))
				end
			end
		end)

		it("keeps the economy within sane bounds", function()
			-- The most expensive Tokens item must be reachable in < 40 hours of play
			-- at the design's 30 Tokens/minute income.
			local maxPrice = 0
			for _, list in { Cosmetics.List, Furniture.List, Pets.List } do
				for _, def in list do
					if def.price and def.price.currency == "Tokens" then
						maxPrice = math.max(maxPrice, def.price.amount)
					end
				end
			end
			expect(maxPrice / 30 / 60).toBeLessThan(40)
			for _, tier in Tuning.Backpack.Upgrades do
				expect(tier.price).toBeGreaterThan(0)
			end
		end)
	end)
end
