--[[
	Self-test of the headless runtime: if these fail, nothing else can be trusted.
]]

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Harness runtime", function()
		it("loads the Rojo-built place with real script sources", function()
			local world = t.newWorld()
			local server = world:createServer()
			expect(server:find("ReplicatedStorage.Shared.Util.Signal")).never.toBeNil()
			expect(server:find("ReplicatedStorage.Remotes.Request")).never.toBeNil()
			local workspace = server:service("Workspace")
			local streaming = world:runIn(server.serverCtx, function()
				return workspace.StreamingEnabled
			end)
			expect(streaming).toBe(true)
		end)

		it("validates property names, types and read-only members like Roblox", function()
			local world = t.newWorld()
			local server = world:createServer()
			world:runIn(server.serverCtx, function()
				local part = Instance.new("Part")
				part.Anchored = true
				expect(function()
					part.Size = 5
				end).toThrow("Unable to assign property Size")
				expect(function()
					part.NotAProperty = 1
				end).toThrow("not a valid member")
				expect(function()
					return part.Nope
				end).toThrow("not a valid member")
				expect(function()
					(part :: any).ClassName = "Model"
				end).toThrow("read only")
				expect(function()
					Instance.new("BasePart")
				end).toThrow("Unable to create")
				part.Material = "Wood"
				expect(part.Material).toBe(Enum.Material.Wood)
				part.Position = Vector3.new(1, 2, 3)
				expect(part.CFrame.Position).toEqual(Vector3.new(1, 2, 3))
				expect(typeof(part)).toBe("Instance")
				expect(type(part)).toBe("userdata")
			end)
		end)

		it("locks Parent after Destroy and fires deferred events", function()
			local world = t.newWorld()
			local server = world:createServer()
			local added = 0
			world:runIn(server.serverCtx, function()
				local folder = Instance.new("Folder")
				folder.ChildAdded:Connect(function()
					added += 1
				end)
				local child = Instance.new("Part")
				child.Parent = folder
				expect(added).toBe(0) -- deferred: not yet
				task.wait()
				expect(added).toBe(1)
				child:Destroy()
				expect(function()
					child.Parent = folder
				end).toThrow("locked")
			end)
		end)

		it("keeps client-local property changes local and hides server-only containers", function()
			local world = t.newWorld()
			local server = world:createServer()
			local alice = server:addPlayer({ userId = 11, name = "Alice" })
			local bob = server:addPlayer({ userId = 12, name = "Bob" })
			local part = world:runIn(server.serverCtx, function()
				local p = Instance.new("Part")
				p.Name = "Door"
				p.Transparency = 0
				p.Parent = workspace
				return p
			end)
			alice:run(function()
				part.Transparency = 1
				expect(part.Transparency).toBe(1)
				expect(game:GetService("ServerScriptService"):FindFirstChild("Server")).toBeNil()
			end)
			bob:run(function()
				expect(part.Transparency).toBe(0)
			end)
			world:runIn(server.serverCtx, function()
				expect(part.Transparency).toBe(0)
				expect(game:GetService("ServerScriptService"):FindFirstChild("Server")).never.toBeNil()
			end)
		end)

		it("rejects remote payloads that Roblox would silently corrupt", function()
			local world = t.newWorld()
			local server = world:createServer()
			local alice = server:addPlayer({ userId = 21, name = "Alice" })
			local remote = server:find("ReplicatedStorage.Remotes.ClientEvent")
			alice:run(function()
				expect(function()
					remote:FireServer({ 1, 2, x = 3 })
				end).toThrow("mixed")
				expect(function()
					remote:FireServer({ [1] = "a", [3] = "c" })
				end).toThrow("sparse")
				expect(function()
					remote:FireServer(function() end)
				end).toThrow("function")
			end)
		end)

		it("runs RemoteFunction round trips between a client and the server", function()
			local world = t.newWorld()
			local server = world:createServer()
			local remote = server:find("ReplicatedStorage.Remotes.Request")
			world:runIn(server.serverCtx, function()
				remote.OnServerInvoke = function(player, a, b)
					return player.Name .. ":" .. tostring(a + b)
				end
			end)
			local alice = server:addPlayer({ userId = 31, name = "Alice" })
			expect(alice:request(2, 3)).toBe("Alice:5")
		end)

		it("advances virtual time deterministically", function()
			local world = t.newWorld()
			local server = world:createServer()
			local fired = {}
			world:runIn(server.serverCtx, function()
				task.delay(10, function()
					table.insert(fired, os.clock())
				end)
			end)
			world:advance(9)
			expect(#fired).toBe(0)
			world:advance(2)
			expect(#fired).toBe(1)
			expect(fired[1]).toBeGreaterThanOrEqual(10)
		end)

		it("emulates DataStore UpdateAsync with failure injection", function()
			local world = t.newWorld()
			local server = world:createServer()
			world.cloud:failNext("DataStore", 1)
			world:runIn(server.serverCtx, function()
				local store = game:GetService("DataStoreService"):GetDataStore("Test")
				local ok = pcall(function()
					store:UpdateAsync("k", function()
						return 1
					end)
				end)
				expect(ok).toBe(false)
				local value = store:UpdateAsync("k", function(old)
					return (old or 0) + 5
				end)
				expect(value).toBe(5)
				expect(store:GetAsync("k")).toBe(5)
				expect(function()
					store:SetAsync("bad", { part = Instance.new("Part") })
				end).toThrow("cannot store Instance")
			end)
		end)
	end)
end
