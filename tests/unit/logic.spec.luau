--[[
	Unit tests for the pure game logic in ReplicatedStorage.Shared.Logic.
]]

local Shared = require("../harness/Shared")

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local Progression = Shared.require("Logic.Progression")
	local DataSchema = Shared.require("Logic.DataSchema")
	local Rewards = Shared.require("Logic.Rewards")
	local Backpack = Shared.require("Logic.Backpack")
	local QuestLogic = Shared.require("Logic.QuestLogic")
	local CollectionLogic = Shared.require("Logic.CollectionLogic")
	local DailyLoginLogic = Shared.require("Logic.DailyLoginLogic")
	local DeliveryLogic = Shared.require("Logic.DeliveryLogic")
	local FishingLogic = Shared.require("Logic.FishingLogic")
	local PartyLogic = Shared.require("Logic.PartyLogic")
	local HouseLogic = Shared.require("Logic.HouseLogic")
	local ShopLogic = Shared.require("Logic.ShopLogic")
	local TitleLogic = Shared.require("Logic.TitleLogic")
	local RateLimiter = Shared.require("Util.RateLimiter")
	local Guards = Shared.require("Net.Guards")
	local Format = Shared.require("Util.Format")
	local TimeUtil = Shared.require("Util.TimeUtil")
	local Tuning = Shared.require("Config.Tuning")
	local GameConfig = Shared.require("Config.GameConfig")

	local noPasses = {
		ownsPass = function()
			return false
		end,
	}

	describe("Progression", function()
		it("starts at level 1 and follows the published curve", function()
			expect(Progression.levelFromXP(0)).toBe(1)
			expect(Progression.xpToNext(1)).toBe(80)
			expect(Progression.levelFromXP(79)).toBe(1)
			expect(Progression.levelFromXP(80)).toBe(2)
			expect(Progression.totalForLevel(2)).toBe(80)
		end)

		it("is strictly increasing and capped at max level", function()
			for level = 1, Progression.MaxLevel - 2 do
				expect(Progression.xpToNext(level + 1)).toBeGreaterThan(Progression.xpToNext(level))
			end
			expect(Progression.xpToNext(Progression.MaxLevel)).toBe(0)
			expect(Progression.levelFromXP(10 ^ 12)).toBe(Progression.MaxLevel)
		end)

		it("matches the pacing targets from the design (L10 ~6.7k XP, L20 ~37k XP)", function()
			expect(Progression.totalForLevel(10)).toBeGreaterThan(6000)
			expect(Progression.totalForLevel(10)).toBeLessThan(7500)
			expect(Progression.totalForLevel(20)).toBeGreaterThan(33000)
			expect(Progression.totalForLevel(20)).toBeLessThan(41000)
		end)

		it("reports fractional progress within a level", function()
			local progress = Progression.progress(120)
			expect(progress.level).toBe(2)
			expect(progress.into).toBe(40)
			expect(progress.fraction).toBeGreaterThan(0)
			expect(progress.fraction).toBeLessThan(1)
		end)
	end)

	describe("Rewards", function()
		it("grants currencies, XP and level-up Tokens", function()
			local data = DataSchema.newData()
			local before = data.Tokens
			local summary = Rewards.apply(data, { Tokens = 100, XP = 100, Tickets = 3 })
			expect(summary.levelsGained).toEqual({ 2 })
			expect(summary.levelUpTokens).toBe(Progression.levelUpTokens(2))
			expect(data.Tokens).toBe(before + 100 + Progression.levelUpTokens(2))
			expect(data.Level).toBe(2)
			expect(data.Tickets).toBe(3)
		end)

		it("ignores negative, NaN and fractional amounts", function()
			local data = DataSchema.newData()
			local before = data.Tokens
			Rewards.apply(data, { Tokens = -500, XP = 0 / 0, Tickets = 2.9 })
			expect(data.Tokens).toBe(before)
			expect(data.XP).toBe(0)
			expect(data.Tickets).toBe(2)
		end)

		it("caps currencies at the configured maximum", function()
			local data = DataSchema.newData()
			data.Tokens = GameConfig.Data.MaxTokens - 5
			local added = Rewards.addTokens(data, 100)
			expect(added).toBe(5)
			expect(data.Tokens).toBe(GameConfig.Data.MaxTokens)
		end)

		it("grants ownership once and auto-equips the first pet", function()
			local data = DataSchema.newData()
			local first = Rewards.apply(data, { Pets = { "Kitten" }, Cosmetics = { "ChefHat" } })
			expect(first.pets).toEqual({ "Kitten" })
			expect(data.Equipped.Pet).toBe("Kitten")
			local second = Rewards.apply(data, { Pets = { "Kitten" }, Cosmetics = { "ChefHat" } })
			expect(#second.pets).toBe(0)
			expect(#second.cosmetics).toBe(0)
		end)

		it("reports items that did not fit in the backpack", function()
			local data = DataSchema.newData()
			local summary = Rewards.apply(data, { Items = { Apple = 30 } }, { capacity = 20 })
			expect(summary.items.Apple).toBe(20)
			expect(summary.dropped.Apple).toBe(10)
		end)

		it("only spends Tokens that the player has", function()
			local data = DataSchema.newData()
			data.Tokens = 50
			expect(Rewards.spendTokens(data, 60)).toBe(false)
			expect(data.Tokens).toBe(50)
			expect(Rewards.spendTokens(data, 50)).toBe(true)
			expect(data.Tokens).toBe(0)
			expect(Rewards.spendTokens(data, -10)).toBe(false)
		end)
	end)

	describe("Backpack", function()
		it("counts total items against capacity", function()
			local backpack = {}
			expect(Backpack.add(backpack, "Apple", 15, 20)).toBe(15)
			expect(Backpack.add(backpack, "Orange", 10, 20)).toBe(5)
			expect(Backpack.used(backpack)).toBe(20)
			expect(Backpack.free(backpack, 20)).toBe(0)
		end)

		it("removes exactly or not at all", function()
			local backpack = { Apple = 2 }
			expect(Backpack.remove(backpack, "Apple", 3)).toBe(false)
			expect(backpack.Apple).toBe(2)
			expect(Backpack.remove(backpack, "Apple", 2)).toBe(true)
			expect(backpack.Apple).toBeNil()
		end)

		it("computes sell value from the catalog", function()
			expect(Backpack.sellValue({ Apple = 2, MoonKoi = 1 })).toBe(2 * 4 + 250)
		end)

		it("derives capacity from upgrades and the Big Backpack pass", function()
			local data = DataSchema.newData()
			expect(DataSchema.backpackCapacity(data, false)).toBe(20)
			data.BackpackTier = 2
			expect(DataSchema.backpackCapacity(data, false)).toBe(45)
			expect(DataSchema.backpackCapacity(data, true)).toBe(75)
		end)
	end)

	describe("QuestLogic", function()
		it("auto-starts the tutorial chain in order", function()
			local data = DataSchema.newData()
			expect(QuestLogic.startEligible(data, 0)).toEqual({ "welcome" })
			local events = QuestLogic.applyActivity(data, { kind = "Talk", npc = "Mayor" })
			expect(events[1].kind).toBe("complete")
			expect(data.Quests.Completed.welcome).toBe(1)
			expect(QuestLogic.startEligible(data, 0)).toEqual({ "first_delivery" })
		end)

		it("only counts deliveries to the objective's target", function()
			local data = DataSchema.newData()
			data.Quests.Completed.welcome = 1
			QuestLogic.startEligible(data, 0)
			QuestLogic.applyActivity(data, { kind = "Deliver", target = "House03" })
			expect(data.Quests.Active.first_delivery.Count).toBe(0)
			QuestLogic.applyActivity(data, { kind = "Deliver", target = "Bakery" })
			expect(data.Quests.Completed.first_delivery).toBe(1)
		end)

		it("advances ordered objectives and consumes hand-in items", function()
			local data = DataSchema.newData()
			data.Quests.Completed.welcome = 1
			data.Quests.Completed.first_delivery = 1
			data.Quests.Active.fresh_fruit = { Step = 1, Count = 0, StartedAt = 0 }
			-- Talking first does nothing: the current objective is picking.
			expect(#QuestLogic.applyActivity(data, { kind = "Talk", npc = "Baker" })).toBe(0)
			for _ = 1, 3 do
				QuestLogic.applyActivity(data, { kind = "Pick", item = "Apple" })
			end
			expect(data.Quests.Active.fresh_fruit.Step).toBe(2)
			-- No apples in the backpack yet: the hand-in reports missing items.
			local missing = QuestLogic.applyActivity(data, { kind = "Talk", npc = "Baker" })
			expect(missing[1].kind).toBe("missingItems")
			data.Backpack.Apple = 4
			local events = QuestLogic.applyActivity(data, { kind = "Talk", npc = "Baker" })
			expect(events[1].kind).toBe("complete")
			expect(data.Backpack.Apple).toBe(1)
		end)

		it("never completes a quest twice", function()
			local data = DataSchema.newData()
			QuestLogic.startEligible(data, 0)
			QuestLogic.applyActivity(data, { kind = "Talk", npc = "Mayor" })
			QuestLogic.applyActivity(data, { kind = "Talk", npc = "Mayor" })
			expect(data.Quests.Completed.welcome).toBe(1)
		end)

		it("selects the same daily quests for the same player and day", function()
			local a = QuestLogic.dailySelection(12345, 20000, 10)
			local b = QuestLogic.dailySelection(12345, 20000, 10)
			expect(a).toEqual(b)
			expect(#a).toBe(Tuning.DailyQuests.Count)
			local ids = {}
			for _, pick in a do
				expect(ids[pick.id]).toBeNil()
				ids[pick.id] = true
			end
		end)

		it("respects daily quest level requirements", function()
			for day = 1, 50 do
				for _, pick in QuestLogic.dailySelection(777, day, 1) do
					expect(pick.id).never.toBe("d_fish")
					expect(pick.id).never.toBe("d_water")
				end
			end
		end)

		it("completes dailies and grants the all-done bonus exactly once", function()
			local data = DataSchema.newData()
			data.Daily = {
				Day = 5,
				BonusClaimed = false,
				Quests = {
					{ Id = "d_pick", Target = 2, Count = 0, Claimed = false },
					{ Id = "d_deliver", Target = 1, Count = 0, Claimed = false },
				},
			}
			QuestLogic.applyActivity(data, { kind = "Pick", item = "Apple" })
			QuestLogic.applyActivity(data, { kind = "Pick", item = "Apple" })
			local events = QuestLogic.applyActivity(data, { kind = "Deliver", target = "Cafe" })
			local kinds = {}
			for _, event in events do
				table.insert(kinds, event.kind)
			end
			expect(kinds).toContain("dailyComplete")
			expect(kinds).toContain("dailyBonus")
			local again = QuestLogic.applyActivity(data, { kind = "Deliver", target = "Cafe" })
			expect(#again).toBe(0)
		end)

		it("refreshes daily quests when the UTC day changes", function()
			local data = DataSchema.newData()
			expect(QuestLogic.refreshDaily(data, 1, 100)).toBe(true)
			expect(QuestLogic.refreshDaily(data, 1, 100)).toBe(false)
			expect(#data.Daily.Quests).toBe(3)
			expect(QuestLogic.refreshDaily(data, 1, 101)).toBe(true)
		end)
	end)

	describe("CollectionLogic", function()
		it("records entries once and detects completion", function()
			local data = DataSchema.newData()
			expect(CollectionLogic.record(data, "fruits", "Apple")).toBe(true)
			local isNew = CollectionLogic.record(data, "fruits", "Apple")
			expect(isNew).toBe(false)
			expect(CollectionLogic.record(data, "fruits", "NotAFruit")).toBe(false)
			for _, id in { "Grapes", "Orange", "GoldenApple", "Cherry" } do
				CollectionLogic.record(data, "fruits", id)
			end
			local _, completed = CollectionLogic.record(data, "fruits", "Starfruit")
			expect(completed).toBe(true)
		end)

		it("only lets a completed album be claimed once", function()
			local data = DataSchema.newData()
			local reward, reason = CollectionLogic.claim(data, "neighbors")
			expect(reward).toBeNil()
			expect(reason).toContain("Complete")
			for _, npc in { "Mayor", "Postmaster", "Baker", "Shopkeeper", "PetKeeper", "Fisher", "Gardener", "FestivalHost" } do
				CollectionLogic.record(data, "neighbors", npc)
			end
			expect(CollectionLogic.claim(data, "neighbors")).never.toBeNil()
			expect(CollectionLogic.claim(data, "neighbors")).toBeNil()
		end)
	end)

	describe("DailyLoginLogic", function()
		it("builds a streak on consecutive days and resets after a gap", function()
			local data = DataSchema.newData()
			expect(DailyLoginLogic.claim(data, 100).day).toBe(1)
			expect(DailyLoginLogic.claim(data, 100)).toBeNil()
			expect(DailyLoginLogic.claim(data, 101).day).toBe(2)
			expect(DailyLoginLogic.claim(data, 102).day).toBe(3)
			expect(DailyLoginLogic.claim(data, 105).day).toBe(1)
		end)

		it("loops the 7-day calendar", function()
			local data = DataSchema.newData()
			for day = 1, 7 do
				DailyLoginLogic.claim(data, 200 + day)
			end
			expect(data.Login.Streak).toBe(7)
			expect(DailyLoginLogic.claim(data, 208).day).toBe(1)
		end)
	end)

	describe("DeliveryLogic", function()
		it("pays more for longer and on-time express deliveries", function()
			local short = DeliveryLogic.reward(60, false, false)
			local long = DeliveryLogic.reward(400, false, false)
			local express = DeliveryLogic.reward(400, true, true)
			local lateExpress = DeliveryLogic.reward(400, true, false)
			expect(long.Tokens).toBeGreaterThan(short.Tokens)
			expect(express.Tokens).toBeGreaterThan(long.Tokens)
			expect(lateExpress.Tokens).toBe(long.Tokens)
		end)

		it("rejects deliveries faster than any player can travel", function()
			expect(DeliveryLogic.isPlausible(300, 1)).toBe(false)
			expect(DeliveryLogic.isPlausible(300, 20)).toBe(true)
		end)

		it("chooses targets outside the exclusion list", function()
			Shared.run(function()
				local rng = Random.new(1)
				for _ = 1, 50 do
					local target = DeliveryLogic.chooseTarget({ "A", "B", "C" }, { A = true }, rng)
					expect(target).never.toBe("A")
				end
				expect(DeliveryLogic.chooseTarget({ "A" }, { A = true }, rng)).toBeNil()
			end)
		end)
	end)

	describe("FishingLogic", function()
		it("accepts reels only inside the bite window", function()
			expect(FishingLogic.verdict(9, 10)).toBe("early")
			expect(FishingLogic.verdict(10.2, 10)).toBe("caught")
			expect(FishingLogic.verdict(9.8, 10)).toBe("caught")
			expect(FishingLogic.verdict(13, 10)).toBe("late")
		end)

		it("rolls fish roughly according to the pool weights", function()
			Shared.run(function()
				local rng = Random.new(42)
				local counts = {}
				for _ = 1, 5000 do
					local item = FishingLogic.roll("Lake", rng)
					counts[item] = (counts[item] or 0) + 1
				end
				expect(counts.Minnow).toBeGreaterThan(counts.Trout)
				expect(counts.Trout).toBeGreaterThan(counts.GoldenCarp or 0)
				expect((counts.MoonKoi or 0)).toBeLessThan(40)
			end)
		end)
	end)

	describe("PartyLogic", function()
		it("creates a party when an invite is accepted", function()
			local registry = PartyLogic.new()
			local invite = registry:invite(1, 2, 0)
			local party = registry:respond(invite.id, 2, true, 1)
			expect(party.leader).toBe(1)
			expect(party.members).toEqual({ 1, 2 })
			expect(registry:partyOf(2)).toBe(party)
		end)

		it("enforces cooldowns, size and expiry", function()
			local registry = PartyLogic.new()
			local _, tooSoon = registry:invite(1, 2, 0), select(2, registry:invite(1, 3, 1))
			expect(tooSoon).toContain("Slow down")
			local expiring = registry:invite(1, 4, 10)
			local _, reason = registry:respond(expiring.id, 4, true, 100)
			expect(reason).toContain("expired")
			local full = PartyLogic.new()
			local now = 0
			for member = 2, Tuning.Party.MaxSize do
				now += 10
				local invite = full:invite(1, member, now)
				full:respond(invite.id, member, true, now)
			end
			now += 10
			local _, fullReason = full:invite(1, 99, now)
			expect(fullReason).toContain("full")
		end)

		it("transfers leadership and disbands below two members", function()
			local registry = PartyLogic.new()
			local a = registry:invite(1, 2, 0)
			registry:respond(a.id, 2, true, 0)
			local b = registry:invite(1, 3, 10)
			registry:respond(b.id, 3, true, 10)
			local party = registry:leave(1)
			expect(party.leader).toBe(2)
			local _, disbanded = registry:leave(2)
			expect(disbanded).toBe(true)
			expect(registry:partyOf(3)).toBeNil()
		end)

		it("only lets the leader kick and never kicks the leader", function()
			local registry = PartyLogic.new()
			local invite = registry:invite(1, 2, 0)
			registry:respond(invite.id, 2, true, 0)
			expect(select(2, registry:kick(2, 1))).toContain("leader")
			expect(select(2, registry:kick(1, 1))).toContain("not in your party")
			expect(registry:kick(1, 2)).never.toBeNil()
		end)
	end)

	describe("HouseLogic", function()
		it("places owned furniture in matching slots only", function()
			local data = DataSchema.newData()
			expect(HouseLogic.place(data, "Seat", "ComfySofa", false)).toBe(false)
			data.Furniture.ComfySofa = true
			expect(select(2, HouseLogic.place(data, "Bed", "ComfySofa", false))).toContain("doesn't fit")
			expect(HouseLogic.place(data, "Seat", "ComfySofa", false)).toBe(true)
			expect(data.House.Slots.Seat).toBe("ComfySofa")
		end)

		it("moves a piece instead of duplicating it", function()
			local data = DataSchema.newData()
			data.Furniture.FlowerBed = true
			HouseLogic.place(data, "Garden1", "FlowerBed", true)
			HouseLogic.place(data, "Garden2", "FlowerBed", true)
			expect(data.House.Slots.Garden1).toBeNil()
			expect(data.House.Slots.Garden2).toBe("FlowerBed")
		end)

		it("requires the premium pass for premium slots and excludes them from the rating", function()
			local data = DataSchema.newData()
			data.Furniture.Hammock = true
			expect(select(2, HouseLogic.place(data, "Balcony", "Hammock", false))).toContain("Dream Home")
			HouseLogic.place(data, "Balcony", "Hammock", true)
			local withPass = HouseLogic.rating(data.House.Slots, true)
			local withoutPass = HouseLogic.rating(data.House.Slots, false)
			expect(withPass - withoutPass).toBe(12)
		end)
	end)

	describe("ShopLogic", function()
		it("charges the catalog price and grants the item", function()
			local data = DataSchema.newData()
			data.Tokens = 1000
			local price = ShopLogic.purchase(data, "Furniture", "Beanbag", { hasPremiumHouse = false })
			expect(price.amount).toBe(300)
			expect(data.Tokens).toBe(700)
			expect(data.Furniture.Beanbag).toBe(true)
		end)

		it("refuses duplicates, unaffordable, locked and unknown items without charging", function()
			local data = DataSchema.newData()
			data.Tokens = 100000
			data.XP = Progression.totalForLevel(5)
			data.Level = 5
			expect(ShopLogic.purchase(data, "Pet", "Puppy", { hasPremiumHouse = false })).never.toBeNil()
			local before = data.Tokens
			expect(select(2, ShopLogic.purchase(data, "Pet", "Puppy", { hasPremiumHouse = false }))).toContain("already")
			expect(select(2, ShopLogic.purchase(data, "Cosmetic", "RoyalCrown", { hasPremiumHouse = false }))).toContain("level")
			expect(select(2, ShopLogic.purchase(data, "Cosmetic", "ChefHat", { hasPremiumHouse = false }))).toContain("isn't for sale")
			expect(select(2, ShopLogic.purchase(data, "Paint", "Royal", { hasPremiumHouse = false }))).toContain("Dream Home")
			data.Tokens = 10
			expect(select(2, ShopLogic.purchase(data, "Furniture", "Beanbag", { hasPremiumHouse = false }))).toContain("Not enough")
			expect(data.Tokens).toBe(10)
			expect(before).toBe(100000 - 900)
		end)

		it("sells backpack upgrades strictly in order", function()
			local data = DataSchema.newData()
			data.Tokens = 100000
			data.XP = Progression.totalForLevel(10)
			data.Level = 10
			expect(select(2, ShopLogic.purchase(data, "Backpack", "Rucksack", { hasPremiumHouse = false }))).toContain("isn't available")
			expect(ShopLogic.purchase(data, "Backpack", "Satchel", { hasPremiumHouse = false })).never.toBeNil()
			expect(data.BackpackTier).toBe(1)
			expect(ShopLogic.purchase(data, "Backpack", "Rucksack", { hasPremiumHouse = false })).never.toBeNil()
		end)

		it("uses Festival Tickets for festival items", function()
			local data = DataSchema.newData()
			data.Tickets = 30
			local price = ShopLogic.purchase(data, "Cosmetic", "LanternHat", { hasPremiumHouse = false })
			expect(price.currency).toBe("Tickets")
			expect(data.Tickets).toBe(0)
		end)
	end)

	describe("TitleLogic", function()
		it("grants titles when their conditions become true", function()
			local data = DataSchema.newData()
			expect(#TitleLogic.grantEarned(data, noPasses)).toBe(0)
			data.Stats.Deliveries = 5
			expect(TitleLogic.grantEarned(data, noPasses)).toEqual({ "Courier" })
			local vip = TitleLogic.grantEarned(data, {
				ownsPass = function(key)
					return key == "VIP"
				end,
			})
			expect(vip).toEqual({ "VIP" })
		end)
	end)

	describe("DataSchema.sanitize", function()
		it("repairs corrupted values and drops invalid references", function()
			local data = {
				Tokens = -50,
				Tickets = 0 / 0,
				XP = "lots",
				Backpack = { Apple = 3.7, Banana = 5, Orange = -2 },
				Equipped = { Hat = "TopHat", Trail = "", Aura = "", Title = "VIP", Pet = "Dragonling" },
				House = { Paint = "Neon", Slots = { Seat = "Telescope", Bed = "SimpleBed", Nowhere = "SimpleBed" } },
				Quests = { Active = { fake_quest = { Step = 1 } }, Completed = {} },
				Purchases = { "a", 5, "b" },
			}
			local repairs = DataSchema.sanitize(data)
			expect(#repairs).toBeGreaterThan(0)
			expect(data.Tokens).toBe(0)
			expect(data.Tickets).toBe(0)
			expect(data.XP).toBe(0)
			expect(data.Backpack).toEqual({ Apple = 3 })
			expect(data.Equipped.Hat).toBe("")
			expect(data.Equipped.Title).toBe("Newcomer")
			expect(data.Equipped.Pet).toBe("")
			expect(data.House.Paint).toBe("Cream")
			expect(data.House.Slots).toEqual({ Bed = "SimpleBed" })
			expect(data.Quests.Active.fake_quest).toBeNil()
			expect(data.Purchases).toEqual({ "a", "b" })
			expect(data.Settings.Music).toBe(true)
		end)

		it("leaves fresh template data unchanged", function()
			local data = DataSchema.newData()
			local repairs = DataSchema.sanitize(data)
			expect(#repairs).toBe(0)
		end)

		it("never replicates private keys", function()
			local view = DataSchema.publicView(DataSchema.newData())
			expect(view.Purchases).toBeNil()
			expect(view.Meta).toBeNil()
			expect(view.Tokens).toBe(50)
		end)
	end)

	describe("RateLimiter", function()
		it("allows bursts then refills over time", function()
			local limiter = RateLimiter.new(3, 1)
			expect(limiter:allow("a", 0)).toBe(true)
			expect(limiter:allow("a", 0)).toBe(true)
			expect(limiter:allow("a", 0)).toBe(true)
			expect(limiter:allow("a", 0)).toBe(false)
			expect(limiter:allow("b", 0)).toBe(true)
			expect(limiter:allow("a", 1.01)).toBe(true)
			expect(limiter:allow("a", 1.02)).toBe(false)
		end)
	end)

	describe("Guards", function()
		it("validates exact shapes and rejects junk", function()
			local guard = Guards.shape({ id = Guards.id(), count = Guards.integer(1, 10) })
			expect(guard({ id = "Apple", count = 3 })).toBe(true)
			expect(guard({ id = "Apple", count = 3, extra = 1 })).toBe(false)
			expect(guard({ id = "App le", count = 3 })).toBe(false)
			expect(guard({ id = "Apple", count = 0 / 0 })).toBe(false)
			expect(guard({ id = "Apple", count = 1.5 })).toBe(false)
			expect(guard({ id = string.rep("x", 41), count = 1 })).toBe(false)
			expect(guard("not a table")).toBe(false)
			expect(guard(setmetatable({ id = "Apple", count = 1 }, {}))).toBe(false)
		end)
	end)

	describe("Format & TimeUtil", function()
		it("formats numbers and durations for the UI", function()
			expect(Format.commas(1234567)).toBe("1,234,567")
			expect(Format.commas(-1000)).toBe("-1,000")
			expect(Format.short(15300)).toBe("15.3K")
			expect(Format.short(2500000)).toBe("2.5M")
			expect(Format.clock(65)).toBe("1:05")
			expect(Format.duration(3725)).toBe("1h 2m")
		end)

		it("computes UTC days, Monday-based weeks and schedules", function()
			expect(TimeUtil.dayNumber(86400 * 3 + 5)).toBe(3)
			-- 1970-01-05 was a Monday: a new week starts there.
			expect(TimeUtil.weekNumber(86400 * 4 - 1)).toBe(TimeUtil.weekNumber(0))
			expect(TimeUtil.weekNumber(86400 * 4)).toBe(TimeUtil.weekNumber(0) + 1)
			local state = TimeUtil.schedule(1800 * 10 + 60, 1800, 180, 0)
			expect(state.active).toBe(true)
			expect(state.endsAt).toBe(1800 * 10 + 180)
			local idle = TimeUtil.schedule(1800 * 10 + 600, 1800, 180, 0)
			expect(idle.active).toBe(false)
			expect(idle.nextStart).toBe(1800 * 11)
		end)
	end)
end
