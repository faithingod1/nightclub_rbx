--!strict
local musicTime = 1000
local os = {time = function() return musicTime end, clock = function() return musicTime end}
local function event()
	local callback = nil
	return {Connect = function(_, fn) callback = fn; return {Disconnect = function() callback = nil end} end,
		Fire = function() if callback then callback() end end}
end
local previousNew = Instance.new
Instance.new = function(class)
	local object = previousNew(class)
	if class == "Sound" then
		object.Ended = event()
		object.IsLoaded = true
		object.Play = function(self) self.Plays = (self.Plays or 0) + 1; self.IsPlaying = true end
		object.Stop = function(self) self.IsPlaying = false end
	end
	return object
end
