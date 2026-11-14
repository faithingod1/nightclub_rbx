--!strict
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Config = require(Shared:WaitForChild("GameConfig"))
local Rules = require(script.Parent:WaitForChild("ClubRules"))
local DataManager = {}

-- Store injection permits deterministic failure/retry tests without live saves.
function DataManager.new(injectedStore: any?, previewOverride: boolean?)
	local preview = if previewOverride ~= nil then previewOverride else RunService:IsStudio() and Config.PERSISTENCE.StudioSessionOnly
	local store = injectedStore or (if preview then nil else DataStoreService:GetDataStore(Config.PERSISTENCE.StoreName))
	local sessions: { [number]: Types.DataSession } = {}
	local function key(id: number): string return "Player_" .. id end
	local function retry(operation: () -> any): (boolean, any)
		for attempt = 1, 3 do
			local ok, result = pcall(operation)
			if ok then return true, result end
			if attempt < 3 then task.wait(attempt) end
		end
		return false, nil
	end
	local function load(id: number): (Types.ClubState?, string)
		if sessions[id] then return nil, "Profile already loaded" end
		local token = HttpService:GenerateGUID(false)
		local profile: Types.Profile?
		if preview then
			profile = { Version = 1, State = Rules.new(), PendingCredits = 0, Received = {}, TipSequence = 0, LastTipAt = 0 }
		else
			local ok, result = retry(function()
				return store:UpdateAsync(key(id), function(old: any)
					if old ~= nil and (typeof(old) ~= "table" or old.Version ~= 1 or not Rules.decode(old.State)) then return nil end
					local record = old or { Version = 1, State = Rules.new(), PendingCredits = 0, Received = {}, TipSequence = 0, LastTipAt = 0 }
					if record.Lock and record.Lock.Token ~= token and record.Lock.Expires > os.time() then return nil end
					record.Lock = { Token = token, Expires = os.time() + Config.PERSISTENCE.LeaseSeconds }
					return record
				end)
			end)
			if not ok or not result or not result.Lock or result.Lock.Token ~= token then
				return nil, "Your club could not be loaded or is open on another server. Please rejoin shortly."
			end
			profile = result
		end
		local record = profile :: Types.Profile
		local state = Rules.decode(record.State)
		if not state then return nil, "Saved club needs recovery; no data was overwritten" end
		sessions[id] = { State = state, Token = token, Expires = os.time() + Config.PERSISTENCE.LeaseSeconds,
			Busy = false, Failed = false, Closing = false, TipSequence = record.TipSequence or 0,
			Outbox = record.Outbox, LastTipAt = record.LastTipAt or 0 }
		return state, if preview then "Studio preview - progress is not saved" else "Club loaded"
	end
	local function writable(id: number): boolean
		local session = sessions[id]
		return session ~= nil and not session.Busy and not session.Failed and not session.Closing
			and (preview or session.Expires > os.time())
	end
	local function save(id: number, release: boolean?): boolean
		local session = sessions[id]
		if not session or session.Busy or session.Failed then return false end
		if preview then return true end
		if session.Expires <= os.time() then session.Failed = true; return false end
		session.Busy = true
		local snapshot = assert(Rules.decode(session.State))
		local operationId = HttpService:GenerateGUID(false)
		local ok, result = retry(function()
			return store:UpdateAsync(key(id), function(record: any)
				-- A retried ambiguous success returns its original result, including credits.
				if record and record.SaveId == operationId then
					if release and not record.Lock then return record end
					if not release and record.Lock and record.Lock.Token == session.Token then return record end
					return nil
				end
				if not record or not record.Lock or record.Lock.Token ~= session.Token or record.Lock.Expires <= os.time() then return nil end
				local state = assert(Rules.decode(snapshot))
				state.Cash += record.PendingCredits or 0
				record.State, record.PendingCredits = state, 0
				record.SaveId = operationId
				record.TipSequence, record.Outbox, record.LastTipAt = session.TipSequence, session.Outbox, session.LastTipAt
				record.Lock = if release then nil else { Token = session.Token, Expires = os.time() + Config.PERSISTENCE.LeaseSeconds }
				return record
			end)
		end)
		session.Busy = false
		if not ok or not result or result.SaveId ~= operationId then session.Failed = true; return false end
		session.State.Cash = result.State.Cash
		session.Expires = os.time() + Config.PERSISTENCE.LeaseSeconds
		return true
	end
	local function read(id: number): Types.ClubState?
		local session = sessions[id]
		if session and not session.Failed then return Rules.decode(session.State) end
		if preview then return nil end
		local ok, profile = retry(function() return store:GetAsync(key(id)) end)
		if not ok or not profile or profile.Version ~= 1 then return nil end
		return Rules.decode(profile.State)
	end
	local function deliver(id: number): boolean
		local session = sessions[id]
		if not session or session.Busy or session.Failed then return false end
		local transfer = session.Outbox
		if not transfer then return true end
		session.Busy = true
		local ok, result = retry(function()
			return store:UpdateAsync(key(transfer.Recipient), function(record: any)
				if not record or record.Version ~= 1 or not Rules.decode(record.State) then return nil end
				record.Received = record.Received or {}
				local sender = tostring(id)
				if (record.Received[sender] or 0) < transfer.Sequence then
					record.PendingCredits = (record.PendingCredits or 0) + transfer.Amount
					record.Received[sender] = transfer.Sequence
				end
				return record
			end)
		end)
		session.Busy = false
		if not ok or not result or (result.Received[tostring(id)] or 0) < transfer.Sequence then return false end
		session.Outbox = nil
		return save(id)
	end
	local function tip(id: number, recipient: number): (boolean, string)
		if not writable(id) then return false, "Your club is saving; try again shortly" end
		local session = sessions[id]
		if session.Outbox then return false, "Previous tip is still being delivered" end
		if id == recipient then return false, "Visit a friend's DJ booth to tip" end
		if os.time() < session.LastTipAt + Config.TIP_COOLDOWN then return false, "Please wait before tipping again" end
		if session.State.Cash < Config.TIP_AMOUNT then return false, "Not enough cash to tip" end
		if preview and not writable(recipient) then return false, "Studio tips require a friend in this server" end
		session.State.Cash -= Config.TIP_AMOUNT
		session.LastTipAt = os.time()
		if preview then sessions[recipient].State.Cash += Config.TIP_AMOUNT; return true, "DJ tipped! (Studio preview)" end
		session.TipSequence += 1
		session.Outbox = { Recipient = recipient, Sequence = session.TipSequence, Amount = Config.TIP_AMOUNT }
		-- Durable debit + outbox first; retries can never mint a second credit.
		if not save(id) then return false, "Save unavailable. Please rejoin to recover your club." end
		if deliver(id) then return true, "DJ tipped! Credit arrives with their next save or join." end
		return true, "Tip saved and queued for delivery"
	end
	local function flush(id: number): boolean
		if not save(id) then return false end
		deliver(id)
		return sessions[id] ~= nil and not sessions[id].Failed
	end
	local function close(id: number)
		local session = sessions[id]
		if not session then return end
		if session.Closing then
			-- BindToClose must wait for a PlayerRemoving save already in flight.
			local deadline = os.clock() + 25
			while sessions[id] == session and os.clock() < deadline do task.wait(0.1) end
			return
		end
		session.Closing = true
		local deadline = os.clock() + 20
		while session.Busy and os.clock() < deadline do task.wait(0.1) end
		if not session.Busy then
			if not session.Failed then deliver(id); save(id, true) end
			sessions[id] = nil
		end
	end
	return { Load = load, Save = save, Flush = flush, Close = close, Read = read, Tip = tip,
		Writable = writable, Preview = preview, Sessions = sessions }
end

return DataManager
