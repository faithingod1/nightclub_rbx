--!strict
local Appearance = modules.Appearance
local original = Appearance.default()
local validated = assert(Appearance.validate(original))
assert(validated ~= original, "validation retained mutable caller table")
for name, limit in Appearance.Limits do
	for _, value in {0, -1, limit+1, 1.5, 0/0, math.huge, "1", false} do
		local bad = Appearance.default()
		bad[name] = value
		assert(Appearance.validate(bad) == nil, "invalid choice accepted: " .. name)
	end
end
assert(Appearance.validate({}) == nil and Appearance.validate(nil) == nil)
print("PASS all appearance fields reject missing, fractional, nonnumeric, infinite and out-of-range values")

local parent = Instance.new("Frame")
parent.AbsoluteSize = Vector2.new(1280,720)
local saves, saved, fail = 0, nil, false
local editor = modules.CharacterCreator.new(parent, original, function(selection)
	saves += 1
	if fail then return false, "Please retry" end
	saved = selection
	return true, "Saved"
end)
local function click(name)
	for _, item in instances do
		if item.Name == name and item.ClassName == "TextButton" and not item.Destroyed then item.Activated:Fire();return end
	end
	error("button not found: " .. name)
end
local function livePreviewCount()
	local count = 0
	for _, item in instances do if item.Name == "CartoonGuest" and not item.Destroyed then count += 1 end end
	return count
end
assert(not editor.IsOpen())
editor.Open(original)
click("HairPrevious") -- wraps to cap
click("SkinNext")
click("TopNext")
assert(livePreviewCount() == 1, "choice change leaked previews")
assert(original.Hair == 1 and original.Skin == 2, "draft edited saved appearance")
click("CANCEL")
assert(not editor.IsOpen() and saves == 0, "cancel saved draft")
editor.Open(original)
click("HairPrevious")
click("SAVE CHARACTER")
assert(not editor.IsOpen() and saved.Hair == 6 and saved.Skin == 2, "save retained cancelled draft or lost selection")
fail = true
editor.Open(saved)
click("SAVE CHARACTER")
assert(editor.IsOpen(), "failed save closed editor")
editor.Destroy()
assert(livePreviewCount() == 0, "editor destroy leaked character")
print("PASS creator choice wrapping, draft isolation, cancel, save, failure retry and preview cleanup")

-- Every supported look constructs a UI-only character; clip updates preserve its depth.
for hair=1,Appearance.Limits.Hair do
	local look = Appearance.default()
	look.Hair, look.Top, look.Face = hair, hair, (hair%3)+1
	local animator = modules.SpriteAnimator.new(parent,modules.GameConfig.GUEST_SPRITE,Color3.new(1,1,1),false,look)
	for _, clip in {"Idle","Walk","Dance"} do animator.Play(clip);animator.Update(0.25,125) end
	assert(animator.Root.ZIndex == 125)
	animator.Destroy()
end
assert(livePreviewCount() == 0)
print("PASS all hairstyles, face shapes and outfits animate and clean up")
