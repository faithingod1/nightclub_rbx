--!strict
-- Exercise the real remote handlers with controlled players and Roblox services.
local serverDb = fakeStore()
service.GetDataStore = function() return serverDb end
local function signal()
	local callbacks = {}
	return { Connect = function(_, callback) table.insert(callbacks, callback); return {Disconnect = function() end} end,
		Fire = function(_, ...) for _, callback in callbacks do callback(...) end end }
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal() }
players.GetPlayers = function() return {} end
players.GetFriendsAsync = function(_, id)
	return { IsFinished = true, GetCurrentPage = function() return {{Id = if id == 100 then 200 else 100, DisplayName = "Friend", Username = "Friend"}} end }
end
services.Players = players
local oldNew = Instance.new
Instance.new = function(class)
	local object = oldNew(class)
	object.SetAttribute = function(self, name, value) self[name] = value end
	object.FireClient = function(self, player, value) self.LastPlayer = player; self.LastValue = value end
	return object
end
local scheduled = {}
task.spawn = function(callback, ...) table.insert(scheduled, {callback, ...}) end
game.BindToClose = function(_, callback) game.CloseCallback = callback end
local function player(id)
	return {UserId = id, Parent = players,
		Kick = function(self, reason) self.Kicked = reason end,
		IsFriendsWithAsync = function(_, target) return target == 100 or target == 200 end,
		GetFriendsOnlineAsync = function() return {{VisitorId = 200}} end,
	}
end
