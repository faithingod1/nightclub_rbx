--!strict
local Types = require(script.Parent.Types)

local GameConfig = {}

GameConfig.TILE_WIDTH = 128
GameConfig.TILE_HEIGHT = 64
GameConfig.STARTING_GRID_W = 10
GameConfig.STARTING_GRID_H = 10
GameConfig.STARTING_CASH = 2500

GameConfig.CHARACTER = {
	Skin = {
		Color3.fromRGB(255, 230, 210),
		Color3.fromRGB(248, 206, 172),
		Color3.fromRGB(230, 180, 140),
		Color3.fromRGB(198, 142, 102),
		Color3.fromRGB(148, 98, 68),
		Color3.fromRGB(85, 54, 42),
	},
	HairColor = {
		Color3.fromRGB(40, 30, 25),
		Color3.fromRGB(92, 56, 34),
		Color3.fromRGB(168, 115, 62),
		Color3.fromRGB(182, 55, 45),
		Color3.fromRGB(135, 78, 48),
		Color3.fromRGB(55, 48, 75),
	},
	Eyes = {
		Color3.fromRGB(75, 48, 28),
		Color3.fromRGB(38, 130, 95),
		Color3.fromRGB(45, 120, 205),
		Color3.fromRGB(175, 115, 40),
		Color3.fromRGB(120, 65, 160),
		Color3.fromRGB(85, 95, 110),
	},
	Top = {
		Color3.fromRGB(28, 30, 36),
		Color3.fromRGB(142, 68, 173),
		Color3.fromRGB(240, 240, 245),
		Color3.fromRGB(70, 140, 215),
		Color3.fromRGB(48, 52, 62),
		Color3.fromRGB(140, 85, 55),
	},
	Bottom = {
		Color3.fromRGB(175, 150, 115),
		Color3.fromRGB(80, 135, 195),
		Color3.fromRGB(38, 55, 88),
		Color3.fromRGB(42, 125, 90),
		Color3.fromRGB(45, 48, 55),
	},
	Shoes = {
		Color3.fromRGB(235, 238, 242),
		Color3.fromRGB(220, 215, 200),
		Color3.fromRGB(25, 25, 30),
		Color3.fromRGB(115, 70, 45),
	},
}

GameConfig.CROWD = {
	MaxGuests = 36,
	MaxQueue = 6,
	ArrivalInterval = 1.2,
	AdmissionInterval = 1.8,
	DecisionInterval = 0.25,
	VisitSeconds = 110,
	RowdyEvery = 9,
	RowdyRadius = 2.5,
	HappinessLossPerSecond = 9,
	HappinessRecoveryPerSecond = 2,
	GuardSpeed = 3.8,
}

-- Original 1024x1024 atlas: four rows of four 256x256 frames.
-- Leave empty to use the animated procedural cartoon guests.
GameConfig.GUEST_SPRITE = {
	AssetId = "",
	Clips = {
		Idle = { FirstFrame = 0, FrameCount = 4, FPS = 4, Looped = true },
		Walk = { FirstFrame = 4, FrameCount = 4, FPS = 10, Looped = true },
		Dance = { FirstFrame = 8, FrameCount = 8, FPS = 12, Looped = true },
	},
} :: Types.SpriteSheet

GameConfig.RESTOCK_COST_PER_UNIT = 2
GameConfig.MOCKTAIL_SALE_PRICE = 8
GameConfig.BASE_COVER_CHARGE = 10

GameConfig.DJ_SKILLS = {
	RefreshSet = {
		CooldownSec = 10,
		SetDurationSec = 180,
		Cost = 50,
	},
	DropTheBass = {
		CooldownSec = 45,
		TipBonusPerDancer = 25,
	},
	MicShoutout = {
		CooldownSec = 30,
		VIPBonusTip = 120,
	},
}

