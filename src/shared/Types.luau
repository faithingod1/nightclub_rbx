--!strict

export type ItemCategory = "Floor" | "DancePad" | "Decor" | "Speaker" | "MocktailBar" | "DJBooth" | "VIPBooth" | "BouncerPost"

export type DJSkillId = "RefreshSet" | "DropTheBass" | "MicShoutout"

export type ItemDef = {
	Id: string,
	Name: string,
	Category: ItemCategory,
	Cost: number,
	Popularity: number,
	Luxury: number,
	FootprintX: number,
	FootprintY: number,
	HeightPx: number,
	FallbackColor: Color3,
	AssetId: string,
	EffectRadius: number?,
	StorageCapacity: number?,
}

export type PlacedItem = {
	Uid: string,
	ItemId: string,
	GX: number,
	GY: number,
	Rot: number?,
}

export type CelebrityVisit = {
	Id: string, Name: string, Genre: string, EndsAt: number,
	Progress: number, Goal: number, Reward: number, Rewarded: boolean,
}

export type Appearance = {
	Skin: number, Face: number, Hair: number, HairColor: number,
	Eyes: number, Top: number, Bottom: number, Shoes: number,
}

export type ClubState = {
	Appearance: Appearance?,
	Celebrity: CelebrityVisit?,
	NextCelebrityAt: number,
	GridWidth: number,
	GridHeight: number,
	Cash: number,
	MocktailStock: number,
	MaxMocktailStock: number,
	Popularity: number,
	Luxury: number,
	ActiveGenre: string,
	DJSetEndsAt: number,
	SkillCooldowns: { [DJSkillId]: number },
	PlacedItems: { [string]: PlacedItem },
}

export type GuestMode = "Queueing" | "Walking" | "Chatting" | "Escorted" | "Entering" | "Dancing" | "GettingMocktail" | "VIPChilling" | "RowdyCrasher" | "Leaving"

export type GuestEntity = {
	Id: number,
	GX: number,
	GY: number,
	TargetGX: number,
	TargetGY: number,
	Speed: number,
	Happiness: number,
	IsVIP: boolean,
	Mode: GuestMode,
	SpriteColor: Color3,
	GuiRoot: Frame?,
}

export type EditMode = "None" | "Build" | "Move" | "Remove"

export type SpriteClip = {
	FirstFrame: number, -- Zero-based, row-major atlas index.
	FrameCount: number,
	FPS: number,
	Looped: boolean,
}

export type SpriteSheet = {
	AssetId: string,
	Clips: { [string]: SpriteClip },
}

export type SpriteAnimator = {
	Root: Frame,
	Play: (name: string) -> (),
	Update: (dt: number, zIndex: number, facing: ("Left" | "Right")?) -> (),
	SetFacing: ((facing: "Left" | "Right") -> ())?,
	Destroy: () -> (),
}

export type CrowdGuest = GuestEntity & {
	Animator: SpriteAnimator,
	Status: TextLabel,
	Path: { Vector2 },
	PathIndex: number,
	Activity: GuestMode,
	WaitUntil: number,
	LeaveAt: number,
	IsRowdy: boolean,
	CelebrityId: string?,
	CelebrityName: string?,
	GuardUid: string?,
	TargetUid: string?,
	SlotKey: string?,
}

export type CrowdGuard = {
	GX: number,
	GY: number,
	Post: PlacedItem,
	Radius: number,
	Animator: SpriteAnimator,
	Status: TextLabel,
	Ring: Folder,
	GuestId: number?,
	Path: { Vector2 },
	PathIndex: number,
	Escorting: boolean,
}

export type GuestController = {
	Update: (dt: number) -> (),
	SetState: (state: ClubState) -> (),
	Rally: () -> (),
	Destroy: () -> (),
}

export type TipTransfer = { Recipient: number, Sequence: number, Amount: number }
export type Profile = {
	Version: number, State: ClubState, Lock: { Token: string, Expires: number }?,
	SaveId: string?, PendingCredits: number, Received: { [string]: number },
	TipSequence: number, Outbox: TipTransfer?, LastTipAt: number,
}
export type DataSession = {
	State: ClubState, Token: string, Expires: number, Busy: boolean, Failed: boolean,
	Closing: boolean, TipSequence: number, Outbox: TipTransfer?, LastTipAt: number,
}
export type FriendCard = { UserId: number, Name: string, Online: boolean }
export type MusicController = { Update: (state: ClubState) -> (), Destroy: () -> () }
export type SocialPanel = { Update: (state: ClubState) -> (), Destroy: () -> () }

export type CharacterEditor = {
	Open: (Appearance?) -> (), IsOpen: () -> boolean, Destroy: () -> (),
}

return {}
