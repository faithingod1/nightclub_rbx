--!strict
local Types = require(script.Parent.Types)

local Appearance = {}

Appearance.Limits = {
	Skin = 6,
	Face = 6,
	Hair = 6,
	HairColor = 6,
	Eyes = 6,
	Top = 6,
	Bottom = 5,
	Shoes = 4,
}

function Appearance.default(): Types.Appearance
	return {
		Skin = 2,
		Face = 1,
		Hair = 1,
		HairColor = 1,
		Eyes = 2,
		Top = 1,
		Bottom = 2,
		Shoes = 1,
	}
end

function Appearance.validate(value: any): Types.Appearance?
	if typeof(value) ~= "table" then
		return nil
	end
	local result = {} :: { [string]: number }
	for name, limit in Appearance.Limits do
		local option = value[name]
		if typeof(option) ~= "number" or option % 1 ~= 0 or option < 1 or option > limit then
			return nil
		end
		result[name] = option
	end
	return result :: any
end

return Appearance
