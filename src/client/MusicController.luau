--!strict
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local MusicController = {}
function MusicController.new(): Types.MusicController
	local sound = Instance.new("Sound")
	sound.Name = "ClubPlaylist"
	sound.Volume = 0.35
	sound.Parent = SoundService
	local genre = ""
	local tracks: { string } = {}
	local index = 0
	local endsAt = 0
	local startedAt = 0
	local failed = 0
	local destroyed = false
	local function nextTrack()
		if destroyed then return end
		sound:Stop()
		if #tracks == 0 or os.time() >= endsAt or failed >= #tracks then return end
		index = index % #tracks + 1
		sound.SoundId = tracks[index]
		startedAt = os.clock()
		sound:Play()
	end
	local ended = sound.Ended:Connect(function() failed = 0; nextTrack() end)
	return {
		Update = function(state: Types.ClubState)
			if destroyed then return end
			local changed = genre ~= state.ActiveGenre or endsAt ~= state.DJSetEndsAt
			endsAt = state.DJSetEndsAt
			if changed then
				genre = state.ActiveGenre
				local def = Config.MUSIC_GENRES[genre]
				tracks = {}
				if def then
					for _, id in def.Playlist do if id ~= "" then table.insert(tracks, id) end end
					if #tracks == 0 and def.SoundId ~= "" then table.insert(tracks, def.SoundId) end
				end
				index, failed = 0, 0
				nextTrack()
			elseif os.time() >= endsAt then sound:Stop()
			elseif #tracks > 0 and not sound.IsLoaded and os.clock() - startedAt >= 10 then
				failed += 1
				nextTrack()
			end
		end,
		Destroy = function() destroyed = true; ended:Disconnect(); sound:Destroy() end,
	}
end
return MusicController
