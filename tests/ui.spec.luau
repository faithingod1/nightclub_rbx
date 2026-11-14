--!strict
local root = Instance.new("Frame")
root.AbsoluteSize = {X = 1200, Y = 800}
local state = {GridWidth = 10, ActiveGenre = "Electro", NextCelebrityAt = musicTime + 30}
local viewed, homeCount, actions, tips = nil, 0, {}, 0
local social = {Parent = {GetAttribute = function() return true end}}
function social:InvokeServer(verb, id)
	if verb == "Friends" then return true, {Cards = {{UserId = 7, Name = "Test Friend", Online = true}}, Preview = true} end
	if verb == "Visit" then return true, state end
	if verb == "Home" then return true, state end
	if verb == "Tip" then tips += 1; return true, "DJ tipped" end
	error("unexpected request")
end
local action = {InvokeServer = function(_, verb, payload) table.insert(actions, {verb, payload}); return true, "Updated" end}
local panel = modules.SocialPanel.new(root, state, action, social,
	function(_, id) viewed = id end, function() viewed = nil; homeCount += 1 end)
panel.Update(state)
local function click(text)
	for _, object in instances do
		if object.ClassName == "TextButton" and object.Text == text and not object.Destroyed then object.Activated:Fire(); return end
	end
	error("button missing: " .. text)
end
click("DJ Genres")
click("Neon Electro")
assert(actions[1][1] == "SetGenre" and actions[1][2].Genre == "Electro")
click("Expand 12x12 - $3000")
assert(actions[2][1] == "ExpandClub")
click("ONLINE\nTest Friend")
assert(viewed == 7)
click("Expand 12x12 - $3000")
assert(#actions == 2, "visitor UI sent expansion")
click("Tip DJ $50")
assert(tips == 1)
click("Return Home")
assert(viewed == nil and homeCount == 1)
state.Celebrity = {Name = "DJ Blox", Genre = "HipHop", EndsAt = musicTime + 100, Progress = 12, Goal = 30, Reward = 900, Rewarded = false}
panel.Update(state)
local found = false
for _, object in instances do
	if object.ClassName == "TextLabel" and object.Text and string.find(object.Text, "12/30s", 1, true) then found = true end
end
assert(found, "mission progress absent from HUD")
panel.Destroy()
for _, object in instances do
	if object.Name == "FriendsBar" or object.Name == "GenreSelector" then assert(object.Destroyed) end
end
print("PASS genre modal, expansion control, friends bar, visit/home/tip callbacks, mission HUD, and UI cleanup")
