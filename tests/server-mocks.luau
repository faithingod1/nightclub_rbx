--!strict
local mockTime = 1000
local guid = 0
local os = { time = function() return mockTime end, clock = function() return mockTime end }
local task = { wait = function(seconds) mockTime += seconds end }
local services = {
	HttpService = { GenerateGUID = function() guid += 1; return "id-" .. guid end },
	RunService = { IsStudio = function() return false end },
}
game.GetService = function(_, name) return services[name] or service end
local function copy(value)
	if typeof(value) ~= "table" then return value end
	local result = {}
	for k, v in value do result[k] = copy(v) end
	return result
end
local function fakeStore()
	local db = { Records = {}, Fail = false, Ambiguous = false, FailingKey = nil, Hook = nil }
	function db:UpdateAsync(key, callback)
		if self.Fail or self.FailingKey == key then error("simulated outage") end
		if self.Hook then self.Hook() end
		local result = callback(copy(self.Records[key]))
		if result == nil then return nil end
		self.Records[key] = copy(result)
		if self.Ambiguous then self.Ambiguous = false; error("response lost after commit") end
		return copy(result)
	end
	function db:GetAsync(key)
		if self.Fail then error("simulated read failure") end
		return copy(self.Records[key])
	end
	return db
end