GameConfig.MUSIC_GENRES = {
	Electro = { Name = "Neon Electro", SoundId = "", Playlist = { "" } },
	HipHop = { Name = "Club Bounce", SoundId = "", Playlist = { "" } },
	SynthPop = { Name = "Retro Pop", SoundId = "", Playlist = { "" } },
}

GameConfig.EXPANSIONS = {
	[10] = { Size = 12, Cost = 3000 },
	[12] = { Size = 14, Cost = 6000 },
	[14] = { Size = 16, Cost = 10000 },
	[16] = { Size = 18, Cost = 16000 },
	[18] = { Size = 20, Cost = 24000 },
} :: { [number]: { Size: number, Cost: number } }
GameConfig.CELEBRITIES = {
	{ Name = "Builderbeat VIP", Genre = "Electro", Reward = 750 },
	{ Name = "DJ Blox", Genre = "HipHop", Reward = 900 },
	{ Name = "Pixel Popstar", Genre = "SynthPop", Reward = 850 },
}
GameConfig.CELEBRITY_DURATION = 120
GameConfig.CELEBRITY_GOAL = 30
GameConfig.CELEBRITY_INTERVAL = 240
GameConfig.TIP_AMOUNT = 50
GameConfig.TIP_COOLDOWN = 60
GameConfig.PERSISTENCE = {
	StoreName = "NeonClubProfiles_v1",
	StudioSessionOnly = true, -- Explicit preview; live servers always persist.
	AutosaveSeconds = 45,
	LeaseSeconds = 180,
}

GameConfig.ITEMS = {
	NeonDancePad = {
		Id = "NeonDancePad",
		Name = "Neon Pulse Tile",
		Category = "DancePad",
		Cost = 100,
		Popularity = 15,
		Luxury = 5,
		FootprintX = 1,
		FootprintY = 1,
		HeightPx = 64,
		FallbackColor = Color3.fromRGB(236, 72, 153),
		AssetId = "",
	},
	BassTower = {
		Id = "BassTower",
		Name = "Subwoofer Stack",
		Category = "Speaker",
		Cost = 350,
		Popularity = 45,
		Luxury = 15,
		FootprintX = 1,
		FootprintY = 1,
		HeightPx = 120,
		FallbackColor = Color3.fromRGB(59, 130, 246),
		AssetId = "",
	},
	FizzMocktailBar = {
		Id = "FizzMocktailBar",
		Name = "Neon Fizz Mocktail Bar",
		Category = "MocktailBar",
		Cost = 500,
		Popularity = 25,
		Luxury = 40,
		FootprintX = 1,
		FootprintY = 1,
		HeightPx = 105,
		FallbackColor = Color3.fromRGB(16, 185, 129),
		AssetId = "",
		StorageCapacity = 250,
	},
	StarterDJBooth = {
		Id = "StarterDJBooth",
		Name = "Laser Turntable Deck",
		Category = "DJBooth",
		Cost = 600,
		Popularity = 60,
		Luxury = 35,
		FootprintX = 1,
		FootprintY = 1,
		HeightPx = 115,
		FallbackColor = Color3.fromRGB(168, 85, 247),
		AssetId = "",
	},
	VelvetVIPBooth = {
		Id = "VelvetVIPBooth",
		Name = "High-Roller VIP Lounge",
		Category = "VIPBooth",
		Cost = 900,
		Popularity = 20,
		Luxury = 95,
		FootprintX = 1,
		FootprintY = 1,
		HeightPx = 100,
		FallbackColor = Color3.fromRGB(245, 158, 11),
		AssetId = "",
	},
	BouncerStation = {
		Id = "BouncerStation",
		Name = "Security Bouncer Post",
		Category = "BouncerPost",
		Cost = 450,
		Popularity = 10,
		Luxury = 30,
		FootprintX = 1,
		FootprintY = 1,
		HeightPx = 115,
		FallbackColor = Color3.fromRGB(239, 68, 68),
		AssetId = "",
		EffectRadius = 3.5,
	},
} :: { [string]: Types.ItemDef }

return GameConfig
