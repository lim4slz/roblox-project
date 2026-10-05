--!strict
--[[
	RateLimiter
	Token bucket per key: `capacity` requests may burst, refilled at
	`perSecond`. Time is passed in explicitly so it can be tested and so the
	server can use os.clock() without hidden globals.
]]

export type RateLimiter = {
	allow: (self: RateLimiter, key: any, now: number, cost: number?) -> boolean,
	forget: (self: RateLimiter, key: any) -> (),
}

type Bucket = { tokens: number, updatedAt: number }

type LimiterImpl = {
	capacity: number,
	perSecond: number,
	buckets: { [any]: Bucket },
}

local LimiterClass = {}
LimiterClass.__index = LimiterClass

local RateLimiter = {}

function RateLimiter.new(capacity: number, perSecond: number): RateLimiter
	assert(capacity > 0 and perSecond > 0, "RateLimiter needs positive capacity and rate")
	local self: LimiterImpl = { capacity = capacity, perSecond = perSecond, buckets = {} }
	return (setmetatable(self, LimiterClass) :: any) :: RateLimiter
end

function LimiterClass.allow(self: LimiterImpl, key: any, now: number, cost: number?): boolean
	local price = cost or 1
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = self.capacity, updatedAt = now }
		self.buckets[key] = bucket
	else
		local elapsed = math.max(0, now - bucket.updatedAt)
		bucket.tokens = math.min(self.capacity, bucket.tokens + elapsed * self.perSecond)
		bucket.updatedAt = now
	end
	if bucket.tokens >= price then
		bucket.tokens -= price
		return true
	end
	return false
end

function LimiterClass.forget(self: LimiterImpl, key: any)
	self.buckets[key] = nil
end

return table.freeze(RateLimiter)
