--!strict
local task = {spawn = function(callback, ...) callback(...) end}
modules.GlossyUI = {style = function() end}
local previousUI = Instance.new
Instance.new = function(class)
	local object = previousUI(class)
	object.Activated = event()
	object.FindFirstChildOfClass = function(self, childClass)
		for _, child in instances do if child.Parent == self and child.ClassName == childClass and not child.Destroyed then return child end end
		return nil
	end
	object.GetPropertyChangedSignal = function() return event() end
	return object
end
