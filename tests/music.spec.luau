--!strict
local Config = modules.GameConfig
local state = {ActiveGenre = "Electro", DJSetEndsAt = musicTime + 180}
local music = modules.MusicController.new()
local sound = instances[#instances]
music.Update(state)
assert(not sound.IsPlaying and not sound.Plays, "empty playlist attempted playback")
Config.MUSIC_GENRES.Electro.Playlist = {"fixture-a", "fixture-b"}
state.DJSetEndsAt += 1
music.Update(state)
assert(sound.SoundId == "fixture-a" and sound.IsPlaying)
sound.Ended:Fire()
assert(sound.SoundId == "fixture-b")
sound.Ended:Fire()
assert(sound.SoundId == "fixture-a", "playlist did not loop")
state.ActiveGenre = "HipHop"
music.Update(state)
assert(not sound.IsPlaying, "silent genre retained old track")
state.ActiveGenre = "Electro"
music.Update(state)
sound.IsLoaded = false
musicTime += 11
music.Update(state)
assert(sound.SoundId == "fixture-b", "failed track did not advance")
musicTime += 11
music.Update(state)
assert(not sound.IsPlaying, "unavailable playlist retried endlessly")
state.DJSetEndsAt = musicTime - 1
music.Update(state)
assert(not sound.IsPlaying, "expired DJ set kept playing")
music.Destroy()
assert(sound.Destroyed)
print("PASS music empty fallback, playlist loop, genre switch, unavailable tracks, expiry, and cleanup")
