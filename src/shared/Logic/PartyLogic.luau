--!strict
--[[
	PartyLogic
	In-memory party registry for one server (parties do not persist).
	Members are identified by UserId. The first member is the leader.
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)

local config = Tuning.Party

export type Party = {
	id: number,
	leader: number,
	members: { number },
}

export type Invite = {
	id: number,
	from: number,
	to: number,
	partyId: number?,
	expiresAt: number,
}

export type Registry = {
	partyOf: (self: Registry, userId: number) -> Party?,
	get: (self: Registry, partyId: number) -> Party?,
	invite: (self: Registry, from: number, to: number, now: number) -> (Invite?, string?),
	respond: (self: Registry, inviteId: number, userId: number, accept: boolean, now: number) -> (Party?, string?),
	leave: (self: Registry, userId: number) -> (Party?, boolean),
	kick: (self: Registry, leaderId: number, targetId: number) -> (Party?, string?),
	expire: (self: Registry, now: number) -> { Invite },
	invitesFor: (self: Registry, userId: number) -> { Invite },
}

type RegistryImpl = {
	parties: { [number]: Party },
	membership: { [number]: number },
	invites: { [number]: Invite },
	nextPartyId: number,
	nextInviteId: number,
	lastInviteAt: { [number]: number },
}

local RegistryClass = {}
RegistryClass.__index = RegistryClass

local PartyLogic = {}

function PartyLogic.new(): Registry
	local self: RegistryImpl = {
		parties = {},
		membership = {},
		invites = {},
		nextPartyId = 1,
		nextInviteId = 1,
		lastInviteAt = {},
	}
	return (setmetatable(self, RegistryClass) :: any) :: Registry
end

function RegistryClass.partyOf(self: RegistryImpl, userId: number): Party?
	local partyId = self.membership[userId]
	return if partyId then self.parties[partyId] else nil
end

function RegistryClass.get(self: RegistryImpl, partyId: number): Party?
	return self.parties[partyId]
end

function RegistryClass.invite(self: RegistryImpl, from: number, to: number, now: number): (Invite?, string?)
	if from == to then
		return nil, "You can't invite yourself."
	end
	local last = self.lastInviteAt[from]
	if last and now - last < config.InviteCooldown then
		return nil, "Slow down! Wait a moment before inviting again."
	end
	local fromParty = RegistryClass.partyOf(self, from)
	if fromParty and fromParty.leader ~= from then
		return nil, "Only the party leader can invite."
	end
	if fromParty and #fromParty.members >= config.MaxSize then
		return nil, "Your party is full."
	end
	if RegistryClass.partyOf(self, to) then
		return nil, "That player is already in a party."
	end
	for _, existing in self.invites do
		if existing.from == from and existing.to == to then
			return nil, "Invite already sent."
		end
	end
	local invite: Invite = {
		id = self.nextInviteId,
		from = from,
		to = to,
		partyId = if fromParty then fromParty.id else nil,
		expiresAt = now + config.InviteTimeout,
	}
	self.nextInviteId += 1
	self.invites[invite.id] = invite
	self.lastInviteAt[from] = now
	return invite, nil
end

function RegistryClass.respond(
	self: RegistryImpl,
	inviteId: number,
	userId: number,
	accept: boolean,
	now: number
): (Party?, string?)
	local invite = self.invites[inviteId]
	if not invite or invite.to ~= userId then
		return nil, "That invite is no longer valid."
	end
	self.invites[inviteId] = nil
	if invite.expiresAt < now then
		return nil, "That invite expired."
	end
	if not accept then
		return nil, nil
	end
	if RegistryClass.partyOf(self, userId) then
		return nil, "Leave your current party first."
	end
	local party = RegistryClass.partyOf(self, invite.from)
	if party then
		if party.leader ~= invite.from then
			return nil, "That invite is no longer valid."
		end
		if #party.members >= config.MaxSize then
			return nil, "That party is full."
		end
	else
		local created: Party = {
			id = self.nextPartyId,
			leader = invite.from,
			members = { invite.from },
		}
		self.nextPartyId += 1
		self.parties[created.id] = created
		self.membership[invite.from] = created.id
		party = created
	end
	assert(party)
	table.insert(party.members, userId)
	self.membership[userId] = party.id
	return party, nil
end

--- Removes a member. Returns (party, disbanded). The party disbands below 2 members.
function RegistryClass.leave(self: RegistryImpl, userId: number): (Party?, boolean)
	-- Pending invites from or to this player are dropped.
	for inviteId, invite in self.invites do
		if invite.from == userId or invite.to == userId then
			self.invites[inviteId] = nil
		end
	end
	local party = RegistryClass.partyOf(self, userId)
	if not party then
		return nil, false
	end
	local index = table.find(party.members, userId)
	if index then
		table.remove(party.members, index)
	end
	self.membership[userId] = nil
	if #party.members < 2 then
		for _, member in party.members do
			self.membership[member] = nil
		end
		self.parties[party.id] = nil
		return party, true
	end
	if party.leader == userId then
		party.leader = party.members[1]
	end
	return party, false
end

function RegistryClass.kick(self: RegistryImpl, leaderId: number, targetId: number): (Party?, string?)
	local party = RegistryClass.partyOf(self, leaderId)
	if not party or party.leader ~= leaderId then
		return nil, "Only the party leader can remove members."
	end
	if leaderId == targetId or not table.find(party.members, targetId) then
		return nil, "That player is not in your party."
	end
	RegistryClass.leave(self, targetId)
	return party, nil
end

function RegistryClass.expire(self: RegistryImpl, now: number): { Invite }
	local expired = {}
	for inviteId, invite in self.invites do
		if invite.expiresAt < now then
			self.invites[inviteId] = nil
			table.insert(expired, invite)
		end
	end
	return expired
end

function RegistryClass.invitesFor(self: RegistryImpl, userId: number): { Invite }
	local result = {}
	for _, invite in self.invites do
		if invite.to == userId then
			table.insert(result, invite)
		end
	end
	return result
end

return table.freeze(PartyLogic)
