--!strict
--[[
	Protocol
	The complete client <-> server contract. There are only four remotes:

	  Request     RemoteFunction  client -> server  (action, payload) -> { ok, message?, data? }
	  ClientEvent RemoteEvent     client -> server  fire-and-forget telemetry (kind, payload)
	  State       RemoteEvent     server -> client  ("snapshot", data) | ("patch", changes)
	  Notify      RemoteEvent     server -> client  (kind, payload) toasts, rewards, dialogues...

	Every Request action is listed here with its payload guard and rate limit.
	The client only ever expresses intent; the server validates everything.
]]

local Guards = require(script.Parent.Guards)

export type ActionSpec = {
	payload: Guards.Guard,
	burst: number,
	perSecond: number,
}

export type Response = {
	ok: boolean,
	message: string?,
	data: any?,
}

local id = Guards.id()
local idOrEmpty = Guards.idOrEmpty()
local userId = Guards.integer(1, 2 ^ 53)
local empty = Guards.shape({})

local function action(payload: Guards.Guard, burst: number?, perSecond: number?): ActionSpec
	return { payload = payload, burst = burst or 5, perSecond = perSecond or 2 }
end

local Protocol = {}

Protocol.Remotes = table.freeze({
	Request = "Request",
	ClientEvent = "ClientEvent",
	State = "State",
	Notify = "Notify",
})

Protocol.Actions = table.freeze({
	["Shop.Buy"] = action(
		Guards.shape({
			kind = Guards.oneOf({ "Cosmetic", "Furniture", "Pet", "Backpack", "Paint" }),
			id = id,
		}),
		6,
		2
	),
	["Shop.Sell"] = action(Guards.shape({ itemId = Guards.optional(id) }), 4, 1),
	["Cosmetic.Equip"] = action(Guards.shape({ slot = Guards.oneOf({ "Hat", "Trail", "Aura" }), id = idOrEmpty })),
	["Title.Equip"] = action(Guards.shape({ id = id })),
	["Pet.Equip"] = action(Guards.shape({ id = idOrEmpty })),
	["House.Place"] = action(Guards.shape({ slot = id, id = idOrEmpty }), 8, 3),
	["House.Like"] = action(Guards.shape({ userId = userId })),
	["House.Visit"] = action(Guards.shape({ userId = userId }), 3, 0.5),
	["House.GoHome"] = action(empty, 3, 0.5),
	["Party.Invite"] = action(Guards.shape({ userId = userId }), 3, 0.5),
	["Party.Respond"] = action(Guards.shape({ inviteId = Guards.integer(1, 2 ^ 31), accept = Guards.boolean() })),
	["Party.Leave"] = action(empty, 3, 0.5),
	["Party.Kick"] = action(Guards.shape({ userId = userId }), 3, 0.5),
	["Daily.Claim"] = action(empty, 3, 0.5),
	["Code.Redeem"] = action(Guards.shape({ code = Guards.string(1, 24) }), 3, 0.3),
	["Collection.Claim"] = action(Guards.shape({ id = id }), 3, 1),
	["Fishing.Reel"] = action(Guards.shape({ session = Guards.integer(1, 2 ^ 31) }), 4, 2),
	["Fishing.Cancel"] = action(empty, 4, 2),
	["Delivery.Cancel"] = action(empty, 3, 1),
	["Settings.Set"] = action(
		Guards.shape({
			key = Guards.oneOf({ "Music", "Sfx", "PartyInvites", "Hints" }),
			value = Guards.boolean(),
		}),
		6,
		3
	),
	["Leaderboard.Get"] = action(
		Guards.shape({ board = Guards.oneOf({ "Deliveries", "Fish", "Homes", "Level" }) }),
		4,
		1
	),
	["Players.List"] = action(empty, 4, 1),
} :: { [string]: ActionSpec })

-- Fire-and-forget telemetry from the client (ClientEvent). Never trusted for rewards.
Protocol.ClientEvents = table.freeze({
	Device = Guards.shape({
		platform = Guards.oneOf({ "Desktop", "Mobile", "Tablet", "Console", "VR" }),
	}),
	ScreenOpened = Guards.shape({ screen = Guards.string(1, 32, "^[%w_]+$") }),
	InvitePrompted = Guards.shape({}),
	OfferResponse = Guards.shape({ offer = id, accepted = Guards.boolean() }),
	PurchasePrompted = Guards.shape({ key = id }),
} :: { [string]: Guards.Guard })

-- Server -> client notification kinds (documentation + client routing).
Protocol.NotifyKinds = table.freeze({
	"Toast",
	"Reward",
	"LevelUp",
	"Dialogue",
	"QuestStarted",
	"QuestCompleted",
	"PartyInvite",
	"PartyUpdate",
	"Fishing",
	"Delivery",
	"Festival",
	"Bloom",
	"Kitten",
	"Announcement",
	"Offer",
	"Collection",
	"Title",
	"Leaderboard",
})

function Protocol.isAction(name: any): boolean
	return type(name) == "string" and Protocol.Actions[name] ~= nil
end

return table.freeze(Protocol)
