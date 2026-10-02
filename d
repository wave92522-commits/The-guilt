--====================================================================--
--  THE GUILT  //  LOCAL MORPH v5.2 / By SM1LER                          --
--  Client-only morph. One LocalScript. Model loads via executor.       --
--  Model: rbxassetid://86440783786301                                  --
--                                                                      --
--  Q / LMB - Cleave combo   E - Lunge        R - Devour                --
--  F - EXECUTE   B - Heavy kick   C - Burrow   G - Crawl prone       --
--  V - Taunt                T - local dummy  RightShift - menu         --
--  P - reload               End - stop & restore                       --
--  H - toggle bind pose                                                --
--                                                                      --
--  Client-side kill: players + NPCs. NPC Health=0 when possible.       --
--====================================================================--

local CONFIG = {
	MODEL_ID        = 86440783786301,
	MODEL_NAMES     = {"Guilt", "GuiltRig", "TheGuilt", "86440783786301"},
	MODEL_YAW       = 0,
	TARGET_HEIGHT   = 24,
	RESIZE_MODEL    = false,
	PIVOT_OVERRIDES = {},
	SAFE_DISTANCE   = 3,
	WALK_SPEED      = 13,
	RUN_SPEED       = 42,
	CRAWL_SPEED     = 10,
	-- Random distant scream: plays on its own every SCREAM_MIN..SCREAM_MAX seconds.
	SCREAM_MIN      = 11,
	SCREAM_MAX      = 32,
	-- Prone crawl tuning (radians). Raise/lower these if your model needs it.
	-- The crawl arms are solved with inverse kinematics from your model's real bone lengths:
	-- each hand is PLANTED on the ground, slides back as the body moves, then lifts and steps forward.
	CRAWL = {
		BODY_PITCH = -1.32,  -- whole body tipped forward (about -1.57 = fully flat)
		CHEST_LIFT = 0.42,   -- how far the chest is propped up on the arms
		NECK_UP    = 0.80,   -- neck craned up so the head still looks forward
		ARM_OUT    = 0.10,   -- arms spread sideways while dragging
		GROUND     = 0.05,   -- wrist height above the floor, as a fraction of model height
		LIFT       = 0.10,   -- how high a hand rises while stepping forward (fraction of height)
		CYCLE_LEN  = 0.5,    -- body travel per full arm cycle, as a fraction of model height
	},
	-- Walking arms (radians). Raise SWING for bigger swings, ELBOW for more bend, LAG for looser,
	-- heavier arms, OUT to hold the arms further from the body.
	WALK_ARMS = {
		BACK       = -0.18, -- both long arms trail slightly behind the torso
		SWING      = 0.24,  -- restrained shoulder swing; not a human marching motion
		ELBOW      = 0.15,
		ELBOW_BASE = 0.08,
		OUT        = 0.08,
		LAG        = 0.62,
	},
	DEVOUR_RANGE    = 18,
	SLAM_RANGE      = 20,
	EXECUTE_RANGE   = 20,
	THROW_DIST      = 120,
	KICK_RANGE      = 19,
	KICK_DIST       = 145,
	ROAR_RANGE      = 36,
	RESPAWN_DELAY   = 22,
	MAX_VICTIM_SIZE = 48,
	KILL_PROPS      = false,
	KILL_PLAYERS    = true,  -- client-side hide/kill players too
	GORE            = 1.4,
	MAX_PIECES      = 420,
	MAX_STAINS      = 260,
	MENU_KEY        = Enum.KeyCode.RightShift,
	LOAD_KEY        = Enum.KeyCode.P,
	STOP_KEY        = Enum.KeyCode.End,
	FONT_TITLE      = Enum.Font.GothamBlack,
	FONT_UI         = Enum.Font.GothamMedium,
	FONT_MARK       = Enum.Font.SourceSansBold,
	NEON_A          = Color3.fromRGB(198, 38, 38),
	NEON_B          = Color3.fromRGB(232, 226, 214),
	NEON_C          = Color3.fromRGB(232, 163, 61),
}

local SND = {
	growl   = "rbxasset://sounds/uuhhh.mp3",
	whoosh  = "rbxasset://sounds/swordlunge.wav",
	slash   = "rbxasset://sounds/swordslash.wav",
	splat   = "rbxasset://sounds/impact_water.mp3",
	hit     = "rbxasset://sounds/hit.wav",
	ui      = "rbxasset://sounds/electronicpingshort.wav",
	roar    = "rbxasset://sounds/snap.mp3",
	drain   = "rbxasset://sounds/rollingball.wav",
	land    = "rbxasset://sounds/action_jump_land.mp3",      -- heavy thud, pitched way down for giant footsteps
	crunch  = "rbxasset://sounds/action_footsteps_plastic.mp3",
}

local CHAIN = {
	{"Quadril",   "HumanoidRootPart"},
	{"Torso",     "Quadril"},
	{"Spine",     "Torso"},
	{"Neck",      "Spine"},
	{"Head",      "Neck"},
	{"Larm",      "Torso"},
	{"ForeLarm",  "Larm"},
	{"Lhand",     "ForeLarm"},
	{"Rarm",      "Torso"},
	{"ForeRarm",  "Rarm"},
	{"Rhand",     "ForeRarm"},
	{"Lleg",      "Quadril"},
	{"LforeLeg",  "Lleg"},
	{"Lfoot",     "LforeLeg"},
	{"Rleg",      "Quadril"},
	{"RforeLeg",  "Rleg"},
	{"Rfoot",     "RforeLeg"},
}

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService     = game:GetService("InsertService")

local player = Players.LocalPlayer
if not player then return end

local genv = (typeof(getgenv) == "function" and getgenv()) or _G
if genv.__GUILT_V5 then pcall(genv.__GUILT_V5) end

local rng = Random.new()
local function rnd(a, b) return rng:NextNumber(a, b) end
local UP = Vector3.new(0, 1, 0)
local IDENTITY = CFrame.new()
local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x) x = clamp01(x) return x * x * (3 - 2 * x) end
local function easeOut(x) x = clamp01(x) return 1 - (1 - x) ^ 3 end
local function easeIn(x) x = clamp01(x) return x * x * x end
local function lerp(a, b, t) return a + (b - a) * t end
local function bez(a, b, c, k) local u = 1 - k return a * (u * u) + b * (2 * u * k) + c * (k * k) end
local function PR(x, y, z, rx, ry, rz)
	return CFrame.new(x or 0, y or 0, z or 0) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
end

local globalConns, morphConns = {}, {}
local function gtrack(c) globalConns[#globalConns + 1] = c return c end
local function mtrack(c) morphConns[#morphConns + 1] = c return c end

local menuOpen, introDone = false, false
local startDevour, startSlam, surface, goUnder, buildEntries, analyze
local mount, unmount, report, layoutViewport, closeMenu
local startExecute, startKick

local S = {
	mounted = false, busy = false, fallback = false, mode = "idle",
	crawlBlend = 0, runBlend = 0, speedS = 0, crawlDrop = 0,
	stepAcc = 0, lastStep = 0, armIK = nil, torsoIK = nil,
	character = nil, humanoid = nil, hrp = nil, model = nil,
	entries = {}, parts = {}, cfs = {}, bones = {}, rig = nil, restPose = false, height = CONFIG.TARGET_HEIGHT,
	unit = 1, yaw = 0, yawCF = CFrame.new(), pose = {}, poseCur = {},
	grabSide = 1, armPivot = {}, armLen = {},
	mawWorld = Vector3.new(), clawWorld = Vector3.new(), faceWorld = Vector3.new(),
	handWorld = { [1] = Vector3.zero, [-1] = Vector3.zero },
	dripEntries = {}, underground = false, walk = 0, phase = 0, sprinting = false, flat = Vector3.new(0, 0, -1),
	shake = 0, camBase = Vector3.zero, atk = nil, atkStart = 0, atkDur = 0, atkHas = false,
	ev = {}, victim = nil, releasePos = nil, atkLock = 0, fLock = 0, nextHide = 0,
	drool = 0, nextDrip = 0, nextVDrip = 0, pending = nil, jumpLocked = false,
	combo = 0, comboWindow = 0, consumed = 0, flip = genv.__GUILT_FLIP or 0,
	origTransp = setmetatable({}, { __mode = "k" }),
}

local sinkValue = Instance.new("NumberValue")

local fxFolder = Instance.new("Folder")
fxFolder.Name = "GuiltFX_v52_SM1LER"
fxFolder.Parent = workspace
local dummyFolder = Instance.new("Folder")
dummyFolder.Name = "GuiltLocalDummies_v52"
dummyFolder.Parent = workspace

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local function refreshFilter() rayParams.FilterDescendantsInstances = {fxFolder, dummyFolder, S.character} end
refreshFilter()

local function groundAt(pos, up, depth)
	return workspace:Raycast(pos + Vector3.new(0, up, 0), Vector3.new(0, -depth, 0), rayParams)
end

local function sfx(id, vol, pitch)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 1
	s.PlaybackSpeed = pitch or 1
	s.Parent = (S.hrp and S.hrp.Parent) and S.hrp or workspace
	pcall(function() s:Play() end)
	Debris:AddItem(s, 6)
end

local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

local function bloodColor()
	if rng:NextNumber() < 0.6 then
		return Color3.fromRGB(rng:NextInteger(180, 240), rng:NextInteger(0, 16), rng:NextInteger(0, 20))
	end
	return Color3.fromRGB(rng:NextInteger(90, 150), 0, rng:NextInteger(0, 12))
end
local function boneColor()
	local b = rng:NextInteger(210, 242)
	return Color3.fromRGB(b, b - rng:NextInteger(6, 20), b - rng:NextInteger(26, 44))
end
local function fleshColor()
	return Color3.fromRGB(rng:NextInteger(130, 185), rng:NextInteger(28, 68), rng:NextInteger(38, 72))
end
local function dirtColor()
	return Color3.fromRGB(rng:NextInteger(38, 68), rng:NextInteger(22, 42), rng:NextInteger(16, 30))
end

local function flatCF(pos, normal)
	local ref = (math.abs(normal.Y) > 0.9) and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local tangent = ref:Cross(normal).Unit
	return CFrame.fromMatrix(pos, tangent, normal, tangent:Cross(normal))
end

local function coneDir(d, spread)
	local up = (math.abs(d.Y) > 0.95) and Vector3.new(0, 0, 1) or UP
	return (CFrame.lookAt(Vector3.zero, d, up) * CFrame.Angles(rnd(-spread, spread), rnd(-spread, spread), 0)).LookVector
end

local function anchorPart(pos)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
	a.Transparency = 1
	a.Size = Vector3.new(0.2, 0.2, 0.2)
	a.Position = pos
	a.Parent = fxFolder
	return a
end

--====================================================================--
-- GORE / FX                                                          --
--====================================================================--
local stains = {}
local function makeDisc(pos, normal, d1, d2, thick, color, material)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = Vector3.new(d1, thick, d2)
	p.CFrame = flatCF(pos, normal) * CFrame.Angles(0, rnd(0, 6.283), 0)
	Instance.new("CylinderMesh").Parent = p
	return p
end

local zc = 0
local function puddle(pos, normal, radius, life, quick)
	if S.mode == "crawl" then return end
	zc = (zc + 1) % 60
	local p = makeDisc(pos + normal * (0.03 + zc * 0.003), normal, 0.2, 0.2, 0.05,
		Color3.fromRGB(rng:NextInteger(80, 135), 0, rng:NextInteger(0, 9)))
	p.Reflectance = 0.2
	p.Parent = fxFolder
	stains[#stains + 1] = p
	if #stains > CONFIG.MAX_STAINS then
		local o = table.remove(stains, 1)
		if o and o.Parent then o:Destroy() end
	end
	tw(p, quick and rnd(0.15, 0.3) or rnd(0.8, 1.6),
		{Size = Vector3.new(radius * 2 * rnd(0.85, 1.2), 0.05, radius * 2 * rnd(0.85, 1.2))}, Enum.EasingStyle.Quart)
	task.delay(life, function()
		if p.Parent then tw(p, 3, {Transparency = 1}) Debris:AddItem(p, 3.1) end
	end)
end

local function scatterPuddles(center, count, spread, rmin, rmax, life)
	for _ = 1, math.max(1, math.floor(count * CONFIG.GORE)) do
		local a = rnd(0, 6.283)
		local g = groundAt(center + Vector3.new(math.cos(a), 0, math.sin(a)) * rnd(2, spread), 8, 30)
		if g then puddle(g.Position, g.Normal, rnd(rmin, rmax), life, false) end
	end
end

local live = 0
local function piece(kind, pos, vel, size)
	if live >= CONFIG.MAX_PIECES then return end
	if S.mode == "crawl" then return end
	live += 1
	local born = os.clock()
	local p = Instance.new("Part")
	if kind == "bone" then
		p.Color, p.Material = boneColor(), Enum.Material.SmoothPlastic
		p.Size = Vector3.new(size * 0.42, size * rnd(1.2, 2.4), size * 0.42)
	elseif kind == "flesh" then
		p.Color, p.Material = fleshColor(), Enum.Material.Slate
		p.Size = Vector3.new(size, size * rnd(0.6, 1.3), size * rnd(0.7, 1.3))
	elseif kind == "dirt" then
		p.Color, p.Material = dirtColor(), Enum.Material.Ground
		p.Size = Vector3.new(size, size * rnd(0.5, 0.9), size)
	else
		p.Color, p.Material = bloodColor(), Enum.Material.SmoothPlastic
		p.Reflectance = 0.16
		p.Size = Vector3.new(size, size * rnd(0.8, 1.25), size * rnd(0.8, 1.25))
	end
	p.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.7, 0.05, 1, 1)
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, true
	p.CastShadow = size > 0.8
	p.CFrame = CFrame.new(pos) * CFrame.Angles(rnd(0, 6.28), rnd(0, 6.28), rnd(0, 6.28))
	p.Parent = fxFolder
	p.AssemblyLinearVelocity = vel
	p.AssemblyAngularVelocity = Vector3.new(rnd(-20, 20), rnd(-20, 20), rnd(-20, 20))
	p.Destroying:Connect(function() live -= 1 end)
	Debris:AddItem(p, 10)
	task.delay(0.18, function() if p.Parent then p.CanCollide = true end end)
	local landed, c = false, nil
	c = p.Touched:Connect(function(hit)
		if landed or os.clock() - born < 0.2 or not hit.CanCollide then return end
		if hit:IsDescendantOf(fxFolder) or (S.character and hit:IsDescendantOf(S.character)) then return end
		landed = true
		c:Disconnect()
		if kind == "blood" and rng:NextNumber() < 0.75 then
			local g = groundAt(p.Position, 1.2, 5)
			if g then puddle(g.Position, g.Normal, math.clamp(size * rnd(1.1, 2), 0.4, 2.8), rnd(15, 26), true) end
		end
		task.delay(rnd(2, 5), function()
			if p.Parent then tw(p, 0.6, {Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1}) Debris:AddItem(p, 0.7) end
		end)
	end)
end

local function carnage(pos, dir, count, o)
	o = o or {}
	local n = math.max(1, math.floor(count * CONFIG.GORE))
	for _ = 1, n do
		local roll = rng:NextNumber()
		local kind = (roll < (o.bone or 0.18)) and "bone"
			or ((roll < (o.bone or 0.18) + (o.flesh or 0.24)) and "flesh" or "blood")
		piece(kind, pos + Vector3.new(rnd(-1, 1), rnd(-0.5, 1), rnd(-1, 1)) * (o.jitter or 1),
			coneDir(dir, o.spread or 0.9) * rnd(o.vmin or 25, o.vmax or 70),
			rnd(o.smin or 0.6, o.smax or 1.8))
	end
end

local function mist(pos, amount, size, col)
	if S.mode == "crawl" then return end
	local a = anchorPart(pos)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Color = ColorSequence.new(col or Color3.fromRGB(200, 20, 20), Color3.fromRGB(45, 0, 0))
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.55),
		NumberSequenceKeypoint.new(1, size * 1.85),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Lifetime = NumberRange.new(0.7, 1.9)
	pe.Speed = NumberRange.new(8, 28)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Drag = 3.4
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(amount)
	Debris:AddItem(a, 3.5)
end

local function ring(pos, normal, maxR, color, dur)
	local p = makeDisc(pos + normal * 0.08, normal, 1, 1, 0.12, color, Enum.Material.Neon)
	p.Transparency = 0.25
	p.Parent = fxFolder
	tw(p, dur, {Size = Vector3.new(maxR * 2, 0.12, maxR * 2), Transparency = 1})
	Debris:AddItem(p, dur + 0.2)
end

local function lightFlash(pos, col, br, range, dur)
	local a = anchorPart(pos)
	local l = Instance.new("PointLight")
	l.Color, l.Brightness, l.Range = col, br, range
	l.Parent = a
	tw(l, dur, {Brightness = 0})
	Debris:AddItem(a, dur + 0.1)
end

local function arterial(getPos, dir, dur, rate)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur and fxFolder.Parent do
			local p = getPos()
			if p then piece("blood", p, coneDir(dir, 0.35) * rnd(18, 34), rnd(0.2, 0.5)) end
			task.wait(rate or 0.025)
		end
	end)
end

local function fissure(pos, normal)
	for i = 1, 9 do
		local a = i / 9 * 6.283 + rnd(-0.2, 0.2)
		local len = rnd(5, 12)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local c = Instance.new("Part")
		c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
		c.Color = Color3.fromRGB(8, 3, 3)
		c.Size = Vector3.new(0.55, 0.1, 0.1)
		c.CFrame = CFrame.lookAt(pos + d * len / 2 + normal * 0.06, pos + d * len + normal * 0.06)
		c.Parent = fxFolder
		local glow = c:Clone()
		glow.Material = Enum.Material.Neon
		glow.Color = CONFIG.NEON_C
		glow.Size = Vector3.new(0.16, 0.13, 0.1)
		glow.Parent = fxFolder
		tw(c, 0.25, {Size = Vector3.new(0.55, 0.1, len)})
		tw(glow, 0.25, {Size = Vector3.new(0.16, 0.13, len)})
		task.delay(1.2, function() if glow.Parent then tw(glow, 2, {Transparency = 1}) end end)
		task.delay(7, function() if c.Parent then tw(c, 2, {Transparency = 1}) end end)
		Debris:AddItem(glow, 3.5)
		Debris:AddItem(c, 9.5)
	end
end

local tint
local function impactTint(strength)
	if not tint then return end
	tint.TintColor = Color3.fromRGB(255, math.floor(140 - 85 * strength), math.floor(140 - 85 * strength))
	tint.Contrast = 0.16 + 0.26 * strength
	tw(tint, 0.6, {TintColor = Color3.fromRGB(255, 226, 224), Contrast = 0.12})
end

local baseFOV
local function fovPunch(amount)
	local cam = workspace.CurrentCamera
	if not cam then return end
	baseFOV = baseFOV or cam.FieldOfView
	cam.FieldOfView = baseFOV + amount
	tw(cam, 0.45, {FieldOfView = baseFOV}, Enum.EasingStyle.Quart)
end

--====================================================================--
-- VICTIMS — players + NPCs (client-side). Real Health kill when can. --
--====================================================================--
local victims = {}

local function getRoot(m)
	local r = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso") or m:FindFirstChild("UpperTorso")
	if r and r:IsA("BasePart") then return r end
	if m.PrimaryPart then return m.PrimaryPart end
	local head = m:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head end
	local best, bestVol = nil, 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local vol = d.Size.X * d.Size.Y * d.Size.Z
			if vol > bestVol then best, bestVol = d, vol end
		end
	end
	return best
end

local LONG_WORDS = {
	"dummy", "mannequin", "zombie", "monster", "creature", "skeleton",
	"ghost", "villager", "civilian", "victim", "enemy", "demon", "ghoul",
	"citizen", "target", "bandit", "cultist", "npc",
}
local SHORT_WORDS = {"npc", "mob", "bot", "boss", "clone", "elite"}

local function nameLooksAlive(m)
	local n = string.lower(m.Name)
	for _, w in ipairs(LONG_WORDS) do
		if n:find(w, 1, true) then return true end
	end
	for _, w in ipairs(SHORT_WORDS) do
		if n:find("%f[%a]" .. w .. "%f[%A]") then return true end
	end
	return false
end

local function isRig(m)
	if m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildOfClass("AnimationController") then return true end
	if m:FindFirstChild("Head") and (m:FindFirstChild("Torso") or m:FindFirstChild("UpperTorso") or m:FindFirstChild("HumanoidRootPart")) then
		return true
	end
	return nameLooksAlive(m)
end

local function isSelf(m)
	local ch = S.character
	if ch and (m == ch or m:IsDescendantOf(ch) or ch:IsDescendantOf(m)) then return true end
	return false
end

local function isPlayerModel(m)
	if Players:GetPlayerFromCharacter(m) then return true end
	for _, other in ipairs(Players:GetPlayers()) do
		local ch = other.Character
		if ch and (m == ch or m:IsDescendantOf(ch) or ch:IsDescendantOf(m)) then return true end
	end
	return false
end

local function validTarget(m)
	if victims[m] or not m.Parent then return nil end
	if isSelf(m) then return nil end
	if m:IsDescendantOf(fxFolder) or m:IsDescendantOf(dummyFolder) then
		-- dummies inside dummyFolder ARE valid targets
		if not m:IsDescendantOf(dummyFolder) then return nil end
	end
	if m:IsDescendantOf(fxFolder) then return nil end
	if S.sourceTemplate and (m == S.sourceTemplate or m:IsDescendantOf(S.sourceTemplate)) then return nil end
	if m.Name == "GuiltMorph_v5" or m.Name == "GuiltMorph_v52" then return nil end
	-- players allowed when KILL_PLAYERS
	if isPlayerModel(m) and not CONFIG.KILL_PLAYERS then return nil end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return nil end
	local rig = hum ~= nil or isRig(m)
	if not (rig or CONFIG.KILL_PROPS) then return nil end
	local root = getRoot(m)
	if not root then return nil end
	local ok, size = pcall(function() return m:GetExtentsSize() end)
	if not ok then return nil end
	local maxDim = math.max(size.X, size.Y, size.Z)
	if maxDim > CONFIG.MAX_VICTIM_SIZE then return nil end
	if not rig and maxDim > 12 then return nil end
	return root
end

local function candidateFromPart(part)
	local m = part:FindFirstAncestorOfClass("Model")
	local nearest, firstRig = m, nil
	while m do
		if isSelf(m) then return nil end
		if m:FindFirstChildOfClass("Humanoid") then
			if isPlayerModel(m) and not CONFIG.KILL_PLAYERS then
				-- skip player models if disabled
			else
				return m
			end
		end
		if not firstRig and isRig(m) then
			if not (isPlayerModel(m) and not CONFIG.KILL_PLAYERS) then firstRig = m end
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	if firstRig then return firstRig end
	if CONFIG.KILL_PROPS and nearest and not isSelf(nearest) then return nearest end
	return nil
end

local function findTarget(range, center)
	local hrp = S.hrp
	if not hrp then return nil end
	center = center or (hrp.Position + S.flat * 5)
	local best, bestD = nil, range + 3
	local seen = {}
	local function consider(m)
		if not m or seen[m] then return end
		seen[m] = true
		local r = validTarget(m)
		if r then
			local d = (r.Position - center).Magnitude
			if d < bestD then best, bestD = m, d end
		end
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = {fxFolder, S.character}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, range, op)) do
		consider(candidateFromPart(part))
	end
	if not best then
		for _, d in ipairs(workspace:GetDescendants()) do
			if d.ClassName == "Humanoid" and d.Parent and d.Parent:IsA("Model") then
				consider(d.Parent)
			end
		end
	end
	return best
end

local function vSet(rec, cf) pcall(function() rec.model:PivotTo(cf) end) end
local function vPos(rec)
	local ok, cf = pcall(function() return rec.model:GetPivot() end)
	return ok and cf.Position or rec.origCF.Position
end

local TOGGLE = {
	BillboardGui = true, SurfaceGui = true, ParticleEmitter = true, Beam = true, Trail = true,
	Highlight = true, Fire = true, Smoke = true, Sparkles = true, PointLight = true,
	SpotLight = true, SurfaceLight = true,
}

local function capture(m)
	local root = getRoot(m)
	if not root then return nil end
	local okp, pivot = pcall(function() return m:GetPivot() end)
	local oks, size = pcall(function() return m:GetExtentsSize() end)
	local rec = {
		model = m, root = root,
		hum = m:FindFirstChildOfClass("Humanoid"),
		parts = {}, transp = {}, collide = {}, anch = {}, toggles = {},
		origCF = okp and pivot or root.CFrame,
		size = oks and size or Vector3.new(4, 6, 2),
		state = "held",
		isPlayer = isPlayerModel(m),
	}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			rec.parts[#rec.parts + 1] = d
			rec.transp[d] = d.Transparency
			rec.collide[d] = d.CanCollide
			rec.anch[d] = d.Anchored
			d.CanCollide = false
			d.Anchored = true
		elseif d:IsA("Decal") then
			rec.parts[#rec.parts + 1] = d
			rec.transp[d] = d.Transparency
		elseif TOGGLE[d.ClassName] then
			rec.toggles[#rec.toggles + 1] = {d, d.Enabled}
			pcall(function() d.Enabled = false end)
		end
	end
	if rec.hum then
		rec.display = rec.hum.DisplayDistanceType
		pcall(function() rec.hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
	end
	victims[m] = rec
	return rec
end

local function restoreVictim(rec, toOrigin)
	victims[rec.model] = nil
	if toOrigin then pcall(function() rec.model:PivotTo(rec.origCF) end) end
	for _, d in ipairs(rec.parts) do
		if d.Parent then
			d.Transparency = rec.transp[d] or 0
			if d:IsA("BasePart") then
				if rec.collide[d] ~= nil then d.CanCollide = rec.collide[d] end
				if rec.anch[d] ~= nil then d.Anchored = rec.anch[d] end
			end
		end
	end
	for _, tg in ipairs(rec.toggles) do
		if tg[1].Parent then pcall(function() tg[1].Enabled = tg[2] end) end
	end
	if rec.hum then
		pcall(function() rec.hum.DisplayDistanceType = rec.display or Enum.HumanoidDisplayDistanceType.Viewer end)
	end
end

-- Real kill attempt: Health=0 (works on local NPCs / some server NPCs). Always client-hide.
local function tryRealKill(rec)
	if rec.hum then
		pcall(function()
			rec.hum.Health = 0
			rec.hum:TakeDamage(rec.hum.MaxHealth + 999)
		end)
	end
end

local function killVictim(rec)
	rec.state = "dead"
	rec.respawnAt = os.clock() + CONFIG.RESPAWN_DELAY
	tryRealKill(rec)
	for _, d in ipairs(rec.parts) do if d.Parent then d.Transparency = 1 end end
	if rec.hum then pcall(function() rec.hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end) end
end

local function dismember(rec, pos, dir, force)
	local list = {}
	for _, limit in ipairs({8, 20}) do
		list = {}
		for _, d in ipairs(rec.parts) do
			if d:IsA("BasePart") and d ~= rec.root and (rec.transp[d] or 0) < 0.9 and d.Size.Magnitude < limit then
				list[#list + 1] = d
			end
		end
		if #list >= 4 then break end
	end
	for i = 1, math.min(7, #list) do
		local src = table.remove(list, rng:NextInteger(1, #list))
		local ok, c = pcall(function()
			src.Archivable = true
			return src:Clone()
		end)
		if ok and c then
			for _, ch in ipairs(c:GetDescendants()) do
				if ch:IsA("JointInstance") or ch:IsA("Constraint") or ch:IsA("LuaSourceContainer")
					or ch:IsA("Attachment") or ch:IsA("BillboardGui") or ch:IsA("SurfaceGui")
					or ch:IsA("Sound") or ch:IsA("ParticleEmitter") or ch:IsA("Beam") or ch:IsA("Trail") then
					ch:Destroy()
				end
			end
			c.Transparency = rec.transp[src] or 0
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.Massless = false, false, false, false, false
			c.CFrame = CFrame.new(pos + Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)))
				* CFrame.Angles(rnd(0, 6), rnd(0, 6), rnd(0, 6))
			c.Parent = fxFolder
			c.AssemblyLinearVelocity = coneDir(dir, 1.1) * rnd(force * 0.5, force)
			c.AssemblyAngularVelocity = Vector3.new(rnd(-25, 25), rnd(-25, 25), rnd(-25, 25))
			task.delay(0.15, function() if c.Parent then c.CanCollide = true end end)
			arterial(function() return c.Parent and c.Position or nil end, UP, 1.4, 0.07)
			task.delay(8, function() if c.Parent then tw(c, 1.5, {Transparency = 1}) end end)
			Debris:AddItem(c, 10)
		end
	end
end

local function checkRespawns()
	local now = os.clock()
	for m, rec in pairs(victims) do
		if not m.Parent then
			victims[m] = nil
		elseif rec.state == "dead" and now >= rec.respawnAt then
			-- players: restore after delay too (client-side only)
			restoreVictim(rec, true)
			if rec.hum then pcall(function()
				if rec.hum.Health <= 0 then rec.hum.Health = rec.hum.MaxHealth end
			end) end
			local p = rec.origCF.Position
			mist(p + UP * 2, 40, 7, CONFIG.NEON_C)
			ring(p - UP * math.clamp(rec.size.Y * 0.5, 1, 20), UP, 8, CONFIG.NEON_A, 0.6)
			lightFlash(p, CONFIG.NEON_C, 5, 20, 0.8)
		end
	end
end

--====================================================================--
-- TEMPLATE LOADING (executor GetObjects / RS / fallback)             --
--====================================================================--
local template, templateLoading = nil, false

local function normalize(res)
	if typeof(res) == "table" then
		local h = Instance.new("Model")
		for _, i in ipairs(res) do
			if typeof(i) == "Instance" then i.Parent = h end
		end
		return h
	elseif typeof(res) == "Instance" then
		if res:IsA("Model") then return res end
		local h = Instance.new("Model")
		res.Parent = h
		return h
	end
end

local function stripModel(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Animator")
			or d:IsA("AnimationController") or d:IsA("Sound") or d:IsA("BodyMover")
			or d:IsA("ForceField") or d:IsA("ClickDetector") or d:IsA("ProximityPrompt") then
			pcall(function() d:Destroy() end)
		end
	end
end

local function buildFallback()
	local m = Instance.new("Model")
	local function part(name, size, cf, color, mat)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Parent = m
		return p
	end
	local boneC = Color3.fromRGB(226, 220, 208)
	local ash = Color3.fromRGB(26, 20, 20)
	part("Torso", Vector3.new(3.2, 8.6, 2.1), CFrame.new(0, 15.2, 0), boneC)
	part("Spine", Vector3.new(2.6, 4.2, 1.9), CFrame.new(0, 20.4, 0), boneC)
	part("Neck", Vector3.new(1.1, 2.4, 1.1), CFrame.new(0, 23.2, 0), ash)
	part("Head", Vector3.new(2.6, 3.4, 2.6), CFrame.new(0, 25.7, 0), boneC)
	part("Quadril", Vector3.new(2.9, 3.2, 2.1), CFrame.new(0, 9.9, 0), ash)
	for _, sx in ipairs({-1, 1}) do
		local L = sx > 0 and "R" or "L"
		part(L .. "arm", Vector3.new(1.05, 7.4, 1.05), CFrame.new(sx * 2.3, 15.4, 0), boneC)
		part("Fore" .. L .. "arm", Vector3.new(0.92, 7.2, 0.92), CFrame.new(sx * 2.35, 8.2, 0.2), boneC)
		part(L .. "hand", Vector3.new(0.85, 2.2, 0.85), CFrame.new(sx * 2.4, 3.6, 0.35), ash)
		part(L .. "leg", Vector3.new(1.15, 8.2, 1.15), CFrame.new(sx * 0.85, 4.2, 0), boneC)
		part(L .. "foreLeg", Vector3.new(1.02, 7.2, 1.02), CFrame.new(sx * 0.9, -3.4, -0.15), boneC)
		part(L .. "foot", Vector3.new(1.15, 0.9, 2.4), CFrame.new(sx * 0.9, -7.2, -0.7), ash)
	end
	local hrp = part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 9.9, 0), ash)
	hrp.Transparency = 1
	return m
end

local function findPrebuilt()
	local containers = {ReplicatedStorage, Workspace, script}
	for _, container in ipairs(containers) do
		for _, name in ipairs(CONFIG.MODEL_NAMES) do
			local direct = container:FindFirstChild(name)
			if direct and direct:IsA("Model") then
				for _, d in ipairs(direct:GetDescendants()) do
					if d:IsA("BasePart") then return direct end
				end
			end
		end
	end
	for _, container in ipairs({ReplicatedStorage, Workspace}) do
		for _, name in ipairs(CONFIG.MODEL_NAMES) do
			local nested = container:FindFirstChild(name, true)
			if nested and nested:IsA("Model") then return nested end
		end
	end
	return nil
end

local function loadTemplate()
	if template then return template end
	if templateLoading then
		while templateLoading do task.wait() end
		return template
	end
	templateLoading = true
	local prebuilt = findPrebuilt()
	S.sourceTemplate = prebuilt
	local raw
	if prebuilt then
		local archivable = prebuilt.Archivable
		prebuilt.Archivable = true
		local ok, clone = pcall(function() return prebuilt:Clone() end)
		prebuilt.Archivable = archivable
		if ok then raw = clone end
	end
	local url = "rbxassetid://" .. CONFIG.MODEL_ID
	local tries = {
		function() return game:GetObjects(url) end,
		function() return (typeof(getobjects) == "function") and getobjects(game, url) or nil end,
		function() return InsertService:LoadLocalAsset(url) end,
		function() return InsertService:LoadAsset(CONFIG.MODEL_ID) end,
	}
	if not raw then
		for _, f in ipairs(tries) do
			local ok, res = pcall(f)
			if ok and res then
				local n = normalize(res)
				if n then
					local has = false
					for _, d in ipairs(n:GetDescendants()) do
						if d:IsA("BasePart") then has = true break end
					end
					if has then raw = n break end
					n:Destroy()
				end
			end
		end
	end
	if raw then
		stripModel(raw)
		local has = false
		for _, d in ipairs(raw:GetDescendants()) do
			if d:IsA("BasePart") then has = true break end
		end
		if not has then raw = nil end
	end
	if not raw then
		S.fallback = true
		raw = buildFallback()
		warn("[Guilt] asset not loaded - procedural fallback (GetObjects needed for catalog model)")
	end
	template = raw
	templateLoading = false
	return template
end

--====================================================================--
-- IMMUTABLE BIND RIG (same as v5.1)                                  --
--====================================================================--
local Rig = {}
do
local function findNamed(model, name, className)
	local direct = model:FindFirstChild(name)
	if direct and direct:IsA(className) then return direct end
	for _, instance in ipairs(model:GetDescendants()) do
		if instance.Name == name and instance:IsA(className) then return instance end
	end
	return nil
end
local function findPart(model, name) return findNamed(model, name, "BasePart") end
local function measure(parts, reference)
	local inv = reference:Inverse()
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for pass = 1, 2 do
		local n = 0
		for _, p in ipairs(parts) do
			if pass == 2 or p.Transparency < 0.95 then
				n += 1
				local cf = inv * p.CFrame
				local hx, hy, hz = p.Size.X / 2, p.Size.Y / 2, p.Size.Z / 2
				local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
				local e = Vector3.new(
					math.abs(r.X) * hx + math.abs(u.X) * hy + math.abs(l.X) * hz,
					math.abs(r.Y) * hx + math.abs(u.Y) * hy + math.abs(l.Y) * hz,
					math.abs(r.Z) * hx + math.abs(u.Z) * hy + math.abs(l.Z) * hz)
				mn = mn:Min(cf.Position - e)
				mx = mx:Max(cf.Position + e)
			end
		end
		if n > 0 then break end
	end
	return mn, mx
end
local function manualScale(model, parts, f, reference)
	for _, p in ipairs(parts) do
		local cf = reference:ToObjectSpace(p.CFrame)
		p.Size = p.Size * f
		p.CFrame = reference * CFrame.new(cf.Position * f) * cf.Rotation
		for _, ch in ipairs(p:GetChildren()) do
			if ch:IsA("SpecialMesh") and ch.MeshType == Enum.MeshType.FileMesh then
				ch.Scale = ch.Scale * f
				ch.Offset = ch.Offset * f
			end
		end
	end
	for _, instance in ipairs(model:GetDescendants()) do
		if instance:IsA("JointInstance") then
			instance.C0 = CFrame.new(instance.C0.Position * f) * instance.C0.Rotation
			instance.C1 = CFrame.new(instance.C1.Position * f) * instance.C1.Rotation
		elseif instance:IsA("Attachment") then
			instance.CFrame = CFrame.new(instance.CFrame.Position * f) * instance.CFrame.Rotation
		end
	end
end
local function captureLinks(model, reference)
	local links, adjacency = {}, {}
	for _, joint in ipairs(model:GetDescendants()) do
		local first, second, pivot, bound
		if joint:IsA("JointInstance") then
			first, second = joint.Part0, joint.Part1
			if first and second then
				local firstFrame = reference:ToObjectSpace(first.CFrame * joint.C0)
				local secondFrame = reference:ToObjectSpace(second.CFrame * joint.C1)
				pivot = firstFrame.Position
				bound = (firstFrame.Position - secondFrame.Position).Magnitude <= 0.02
			end
		elseif joint:IsA("WeldConstraint") then
			first, second = joint.Part0, joint.Part1
		end
		if first and second and first:IsDescendantOf(model) and second:IsDescendantOf(model) then
			links[#links + 1] = {p0 = first, p1 = second, pivot = bound and pivot or nil, motor = joint:IsA("Motor6D") and bound == true}
			adjacency[first] = adjacency[first] or {}
			adjacency[second] = adjacency[second] or {}
			adjacency[first][#adjacency[first] + 1] = second
			adjacency[second][#adjacency[second] + 1] = first
		end
	end
	return links, adjacency
end
local function halfExtent(entry, direction)
	local frame, size = entry.rel, entry.part.Size
	return math.abs(frame.RightVector:Dot(direction)) * size.X * 0.5
		+ math.abs(frame.UpVector:Dot(direction)) * size.Y * 0.5
		+ math.abs(frame.LookVector:Dot(direction)) * size.Z * 0.5
end
local function estimatePivot(parentEntry, childEntry)
	local delta = childEntry.rel.Position - parentEntry.rel.Position
	if delta.Magnitude < 0.0001 then return childEntry.rel.Position end
	local direction = delta.Unit
	local parentEdge = parentEntry.rel.Position + direction * halfExtent(parentEntry, direction)
	local childEdge = childEntry.rel.Position - direction * halfExtent(childEntry, direction)
	return (parentEdge + childEdge) * 0.5
end
local function posedOffset(name, pose)
	local requested = pose[name] or IDENTITY
	return requested.Rotation
end
function Rig.Evaluate(rig, base, pose)
	local pelvis = pose.Quadril or IDENTITY
	base = base * CFrame.new(pelvis.Position * rig.unit)
	local frames = {HumanoidRootPart = base * rig.rootRest}
	for _, name in ipairs(rig.order) do
		local node = rig.nodes[name]
		local parentFrame = frames[node.parent]
		frames[name] = parentFrame * node.c0 * posedOffset(name, pose) * node.c1Inverse
	end
	local cframes = {}
	for index, entry in ipairs(rig.entries) do
		cframes[index] = frames[entry.owner] * entry.ownerOffset
	end
	return cframes, frames
end
local function finiteCFrame(frame)
	for _, number in ipairs({frame:GetComponents()}) do
		if number ~= number or math.abs(number) > 10000000 then return false end
	end
	return true
end
function Rig.Check(rig)
	local frames = Rig.Evaluate(rig, IDENTITY, {})
	local bindError, jointError = 0, 0
	for index, entry in ipairs(rig.entries) do
		if not finiteCFrame(frames[index]) then return false, "Invalid bind matrix for " .. entry.part.Name end
		bindError = math.max(bindError, (frames[index].Position - entry.rel.Position).Magnitude)
		if frames[index].LookVector:Dot(entry.rel.LookVector) < 0.99999
			or frames[index].UpVector:Dot(entry.rel.UpVector) < 0.99999 then
			return false, "Bind rotation does not match " .. entry.part.Name
		end
	end
	local testPose = {}
	for index, link in ipairs(CHAIN) do
		testPose[link[1]] = CFrame.Angles((index % 3 - 1) * 0.11, (index % 4 - 2) * 0.07, 0.06)
	end
	for _, base in ipairs({IDENTITY, CFrame.new(817, 13, -529) * CFrame.Angles(0, 2.9, 0)}) do
		local _, animated = Rig.Evaluate(rig, base, testPose)
		for name, node in pairs(rig.nodes) do
			local parentJoint = animated[node.parent] * node.c0
			local childJoint = animated[name] * node.c1
			jointError = math.max(jointError, (parentJoint.Position - childJoint.Position).Magnitude)
		end
	end
	rig.bindError, rig.jointError = bindError, jointError
	local tolerance = math.max(0.002, rig.height * 0.0001)
	return bindError <= tolerance and jointError <= tolerance,
		string.format("bind %.5f / joints %.5f", bindError, jointError)
end
function Rig.Render(rig, base, pose)
	local cframes, frames = Rig.Evaluate(rig, base, pose)
	local limit = math.max(rig.maxRadius + rig.height * 2, rig.height * CONFIG.SAFE_DISTANCE)
	for index, frame in ipairs(cframes) do
		if not finiteCFrame(frame) or (frame.Position - base.Position).Magnitude > limit then
			return nil, "Out-of-bounds pose: " .. rig.entries[index].part.Name
		end
	end
	if rig.viewport then
		for index, part in ipairs(rig.parts) do part.CFrame = cframes[index] end
	else
		workspace:BulkMoveTo(rig.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for name, node in pairs(rig.nodes) do
		if node.bone then
			local offset = posedOffset(name, pose)
			node.bone.Transform = node.c1 * offset * node.c1Inverse
		end
	end
	return frames
end
function Rig.CheckPose(rig, pose)
	local base = CFrame.new(-417, 9, 702) * CFrame.Angles(0, 1.83, 0)
	local cframes, frames = Rig.Evaluate(rig, base, pose)
	local limit = math.max(rig.maxRadius + rig.height * 2, rig.height * CONFIG.SAFE_DISTANCE)
	for index, frame in ipairs(cframes) do
		if not finiteCFrame(frame) or (frame.Position - base.Position).Magnitude > limit then
			return false, "Pose escapes bounds at " .. rig.entries[index].part.Name
		end
	end
	for name, node in pairs(rig.nodes) do
		local parentPoint = (frames[node.parent] * node.c0).Position
		local childPoint = (frames[name] * node.c1).Position
		if (parentPoint - childPoint).Magnitude > math.max(0.002, rig.height * 0.0001) then
			return false, "Joint gap at " .. name
		end
	end
	return true
end

buildEntries = function(model)
	stripModel(model)
	local parts = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery, part.CanTouch = false, false
			part.LocalTransparencyModifier = 0
			parts[#parts + 1] = part
		end
	end
	if #parts == 0 then return nil, nil, nil, "No BaseParts in this model" end
	local root = findPart(model, "HumanoidRootPart")
	if not root then return nil, nil, nil, "HumanoidRootPart is missing" end
	local reference = root.CFrame
	local mn, mx = measure(parts, reference)
	if CONFIG.RESIZE_MODEL then
		local scale = CONFIG.TARGET_HEIGHT / math.max(mx.Y - mn.Y, 0.1)
		if not pcall(function() model:ScaleTo(model:GetScale() * scale) end) then
			manualScale(model, parts, scale, reference)
		end
		reference = root.CFrame
		mn, mx = measure(parts, reference)
	end
	local height = math.max(mx.Y - mn.Y, 1)
	local feet = {}
	for _, name in ipairs({"Lfoot", "Rfoot"}) do
		local foot = findPart(model, name)
		if foot then feet[#feet + 1] = foot end
	end
	local bottomY = mn.Y
	if #feet > 0 then
		local footBounds = measure(feet, reference)
		bottomY = footBounds.Y
	end
	local origin = reference * CFrame.new((mn.X + mx.X) * 0.5, bottomY, (mn.Z + mx.Z) * 0.5)
	local entries, byPart = {}, {}
	for index, part in ipairs(parts) do
		local entry = {part = part, rel = origin:ToObjectSpace(part.CFrame)}
		entries[index], byPart[part] = entry, entry
	end
	local links, adjacency = captureLinks(model, origin)
	local rig = {
		entries = entries, parts = parts, rootRest = byPart[root].rel,
		nodes = {}, order = {}, height = height, unit = height / 24,
		maxRadius = 0,
	}
	local partNames, boneNames = {[root] = "HumanoidRootPart"}, {}
	local missing = {}
	for _, link in ipairs(CHAIN) do
		local name = link[1]
		local part = findPart(model, name)
		local bone = not part and findNamed(model, name, "Bone") or nil
		if part or bone then
			local rest = part and byPart[part].rel or origin:ToObjectSpace(bone.WorldCFrame)
			rig.nodes[name] = {name = name, part = part, bone = bone, rest = rest, parent = link[2]}
			if part then partNames[part] = name else boneNames[bone] = name end
		else missing[#missing + 1] = name end
	end
	if #missing > 0 then
		return nil, nil, nil, "Missing named parts/bones: " .. table.concat(missing, ", ")
	end
	for name, node in pairs(rig.nodes) do
		local pivot
		if node.part then
			for _, link in ipairs(links) do
				if link.motor and link.p1 == node.part and partNames[link.p0] then
					node.parent, pivot = partNames[link.p0], link.pivot
					break
				end
			end
			local parentPart = node.parent == "HumanoidRootPart" and root or rig.nodes[node.parent].part
			if not pivot and parentPart then
				for _, link in ipairs(links) do
					if link.p0 == parentPart and link.p1 == node.part and link.pivot then pivot = link.pivot break end
				end
			end
			if not pivot and parentPart then
				for _, attachment in ipairs(node.part:GetChildren()) do
					local other = attachment:IsA("Attachment") and parentPart:FindFirstChild(attachment.Name)
					if other and other:IsA("Attachment") then
						pivot = origin:PointToObjectSpace(attachment.WorldPosition)
						break
					end
				end
			end
			if not pivot and node.part.PivotOffset.Position.Magnitude > 0.0001 then
				pivot = origin:PointToObjectSpace(node.part:GetPivot().Position)
			end
			if not pivot then
				pivot = parentPart and estimatePivot(byPart[parentPart], byPart[node.part]) or node.rest.Position
			end
		else
			local actualParent = node.bone.Parent
			node.parent = "HumanoidRootPart"
			while actualParent and actualParent ~= model do
				local parentName = boneNames[actualParent] or partNames[actualParent]
				if parentName then node.parent = parentName break end
				actualParent = actualParent.Parent
			end
			pivot = node.rest.Position
		end
		local override = CONFIG.PIVOT_OVERRIDES[name]
		if typeof(override) == "Vector3" then pivot = override end
		local parentRest = node.parent == "HumanoidRootPart" and rig.rootRest or rig.nodes[node.parent].rest
		if typeof(override) ~= "Vector3" and (pivot - node.rest.Position).Magnitude > height * 1.5 then
			pivot = (parentRest.Position + node.rest.Position) * 0.5
			warn("[Guilt] Invalid imported pivot corrected for " .. name)
		end
		local jointFrame = CFrame.new(pivot)
		node.pivot = jointFrame
		node.c0 = parentRest:ToObjectSpace(jointFrame)
		node.c1 = node.rest:ToObjectSpace(jointFrame)
		node.c1Inverse = node.c1:Inverse()
	end
	local visiting, visited = {}, {}
	local function visit(name)
		if name == "HumanoidRootPart" or visited[name] then return end
		if visiting[name] then error("Cyclic skeleton at " .. name) end
		visiting[name] = true
		visit(rig.nodes[name].parent)
		visiting[name], visited[name] = nil, true
		rig.order[#rig.order + 1] = name
	end
	local ok, orderError = pcall(function()
		for _, link in ipairs(CHAIN) do visit(link[1]) end
	end)
	if not ok then return nil, nil, nil, tostring(orderError) end
	for _, entry in ipairs(entries) do
		local owner = partNames[entry.part]
		if not owner then
			local queue, seen = {entry.part}, {[entry.part] = true}
			local index = 1
			while queue[index] and not owner do
				for _, neighbor in ipairs(adjacency[queue[index]] or {}) do
					if partNames[neighbor] then owner = partNames[neighbor] break end
					if not seen[neighbor] then seen[neighbor] = true queue[#queue + 1] = neighbor end
				end
				index += 1
			end
			if not owner then
				local ancestor = entry.part.Parent
				while ancestor and ancestor ~= model do
					if partNames[ancestor] then owner = partNames[ancestor] break end
					ancestor = ancestor.Parent
				end
			end
			if not owner then
				local distance = math.huge
				for name, node in pairs(rig.nodes) do
					if node.part then
						local d = (entry.rel.Position - node.rest.Position).Magnitude
						if d < distance then owner, distance = name, d end
					end
				end
			end
		end
		entry.owner = owner or "HumanoidRootPart"
		entry.bone = entry.owner
		local ownerRest = entry.owner == "HumanoidRootPart" and rig.rootRest or rig.nodes[entry.owner].rest
		entry.ownerOffset = ownerRest:ToObjectSpace(entry.rel)
		rig.maxRadius = math.max(rig.maxRadius, entry.rel.Position.Magnitude)
	end
	local valid, detail = Rig.Check(rig)
	if not valid then return nil, nil, nil, "Rig self-check failed: " .. detail end
	rig.checkDetail = detail
	for _, instance in ipairs(model:GetDescendants()) do
		if instance:IsA("JointInstance") or instance:IsA("Constraint") or instance:IsA("WeldConstraint") then
			instance:Destroy()
		end
	end
	root.Transparency = 1
	return entries, parts, height, rig
end

analyze = function()
	assert(S.rig, "Bind rig has not been built")
	S.yaw = ((S.fallback and 0 or CONFIG.MODEL_YAW) + S.flip) % 360
	S.yawCF = CFrame.Angles(0, math.rad(S.yaw), 0)
	S.bones = S.rig.nodes
	S.usingNamedBones = true
	for _, side in ipairs({1, -1}) do
		local arm = S.bones[side > 0 and "Rarm" or "Larm"]
		local hand = S.bones[side > 0 and "Rhand" or "Lhand"]
		S.armPivot[side] = arm.pivot.Position
		S.armLen[side] = (hand.rest.Position - arm.pivot.Position).Magnitude
	end
	S.grabSide = 1
	S.dripEntries = {}
	-- How far the body must drop so the pelvis rests near the ground in the prone crawl.
	local hipY = S.bones.Quadril and S.bones.Quadril.pivot.Position.Y or S.height * 0.42
	S.crawlDrop = math.max(0, hipY - S.height * 0.06)

	-- Side-view (forward, up) geometry of the arm chain, used by the crawl IK. Model forward is -Z.
	S.armIK, S.torsoIK = nil, nil
	do
		local function sag(v) return -v.Z, v.Y end
		local function pivotOf(name) return S.bones[name] and S.bones[name].pivot.Position end
		local hipP, torP = pivotOf("Quadril"), pivotOf("Torso")
		local ik, ok = {}, hipP ~= nil and torP ~= nil
		for _, side in ipairs({1, -1}) do
			local a = side > 0 and "R" or "L"
			local ps, pe, pw = pivotOf(a .. "arm"), pivotOf("Fore" .. a .. "arm"), pivotOf(a .. "hand")
			local hand = S.bones[a .. "hand"]
			if not (ps and pe and pw and hand and ok) then ok = false break end
			local d = {}
			d.sf, d.sy = sag(ps - torP)                  -- shoulder, relative to the torso pivot
			d.uf, d.uy = sag(pe - ps)                    -- upper arm (shoulder -> elbow)
			d.ff, d.fy = sag(pw - pe)                    -- forearm (elbow -> wrist)
			d.hf, d.hy = sag(hand.rest.Position - pw)    -- hand (wrist -> hand centre)
			d.L1 = math.max(math.sqrt(d.uf * d.uf + d.uy * d.uy), 0.5)
			d.L2 = math.max(math.sqrt(d.ff * d.ff + d.fy * d.fy), 0.5)
			d.angU, d.angF = math.atan2(d.uy, d.uf), math.atan2(d.fy, d.ff)
			d.angH = (d.hf * d.hf + d.hy * d.hy > 0.01) and math.atan2(d.hy, d.hf) or -math.pi / 2
			ik[side] = d
		end
		if ok then
			S.armIK = ik
			S.torsoIK = {af = 0, ay = 0, hipY = hipY}
			S.torsoIK.af, S.torsoIK.ay = sag(torP - hipP)
		end
	end
	for _, e in ipairs(S.entries) do
		e.p0 = e.rel.Position
		if e.part.Transparency < 0.9 and e.p0.Y > S.height * 0.25 and e.p0.Y < S.height * 0.85 then
			S.dripEntries[#S.dripEntries + 1] = e
		end
	end
	S.pose, S.poseCur = {}, {}
end
end

--====================================================================--
-- POSE ENGINE                                                        --
--====================================================================--
local function mixPose(a, b, k)
	local r = {}
	for _, link in ipairs(CHAIN) do
		local name = link[1]
		r[name] = (a[name] or IDENTITY):Lerp(b[name] or IDENTITY, k)
	end
	return r
end

-- Numeric clips: every bone is {rx, ry, rz, px, py, pz}. They are interpolated with a
-- Catmull-Rom spline so motion flows through keyframes instead of stopping at each one.
function Rig.Clip(frames)
	for _, f in ipairs(frames) do
		f.n = {}
		local pose = {}
		for _, link in ipairs(CHAIN) do
			local name = link[1]
			local a = f.p[name]
			local v = {a and a[1] or 0, a and a[2] or 0, a and a[3] or 0, a and a[4] or 0, a and a[5] or 0, a and a[6] or 0}
			f.n[name] = v
			pose[name] = PR(v[4], v[5], v[6], v[1], v[2], v[3])
		end
		f.p = pose
	end
	return frames
end

function Rig.spline(v0, v1, v2, v3, t0, t1, t2, t3, u)
	local span = t2 - t1
	local d02 = math.max(t2 - t0, 1e-4)
	local d13 = math.max(t3 - t1, 1e-4)
	local m1 = (v2 - v0) / d02 * span
	local m2 = (v3 - v1) / d13 * span
	local u2, u3 = u * u, u * u * u
	return (2 * u3 - 3 * u2 + 1) * v1 + (u3 - 2 * u2 + u) * m1 + (-2 * u3 + 3 * u2) * v2 + (u3 - u2) * m2
end

local function sampleClip(frames, at)
	if at <= frames[1].t then return frames[1].p end
	for i = 2, #frames do
		local right, left = frames[i], frames[i - 1]
		if at <= right.t then
			local span = right.t - left.t
			local u = span > 0 and (at - left.t) / span or 1
			if not left.n then
				return mixPose(left.p, right.p, smooth(u))
			end
			local before = frames[math.max(i - 2, 1)]
			local after = frames[math.min(i + 1, #frames)]
			local pose = {}
			for _, link in ipairs(CHAIN) do
				local name = link[1]
				local a, b = left.n[name], right.n[name]
				local c, d = before.n[name], after.n[name]
				local out = {}
				for j = 1, 6 do
					if right.ease == "in" then
						out[j] = a[j] + (b[j] - a[j]) * (u ^ 2.2)
					elseif right.ease == "out" then
						out[j] = a[j] + (b[j] - a[j]) * (1 - (1 - u) ^ 2.2)
					else
						out[j] = Rig.spline(c[j], a[j], b[j], d[j], before.t, left.t, right.t, after.t, u)
					end
				end
				pose[name] = PR(out[4], out[5], out[6], out[1], out[2], out[3])
			end
			return pose
		end
	end
	return frames[#frames].p
end

-- ---------------------------------------------------------------------------------------------
-- Crawl arms: two-bone IK in the body's side view (forward, up). Every number comes from the
-- model's own bone lengths, so the hands really touch the ground whatever the proportions are.
-- Angles use the same convention as the pose engine: +rx swings a hanging arm forward.
-- ---------------------------------------------------------------------------------------------
function Rig.rot2(a, f, y)
	local c, s = math.cos(a), math.sin(a)
	return f * c - y * s, f * s + y * c
end
function Rig.wrap(x) return (x + math.pi) % (math.pi * 2) - math.pi end

-- Shoulder pose angles that put the wrist at (wf, wy). Slides the target forward if the elbow
-- would dig into the floor. Returns shoulder, elbow and hand rotations.
function Rig.reachArm(side, sf, sy, net, wf, wy, handAng, minElbowY)
	local d = S.armIK[side]
	local L1, L2 = d.L1, d.L2
	local maxD, minD = L1 + L2 - 0.02, math.abs(L1 - L2) + 0.05
	local phi1, delta = 0, 0
	for _ = 1, 12 do
		local df, dy = wf - sf, wy - sy
		local dist = math.clamp(math.sqrt(df * df + dy * dy), minD, maxD)
		local cosd = math.clamp((dist * dist - L1 * L1 - L2 * L2) / (2 * L1 * L2), -1, 1)
		delta = math.acos(cosd)                                   -- elbow bends the natural way
		local gamma = math.atan2(L2 * math.sin(delta), L1 + L2 * math.cos(delta))
		phi1 = math.atan2(dy, df) - gamma
		if sy + L1 * math.sin(phi1) >= minElbowY or dist >= maxD then break end
		wf += 0.7
	end
	local a1 = Rig.wrap(phi1 - d.angU - net)
	local a2 = Rig.wrap(delta - (d.angF - d.angU))
	local a3 = Rig.wrap(handAng - d.angH - net - a1 - a2)
	return a1, a2, a3
end

-- Alternating hand cycle. th is the stride phase in radians, moveAmt 0..1 fades the stepping out
-- when the monster is lying still.
function Rig.crawlArms(th, moveAmt)
	local C = CONFIG.CRAWL
	local I, T = S.armIK, S.torsoIK
	if not (I and I[1] and I[-1] and T) then return nil end
	local h = S.height
	local u = th / (math.pi * 2)
	local hipH = T.hipY - S.crawlDrop * smooth(S.crawlBlend)
	local Pq, Pc = C.BODY_PITCH, C.CHEST_LIFT
	local net = Pq + Pc                                           -- rotation of the shoulder frame
	local PF = 0.55                                               -- share of the cycle a hand stays planted
	local stride = math.max(h * C.CYCLE_LEN, 2.2)
	local groundY = h * C.GROUND
	local out = {}
	for _, side in ipairs({1, -1}) do
		local d = I[side]
		local f1, y1 = Rig.rot2(Pq, T.af, T.ay)
		local f2, y2 = Rig.rot2(net, d.sf, d.sy)
		local sf, sy = f1 + f2, hipH + y1 + y2                    -- shoulder in the side view
		local reachMax = (d.L1 + d.L2) * 0.97
		local dy = math.max(sy - groundY, 0)
		local reachH = reachMax > dy and math.sqrt(reachMax * reachMax - dy * dy) or 1
		-- a planted hand slides back exactly as far as the body travels: no ice skating
		local slide = math.min(PF * stride, reachH * 0.85) * moveAmt
		local fFar = sf + reachH * 0.98 - (1 - moveAmt) * reachH * 0.12
		local fNear = fFar - slide
		local cyc = (u + (side > 0 and 0 or 0.5)) % 1
		local wf, wy, lift
		if cyc < PF then
			local q = cyc / PF
			wf, wy, lift = fFar - q * slide, groundY, 0
		else
			local q = (cyc - PF) / (1 - PF)
			local e = q * q * (3 - 2 * q)
			lift = math.sin(q * math.pi)
			wf, wy = fNear + e * slide, groundY + lift * h * C.LIFT * moveAmt
		end
		local handAng = -0.12 - 0.85 * lift                       -- flat on the floor, fingers droop in the air
		local a1, a2, a3 = Rig.reachArm(side, sf, sy, net, wf, wy, handAng, h * 0.035)
		local n = side > 0 and "R" or "L"
		out[n .. "arm"] = PR(0, 0, 0, a1, 0, side * C.ARM_OUT)
		out["Fore" .. n .. "arm"] = PR(0, 0, 0, a2)
		out[n .. "hand"] = PR(0, 0, 0, a3)
	end
	return out
end

local function idlePose(t, walkAmount, mode)
	local breathe = math.sin(t * 1.35)
	local twitch = math.max(0, math.noise(t * 1.15, 4.2) - 0.28)
	local c = walkAmount
	local P = {
		Quadril   = PR(0, breathe * 0.03, 0, -0.04 * c, 0, 0),
		Torso     = PR(0, breathe * 0.045, 0, -0.05 - 0.12 * c, math.sin(t * 0.5) * 0.035, math.sin(t * 0.37) * 0.03),
		Spine     = PR(0, breathe * 0.04, 0, -0.03 - 0.08 * c, 0, math.sin(t * 0.41) * 0.025),
		Neck      = PR(0, 0, 0, 0.04 + 0.1 * c, math.sin(t * 0.44) * 0.1, 0),
		Head      = PR(0, 0, 0, math.sin(t * 0.9) * 0.035 + twitch * 0.12, math.sin(t * 0.31) * 0.16, math.sin(t * 0.47) * 0.045),
		Larm      = PR(0, 0, 0, 0.05 - 0.42 * c + math.sin(t * 1.1 + 1) * 0.045, 0, -0.075 - 0.06 * c),
		Rarm      = PR(0, 0, 0, 0.05 - 0.42 * c + math.sin(t * 1.07) * 0.045, 0,  0.075 + 0.06 * c),
		ForeLarm  = PR(0, 0, 0, 0.16 + twitch * 0.14 + math.sin(t * 1.6) * 0.03, 0, 0),
		ForeRarm  = PR(0, 0, 0, 0.16 - twitch * 0.12 + math.sin(t * 1.5) * 0.03, 0, 0),
		Lhand     = PR(0, 0, 0, -0.14 + math.sin(t * 2.1) * 0.035, 0, 0.04),
		Rhand     = PR(0, 0, 0, -0.14 + math.sin(t * 2.0) * 0.035, 0, -0.04),
		Lleg      = PR(0, 0, 0, -0.03 + math.sin(t * 0.7 + 1) * 0.018, 0, -0.02),
		Rleg      = PR(0, 0, 0, -0.03 + math.sin(t * 0.68) * 0.018, 0, 0.02),
		LforeLeg  = PR(0, 0, 0, 0.05, 0, 0),
		RforeLeg  = PR(0, 0, 0, 0.05, 0, 0),
		Lfoot     = PR(0, 0, 0, -0.03, 0, 0),
		Rfoot     = PR(0, 0, 0, -0.03, 0, 0),
	}
	-- PRONE CRAWL (G): the body lies almost flat with the chest propped up. The neck is craned
	-- up so the head still looks forward, the arms drag the body one after the other like a
	-- commando crawl, and the legs trail behind. All numbers live in CONFIG.CRAWL.
	if mode == "crawl" then
		local C = CONFIG.CRAWL
		local amp = 0.2 + 0.8 * clamp01(walkAmount)           -- hardly paddling while standing still
		local th = S.phase * math.pi * 2
		local sway = math.sin(th) * amp
		-- fallback arms, only used if the arm bones could not be measured
		local rArm, rFore, rHand = PR(0, 0, 0, 1.2, 0, C.ARM_OUT), PR(0, 0, 0, 0.5), PR(0, 0, 0, -0.3)
		local lArm, lFore, lHand = PR(0, 0, 0, 1.2, 0, -C.ARM_OUT), PR(0, 0, 0, 0.5), PR(0, 0, 0, -0.3)
		local function legKick(off)
			local k = math.sin(th + off) * amp
			return PR(0, 0, 0, -0.28 + k * 0.10, 0, 0),
				PR(0, 0, 0, -(0.14 + 0.42 * (0.5 + 0.5 * math.sin(th + off + 1.2) * amp)), 0, 0)
		end
		local lLeg, lShin = legKick(math.pi)
		local rLeg, rShin = legKick(0)
		P = {
			Quadril  = PR(0, breathe * 0.03, 0, C.BODY_PITCH, sway * 0.07, sway * 0.04),
			Torso    = PR(0, 0, 0, C.CHEST_LIFT + breathe * 0.02, -sway * 0.10, -sway * 0.04),
			Spine    = PR(0, 0, 0, C.CHEST_LIFT * 0.35, -sway * 0.06, 0),
			Neck     = PR(0, 0, 0, C.NECK_UP + math.sin(t * 0.9) * 0.04, sway * 0.10 + math.sin(t * 0.5) * 0.05, 0),
			Head     = PR(0, 0, 0, 0.05 + math.sin(t * 1.1) * 0.03, -sway * 0.08, math.sin(t * 0.7) * 0.05),
			Larm     = lArm, ForeLarm = lFore, Lhand = lHand,
			Rarm     = rArm, ForeRarm = rFore, Rhand = rHand,
			Lleg     = lLeg, LforeLeg = lShin, Lfoot = PR(0, 0, 0, 0.30, 0, 0),
			Rleg     = rLeg, RforeLeg = rShin, Rfoot = PR(0, 0, 0, 0.30, 0, 0),
		}
		-- real arms: hands planted on the ground by IK
		local ok, ik = pcall(Rig.crawlArms, th, clamp01(walkAmount))
		if ok and ik then for name, pose in pairs(ik) do P[name] = pose end end
	end
	return P
end

-- One continuous gait: r = 0 is a walk, r = 1 is a full run. Everything is a smooth function of the
-- stride phase, so walking, running and the blend between them never snap.
function Rig.gait(th, r)
	local s = math.sin(th)
	local legAmp = lerp(0.42, 0.95, r)
	local kneeBase = lerp(0.08, 0.20, r)
	local kneeAmp = lerp(0.52, 1.30, r)
	local function leg(ph)
		local swing = math.sin(ph)
		local flex = math.max(0, math.cos(ph - 0.25)) ^ 1.3
		return
			PR(0, 0, 0, swing * legAmp + lerp(0.0, 0.10, r)),
			PR(0, 0, 0, -(kneeBase + kneeAmp * flex)),
			PR(0, 0, 0, 0.18 * flex - 0.10 * swing)
	end
	local lLeg, lShin, lFoot = leg(th)
	local rLeg, rShin, rFoot = leg(th + math.pi)

	-- Arms. Walk: long, heavy arms that dangle and swing like pendulums. The swing lags behind the
	-- legs, the elbow folds as the arm comes forward, the wrist trails behind the motion and the
	-- arms stay a little away from the body. Run: a tighter pump with the elbows bent about 55 degrees.
	-- Every walk number is in CONFIG.WALK_ARMS.
	local W = CONFIG.WALK_ARMS
	local speedK = clamp01(S.speedS / CONFIG.WALK_SPEED)        -- smaller swings at very low speed
	local armAmp = lerp(W.SWING * lerp(0.6, 1.0, speedK), 0.88, r)
	local function armSet(side, ph)
		local a = ph - lerp(W.LAG, 0.05, r)
		local swing = -math.sin(a) - lerp(0.12, 0.0, r) * math.sin(2 * a + 0.5)  -- + forward / - backward
		local bend = 0.5 - 0.5 * math.sin(a + 0.5)                -- 1 at the front of the swing
		local follow = math.cos(a)                                -- the wrist lags behind the arm
		return
			PR(0, 0, 0, lerp(W.BACK, 0.22, r) + swing * armAmp, 0,
				side * (lerp(W.OUT, 0.05, r) + lerp(0.035, 0.0, r) * math.sin(2 * a))),
			PR(0, 0, 0, lerp(W.ELBOW_BASE, 0.95, r) + lerp(W.ELBOW, 0.40, r) * bend),
			PR(0, 0, 0, lerp(-0.10, -0.12, r) + lerp(0.22, 0.10, r) * follow, 0, side * 0.03)
	end
	local lArm, lFore, lHand = armSet(-1, th)               -- left arm swings opposite the left leg
	local rArm, rFore, rHand = armSet(1, th + math.pi)

	return {
		Quadril  = PR(0, lerp(0.03, 0.10, r) * math.cos(th * 2), 0, lerp(-0.02, -0.07, r),
			s * lerp(0.05, 0.11, r), s * lerp(0.02, 0.04, r)),
		Torso    = PR(0, 0, 0, lerp(-0.05, -0.16, r), -s * lerp(0.09, 0.14, r), s * 0.02),
		Spine    = PR(0, 0, 0, lerp(-0.03, -0.06, r), -s * lerp(0.04, 0.07, r), 0),
		Neck     = PR(0, 0, 0, lerp(0.05, 0.22, r), s * 0.04, 0),
		Head     = PR(0, 0, 0, lerp(-0.03, -0.06, r), -s * 0.02, 0),
		Larm = lArm, ForeLarm = lFore, Lhand = lHand,
		Rarm = rArm, ForeRarm = rFore, Rhand = rHand,
		Lleg = lLeg, LforeLeg = lShin, Lfoot = lFoot,
		Rleg = rLeg, RforeLeg = rShin, Rfoot = rFoot,
	}
end

local function movingPose(t, speed, dt)
	local moving = S.humanoid.MoveDirection.Magnitude > 0.05 and speed > 0.5
	-- Smooth speed and run-blend: stride frequency and gait style change gradually.
	S.speedS += (speed - S.speedS) * math.min(1, dt * 6)
	local wantRun = (S.sprinting and S.mode ~= "crawl" and moving) and 1 or 0
	S.runBlend += (wantRun - S.runBlend) * math.min(1, dt * 5)
	local dph = 0
	if S.mode == "crawl" then
		if moving then
			-- same stride length the planted-hand slide in Rig.crawlArms is built on
			dph = S.speedS * dt / math.max(S.height * CONFIG.CRAWL.CYCLE_LEN, 2.2)
		else
			dph = dt * 0.35 -- slow breathing sway while lying still
		end
	elseif S.speedS > 0.3 then
		-- long, heavy strides: a giant covers a lot of ground per step
		local stride = math.max(lerp(S.height * 0.62, S.height * 0.95, S.runBlend), 2.2)
		dph = S.speedS * dt / stride
	end
	S.phase = (S.phase + dph) % 1
	S.stepAcc += dph
	local state = S.humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		local rising = S.hrp.AssemblyLinearVelocity.Y > 0
		return {
			Quadril = PR(0, 0, 0, rising and -0.1 or 0.12), Torso = PR(0, 0, 0, -0.06),
			Neck = PR(0, 0, 0, 0.1), Head = PR(0, 0, 0, -0.07),
			Lleg = PR(0, 0, 0, rising and 0.45 or 0.12), Rleg = PR(0, 0, 0, rising and -0.14 or 0.12),
			LforeLeg = PR(0, 0, 0, rising and -0.7 or -0.2), RforeLeg = PR(0, 0, 0, -0.35),
			Larm = PR(0, 0, 0, -0.2, 0, -0.3), Rarm = PR(0, 0, 0, -0.2, 0, 0.3),
			ForeLarm = PR(0, 0, 0, 0.25), ForeRarm = PR(0, 0, 0, 0.25),
		}
	end
	if S.mode == "crawl" then return idlePose(t, S.walk, "crawl") end
	local idle = idlePose(t, 0, "idle")
	if S.walk < 0.01 and S.speedS < 0.3 then return idle end
	local gait = Rig.gait(S.phase * math.pi * 2, S.runBlend)
	return mixPose(idle, gait, S.walk)
end

-- CLIPS
local Clips = {}
Clips.Spawn = {
	{t = 0.0,  p = {
		Quadril = PR(0, -2.1, 0, -0.9), Torso = PR(0, 0, 0, -0.5), Spine = PR(0, 0, 0, -0.35),
		Neck = PR(0, 0, 0, 0.85), Head = PR(0, 0, 0, 0.4),
		Larm = PR(0, 0, 0, 1.7, 0, -0.5), Rarm = PR(0, 0, 0, 1.7, 0, 0.5),
		ForeLarm = PR(0, 0, 0, 0.7), ForeRarm = PR(0, 0, 0, 0.7),
		Lleg = PR(0, 0, 0, 1.05), Rleg = PR(0, 0, 0, 1.05),
		LforeLeg = PR(0, 0, 0, -1.5), RforeLeg = PR(0, 0, 0, -1.5),
	}},
	{t = 0.7,  p = {
		Quadril = PR(0, -0.8, 0, -0.22), Torso = PR(0, 0, 0, -0.16), Neck = PR(0, 0, 0, 0.32),
		Larm = PR(0, 0, 0, 0.8, 0, -0.3), Rarm = PR(0, 0, 0, 0.8, 0, 0.3),
		Lleg = PR(0, 0, 0, 0.45), Rleg = PR(0, 0, 0, 0.45),
		LforeLeg = PR(0, 0, 0, -0.75), RforeLeg = PR(0, 0, 0, -0.75),
	}},
	{t = 1.15, p = {
		Torso = PR(0, 0, 0, 0.09), Spine = PR(0, 0, 0, 0.05),
		Neck = PR(0, 0, 0, -0.2), Head = PR(0, 0, 0, -0.15),
		Larm = PR(0, 0, 0, -0.12, 0, -0.14), Rarm = PR(0, 0, 0, -0.12, 0, 0.14),
	}},
	{t = 1.7,  p = {}},
}
Clips.Cleave1 = {
	{t = 0.0,  p = {}},
	{t = 0.12, p = {
		Quadril = PR(0, 0, 0, 0, -0.14, 0), Torso = PR(0, 0, 0, -0.08, -0.34, -0.08),
		Spine = PR(0, 0, 0, 0, -0.12, 0), Neck = PR(0, 0, 0, 0.05, 0.3, 0),
		Rarm = PR(0, 0, 0, -0.75, -0.25, 0.95), ForeRarm = PR(0, 0, 0, 0.95), Rhand = PR(0, 0, 0, -0.5),
		Larm = PR(0, 0, 0, 0.2, 0, -0.28), ForeLarm = PR(0, 0, 0, 0.4),
	}},
	{t = 0.22, p = {
		Quadril = PR(0, 0, 0, 0, 0.19, 0), Torso = PR(0, 0, 0, -0.11, 0.42, 0.07),
		Spine = PR(0, 0, 0, 0, 0.15, 0), Neck = PR(0, 0, 0, 0.07, -0.32, 0),
		Rarm = PR(0, 0, 0, 1.35, 0.28, -0.72), ForeRarm = PR(0, 0, 0, 0.16), Rhand = PR(0, 0, 0, 0.28),
		Larm = PR(0, 0, 0, 0.42, 0, -0.13), Rleg = PR(0, 0, 0, 0.2, 0, 0.05),
	}},
	{t = 0.36, p = {
		Torso = PR(0, 0, 0, -0.07, 0.3, 0.04), Rarm = PR(0, 0, 0, 0.85, 0.3, -0.7),
		ForeRarm = PR(0, 0, 0, 0.1), Rhand = PR(0, 0, 0, -0.1),
	}},
	{t = 0.58, p = {}},
}
Clips.Cleave2 = {
	{t = 0.0,  p = {}},
	{t = 0.13, p = {
		Quadril = PR(0, 0, 0, 0, 0.16, 0), Torso = PR(0, 0, 0, -0.07, 0.36, 0.07),
		Larm = PR(0, 0, 0, -0.8, 0.25, -0.98), ForeLarm = PR(0, 0, 0, 1.0), Lhand = PR(0, 0, 0, -0.5),
		Rarm = PR(0, 0, 0, 0.28, 0, 0.3), ForeRarm = PR(0, 0, 0, 0.42), Neck = PR(0, 0, 0, 0.06, -0.3, 0),
	}},
	{t = 0.23, p = {
		Quadril = PR(0, 0, 0, 0, -0.2, 0), Torso = PR(0, 0, 0, -0.11, -0.44, -0.08),
		Spine = PR(0, 0, 0, 0, -0.16, 0),
		Larm = PR(0, 0, 0, 1.42, -0.28, 0.76), ForeLarm = PR(0, 0, 0, 0.16), Lhand = PR(0, 0, 0, 0.3),
		Lleg = PR(0, 0, 0, 0.22, 0, -0.05), Neck = PR(0, 0, 0, 0.08, 0.32, 0),
	}},
	{t = 0.37, p = {
		Torso = PR(0, 0, 0, -0.07, -0.31, -0.05), Larm = PR(0, 0, 0, 0.9, -0.3, 0.72), ForeLarm = PR(0, 0, 0, 0.1),
	}},
	{t = 0.59, p = {}},
}
Clips.Cleave3 = {
	{t = 0.0,  p = {}},
	{t = 0.14, p = {
		Torso = PR(0, 0, 0, -0.14, -0.42, 0), Spine = PR(0, 0, 0, 0, -0.14, 0),
		Rarm = PR(0, 0, 0, -0.65, 0, 0.8), ForeRarm = PR(0, 0, 0, 0.85),
		Larm = PR(0, 0, 0, 0.42, 0, -0.42), ForeLarm = PR(0, 0, 0, 0.6), Neck = PR(0, 0, 0, 0.1, 0.35, 0),
	}},
	{t = 0.24, p = {
		Quadril = PR(0, 0, 0, 0, 0.24, 0), Torso = PR(0, 0, 0, -0.1, 0.46, 0.05), Spine = PR(0, 0, 0, 0, 0.16, 0),
		Rarm = PR(0, 0, 0, 1.35, 0, -0.45), ForeRarm = PR(0, 0, 0, 0.12),
		Larm = PR(0, 0, 0, -0.42, 0, -0.75), ForeLarm = PR(0, 0, 0, 0.9), Lhand = PR(0, 0, 0, -0.4),
	}},
	{t = 0.52, p = {
		Torso = PR(0, 0, 0, -0.14, 0.42, -0.05),
		Larm = PR(0, 0, 0, 1.5, -0.15, 0.8), ForeLarm = PR(0, 0, 0, 0.12), Lhand = PR(0, 0, 0, 0.28),
		Rarm = PR(0, 0, 0, 0.22, 0, 0.12), ForeRarm = PR(0, 0, 0, 0.35),
		Neck = PR(0, 0, 0, 0.12, -0.3, 0), Head = PR(0, 0, 0, 0.05, 0.22, 0.1),
	}},
	{t = 0.92, p = {}},
}
Clips.Lunge = {
	{t = 0.0,  p = {}},
	{t = 0.14, p = {
		Quadril = PR(0, -0.55, 0, -0.12), Torso = PR(0, 0, 0, -0.3, 0, 0), Spine = PR(0, 0, 0, -0.12),
		Neck = PR(0, 0, 0, 0.22), Head = PR(0, 0, 0, 0.12),
		Lleg = PR(0, 0, 0, 0.48, 0, -0.08), Rleg = PR(0, 0, 0, 0.48, 0, 0.08),
		LforeLeg = PR(0, 0, 0, -0.75), RforeLeg = PR(0, 0, 0, -0.75),
		Larm = PR(0, 0, 0, -0.62, 0, -0.25), Rarm = PR(0, 0, 0, -0.62, 0, 0.25),
		ForeLarm = PR(0, 0, 0, 0.4), ForeRarm = PR(0, 0, 0, 0.4),
	}},
	{t = 0.26, p = {
		Torso = PR(0, 0, 0, -0.48, 0, 0), Spine = PR(0, 0, 0, -0.16), Neck = PR(0, 0, 0, 0.42), Head = PR(0, 0, 0, 0.16),
		Larm = PR(0, 0, 0, 1.95, 0, -0.16), Rarm = PR(0, 0, 0, 1.95, 0, 0.16),
		ForeLarm = PR(0, 0, 0, 0.26), ForeRarm = PR(0, 0, 0, 0.26),
		Lhand = PR(0, 0, 0, -0.26), Rhand = PR(0, 0, 0, -0.26),
		Lleg = PR(0, 0, 0, -0.36), Rleg = PR(0, 0, 0, 0.62),
		LforeLeg = PR(0, 0, 0, -0.2), RforeLeg = PR(0, 0, 0, -0.95),
	}},
	{t = 0.55, p = {
		Torso = PR(0, 0, 0, -0.2), Neck = PR(0, 0, 0, 0.18),
		Larm = PR(0, 0, 0, 0.95, 0, -0.16), Rarm = PR(0, 0, 0, 0.95, 0, 0.16),
		ForeLarm = PR(0, 0, 0, 0.42), ForeRarm = PR(0, 0, 0, 0.42),
	}},
	{t = 0.82, p = {}},
}
Clips.Devour = {
	{t = 0.0,  p = {}},
	{t = 0.30, p = {
		Rarm = PR(0, 0, 0, 2.75, 0, -0.26), ForeRarm = PR(0, 0, 0, 0.4), Rhand = PR(0, 0, 0, -0.3),
		Larm = PR(0, 0, 0, 0.3, 0, -0.3), Torso = PR(0, 0, 0, -0.12, 0, 0), Neck = PR(0, 0, 0, 0.16), Head = PR(0, 0, 0, 0.12),
	}},
	{t = 0.85, p = {
		Quadril = PR(0, 0.55, 0, -0.1), Torso = PR(0, 0, 0, -0.24, 0, 0), Spine = PR(0, 0, 0, -0.14),
		Neck = PR(0, 0, 0, 0.34), Head = PR(0, 0, 0, 0.28),
		Rarm = PR(0, 0, 0, 3.3, 0, -0.16), ForeRarm = PR(0, 0, 0, 0.2), Rhand = PR(0, 0, 0, -0.2),
		Larm = PR(0, 0, 0, 0.95, 0, -0.55), ForeLarm = PR(0, 0, 0, 0.6), Lhand = PR(0, 0, 0, -0.3),
		Lleg = PR(0, 0, 0, -0.22), Rleg = PR(0, 0, 0, 0.3), RforeLeg = PR(0, 0, 0, -0.75),
	}},
	{t = 1.15, p = {
		Quadril = PR(0, 0.62, 0, 0.1), Torso = PR(0, 0, 0, -0.06, 0, 0), Spine = PR(0, 0, 0, -0.05),
		Neck = PR(0, 0, 0, -0.22), Head = PR(0, 0, 0, -0.2),
		Rarm = PR(0, 0, 0, 3.05, 0, -0.1), ForeRarm = PR(0, 0, 0, 0.25), Larm = PR(0, 0, 0, 0.75, 0, -0.42),
	}},
	{t = 1.58, p = {
		Torso = PR(0, 0, 0, -0.2, 0, 0), Spine = PR(0, 0, 0, -0.12), Neck = PR(0, 0, 0, 0.3), Head = PR(0, 0, 0, 0.34),
		Rarm = PR(0, 0, 0, 3.25, 0, -0.12), ForeRarm = PR(0, 0, 0, 0.2), Rhand = PR(0, 0, 0, 0.2),
		Larm = PR(0, 0, 0, 0.9, 0, -0.5),
	}},
	{t = 2.05, p = {
		Quadril = PR(0, 0.2, 0, 0.16), Torso = PR(0, 0, 0, 0.18, 0, 0), Spine = PR(0, 0, 0, 0.1),
		Neck = PR(0, 0, 0, -0.28), Head = PR(0, 0, 0, -0.3),
		Rarm = PR(0, 0, 0, 2.15, 0, -0.14), ForeRarm = PR(0, 0, 0, 0.4),
		Larm = PR(0, 0, 0, 0.35, 0, -0.3), ForeLarm = PR(0, 0, 0, 0.25),
	}},
	{t = 2.45, p = {
		Quadril = PR(0, 0.12, 0, 0.1), Torso = PR(0, 0, 0, 0.08, 0, 0), Neck = PR(0, 0, 0, 0.1), Head = PR(0, 0, 0, -0.16),
		Rarm = PR(0, 0, 0, 1.25, 0, -0.16), ForeRarm = PR(0, 0, 0, 0.55), Larm = PR(0, 0, 0, 0.12, 0, -0.2),
	}},
	{t = 2.9,  p = {}},
}
Clips.Slam = {
	{t = 0.0,  p = {}},
	{t = 0.58, p = {
		Quadril = PR(0, 0.62, 0, -0.16), Torso = PR(0, 0, 0, 0.18, 0, 0), Spine = PR(0, 0, 0, 0.1),
		Neck = PR(0, 0, 0, 0.24), Head = PR(0, 0, 0, 0.24),
		Larm = PR(0, 0, 0, 2.7, 0, -0.3), Rarm = PR(0, 0, 0, 2.7, 0, 0.3),
		ForeLarm = PR(0, 0, 0, 0.35), ForeRarm = PR(0, 0, 0, 0.35),
		Lhand = PR(0, 0, 0, -0.25), Rhand = PR(0, 0, 0, -0.25),
		Lleg = PR(0, 0, 0, -0.18), Rleg = PR(0, 0, 0, -0.18),
		LforeLeg = PR(0, 0, 0, -0.35), RforeLeg = PR(0, 0, 0, -0.35),
	}},
	{t = 0.78, p = {
		Quadril = PR(0, -0.62, 0, 0.2), Torso = PR(0, 0, 0, -0.34, 0, 0), Spine = PR(0, 0, 0, -0.18),
		Neck = PR(0, 0, 0, -0.28), Head = PR(0, 0, 0, -0.22),
		Larm = PR(0, 0, 0, 0.06, 0, -0.1), Rarm = PR(0, 0, 0, 0.06, 0, 0.1),
		ForeLarm = PR(0, 0, 0, 0.08), ForeRarm = PR(0, 0, 0, 0.08),
		Lleg = PR(0, 0, 0, 0.62, 0, -0.1), Rleg = PR(0, 0, 0, 0.62, 0, 0.1),
		LforeLeg = PR(0, 0, 0, -1.0), RforeLeg = PR(0, 0, 0, -1.0),
	}},
	{t = 0.96, p = {
		Quadril = PR(0, -0.58, 0, 0.2), Torso = PR(0, 0, 0, -0.34, 0, 0),
		Larm = PR(0, 0, 0, 0.06, 0, -0.1), Rarm = PR(0, 0, 0, 0.06, 0, 0.1),
	}},
	{t = 1.65, p = {}},
}

-- ============================================================
-- F EXECUTE — замах 1-й → захват → подъём → осмотр →
--             прихлоп 2-й ладонью → высокий замах → бросок
-- ============================================================
-- Bone values are {rx, ry, rz, px, py, pz}. rx: + swings an arm forward / tips a body part back.
-- ry: + turns left, - turns right. rz: roll (right arm + is outward, left arm - is outward).
-- Quadril py/pz move the whole body (down = crouch, -pz = lunge forward).
--   0.00  stand
--   0.32  crouch, twist right, cock the right arm back
--   0.60  snap forward and grab (right hand)
--   1.30  stand up, lift the victim to head height
--   1.60  bring the victim to the face and study it
--   2.15  raise the left hand, 2.30 palm strike
--   3.00  huge overhead wind-up, 3.14 release, then follow-through
Clips.Execute = Rig.Clip({
	{t = 0.00, p = {}},
	{t = 0.32, p = {
		Quadril = {-0.10, -0.18, 0, 0, -1.10, 0.25},
		Torso   = {-0.12, -0.38, 0.05},
		Spine   = {-0.04, -0.14, 0},
		Neck    = {0.05, 0.35, 0},
		Head    = {0.00, 0.20, 0},
		Rarm    = {-0.45, 0, 0.55},
		ForeRarm= {0.70, 0, 0},
		Rhand   = {-0.20, 0, 0},
		Larm    = {0.55, 0, -0.30},
		ForeLarm= {0.90, 0, 0},
		Lleg    = {0.40, 0, -0.04},   LforeLeg = {-0.75, 0, 0},
		Rleg    = {0.30, 0, 0.04},    RforeLeg = {-0.65, 0, 0},
	}},
	{t = 0.60, ease = "in", p = {
		Quadril = {-0.20, 0.30, 0, 0, -0.70, -0.95},
		Torso   = {-0.30, 0.40, -0.05},
		Spine   = {-0.12, 0.12, 0},
		Neck    = {0.18, -0.30, 0},
		Head    = {0.08, -0.15, 0},
		Rarm    = {1.52, 0, -0.18},
		ForeRarm= {0.12, 0, 0},
		Rhand   = {0.30, 0, 0},
		Larm    = {-0.30, 0, -0.45},
		ForeLarm= {0.40, 0, 0},
		Rleg    = {0.55, 0, 0.04},    RforeLeg = {-0.40, 0, 0},
		Lleg    = {-0.35, 0, -0.04},  LforeLeg = {-0.50, 0, 0},
	}},
	{t = 0.85, p = {
		Quadril = {-0.16, 0.20, 0, 0, -0.60, -0.70},
		Torso   = {-0.24, 0.30, -0.04},
		Spine   = {-0.10, 0.08, 0},
		Neck    = {0.16, -0.22, 0},
		Head    = {0.06, -0.10, 0},
		Rarm    = {1.38, 0, -0.20},
		ForeRarm= {0.40, 0, 0},
		Rhand   = {-0.25, 0, 0},
		Larm    = {-0.20, 0, -0.45},
		ForeLarm= {0.40, 0, 0},
		Rleg    = {0.50, 0, 0.04},    RforeLeg = {-0.38, 0, 0},
		Lleg    = {-0.30, 0, -0.04},  LforeLeg = {-0.46, 0, 0},
	}},
	{t = 1.30, p = {
		Quadril = {0, 0.10, 0, 0, 0, -0.20},
		Torso   = {-0.04, 0.10, 0},
		Spine   = {0, 0, 0},
		Neck    = {0.10, -0.10, 0},
		Head    = {-0.05, 0, 0},
		Rarm    = {2.05, 0, -0.22},
		ForeRarm= {0.55, 0, 0},
		Rhand   = {-0.15, 0, 0},
		Larm    = {0.35, 0, -0.28},
		ForeLarm= {0.60, 0, 0},
		Rleg    = {0.10, 0, 0.03},    Lleg = {0.05, 0, -0.03},
	}},
	{t = 1.60, p = {
		Quadril = {-0.04, 0, 0, 0, 0, -0.30},
		Torso   = {-0.10, 0, 0},
		Spine   = {-0.16, 0, 0},
		Neck    = {-0.22, 0, 0},
		Head    = {0.04, -0.04, 0.18},
		Rarm    = {2.20, 0, -0.20},
		ForeRarm= {1.05, 0, 0},
		Rhand   = {-0.10, 0, 0},
		Larm    = {0.55, 0, -0.30},
		ForeLarm= {0.70, 0, 0},
		Rleg    = {0.10, 0, 0.03},    Lleg = {0.05, 0, -0.03},
	}},
	{t = 1.95, p = {
		Quadril = {-0.04, 0, 0, 0, 0, -0.30},
		Torso   = {-0.10, 0, 0},
		Spine   = {-0.16, 0, 0},
		Neck    = {-0.24, 0, 0},
		Head    = {0.04, 0.12, -0.20},
		Rarm    = {2.22, 0, -0.20},
		ForeRarm= {1.08, 0, 0},
		Rhand   = {-0.10, 0, 0},
		Larm    = {1.00, 0, -0.38},
		ForeLarm= {0.80, 0, 0},
		Rleg    = {0.10, 0, 0.03},    Lleg = {0.05, 0, -0.03},
	}},
	{t = 2.15, p = {
		Quadril = {0.02, 0, 0, 0, 0.10, -0.20},
		Torso   = {0.06, 0, 0},
		Spine   = {-0.04, 0, 0},
		Neck    = {-0.10, 0, 0},
		Head    = {0, 0, 0},
		Rarm    = {2.20, 0, -0.20},
		ForeRarm= {1.00, 0, 0},
		Rhand   = {-0.10, 0, 0},
		Larm    = {2.55, 0, -0.45},
		ForeLarm= {0.55, 0, 0},
		Lhand   = {-0.10, 0, 0},
	}},
	{t = 2.30, ease = "in", p = {
		Quadril = {-0.12, 0.06, 0, 0, -0.25, -0.65},
		Torso   = {-0.28, 0.06, 0},
		Spine   = {-0.14, 0, 0},
		Neck    = {-0.28, 0, 0},
		Head    = {0.06, 0, 0},
		Rarm    = {2.15, 0, -0.20},
		ForeRarm= {1.00, 0, 0},
		Rhand   = {-0.10, 0, 0},
		Larm    = {1.55, 0, -0.12},
		ForeLarm= {0.15, 0, 0},
		Lhand   = {0.25, 0, 0},
	}},
	{t = 2.55, p = {
		Quadril = {-0.04, 0, 0, 0, -0.10, -0.25},
		Torso   = {-0.10, 0, 0},
		Spine   = {-0.06, 0, 0},
		Neck    = {-0.10, 0, 0},
		Head    = {0.04, 0, 0},
		Rarm    = {2.45, 0, -0.10},
		ForeRarm= {0.70, 0, 0},
		Larm    = {0.80, 0, -0.25},
		ForeLarm= {0.35, 0, 0},
	}},
	{t = 3.00, p = {
		Quadril = {0.22, 0, 0, 0, 0.15, 0.65},
		Torso   = {0.34, 0.06, 0},
		Spine   = {0.20, 0, 0},
		Neck    = {0.30, 0, 0},
		Head    = {0.12, 0, 0},
		Rarm    = {3.45, 0, 0.25},
		ForeRarm= {0.25, 0, 0},
		Rhand   = {-0.15, 0, 0},
		Larm    = {2.20, 0, -0.55},
		ForeLarm= {0.30, 0, 0},
		Lleg    = {-0.25, 0, -0.04},  LforeLeg = {-0.20, 0, 0},
		Rleg    = {0.22, 0, 0.04},    RforeLeg = {-0.30, 0, 0},
	}},
	{t = 3.14, ease = "in", p = {
		Quadril = {-0.28, 0.15, 0, 0, -0.55, -1.40},
		Torso   = {-0.42, 0.25, 0},
		Spine   = {-0.20, 0.06, 0},
		Neck    = {0.02, 0, 0},
		Head    = {0, 0, 0},
		Rarm    = {2.25, 0, -0.10},
		ForeRarm= {0.12, 0, 0},
		Rhand   = {0.20, 0, 0},
		Larm    = {-0.20, 0, -0.60},
		ForeLarm= {0.30, 0, 0},
		Rleg    = {0.65, 0, 0.04},    RforeLeg = {-0.55, 0, 0},
		Lleg    = {-0.40, 0, -0.04},  LforeLeg = {-0.20, 0, 0},
	}},
	{t = 3.32, p = {
		Quadril = {-0.30, 0.18, 0, 0, -0.70, -1.50},
		Torso   = {-0.52, 0.30, 0},
		Spine   = {-0.22, 0.08, 0},
		Neck    = {0.20, 0, 0},
		Head    = {0.06, 0, 0},
		Rarm    = {0.95, 0, -0.25},
		ForeRarm= {0.22, 0, 0},
		Rhand   = {0.10, 0, 0},
		Larm    = {-0.35, 0, -0.55},
		ForeLarm= {0.30, 0, 0},
		Rleg    = {0.62, 0, 0.04},    RforeLeg = {-0.55, 0, 0},
		Lleg    = {-0.40, 0, -0.04},  LforeLeg = {-0.20, 0, 0},
	}},
	{t = 4.10, p = {
		Quadril = {-0.10, 0.04, 0, 0, -0.25, -0.50},
		Torso   = {-0.14, 0.06, 0},
		Neck    = {0.12, 0, 0},
		Rarm    = {0.25, 0, 0.05},
		ForeRarm= {0.25, 0, 0},
		Larm    = {0.15, 0, -0.10},
		Rleg    = {0.25, 0, 0},       RforeLeg = {-0.25, 0, 0},
		Lleg    = {-0.15, 0, 0},
	}},
	{t = 4.90, p = {}},
})

-- F with nobody in reach: the same wind-up and swipe, then a clean recovery.
Clips.ExecuteMiss = Rig.Clip({
	{t = 0.00, p = {}},
	{t = 0.32, p = {
		Quadril = {-0.10, -0.18, 0, 0, -1.10, 0.25},
		Torso   = {-0.12, -0.38, 0.05},
		Spine   = {-0.04, -0.14, 0},
		Neck    = {0.05, 0.35, 0},
		Rarm    = {-0.45, 0, 0.55},
		ForeRarm= {0.70, 0, 0},
		Larm    = {0.55, 0, -0.30},
		ForeLarm= {0.90, 0, 0},
		Lleg    = {0.40, 0, -0.04},   LforeLeg = {-0.75, 0, 0},
		Rleg    = {0.30, 0, 0.04},    RforeLeg = {-0.65, 0, 0},
	}},
	{t = 0.60, ease = "in", p = {
		Quadril = {-0.20, 0.30, 0, 0, -0.70, -0.95},
		Torso   = {-0.30, 0.40, -0.05},
		Spine   = {-0.12, 0.12, 0},
		Neck    = {0.18, -0.30, 0},
		Rarm    = {1.52, 0, -0.18},
		ForeRarm= {0.12, 0, 0},
		Rhand   = {0.30, 0, 0},
		Larm    = {-0.30, 0, -0.45},
		ForeLarm= {0.40, 0, 0},
		Rleg    = {0.55, 0, 0.04},    RforeLeg = {-0.40, 0, 0},
		Lleg    = {-0.35, 0, -0.04},  LforeLeg = {-0.50, 0, 0},
	}},
	{t = 0.85, p = {
		Quadril = {-0.14, 0.18, 0, 0, -0.45, -0.60},
		Torso   = {-0.20, 0.26, 0},
		Rarm    = {1.30, 0, -0.18},
		ForeRarm= {0.30, 0, 0},
		Larm    = {-0.15, 0, -0.40},
		Rleg    = {0.40, 0, 0.04},    RforeLeg = {-0.30, 0, 0},
		Lleg    = {-0.25, 0, -0.04},
	}},
	{t = 1.50, p = {}},
})

-- B KICK: plant the left leg, pull the right knee high, extend through the target and recover.
Clips.Kick = Rig.Clip({
	{t = 0.00, p = {}},
	{t = 0.22, p = {
		Quadril = {-0.08, -0.20, 0.06, 0, -0.45, 0.20},
		Torso = {-0.10, -0.22, -0.06}, Spine = {-0.04, -0.08, 0},
		Neck = {0.10, 0.18, 0}, Head = {0.04, 0.10, 0},
		Rleg = {1.20, 0, 0.12}, RforeLeg = {-1.45, 0, 0}, Rfoot = {0.45, 0, 0},
		Lleg = {-0.16, 0, -0.08}, LforeLeg = {-0.26, 0, 0},
		Larm = {0.52, 0, -0.46}, ForeLarm = {0.70, 0, 0},
		Rarm = {-0.42, 0, 0.42}, ForeRarm = {0.55, 0, 0},
	}},
	{t = 0.50, ease = "in", p = {
		Quadril = {-0.18, 0.14, -0.05, 0, -0.30, -0.85},
		Torso = {-0.25, 0.20, 0.05}, Spine = {-0.10, 0.08, 0},
		Neck = {0.18, -0.12, 0}, Head = {0.06, -0.08, 0},
		Rleg = {1.45, 0, 0.08}, RforeLeg = {-0.05, 0, 0}, Rfoot = {-0.22, 0, 0},
		Lleg = {0.12, 0, -0.08}, LforeLeg = {-0.35, 0, 0},
		Larm = {-0.45, 0, -0.58}, ForeLarm = {0.42, 0, 0},
		Rarm = {0.62, 0, 0.52}, ForeRarm = {0.55, 0, 0},
	}},
	{t = 0.66, p = {
		Quadril = {-0.20, 0.18, -0.05, 0, -0.35, -1.05},
		Torso = {-0.28, 0.24, 0.05}, Spine = {-0.12, 0.10, 0},
		Neck = {0.20, -0.14, 0},
		Rleg = {1.28, 0, 0.08}, RforeLeg = {0.04, 0, 0}, Rfoot = {-0.30, 0, 0},
		Lleg = {0.15, 0, -0.08}, LforeLeg = {-0.40, 0, 0},
		Larm = {-0.55, 0, -0.62}, ForeLarm = {0.38, 0, 0},
		Rarm = {0.72, 0, 0.58}, ForeRarm = {0.50, 0, 0},
	}},
	{t = 0.95, p = {
		Quadril = {-0.12, 0.08, 0, 0, -0.18, -0.50},
		Torso = {-0.14, 0.10, 0}, Neck = {0.12, -0.06, 0},
		Rleg = {0.20, 0, 0.06}, RforeLeg = {-0.75, 0, 0}, Rfoot = {0.20, 0, 0},
		Lleg = {0.05, 0, -0.05}, LforeLeg = {-0.20, 0, 0},
		Larm = {0.10, 0, -0.25}, Rarm = {0.15, 0, 0.25},
	}},
	{t = 1.35, p = {}},
})

Clips.Roar = {
	{t = 0.0,  p = {}},
	{t = 0.32, p = {
		Quadril = PR(0, -0.16, 0, -0.05), Torso = PR(0, 0, 0, -0.18, 0, 0), Spine = PR(0, 0, 0, -0.1),
		Neck = PR(0, 0, 0, 0.26), Head = PR(0, 0, 0, 0.18),
		Larm = PR(0, 0, 0, 0.32, 0, -0.44), Rarm = PR(0, 0, 0, 0.32, 0, 0.44),
		ForeLarm = PR(0, 0, 0, 0.5), ForeRarm = PR(0, 0, 0, 0.5),
	}},
	{t = 0.58, p = {
		Quadril = PR(0, 0.12, 0, 0.08), Torso = PR(0, 0, 0, 0.2, 0, 0), Spine = PR(0, 0, 0, 0.12),
		Neck = PR(0, 0, 0, -0.46), Head = PR(0, 0, 0, -0.36),
		Larm = PR(0, 0, 0, -0.28, 0, -1.2), Rarm = PR(0, 0, 0, -0.28, 0, 1.2),
		ForeLarm = PR(0, 0, 0, 0.28), ForeRarm = PR(0, 0, 0, 0.28),
		Lhand = PR(0, 0, 0, -0.42), Rhand = PR(0, 0, 0, -0.42),
	}},
	{t = 1.08, p = {
		Torso = PR(0, 0, 0, 0.14, 0, 0), Neck = PR(0, 0, 0, -0.34), Head = PR(0, 0, 0, -0.26),
		Larm = PR(0, 0, 0, -0.2, 0, -0.95), Rarm = PR(0, 0, 0, -0.2, 0, 0.95),
	}},
	{t = 1.55, p = {}},
}
Clips.Taunt = {
	{t = 0.0,  p = {}},
	{t = 0.4,  p = {
		Torso = PR(0, 0, 0, 0.06, -0.16, 0), Neck = PR(0, 0, 0, -0.28, 0.36, -0.14), Head = PR(0, 0, 0, 0.12, 0.22, -0.18),
		Larm = PR(0, 0, 0, 0.5, 0, -0.5), Rarm = PR(0, 0, 0, 0.22, 0, 0.2),
		ForeLarm = PR(0, 0, 0, 1.25), Lhand = PR(0, 0, 0, 0.3),
	}},
	{t = 0.95, p = {
		Torso = PR(0, 0, 0, -0.03, 0.18, 0), Neck = PR(0, 0, 0, -0.12, -0.38, 0.16), Head = PR(0, 0, 0, -0.16, -0.2, 0.22),
		Larm = PR(0, 0, 0, 0.45, 0, -0.68), Rarm = PR(0, 0, 0, 0.45, 0, 0.68),
		ForeLarm = PR(0, 0, 0, 0.8), ForeRarm = PR(0, 0, 0, 0.8),
		Lhand = PR(0, 0, 0, -0.2), Rhand = PR(0, 0, 0, -0.2),
	}},
	{t = 1.7,  p = {}},
}
Clips.Flinch = {
	{t = 0.0,  p = {}},
	{t = 0.09, p = {
		Torso = PR(0, 0, 0, 0.2, 0.14, -0.06), Spine = PR(0, 0, 0, 0.1),
		Neck = PR(0, 0, 0, -0.18), Head = PR(0, 0, 0, 0.12, -0.14, 0.1),
		Larm = PR(0, 0, 0, 0.32, 0, -0.2), Rarm = PR(0, 0, 0, 0.32, 0, 0.2),
		ForeLarm = PR(0, 0, 0, 0.55), ForeRarm = PR(0, 0, 0, 0.55),
	}},
	{t = 0.38, p = {}},
}
Clips.Land = {
	{t = 0.0, p = {
		Quadril = PR(0, -0.5, 0, -0.07), Torso = PR(0, 0, 0, -0.12), Neck = PR(0, 0, 0, 0.16),
		Lleg = PR(0, 0, 0, 0.42), Rleg = PR(0, 0, 0, 0.42),
		LforeLeg = PR(0, 0, 0, -0.7), RforeLeg = PR(0, 0, 0, -0.7),
		Larm = PR(0, 0, 0, 0.22, 0, -0.2), Rarm = PR(0, 0, 0, 0.22, 0, 0.2),
	}},
	{t = 0.14, p = {
		Quadril = PR(0, -0.16, 0, -0.02), Torso = PR(0, 0, 0, -0.04),
		Lleg = PR(0, 0, 0, 0.14), Rleg = PR(0, 0, 0, 0.14),
	}},
	{t = 0.33, p = {}},
}

function Rig.CheckClips(rig)
	local samples = 0
	for name, frames in pairs(Clips) do
		for index, keyframe in ipairs(frames) do
			local ok, detail = Rig.CheckPose(rig, keyframe.p)
			if not ok then return false, name .. ": " .. detail end
			samples += 1
			if frames[index + 1] then
				local midpoint = (keyframe.t + frames[index + 1].t) * 0.5
				ok, detail = Rig.CheckPose(rig, sampleClip(frames, midpoint))
				if not ok then return false, name .. " transition: " .. detail end
				samples += 1
			end
		end
	end
	rig.clipSamples = samples
	return true
end

--====================================================================--
-- UI HELPERS                                                         --
--====================================================================--
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(p, r) return new("UICorner", {CornerRadius = r or UDim.new(0, 10)}, p) end
local function stroke(p, col, th, tr)
	return new("UIStroke", {
		Color = col, Thickness = th or 2, Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, p)
end
local NEON_GRAD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, CONFIG.NEON_A),
	ColorSequenceKeypoint.new(0.5, CONFIG.NEON_C),
	ColorSequenceKeypoint.new(1, CONFIG.NEON_B),
})

local gui = new("ScreenGui", {
	Name = "GuiltLocal_v52_SM1LER", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
do
	local ok, hui = pcall(function() return (typeof(gethui) == "function") and gethui() or nil end)
	gui.Parent = (ok and hui) or player:WaitForChild("PlayerGui")
end

local function neonText(parent, text, font, w, h, pos, color, z)
	local holder = new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), Position = pos,
		AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z,
	}, parent)
	local function layer(col, x, y, tr, zz)
		return new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(x, y), Font = font, Text = text,
			TextScaled = true, TextColor3 = col, TextTransparency = tr, ZIndex = zz,
		}, holder)
	end
	local a = layer(CONFIG.NEON_B, -1, 0, 0.92, z)
	local b = layer(CONFIG.NEON_C, 1, 0, 0.92, z)
	local main = layer(color, 0, 0, 0, z + 1)
	new("UIStroke", {Color = color, Thickness = 0.5, Transparency = 0.85}, main)
	return holder, main, a, b
end

--====================================================================--
-- INTRO                                                              --
--====================================================================--
local function playIntro(done)
	local root = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0, ZIndex = 200,
	}, gui)
	local skipped = false
	local skipConn
	skipConn = UserInputService.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch
			or i.KeyCode == Enum.KeyCode.Space
			or i.KeyCode == Enum.KeyCode.Return
			or i.KeyCode == Enum.KeyCode.Escape then
			skipped = true
		end
	end)
	for i = 0, 80 do
		new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.62,
			BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, i / 80), ZIndex = 240,
		}, root)
	end
	local ash = {}
	for i = 1, 60 do
		ash[i] = new("Frame", {
			BackgroundColor3 = (i % 5 == 0) and CONFIG.NEON_C or CONFIG.NEON_B,
			BackgroundTransparency = rnd(0.5, 0.85), BorderSizePixel = 0,
			Size = UDim2.fromOffset(rng:NextInteger(1, 3), rng:NextInteger(1, 4)),
			Position = UDim2.fromScale(rnd(0, 1), rnd(0.7, 1.1)), ZIndex = 232,
		}, root)
	end
	local ashConn = RunService.RenderStepped:Connect(function(dt)
		for _, f in ipairs(ash) do
			local p = f.Position
			f.Position = UDim2.fromScale(p.X.Scale, p.Y.Scale - dt * rnd(0.02, 0.09))
			if p.Y.Scale < -0.05 then f.Position = UDim2.fromScale(rnd(0, 1), 1.05) end
		end
	end)
	local line1 = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 3), BackgroundColor3 = CONFIG.NEON_B, BorderSizePixel = 0, ZIndex = 210,
	}, root)
	local line2 = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 5),
		Size = UDim2.new(0, 0, 0, 1), BackgroundColor3 = CONFIG.NEON_C, BorderSizePixel = 0, ZIndex = 210,
	}, root)
	task.wait(0.4)
	if not skipped then
		sfx(SND.ui, 1, 0.6)
		tw(line1, 0.42, {Size = UDim2.new(1, 0, 0, 3)}, Enum.EasingStyle.Quart)
		tw(line2, 0.55, {Size = UDim2.new(1, 0, 0, 1)}, Enum.EasingStyle.Quart)
		task.wait(0.55)
	end
	tw(line1, 0.3, {Size = UDim2.new(0, 0, 0, 3), BackgroundTransparency = 1})
	tw(line2, 0.3, {Size = UDim2.new(0, 0, 0, 1), BackgroundTransparency = 1})
	local sigil = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 206, ClipsDescendants = true,
	}, root)
	local sigScale = new("UIScale", {}, sigil)
	for i = 1, 4 do
		local ringF = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(420 - i * 62, 420 - i * 62), BackgroundTransparency = 1, ZIndex = 206,
		}, sigil)
		corner(ringF, UDim.new(1, 0))
		local rs = stroke(ringF, (i % 2 == 0) and CONFIG.NEON_C or CONFIG.NEON_A, 1.4, 0.25)
		if i == 2 then
			new("UIGradient", {
				Rotation = 30 * i,
				Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 0.1)}),
			}, rs)
		end
		task.spawn(function()
			for _ = 1, 6 do
				if sigil.Parent and not skipped then
					ringF.Rotation += (i % 2 == 0) and 8 or -6
					task.wait(0.06)
				end
			end
		end)
	end
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(a) * 176, 0.5, math.sin(a) * 176),
			Size = UDim2.fromOffset(rng:NextInteger(10, 30), 2), Rotation = math.deg(a),
			BackgroundColor3 = CONFIG.NEON_A, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 207,
		}, sigil)
	end
	local core = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(140, 140), BackgroundColor3 = CONFIG.NEON_A,
		BackgroundTransparency = 0.82, ZIndex = 205,
	}, sigil)
	corner(core, UDim.new(1, 0))
	if not skipped then
		sfx(SND.growl, 2.2, 0.3)
		tw(sigil, 0.9, {Size = UDim2.fromOffset(470, 470)}, Enum.EasingStyle.Quint)
		tw(sigScale, 1.1, {Scale = 1}, Enum.EasingStyle.Elastic)
		tw(core, 1.2, {Size = UDim2.fromOffset(220, 220), BackgroundTransparency = 0.7}, Enum.EasingStyle.Quart)
		task.wait(0.75)
	end
	local title = "THE GUILT"
	local letters = {}
	local lw, gap = 74, 22
	local total = 0
	for i = 1, #title do total += (title:sub(i, i) == " ") and gap or lw end
	local x = -total / 2
	if not skipped then sfx(SND.whoosh, 2, 0.42) end
	for i = 1, #title do
		local ch = title:sub(i, i)
		if ch == " " then
			x += gap
		else
			local holder, main, a2, b2 = neonText(root, ch, CONFIG.FONT_TITLE, lw + 10, 116,
				UDim2.new(0.5, x + lw / 2, 0.64, -84), CONFIG.NEON_A, 220)
			holder.Rotation = rnd(-46, 46)
			for _, l in ipairs({main, a2, b2}) do l.TextTransparency = 1 end
			tw(holder, 0.6, {Position = UDim2.new(0.5, x + lw / 2, 0.64, 0), Rotation = 0}, Enum.EasingStyle.Back)
			tw(main, 0.34, {TextTransparency = 0})
			tw(a2, 0.34, {TextTransparency = 0.5})
			tw(b2, 0.34, {TextTransparency = 0.5})
			letters[#letters + 1] = {h = holder, x = x + lw / 2}
			x += lw
			if not skipped then task.wait(0.055) end
		end
	end
	local sub = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.77), Size = UDim2.fromOffset(560, 26),
		Font = CONFIG.FONT_UI, TextScaled = true, Text = "",
		TextColor3 = CONFIG.NEON_B, ZIndex = 220,
	}, root)
	local subText = "By SM1LER // v5.2 // F=EXECUTE B=KICK G=CRAWL"
	for i = 1, #subText do
		if skipped then sub.Text = subText break end
		sub.Text = subText:sub(1, i)
		sfx(SND.ui, 0.35, 1.4)
		task.wait(0.022)
	end
	if not skipped then task.wait(0.45) end
	local cols = {CONFIG.NEON_A, CONFIG.NEON_B, CONFIG.NEON_C, Color3.new(1, 1, 1)}
	local t0 = os.clock()
	while os.clock() - t0 < 0.75 do
		for _ = 1, 5 do
			local bar = new("Frame", {
				BackgroundColor3 = cols[rng:NextInteger(1, 4)], BorderSizePixel = 0, ZIndex = 230,
				Position = UDim2.fromScale(rnd(0, 0.9), rnd(0, 1)),
				Size = UDim2.new(rnd(0.08, 0.45), 0, 0, rng:NextInteger(2, 15)),
			}, root)
			Debris:AddItem(bar, 0.07)
		end
		for _, l in ipairs(letters) do
			l.h.Position = UDim2.new(0.5, l.x + rng:NextInteger(-8, 8), 0.64, rng:NextInteger(-6, 6))
		end
		sigil.Position = UDim2.new(0.5, rng:NextInteger(-8, 8), 0.47, 0)
		task.wait(0.04)
	end
	sfx(SND.roar, 2.6, 0.6)
	sfx(SND.growl, 2.4, 0.26)
	local flash = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 232, 226),
		BorderSizePixel = 0, ZIndex = 250,
	}, root)
	for _, d in ipairs(root:GetChildren()) do if d ~= flash then d.Visible = false end end
	root.BackgroundTransparency = 0
	tw(flash, 0.5, {BackgroundTransparency = 1})
	task.wait(0.18)
	ashConn:Disconnect()
	skipConn:Disconnect()
	tw(root, 0.5, {BackgroundTransparency = 1})
	task.wait(0.55)
	root:Destroy()
	introDone = true
	done()
end

--====================================================================--
-- MENU                                                               --
--====================================================================--
local menuRoot = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 100, Visible = false, Active = true,
}, gui)
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(900, 584), BackgroundColor3 = Color3.fromRGB(9, 6, 5),
	BorderSizePixel = 0, ZIndex = 101, ClipsDescendants = true,
}, menuRoot)
corner(panel, UDim.new(0, 18))
local pStroke = stroke(panel, Color3.new(1, 1, 1), 2.5)
local pGrad = new("UIGradient", {Color = NEON_GRAD, Rotation = 24}, pStroke)
local pScale = new("UIScale", {}, panel)

local topBar = new("Frame", {
	Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = Color3.fromRGB(14, 9, 8),
	BorderSizePixel = 0, ZIndex = 102,
}, panel)
new("UIGradient", {
	Color = ColorSequence.new(CONFIG.NEON_A, Color3.fromRGB(24, 10, 10)), Rotation = 0,
}, topBar)
neonText(topBar, "THE GUILT", CONFIG.FONT_TITLE, 260, 62, UDim2.new(0, 190, 0.5, 0), CONFIG.NEON_B, 110)
neonText(topBar, "By SM1LER", CONFIG.FONT_MARK, 160, 28, UDim2.new(0, 470, 0.5, -8), CONFIG.NEON_C, 110)
neonText(topBar, "v5.2", CONFIG.FONT_TITLE, 70, 28, UDim2.new(0, 470, 0.5, 20), CONFIG.NEON_A, 110)
new("TextLabel", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -66, 0.5, 0), Size = UDim2.fromOffset(260, 46),
	Font = CONFIG.FONT_UI, TextScaled = true, Text = "F=EXECUTE // B=KICK // G=CRAWL",
	TextColor3 = CONFIG.NEON_B, TextXAlignment = Enum.TextXAlignment.Right,
	TextTransparency = 0.25, ZIndex = 110,
}, topBar)

local closeBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Color3.fromRGB(24, 6, 5),
	AutoButtonColor = false, Text = "", ZIndex = 112,
}, topBar)
corner(closeBtn, UDim.new(1, 0))
local cStroke = stroke(closeBtn, CONFIG.NEON_A, 2)
local cScale = new("UIScale", {}, closeBtn)
for _, r in ipairs({45, -45}) do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(17, 3), Rotation = r,
		BackgroundColor3 = CONFIG.NEON_A, BorderSizePixel = 0, ZIndex = 113,
	}, closeBtn)
end
closeBtn.MouseEnter:Connect(function() tw(cScale, 0.15, {Scale = 1.16}, Enum.EasingStyle.Back) tw(cStroke, 0.15, {Thickness = 4}) end)
closeBtn.MouseLeave:Connect(function() tw(cScale, 0.15, {Scale = 1}) tw(cStroke, 0.15, {Thickness = 2}) end)
closeBtn.Activated:Connect(function() sfx(SND.ui, 0.8, 0.75) closeMenu() end)

local vpfHolder = new("Frame", {
	Position = UDim2.fromOffset(24, 96), Size = UDim2.fromOffset(420, 388),
	BackgroundColor3 = Color3.fromRGB(11, 7, 6), BorderSizePixel = 0, ZIndex = 102, ClipsDescendants = true,
}, panel)
corner(vpfHolder, UDim.new(0, 14))
local vpf = new("ViewportFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 103,
	Ambient = Color3.fromRGB(120, 40, 30), LightColor = Color3.fromRGB(255, 120, 90),
	LightDirection = Vector3.new(0.5, -0.5, 1),
}, vpfHolder)
local vcam = new("Camera", {FieldOfView = 30}, vpf)
vpf.CurrentCamera = vcam
local vGlow = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(320, 320), BackgroundColor3 = CONFIG.NEON_A,
	BackgroundTransparency = 0.86, ZIndex = 103,
}, vpfHolder)
corner(vGlow, UDim.new(1, 0))
local vRing = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromOffset(290, 290), BackgroundTransparency = 1, ZIndex = 104,
}, vpfHolder)
corner(vRing, UDim.new(1, 0))
local vRingStroke = stroke(vRing, CONFIG.NEON_C, 1.6, 0.45)
local vLabel = new("TextLabel", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, -42), Size = UDim2.fromOffset(360, 30),
	Font = CONFIG.FONT_UI, TextScaled = true, Text = "VIEWPORT · BIND RIG · By SM1LER",
	TextColor3 = CONFIG.NEON_B, TextTransparency = 0.35, ZIndex = 105,
}, vpfHolder)

local stats = new("Frame", {
	Position = UDim2.fromOffset(24, 492), Size = UDim2.fromOffset(420, 66),
	BackgroundTransparency = 1, ZIndex = 102,
}, panel)
Instance.new("UIListLayout", stats).FillDirection = Enum.FillDirection.Horizontal
stats:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 8)
local statLabels = {}
for _, key in ipairs({"HEIGHT", "SPEED", "STATE"}) do
	local cell = new("Frame", {
		Size = UDim2.new(1 / 3, -6, 1, 0), BackgroundColor3 = Color3.fromRGB(17, 11, 10),
		BorderSizePixel = 0, ZIndex = 102,
	}, stats)
	corner(cell, UDim.new(0, 8))
	stroke(cell, Color3.fromRGB(70, 42, 38), 1.4, 0.4)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 7), Size = UDim2.new(1, 0, 0, 14),
		Font = CONFIG.FONT_UI, TextScaled = true, Text = key, TextColor3 = CONFIG.NEON_C, ZIndex = 103,
	}, cell)
	statLabels[key] = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 32),
		Font = CONFIG.FONT_TITLE, TextScaled = true, Text = "-", TextColor3 = CONFIG.NEON_B, ZIndex = 103,
	}, cell)
end

local rightCol = new("Frame", {
	Position = UDim2.fromOffset(472, 96), Size = UDim2.fromOffset(400, 340),
	BackgroundTransparency = 1, ZIndex = 102,
}, panel)
Instance.new("UIListLayout", rightCol).Padding = UDim.new(0, 12)

local function mkBtn(label, desc, col, order, cb)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = Color3.fromRGB(10, 7, 6),
		AutoButtonColor = false, Text = "", BorderSizePixel = 0, ZIndex = 102,
		ClipsDescendants = true, LayoutOrder = order,
	}, rightCol)
	corner(b, UDim.new(0, 12))
	local s = stroke(b, col, 2.2)
	local sc = new("UIScale", {}, b)
	local fill = new("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = col,
		BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 102,
	}, b)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 8), Size = UDim2.new(1, -90, 0, 28),
		Font = CONFIG.FONT_TITLE, Text = label, TextSize = 20, TextScaled = false,
		TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 104,
	}, b)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 38), Size = UDim2.new(1, -80, 0, 28),
		Font = CONFIG.FONT_UI, Text = desc, TextSize = 13, TextScaled = false, TextWrapped = true,
		TextColor3 = Color3.fromRGB(150, 130, 120), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 104,
	}, b)
	local idx = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(44, 44),
		Font = CONFIG.FONT_MARK, Text = string.format("%02d", order), TextScaled = true,
		TextColor3 = col, TextTransparency = 0.35, ZIndex = 104,
	}, b)
	b.MouseEnter:Connect(function()
		sfx(SND.ui, 0.3, 2)
		tw(sc, 0.15, {Scale = 1.045}, Enum.EasingStyle.Back)
		tw(s, 0.15, {Thickness = 4})
		tw(fill, 0.28, {Size = UDim2.fromScale(1, 1)})
		tw(idx, 0.15, {TextTransparency = 0})
	end)
	b.MouseLeave:Connect(function()
		tw(sc, 0.15, {Scale = 1})
		tw(s, 0.15, {Thickness = 2.2})
		tw(fill, 0.28, {Size = UDim2.fromScale(0, 1)})
		tw(idx, 0.15, {TextTransparency = 0.35})
	end)
	b.Activated:Connect(function()
		sfx(SND.ui, 0.85, 0.8)
		fill.BackgroundTransparency = 0.35
		tw(fill, 0.3, {BackgroundTransparency = 0.82})
		cb()
	end)
	return b
end

mkBtn("MORPH", "Transform and play the spawn sequence", CONFIG.NEON_A, 1, function() task.spawn(mount) closeMenu() end)
mkBtn("BURROW", "Enter or leave the ground (C)", CONFIG.NEON_C, 2, function()
	if S.underground then surface() else goUnder() end
end)
mkBtn("DEVIANT MODE", "Rotate the model by 180 degrees", CONFIG.NEON_B, 3, function()
	S.flip = (S.flip + 180) % 360
	genv.__GUILT_FLIP = S.flip
	if S.mounted then analyze() end
	if layoutViewport then layoutViewport() end
end)
mkBtn("RESET", "Restore your original character", CONFIG.NEON_A, 4, function() unmount() end)

local statusBox = new("Frame", {
	Position = UDim2.fromOffset(472, 448), Size = UDim2.fromOffset(400, 110),
	BackgroundColor3 = Color3.fromRGB(12, 8, 7), BorderSizePixel = 0, ZIndex = 102,
}, panel)
corner(statusBox, UDim.new(0, 12))
local statusStroke = stroke(statusBox, CONFIG.NEON_A, 1.6, 0.5)
new("UIGradient", {Color = NEON_GRAD}, statusStroke)
local menuStatus = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 46),
	Font = CONFIG.FONT_UI, TextSize = 13, TextScaled = false, TextWrapped = true,
	Text = "STATUS: LOADING MODEL...", TextColor3 = CONFIG.NEON_C,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 103,
}, statusBox)
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 0, 46),
	Font = CONFIG.FONT_UI, TextSize = 12, TextScaled = false,
	Text = "Q attack / E lunge / R devour / F execute / B kick\nG crawl / C burrow / X roar / V taunt / T dummy / H bind pose",
	TextColor3 = Color3.fromRGB(170, 150, 140), TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true, ZIndex = 103,
}, statusBox)

local embers = {}
for i = 1, 34 do
	local col = ({CONFIG.NEON_A, CONFIG.NEON_C, CONFIG.NEON_B})[i % 3 + 1]
	local f = new("Frame", {
		Size = UDim2.fromOffset(3, 3), BackgroundColor3 = col,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 105,
	}, panel)
	embers[i] = {f = f, x = math.random(), y = math.random(), s = rnd(0.05, 0.16), w = rnd(0, 6)}
end

local reopen = new("TextButton", {
	Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(54, 54),
	BackgroundColor3 = Color3.fromRGB(10, 5, 4), AutoButtonColor = false,
	Text = "", Visible = false, ZIndex = 90,
}, gui)
corner(reopen, UDim.new(1, 0))
local rStroke = stroke(reopen, Color3.new(1, 1, 1), 2)
local rGrad = new("UIGradient", {Color = NEON_GRAD}, rStroke)
local rScale = new("UIScale", {}, reopen)
local rCore = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, ZIndex = 91,
}, reopen)
for row = -1, 1 do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, row * 6),
		Size = UDim2.fromOffset(row == 0 and 18 or 13, 2),
		BackgroundColor3 = CONFIG.NEON_A, BorderSizePixel = 0, ZIndex = 92,
	}, rCore)
end

local function baseScale()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min(v.X / 940, v.Y / 624), 0.3, 1.12)
end

closeMenu = function()
	menuOpen = false
	tw(pScale, 0.26, {Scale = baseScale() * 0.76}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tw(menuRoot, 0.3, {BackgroundTransparency = 1})
	task.delay(0.28, function()
		if not menuOpen then menuRoot.Visible = false reopen.Visible = true end
	end)
end
local function openMenu()
	menuOpen = true
	menuRoot.Visible = true
	reopen.Visible = false
	menuRoot.BackgroundTransparency = 1
	tw(menuRoot, 0.34, {BackgroundTransparency = 0})
	pScale.Scale = baseScale() * 0.82
	tw(pScale, 0.5, {Scale = baseScale()}, Enum.EasingStyle.Back)
end
reopen.MouseEnter:Connect(function() tw(rScale, 0.15, {Scale = 1.14}, Enum.EasingStyle.Back) end)
reopen.MouseLeave:Connect(function() tw(rScale, 0.15, {Scale = 1}) end)

-- The only visible HUD element while the menu is closed: a draggable menu button.
local menuDrag, dragTouch, dragMoved = false, false, false
local dragInput, dragStart, dragOrigin
gtrack(reopen.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	menuDrag = true
	dragTouch = input.UserInputType == Enum.UserInputType.Touch
	dragMoved = false
	dragInput = input
	dragStart = input.Position
	dragOrigin = reopen.Position
end))
gtrack(UserInputService.InputChanged:Connect(function(input)
	if not menuDrag then return end
	local isDragMotion = (dragTouch and input == dragInput)
		or (not dragTouch and input.UserInputType == Enum.UserInputType.MouseMovement)
	if not isDragMotion then return end
	local delta = input.Position - dragStart
	if delta.Magnitude > 5 then dragMoved = true end
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local maxX = math.max(8, viewport.X - reopen.AbsoluteSize.X - 8)
	local maxY = math.max(8, viewport.Y - reopen.AbsoluteSize.Y - 8)
	reopen.Position = UDim2.fromOffset(
		math.clamp(dragOrigin.X.Offset + delta.X, 8, maxX),
		math.clamp(dragOrigin.Y.Offset + delta.Y, 8, maxY))
end))
gtrack(UserInputService.InputEnded:Connect(function(input)
	local ended = menuDrag and ((dragTouch and input == dragInput)
		or (not dragTouch and input.UserInputType == Enum.UserInputType.MouseButton1))
	if not ended then return end
	local open = not dragMoved
	menuDrag, dragInput, dragStart, dragOrigin = false, nil, nil, nil
	if open then openMenu() end
end))

local vpModel, vpH, vpEntries, vpRig
layoutViewport = function()
	if not (vpModel and vpRig) then return end
	local yawCF = CFrame.Angles(0, math.rad(((S.fallback and 0 or CONFIG.MODEL_YAW) + S.flip) % 360), 0)
	Rig.Render(vpRig, yawCF, {})
end
task.spawn(function()
	local tpl = loadTemplate()
	local model = tpl:Clone()
	local ok, entries, parts, h, rig = pcall(buildEntries, model)
	if not ok or not entries then
		model:Destroy()
		vLabel.Text = "RIG ERROR / CHECK OUTPUT"
		warn("[Guilt] Preview rig: " .. tostring(ok and rig or entries))
		return
	end
	local clipsValid, clipError = Rig.CheckClips(rig)
	if not clipsValid then
		model:Destroy()
		warn("[Guilt] Preview clip check: " .. tostring(clipError))
		return
	end
	model.Name = "GuiltVPModel"
	local world = Instance.new("WorldModel")
	world.Parent = vpf
	model.Parent = world
	rig.viewport = true
	vpModel, vpH, vpEntries, vpRig = model, h, entries, rig
	layoutViewport()
end)

report = function(text, isError)
	menuStatus.Text = "STATUS: " .. text
	menuStatus.TextColor3 = isError and Color3.fromRGB(255, 122, 112) or CONFIG.NEON_C
	if isError then warn("[Guilt] " .. text) else print("[Guilt] " .. text) end
end

local function feetOffset()
	local hum, hrp = S.humanoid, S.hrp
	if not (hum and hrp) then return 3 end
	if hum.RigType == Enum.HumanoidRigType.R15 then
		return hum.HipHeight + hrp.Size.Y / 2
	end
	local leg = S.character and S.character:FindFirstChild("Left Leg")
	return hum.HipHeight + hrp.Size.Y / 2 + (leg and leg.Size.Y or 2)
end

--====================================================================--
-- ATTACK FX                                                          --
--====================================================================--
local function chompFX(rec)
	local maw = S.mawWorld
	local fwd = S.flat
	dismember(rec, maw, (fwd * 0.7 + UP).Unit, 55)
	killVictim(rec)
	S.consumed += 1
	carnage(maw, (fwd * 0.6 + UP).Unit, 85, {spread = 1.0, vmin = 28, vmax = 80, smin = 0.6, smax = 2.2})
	carnage(maw, (fwd + UP * 0.2).Unit, 40, {spread = 0.5, vmin = 35, vmax = 70, smin = 0.3, smax = 0.8, bone = 0.1, flesh = 0.1})
	for _ = 1, math.floor(40 * CONFIG.GORE) do
		piece("blood", maw + Vector3.new(rnd(-1, 1), rnd(-0.5, 0.5), rnd(-1, 1)),
			Vector3.new(rnd(-5, 5), rnd(-16, -1), rnd(-5, 5)) + fwd * rnd(2, 9), rnd(0.3, 1.1))
	end
	mist(maw, 95, 12)
	mist(maw, 30, 6, CONFIG.NEON_C)
	lightFlash(maw, CONFIG.NEON_A, 10, 50, 0.7)
	local feet = S.hrp.Position - Vector3.new(0, feetOffset(), 0)
	local g = groundAt(feet + fwd * 3, 6, 30)
	local gp, gn = g and g.Position or feet, g and g.Normal or UP
	puddle(gp, gn, 9, 45, false)
	scatterPuddles(gp, 8, 16, 1.2, 3.6, 32)
	ring(gp, gn, 28, CONFIG.NEON_A, 0.55)
	task.delay(0.08, function() ring(gp, gn, 20, CONFIG.NEON_C, 0.5) end)
	arterial(function() return S.mawWorld end, (fwd + UP * 0.5).Unit, 0.7)
	S.shake = 2.6
	impactTint(1)
	fovPunch(14)
	sfx(SND.splat, 4, 0.45)
	sfx(SND.slash, 3, 0.5)
	sfx(SND.hit, 3, 0.4)
	sfx(SND.growl, 3, 0.28)
	S.drool = os.clock() + 7
end

local function biteFX()
	local maw = S.mawWorld
	carnage(maw, (S.flat + UP * 0.3).Unit, 14, {spread = 1.1, vmin = 10, vmax = 30, smin = 0.3, smax = 0.9, bone = 0.25})
	for _ = 1, 8 do piece("blood", maw, Vector3.new(rnd(-3, 3), rnd(-10, -2), rnd(-3, 3)), rnd(0.25, 0.6)) end
	S.shake = math.max(S.shake, 0.7)
	sfx(SND.slash, 2, rnd(0.4, 0.55))
	sfx(SND.splat, 2, rnd(0.6, 0.8))
end

local function spitFX()
	local maw = S.mawWorld
	for _ = 1, 7 do piece("bone", maw, coneDir((S.flat + UP * 0.4).Unit, 0.4) * rnd(25, 45), rnd(0.8, 1.6)) end
	carnage(maw, S.flat, 12, {spread = 0.5, vmin = 15, vmax = 35, smin = 0.3, smax = 0.7})
	sfx(SND.whoosh, 2, 0.8)
end

local function slamHitFX(rec, pos)
	local feet = pos - Vector3.new(0, 2.5, 0)
	local g = groundAt(pos, 3, 20)
	local gp, gn = g and g.Position or feet, g and g.Normal or UP
	dismember(rec, pos, (UP * 0.8 + S.flat * 0.5).Unit, 60)
	killVictim(rec)
	S.consumed += 1
	carnage(pos, UP, 70, {spread = 1.3, vmin = 25, vmax = 75})
	carnage(pos, (S.flat + UP * 0.3).Unit, 35, {spread = 0.6, vmin = 30, vmax = 65, smin = 0.3, smax = 0.8})
	for _ = 1, math.floor(18 * CONFIG.GORE) do piece("dirt", gp + UP, coneDir(UP, 0.9) * rnd(18, 45), rnd(0.4, 1.1)) end
	mist(pos, 70, 10)
	lightFlash(pos, CONFIG.NEON_A, 9, 45, 0.6)
	puddle(gp, gn, 8, 40, false)
	scatterPuddles(gp, 7, 14, 1.2, 3.2, 30)
	ring(gp, gn, 24, CONFIG.NEON_A, 0.5)
	ring(gp, gn, 16, CONFIG.NEON_C, 0.45)
	fissure(gp, gn)
	S.shake = 2.2
	impactTint(0.85)
	fovPunch(10)
	sfx(SND.hit, 4, 0.45)
	sfx(SND.splat, 4, 0.5)
end

local function slapFX(pos)
	carnage(pos, (S.flat + UP * 0.3).Unit, 55, {spread = 1.0, vmin = 22, vmax = 65, smin = 0.45, smax = 1.6})
	mist(pos, 55, 9)
	lightFlash(pos, CONFIG.NEON_A, 9, 42, 0.55)
	S.shake = 2.5
	impactTint(0.95)
	fovPunch(10)
	sfx(SND.hit, 4, 0.48)
	sfx(SND.splat, 4, 0.52)
	sfx(SND.slash, 3, 0.55)
end

local function throwLandFX(pos, rec)
	local g = groundAt(pos, 4, 30)
	local gp, gn = g and g.Position or pos, g and g.Normal or UP
	if rec then
		dismember(rec, pos, UP, 70)
		if rec.state ~= "dead" then
			killVictim(rec)
			S.consumed += 1
		else
			rec.respawnAt = os.clock() + CONFIG.RESPAWN_DELAY
			for _, part in ipairs(rec.parts) do if part.Parent then part.Transparency = 1 end end
			if rec.hum then pcall(function() rec.hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end) end
		end
	end
	carnage(pos, UP, 95, {spread = 1.35, vmin = 28, vmax = 88, smin = 0.55, smax = 2.2})
	mist(pos, 85, 12)
	mist(pos, 30, 6, CONFIG.NEON_C)
	lightFlash(pos, CONFIG.NEON_A, 11, 55, 0.75)
	puddle(gp, gn, 10, 48, false)
	scatterPuddles(gp, 9, 18, 1.2, 3.8, 34)
	ring(gp, gn, 28, CONFIG.NEON_A, 0.6)
	ring(gp, gn, 18, CONFIG.NEON_C, 0.5)
	fissure(gp, gn)
	S.shake = 2.8
	impactTint(1)
	fovPunch(14)
	sfx(SND.hit, 4, 0.4)
	sfx(SND.splat, 4, 0.42)
	sfx(SND.growl, 3, 0.28)
end

local function roarFX(center)
	local g = groundAt(center, 4, 26)
	local gp, gn = g and g.Position or center, g and g.Normal or UP
	ring(gp, gn, CONFIG.ROAR_RANGE, CONFIG.NEON_A, 0.8)
	task.delay(0.1, function() ring(gp, gn, CONFIG.ROAR_RANGE * 0.66, CONFIG.NEON_C, 0.7) end)
	mist(center + UP * 2, 40, 10, CONFIG.NEON_C)
	lightFlash(center + UP * 3, CONFIG.NEON_A, 8, 46, 0.7)
	fissure(gp, gn)
	S.shake = 2.1
	impactTint(0.8)
	fovPunch(12)
end

local function kickHitFX(pos)
	-- Pure impact feedback: red blood particles only, no bones, flesh clones, kill or dismember.
	for _ = 1, math.floor(38 * CONFIG.GORE) do
		piece("blood", pos + Vector3.new(rnd(-0.8, 0.8), rnd(-0.5, 1), rnd(-0.8, 0.8)),
			coneDir((S.flat + UP * 0.35).Unit, 0.65) * rnd(22, 62), rnd(0.20, 0.65))
	end
	mist(pos, 45, 8, CONFIG.NEON_A)
	ring(pos - UP * 2, UP, 11, CONFIG.NEON_A, 0.38)
	lightFlash(pos, CONFIG.NEON_A, 8, 38, 0.45)
	S.shake = math.max(S.shake, 1.75)
	impactTint(0.65)
	fovPunch(9)
	sfx(SND.hit, 5.5, 0.32)
	sfx(SND.splat, 3.5, 0.55)
	sfx(SND.whoosh, 2.6, 0.43)
end

--====================================================================--
-- ATTACK CONTROL                                                     --
--====================================================================--
local function finishAttack()
	if S.victim and S.victim.state == "held" then
		restoreVictim(S.victim, true)
	elseif S.victim and S.victim.state == "dead" then
		-- interrupted after the kill: never leave a floating body behind
		for _, part in ipairs(S.victim.parts) do if part.Parent then part.Transparency = 1 end end
	end
	S.atk, S.victim, S.releasePos = nil, nil, nil
end

startDevour = function()
	if not S.mounted or S.restPose or S.atk or menuOpen or os.clock() < S.atkLock then return end
	if S.underground then S.pending = "devour" surface() return end
	local target = findTarget(CONFIG.DEVOUR_RANGE)
	S.atk, S.atkStart, S.ev = "devour", os.clock(), {}
	S.victim = target and capture(target) or nil
	S.atkHas = S.victim ~= nil
	S.atkDur = S.atkHas and 2.9 or 1.25
	S.atkLock = S.atkStart + S.atkDur + 0.12
	sfx(SND.growl, 2.4, 0.34)
	sfx(SND.whoosh, 2, 0.55)
end

startSlam = function()
	if not S.mounted or S.restPose or S.atk or menuOpen or os.clock() < S.atkLock then return end
	if S.underground then S.pending = "slam" surface() return end
	S.atk, S.atkStart, S.ev, S.atkHas = "slam", os.clock(), {}, false
	S.atkDur = 1.7
	S.atkLock = S.atkStart + S.atkDur + 0.06
	sfx(SND.growl, 1.8, 0.4)
end

-- F EXECUTE
startExecute = function()
	if not S.mounted or S.restPose or S.atk or menuOpen or os.clock() < S.atkLock then return end
	if S.underground then S.pending = "execute" surface() return end
	local target = findTarget(CONFIG.EXECUTE_RANGE)
	S.atk, S.atkStart, S.ev = "execute", os.clock(), {}
	S.victim = target and capture(target) or nil
	S.atkHas = S.victim ~= nil
	S.atkDur = S.atkHas and 4.9 or 1.5
	S.atkLock = S.atkStart + S.atkDur + 0.15
	S.grabSide = 1 -- right hand leads
	S.mode, S.drool = "idle", 0
	sfx(SND.growl, 2.6, 0.3)
	sfx(SND.whoosh, 2.2, 0.48)
end

startKick = function()
	if not S.mounted or S.restPose or S.atk or menuOpen or os.clock() < S.atkLock then return end
	if S.underground then S.pending = "kick" surface() return end
	local target = findTarget(CONFIG.KICK_RANGE, S.hrp.Position + S.flat * 7)
	S.atk, S.atkStart, S.atkDur, S.atkHas = "kick", os.clock(), 1.85, target ~= nil
	S.ev = {kickTarget = target}
	S.atkLock = S.atkStart + 1.95
	S.mode, S.drool = "idle", 0
	sfx(SND.whoosh, 1.8, 0.58)
end

local function startCleave()
	if not S.mounted or S.restPose or S.atk or menuOpen or os.clock() < S.atkLock then return end
	local t = os.clock()
	if t - S.comboWindow > 1.4 then S.combo = 0 end
	S.combo = (S.combo % 3) + 1
	S.comboWindow = t
	S.atk, S.atkStart, S.ev, S.atkHas = "cleave", os.clock(), {hit = {}}, false
	S.atkDur = S.combo == 3 and 0.92 or 0.6
	S.atkLock = S.atkStart + 0.34
	sfx(SND.whoosh, 1.9, rnd(0.75, 0.95))
end

local function startLunge()
	if not S.mounted or S.restPose or S.atk or menuOpen or os.clock() < S.atkLock then return end
	if S.underground then S.pending = "lunge" surface() return end
	S.atk, S.atkStart, S.ev, S.atkHas = "lunge", os.clock(), {}, false
	S.atkDur = 0.82
	S.atkLock = S.atkStart + 0.7
	sfx(SND.whoosh, 2.2, 0.5)
	sfx(SND.growl, 1.6, 0.42)
end

local function startRoar()
	if not S.mounted or S.restPose or S.atk or menuOpen or os.clock() < S.atkLock then return end
	S.atk, S.atkStart, S.ev, S.atkHas = "roar", os.clock(), {}, false
	S.atkDur = 1.55
	S.atkLock = S.atkStart + 1.2
	sfx(SND.roar, 2.4, 0.7)
end

local function dealDamage(rec, amount)
	local hum = rec.hum
	if not hum then
		killVictim(rec)
		S.consumed += 1
		return true
	end
	local newHealth = math.max(0, hum.Health - amount)
	pcall(function() hum.Health = newHealth end)
	if newHealth <= 0 then
		killVictim(rec)
		S.consumed += 1
		return true
	end
	return false
end

local function updateDevour(at, t)
	if not S.atkHas then
		if at >= 0.36 and not S.ev.swipe then
			S.ev.swipe = true
			sfx(SND.slash, 2, 0.6)
			S.shake = math.max(S.shake, 0.3)
		end
		return
	end
	local rec = S.victim
	if not rec or not rec.model.Parent then return end
	local hang = math.clamp(rec.size.Y * 0.48, 1.5, S.height * 0.42)
	if at < 0.30 then
		vSet(rec, rec.origCF * CFrame.new(math.sin(at * 55) * 0.2 * (at / 0.3), 0, 0))
	elseif at < 1.10 then
		if not S.ev.grab then
			S.ev.grab = true
			sfx(SND.hit, 3, 0.7)
			sfx(SND.splat, 2, 0.9)
			S.shake = math.max(S.shake, 0.9)
			carnage(S.clawWorld, UP, 12, {spread = 1.2, vmin = 8, vmax = 22, smin = 0.3, smax = 0.8, bone = 0, flesh = 0.1})
		end
		local k = smooth((at - 0.30) / 0.1)
		local faceRot = CFrame.lookAt(Vector3.zero, -S.flat).Rotation
		local sway = CFrame.Angles(math.sin(at * 8) * 0.35 + math.sin(at * 31) * 0.06,
			math.sin(at * 23) * 0.1, math.sin(at * 6.3) * 0.25)
		local target = CFrame.new(S.clawWorld - UP * hang) * faceRot * CFrame.Angles(0, 0, math.pi) * sway
		vSet(rec, rec.origCF:Lerp(target, k))
		if at > 0.85 and not S.ev.squeeze then
			S.ev.squeeze = true
			sfx(SND.splat, 3, 0.6)
			S.shake = math.max(S.shake, 0.8)
			arterial(function() return S.clawWorld end, S.flat:Cross(UP).Unit, 0.25, 0.02)
			arterial(function() return S.clawWorld end, -S.flat:Cross(UP).Unit, 0.25, 0.02)
		end
		if t > S.nextVDrip then
			S.nextVDrip = t + (at > 0.85 and 0.025 or 0.06)
			piece("blood", vPos(rec) + Vector3.new(rnd(-0.6, 0.6), rnd(-1, 0.5), rnd(-0.6, 0.6)),
				Vector3.new(rnd(-3, 3), rnd(-4, 1), rnd(-3, 3)), rnd(0.2, 0.5))
		end
	elseif at < 1.55 then
		if not S.ev.toss then
			S.ev.toss = true
			S.releasePos = vPos(rec)
			sfx(SND.whoosh, 3, 0.5)
		end
		local k = clamp01((at - 1.10) / 0.45) ^ 1.15
		local maw = S.mawWorld
		local mid = (S.releasePos + maw) / 2 + UP * (S.height * 0.42)
		vSet(rec, CFrame.new(bez(S.releasePos, mid, maw, k)) * CFrame.Angles(k * 9, k * 5, k * 2))
		if t > S.nextVDrip then
			S.nextVDrip = t + 0.03
			piece("blood", vPos(rec), Vector3.new(rnd(-2, 2), rnd(-2, 0), rnd(-2, 2)), rnd(0.25, 0.55))
		end
	else
		if not S.ev.chomp then S.ev.chomp = true chompFX(rec) end
		vSet(rec, CFrame.new(S.mawWorld))
		for i, bt in ipairs({1.85, 2.05, 2.25}) do
			if at >= bt and not S.ev["b" .. i] then S.ev["b" .. i] = true biteFX() end
		end
		if at >= 2.4 and not S.ev.spit then S.ev.spit = true spitFX() end
	end
end

-- F EXECUTE victim timeline
local function updateExecute(at, t)
	if not S.atkHas then
		if at >= 0.55 and not S.ev.miss then
			S.ev.miss = true
			sfx(SND.slash, 2, 0.55)
			S.shake = math.max(S.shake, 0.35)
		end
		return
	end
	local rec = S.victim
	if not rec or not rec.model.Parent then return end
	local hang = math.clamp(rec.size.Y * 0.48, 1.4, S.height * 0.42)
	local hand = S.handWorld[S.grabSide]
	local faceRot = CFrame.lookAt(Vector3.zero, -S.flat).Rotation   -- the victim faces the monster
	local GRAB, SLAP, RELEASE, FLIGHT = 0.60, 2.28, 3.14, 1.15

	-- While held, the victim hangs from the grabbing hand and swings like a heavy ragdoll.
	local function held(struggle)
		local limp = at >= SLAP and 0.55 or 0
		local sway = CFrame.Angles(
			0.14 + limp + math.sin(at * 3.1) * 0.10 * struggle,
			math.sin(at * 2.3) * 0.12 * struggle,
			math.sin(at * 2.7) * 0.10 * struggle)
		local pos = hand - UP * hang * 0.50
		if at >= SLAP then
			-- the palm strike knocks the body away from the face, then it settles back
			pos += S.flat * 1.6 * (1 - smooth((at - SLAP) / 0.35)) * smooth((at - SLAP) / 0.04)
		end
		return CFrame.new(pos) * faceRot * sway
	end

	if at < GRAB then
		-- the victim is still free and struggles while the monster winds up
		local shake = math.clamp((at - 0.25) / 0.3, 0, 1)
		vSet(rec, rec.origCF * CFrame.new(math.sin(at * 41) * 0.18 * shake, 0, 0))
	elseif at < RELEASE then
		if not S.ev.grab then
			S.ev.grab = true
			sfx(SND.hit, 3.2, 0.65)
			sfx(SND.splat, 2.2, 0.85)
			S.shake = math.max(S.shake, 1.0)
			carnage(hand, UP, 14, {spread = 1.2, vmin = 8, vmax = 24, smin = 0.3, smax = 0.85, bone = 0, flesh = 0.12})
		end
		if at >= 1.30 and not S.ev.lift then
			S.ev.lift = true
			sfx(SND.growl, 1.8, 0.4)
		end
		if at >= SLAP - 0.01 and not S.ev.slap then
			S.ev.slap = true
			slapFX(vPos(rec))
			-- local kill at palm impact; the body stays visible for the throw
			tryRealKill(rec)
			rec.state = "dead"
			rec.respawnAt = os.clock() + CONFIG.RESPAWN_DELAY
			S.consumed += 1
		end
		if at >= 3.00 and not S.ev.charge then
			S.ev.charge = true
			sfx(SND.whoosh, 2.2, 0.35)
		end
		-- snap from the ground into the hand over 0.18s, then follow the hand exactly
		local k = smooth((at - GRAB) / 0.18)
		local struggle = at < SLAP and (1.0 - 0.5 * smooth((at - 1.2) / 0.6)) or 0.35
		local target = held(struggle)
		vSet(rec, rec.origCF:Lerp(target, k))
		S.ev.lastHand = target.Position
		if t > S.nextVDrip then
			S.nextVDrip = t + (at >= SLAP and 0.04 or 0.09)
			local p = target.Position
			piece("blood", p + Vector3.new(rnd(-0.5, 0.5), rnd(-0.8, 0.3), rnd(-0.5, 0.5)),
				Vector3.new(rnd(-2, 2), rnd(-3, 0), rnd(-2, 2)), rnd(0.18, 0.45))
		end
	else
		if not S.ev.thrown then
			S.ev.thrown = true
			local from = S.ev.lastHand or vPos(rec)
			local flatDir = S.flat
			local to = S.hrp.Position + flatDir * CONFIG.THROW_DIST
			local g = groundAt(to, 60, 140)
			to = Vector3.new(to.X, (g and g.Position.Y or from.Y - 8) + 1.5, to.Z)
			S.ev.throwFrom, S.ev.throwTo = from, to
			S.ev.apex = math.clamp((to - from).Magnitude * 0.20, 12, 34)
			sfx(SND.whoosh, 3.2, 0.42)
			S.shake = math.max(S.shake, 1.4)
		end
		local s = clamp01((at - RELEASE) / FLIGHT)
		if not S.ev.landed then
			if s >= 1 then
				S.ev.landed = true
				throwLandFX(S.ev.throwTo, rec)
			else
				-- ballistic arc: constant forward speed, parabolic height, forward tumble
				local from, to = S.ev.throwFrom, S.ev.throwTo
				local pos = from + (to - from) * s + UP * (S.ev.apex * 4 * s * (1 - s))
				local right = S.flat:Cross(UP).Unit
				vSet(rec, CFrame.new(pos) * CFrame.fromAxisAngle(right, -s * math.pi * 3.5) * faceRot)
			end
		else
			vSet(rec, CFrame.new(S.ev.throwTo - Vector3.new(0, 1, 0)))
		end
	end
end

local function updateKick(at)
	-- Foot reaches full extension at 0.50. Capture only at impact so the target is free during wind-up.
	if at >= 0.48 and not S.ev.kickHit then
		S.ev.kickHit = true
		local target = S.ev.kickTarget
		local rec = target and validTarget(target) and capture(target) or nil
		S.victim, S.atkHas = rec, rec ~= nil
		if rec then
			local from = vPos(rec)
			local to = from + S.flat * CONFIG.KICK_DIST + UP * 3
			local g = groundAt(to, 55, 130)
			if g then to = Vector3.new(to.X, g.Position.Y + math.max(1.5, rec.size.Y * 0.2), to.Z) end
			S.ev.kickFrom, S.ev.kickTo = from, to
			S.ev.kickApex = math.clamp((to - from).Magnitude * 0.16, 14, 30)
			kickHitFX(from)
		else
			sfx(SND.whoosh, 2.2, 0.48)
		end
	end
	local rec = S.victim
	if rec and rec.model.Parent and S.ev.kickFrom then
		local k = clamp01((at - 0.48) / 1.08)
		if k < 1 then
			local from, to = S.ev.kickFrom, S.ev.kickTo
			local pos = from + (to - from) * k + UP * (S.ev.kickApex * 4 * k * (1 - k))
			local axis = S.flat:Cross(UP).Unit
			vSet(rec, CFrame.new(pos) * CFrame.fromAxisAngle(axis, -k * math.pi * 4))
		else
			-- No death: restore collisions/visibility at the landing point and leave a final shove.
			vSet(rec, CFrame.new(S.ev.kickTo))
			restoreVictim(rec, false)
			pcall(function()
				rec.root.AssemblyLinearVelocity = S.flat * 45 + UP * 8
			end)
			S.victim = nil
		end
	end
end

local function updateSlam(at)
	if at >= 0.6 and not S.ev.swing then S.ev.swing = true sfx(SND.whoosh, 3, 0.42) end
	if at >= 0.78 and not S.ev.hit then
		S.ev.hit = true
		local center = S.hrp.Position + S.flat * (CONFIG.SLAM_RANGE * 0.55)
		local target = findTarget(CONFIG.SLAM_RANGE * 0.7, center)
		local rec = target and capture(target)
		if rec then
			S.atkHas = true
			slamHitFX(rec, vPos(rec))
		else
			sfx(SND.slash, 2.5, 0.45)
			S.shake = math.max(S.shake, 0.35)
		end
	end
end

local function updateLunge(at)
	if at >= 0.16 and not S.ev.dash then
		S.ev.dash = true
		local hrp = S.hrp
		if hrp then hrp.AssemblyLinearVelocity = Vector3.new(S.flat.X * 68, hrp.AssemblyLinearVelocity.Y, S.flat.Z * 68) end
		sfx(SND.whoosh, 2.4, 0.4)
	end
	if at >= 0.26 and not S.ev.hit then
		S.ev.hit = true
		sfx(SND.slash, 2.3, rnd(0.8, 1.0))
		sfx(SND.splat, 1.8, rnd(0.7, 0.9))
		S.shake = math.max(S.shake, 0.55)
		local target = findTarget(11, S.hrp.Position + S.flat * 4)
		local rec = target and capture(target)
		if rec then
			S.atkHas = true
			local p = vPos(rec)
			carnage(p, S.flat, 26, {vmin = 16, vmax = 48, smin = 0.3, smax = 0.8})
			arterial(function() return p end, UP, 0.4, 0.05)
			if dealDamage(rec, 55) then
				dismember(rec, p, S.flat, 60)
			else
				restoreVictim(rec, true)
			end
		end
	end
end

local function updateCleave(at)
	local spec = {t1 = 0.22, t2 = 0.52}
	if S.combo == 3 then spec.t1, spec.t2 = 0.24, 0.52 end
	local function strikeOnce(time)
		if at >= time and not S.ev["s" .. time] then
			S.ev["s" .. time] = true
			sfx(SND.slash, 2.2, rnd(0.85, 1.15))
			sfx(SND.splat, 1.6, rnd(0.85, 1.05))
			S.shake = math.max(S.shake, 0.42)
			local list = {}
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Exclude
			op.FilterDescendantsInstances = {fxFolder, S.character}
			local center = S.hrp.Position + S.flat * 5
			local seen = {}
			for _, part in ipairs(workspace:GetPartBoundsInRadius(center, 9.5, op)) do
				local m = candidateFromPart(part)
				if m and not seen[m] then
					seen[m] = true
					local r = validTarget(m)
					if r then
						list[#list + 1] = m
						if #list >= 3 then break end
					end
				end
			end
			for _, m in ipairs(list) do
				local rec = capture(m)
				if rec then
					local loss = S.combo == 3 and 65 or (S.combo == 2 and 42 or 30)
					local p = vPos(rec)
					if dealDamage(rec, loss) then
						dismember(rec, p, S.flat, 55)
						carnage(p, (S.flat + UP * 0.2).Unit, 40, {vmin = 20, vmax = 60})
					else
						carnage(p, S.flat, 16, {vmin = 12, vmax = 34, smin = 0.25, smax = 0.7})
						arterial(function() return p end, UP, 0.35, 0.05)
						restoreVictim(rec, true)
					end
				end
			end
		end
	end
	strikeOnce(spec.t1)
	if S.combo == 3 then strikeOnce(spec.t2) end
end

local function updateRoar(at)
	if at >= 0.58 and not S.ev.shock then
		S.ev.shock = true
		local center = S.hrp.Position
		roarFX(center)
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.FilterDescendantsInstances = {fxFolder, S.character}
		local seen = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(center + UP * 2, CONFIG.ROAR_RANGE, op)) do
			local m = candidateFromPart(part)
			if m and not seen[m] then
				seen[m] = true
				if validTarget(m) then
					local rec = capture(m)
					if rec then
						local p = vPos(rec)
						carnage(p, UP, 10, {vmin = 10, vmax = 26, smin = 0.25, smax = 0.6})
						if dealDamage(rec, 18) then
							dismember(rec, p, UP, 45)
						else
							restoreVictim(rec, true)
						end
					end
				end
			end
		end
	end
end

--====================================================================--
-- UNDERGROUND                                                        --
--====================================================================--
local mound = Instance.new("Part")
mound.Size = Vector3.new(8, 2.5, 8)
mound.Anchored, mound.CanCollide, mound.CanQuery, mound.CanTouch = true, false, false, false
mound.Material = Enum.Material.Ground
mound.Color = Color3.fromRGB(42, 24, 20)
mound.Transparency = 1
do local sm = Instance.new("SpecialMesh") sm.MeshType = Enum.MeshType.Sphere sm.Parent = mound end
mound.Parent = fxFolder

goUnder = function()
	if not S.mounted or S.restPose or S.underground or S.atk or os.clock() < S.fLock then return end
	S.underground = true
	S.fLock = os.clock() + 0.85
	if S.sinkTween then S.sinkTween:Cancel() end
	S.sinkTween = tw(sinkValue, 0.72, {Value = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local feet = S.hrp.Position - Vector3.new(0, feetOffset(), 0)
	for _ = 1, math.floor(30 * CONFIG.GORE) do piece("dirt", feet + UP, coneDir(UP, 0.8) * rnd(18, 45), rnd(0.4, 1)) end
	carnage(feet + UP, UP, 25, {spread = 0.7, vmin = 18, vmax = 45, bone = 0, flesh = 0.1})
	ring(feet, UP, 14, CONFIG.NEON_C, 0.5)
	sfx(SND.splat, 3, 0.5)
end

surface = function()
	if not S.underground then return end
	S.underground = false
	S.fLock = os.clock() + 0.85
	if S.sinkTween then S.sinkTween:Cancel() end
	S.sinkTween = tw(sinkValue, 0.36, {Value = 0}, Enum.EasingStyle.Quad)
	local feet = S.hrp.Position - Vector3.new(0, feetOffset(), 0)
	for _ = 1, math.floor(35 * CONFIG.GORE) do piece("dirt", feet + UP, coneDir(UP, 0.8) * rnd(22, 55), rnd(0.4, 1.1)) end
	carnage(feet + UP, UP, 40, {spread = 0.8, vmin = 25, vmax = 65, bone = 0.05, flesh = 0.15})
	mist(feet + UP * 3, 45, 9)
	ring(feet, UP, 22, CONFIG.NEON_A, 0.6)
	S.shake = 1.5
	sfx(SND.hit, 3, 0.5)
	sfx(SND.growl, 3, 0.3)
	local p = S.pending
	S.pending = nil
	if p then
		task.delay(0.45, function()
			S.atkLock = 0
			if p == "devour" then startDevour()
			elseif p == "execute" then startExecute()
			elseif p == "kick" then startKick()
			elseif p == "lunge" then startLunge()
			else startSlam() end
		end)
	end
end

--====================================================================--
-- ANIMATION STEP                                                     --
--====================================================================--
-- Giant footstep: a deep layered thud, a puff of dust and a small ground-shake.
-- Walking is slow and heavy, running is faster, louder and shakes the camera more.
local function stepSfxAt(pos, id, volume, pitch, maxDistance)
	local a = anchorPart(pos)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = math.clamp(volume, 0, 10)
	sound.PlaybackSpeed = pitch
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 18
	sound.RollOffMaxDistance = maxDistance or 210
	sound.EmitterSize = 22
	sound.Parent = a
	pcall(function() sound:Play() end)
	Debris:AddItem(a, 7)
end

function Rig.giantStep(footName, frames)
	local run = S.runBlend
	local foot = frames and frames[footName]
	local from = foot and foot.Position or S.hrp.Position
	local g = groundAt(from, 4, S.height)
	local gp = g and g.Position or (S.hrp.Position - Vector3.new(0, feetOffset(), 0))
	local vol = lerp(6.5, 9.0, run)
	-- Spatial layers are emitted at the actual foot instead of the hidden player root.
	stepSfxAt(gp, SND.land, vol, rnd(0.40, 0.48) + run * 0.05, 260)
	stepSfxAt(gp, SND.hit, vol * 0.82, rnd(0.30, 0.37) + run * 0.04, 220)
	stepSfxAt(gp, SND.crunch, vol * 0.65, rnd(0.38, 0.46), 175)
	if run > 0.5 then
		stepSfxAt(gp, SND.splat, 5.0, rnd(0.28, 0.34), 230)
	end
	S.shake = math.max(S.shake, lerp(0.10, 0.20, run))
	mist(gp + UP * 0.4, math.floor(lerp(3, 7, run)), lerp(3.2, 4.6, run), Color3.fromRGB(105, 98, 90))
end

local function step(dt)
	local hum, hrp = S.humanoid, S.hrp
	if not (S.mounted and hum and hrp and hrp.Parent) then return end
	local t = os.clock()
	local v = hrp.AssemblyLinearVelocity
	local spd = Vector3.new(v.X, 0, v.Z).Magnitude
	S.walk += (((spd > 1.5) and 1 or 0) - S.walk) * math.min(1, dt * 8)
	local lk = hrp.CFrame.LookVector
	local fl = Vector3.new(lk.X, 0, lk.Z)
	if fl.Magnitude > 0.01 then S.flat = fl.Unit end
	local feet = hrp.Position - Vector3.new(0, feetOffset(), 0)
	local base = CFrame.lookAt(feet, feet + S.flat)

	local targetPose
	if S.underground and not S.atk then
		targetPose = idlePose(t, S.walk, "idle")
	else
		targetPose = movingPose(t, spd, dt)
	end
	if S.atk then
		local at = t - S.atkStart
		local clip
		if S.atk == "devour" then clip = Clips.Devour
		elseif S.atk == "slam" then clip = Clips.Slam
		elseif S.atk == "lunge" then clip = Clips.Lunge
		elseif S.atk == "spawn" then clip = Clips.Spawn
		elseif S.atk == "execute" then clip = S.atkHas and Clips.Execute or Clips.ExecuteMiss
		elseif S.atk == "kick" then clip = Clips.Kick
		elseif S.atk == "cleave" then
			clip = (S.combo == 1 and Clips.Cleave1) or (S.combo == 2 and Clips.Cleave2) or Clips.Cleave3
		elseif S.atk == "roar" then clip = Clips.Roar
		elseif S.atk == "taunt" then clip = Clips.Taunt
		elseif S.atk == "flinch" then clip = Clips.Flinch
		elseif S.atk == "land" then clip = Clips.Land
		end
		if clip then targetPose = sampleClip(clip, at) end
		if S.atk == "execute" and S.atkHas and at >= 1.45 and at < 2.2 then
			-- tiny eye-line adjustments while studying the victim: deliberate, never frozen
			targetPose.Head = (targetPose.Head or IDENTITY)
				* CFrame.Angles(math.sin(at * 5.1) * 0.018, math.sin(at * 2.7) * 0.028, math.sin(at * 3.4) * 0.012)
		end
	end

	-- blend into / out of the prone crawl smoothly (the body sinks to the floor or stands back up)
	S.crawlBlend += ((S.mode == "crawl" and 1 or 0) - S.crawlBlend) * math.min(1, dt * 5)
	local poseRate = S.atk and 26 or ((S.mode == "crawl" or S.crawlBlend > 0.02) and 7 or 12)
	local alpha = 1 - math.exp(-dt * poseRate)
	for _, link in ipairs(CHAIN) do
		local name = link[1]
		local a = S.poseCur[name] or IDENTITY
		local b = targetPose[name] or IDENTITY
		S.poseCur[name] = a:Lerp(b, alpha)
		S.pose[name] = S.poseCur[name]
	end

	local sink = S.restPose and 0 or clamp01(sinkValue.Value)
	local hsF = S.height / 24
	local bodyCF = base
		* CFrame.new(0, -sink * (S.height + 3) - (S.restPose and 0 or smooth(S.crawlBlend) * S.crawlDrop), 0)
		* CFrame.new(0, (not S.restPose and S.atk == "devour" and 0.5 or 0) * hsF, 0)
		* CFrame.Angles((S.underground and -0.45 or 0) * sink, 0, 0)
		* S.yawCF
	local frames, renderError = Rig.Render(S.rig, bodyCF, S.restPose and {} or S.pose)
	if not frames then
		finishAttack()
		S.restPose, S.underground = true, false
		if S.sinkTween then S.sinkTween:Cancel() end
		sinkValue.Value = 0
		frames = Rig.Render(S.rig, base * S.yawCF, {})
		report("Animation paused safely: " .. tostring(renderError) .. ". H toggles bind pose.", true)
		if not frames then return end
	end
	local head = S.bones.Head
	local rhand = S.bones.Rhand
	local lhand = S.bones.Lhand
	local headFrame = head.bone and head.bone.TransformedWorldCFrame or frames.Head
	local rhandFrame = rhand.bone and rhand.bone.TransformedWorldCFrame or frames.Rhand
	local lhandFrame = lhand.bone and lhand.bone.TransformedWorldCFrame or frames.Lhand
	local mouthOffset = head.rest:VectorToObjectSpace(Vector3.new(0, -S.height * 0.012, -S.height * 0.035))
	S.mawWorld = headFrame * mouthOffset
	S.faceWorld = headFrame.Position
	S.clawWorld = rhandFrame.Position
	S.handWorld[1] = rhandFrame.Position
	S.handWorld[-1] = lhandFrame.Position

	-- Footsteps: one thud every time a foot lands (twice per stride), walking and running only.
	local stepIndex = math.floor(S.stepAcc * 2 + 0.5)
	local grounded = hum.FloorMaterial ~= Enum.Material.Air
	if S.mode ~= "crawl" and not S.atk and not S.underground and not S.restPose
		and S.speedS > 3 and grounded then
		if stepIndex > S.lastStep then
			S.lastStep = stepIndex
			-- the left foot lands at phase 0.25 (odd steps), the right foot at 0.75 (even steps)
			Rig.giantStep(stepIndex % 2 == 1 and "Lfoot" or "Rfoot", frames)
		end
	else
		S.lastStep = stepIndex   -- stay in sync so there is no burst of thuds when we start walking again
	end

	if S.atk then
		local at = t - S.atkStart
		if S.atk == "devour" then updateDevour(at, t)
		elseif S.atk == "slam" then updateSlam(at)
		elseif S.atk == "lunge" then updateLunge(at)
		elseif S.atk == "cleave" then updateCleave(at)
		elseif S.atk == "roar" then updateRoar(at)
		elseif S.atk == "execute" then updateExecute(at, t)
		elseif S.atk == "kick" then updateKick(at)
		end
		if at >= S.atkDur then finishAttack() end
	end

	S.shake *= math.exp(-dt * 4)
	if S.shake < 0.01 then S.shake = 0 end
	-- the camera sits lower while crawling so you see the world from the floor
	local camBase = S.camBase * (1 - 0.6 * smooth(S.crawlBlend))
	-- a tiny footstep rumble while sprinting (scales with actual speed, dies out on stop)
	local runShake = S.runBlend * math.min(1, S.speedS / CONFIG.RUN_SPEED) * 0.10
	local wob = runShake > 0.005
		and Vector3.new(math.sin(t * 23) * runShake, math.abs(math.sin(t * 17)) * runShake * 1.6, 0)
		or Vector3.zero
	hum.CameraOffset = camBase + wob + Vector3.new(rnd(-1, 1) * S.shake, rnd(-1, 1) * S.shake, 0)
end

local function hideInst(d)
	if d:IsA("BasePart") or d:IsA("Decal") then
		if S.origTransp[d] == nil then S.origTransp[d] = d.Transparency end
		if d.Transparency ~= 1 then d.Transparency = 1 end
	end
end

local function bodySafePos(entry)
	local part = entry.part
	if part and part.Parent then return part.Position end
	return S.mawWorld
end

local function heart(dt)
	local hum, hrp = S.humanoid, S.hrp
	if not (S.mounted and hum and hrp and hrp.Parent) then return end
	dt = dt or 0.016
	local t = os.clock()
	local mul = 1
	if S.atk == "devour" and S.atkHas then mul = 0
	elseif S.atk == "execute" and S.atkHas then mul = 0
	elseif S.atk then mul = 0.35 end
	local wanted = (S.underground and CONFIG.RUN_SPEED or (S.mode == "crawl" and CONFIG.CRAWL_SPEED or (S.sprinting and CONFIG.RUN_SPEED or CONFIG.WALK_SPEED))) * mul
	if mul == 0 then
		hum.WalkSpeed = 0
	else
		-- accelerate quickly but smoothly, brake a little faster than we accelerate
		local rate = wanted > hum.WalkSpeed and 6 or 9
		hum.WalkSpeed = hum.WalkSpeed + (wanted - hum.WalkSpeed) * math.min(1, dt * rate)
		if math.abs(wanted - hum.WalkSpeed) < 0.15 then hum.WalkSpeed = wanted end
	end
	if S.underground ~= S.jumpLocked then
		S.jumpLocked = S.underground
		hum.JumpPower = S.underground and 0 or (S.origJump or 50)
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, not S.underground and S.origJumpEnabled ~= false)
	end
	if t > S.nextHide then
		S.nextHide = t + 0.45
		for _, d in ipairs(S.character:GetDescendants()) do hideInst(d) end
	end
	-- Rare, random, distant scream: layered low-pitched cries with a small camera jolt.
	if not S.underground and not S.restPose then
		if (S.nextScream or 0) == 0 then S.nextScream = t + rnd(CONFIG.SCREAM_MIN, CONFIG.SCREAM_MAX) end
		if t > S.nextScream then
			S.nextScream = t + rnd(CONFIG.SCREAM_MIN, CONFIG.SCREAM_MAX)
			sfx(SND.growl, 4, rnd(0.16, 0.24))
			sfx(SND.roar, 2.6, rnd(0.28, 0.42))
			task.delay(0.12, function() if S.mounted then sfx(SND.growl, 2.2, rnd(0.30, 0.40)) end end)
			S.shake = math.max(S.shake, 0.55)
		end
	end
	if S.underground then
		if sinkValue.Value > 0.55 then
			mound.Transparency = 0
			mound.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - feetOffset() + math.sin(t * 9) * 0.1, hrp.Position.Z)
		end
		local pos = hrp.Position
		if not S.lastTrail or (pos - S.lastTrail).Magnitude > 2.5 then
			S.lastTrail = pos
			local g = groundAt(pos, 0, feetOffset() + 6)
			if g then
				puddle(g.Position, g.Normal, rnd(1, 2), 10, true)
				piece("dirt", g.Position + UP, Vector3.new(rnd(-6, 6), rnd(12, 22), rnd(-6, 6)), rnd(0.3, 0.8))
			end
		end
	elseif mound.Transparency < 1 then
		mound.Transparency = 1
	end
	-- G is deliberately clean: no dust, smoke, puddles, gore or other particles while crawling.
	if S.mode ~= "crawl" and t < S.drool and t > S.nextDrip then
		S.nextDrip = t + 0.08
		local d = S.dripEntries[rng:NextInteger(1, math.max(1, #S.dripEntries))]
		if d then piece("blood", bodySafePos(d), Vector3.new(rnd(-1, 1), -2, rnd(-1, 1)), rnd(0.18, 0.4)) end
	end
end

--====================================================================--
-- MOUNT / UNMOUNT                                                    --
--====================================================================--
local savedLighting
mount = function()
	if S.mounted or S.busy then return end
	S.busy = true
	local tpl = loadTemplate()
	local model = tpl:Clone()
	local entries, parts, h, rig = buildEntries(model)
	if not entries then
		S.busy = false
		model:Destroy()
		report("MODEL BUILD FAILED: " .. tostring(rig), true)
		return
	end
	local clipsValid, clipError = Rig.CheckClips(rig)
	if not clipsValid then
		S.busy = false
		model:Destroy()
		report("ANIMATION CHECK FAILED: " .. tostring(clipError), true)
		return
	end
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:WaitForChild("Humanoid", 10)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if not (hum and hrp) then
		S.busy = false
		model:Destroy()
		report("Character missing Humanoid/HumanoidRootPart.", true)
		return
	end

	local pl = Instance.new("PointLight")
	pl.Color, pl.Range, pl.Brightness = CONFIG.NEON_A, 30, 1.7
	pl.Parent = rig.nodes.Spine.part or rig.parts[1]

	S.character, S.humanoid, S.hrp = char, hum, hrp
	S.entries, S.parts, S.height, S.model, S.cfs = entries, parts, h, model, {}
	S.rig, S.restPose, S.phase = rig, false, 0
	S.unit = h / 24
	S.origWalk, S.origJump, S.origDisplay = hum.WalkSpeed, hum.JumpPower, hum.DisplayDistanceType
	S.origCameraOffset = hum.CameraOffset
	S.origJumpEnabled = hum:GetStateEnabled(Enum.HumanoidStateType.Jumping)
	S.origMin, S.origMax = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
	S.underground, S.atk, S.jumpLocked, S.mode, S.consumed = false, nil, false, "idle", 0
	S.crawlBlend, S.runBlend, S.speedS, S.nextScream = 0, 0, 0, 0
	S.stepAcc, S.lastStep = 0, 0
	S.lastTrail, S.drool, S.nextDrip, S.nextVDrip = nil, 0, 0, 0
	refreshFilter()
	analyze()
	for _, d in ipairs(char:GetDescendants()) do hideInst(d) end
	mtrack(char.DescendantAdded:Connect(function(d) task.defer(hideInst, d) end))
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	S.camBase = Vector3.new(0, math.max(0, (h - 5) * 0.42), 0)
	pcall(function()
		player.CameraMinZoomDistance = h * 0.6
		player.CameraMaxZoomDistance = math.max(S.origMax, h * 3.2)
	end)

	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "GuiltTint"
	tint.TintColor = Color3.fromRGB(255, 228, 222)
	tint.Saturation = -0.18
	tint.Contrast = 0.14
	tint.Parent = Lighting
	savedLighting = {Ambient = Lighting.Ambient, FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd}
	Lighting.Ambient = Lighting.Ambient:Lerp(Color3.fromRGB(52, 0, 8), 0.55)
	Lighting.FogColor = Color3.fromRGB(18, 0, 4)
	Lighting.FogEnd = math.min(Lighting.FogEnd, 620)

	sinkValue.Value = 1
	model.Name = "GuiltMorph_v52"
	model.Parent = fxFolder
	S.mounted = true
	step(0.016)
	local function safeMorphFrame(callback)
		return function(...)
			if not S.mounted then return end
			local ok, err = xpcall(callback, debug.traceback, ...)
			if not ok then
				unmount()
				report("Morph stopped safely: " .. tostring(err), true)
			end
		end
	end
	mtrack(RunService.RenderStepped:Connect(safeMorphFrame(step)))
	mtrack(RunService.Heartbeat:Connect(safeMorphFrame(heart)))
	mtrack(hum.Died:Connect(function() if S.atk then finishAttack() end end))
	local lastHealth = hum.Health
	mtrack(hum.HealthChanged:Connect(function(health)
		if S.mounted and not S.restPose and not S.atk and health < lastHealth then
			S.atk, S.atkStart, S.atkDur, S.ev = "flinch", os.clock(), 0.38, {}
		end
		lastHealth = health
	end))
	mtrack(hum.StateChanged:Connect(function(old, newState)
		if S.mounted and not S.restPose and not S.atk and old == Enum.HumanoidStateType.Freefall
			and newState == Enum.HumanoidStateType.Landed then
			S.atk, S.atkStart, S.atkDur, S.ev = "land", os.clock(), 0.33, {}
		end
	end))

	if S.sinkTween then S.sinkTween:Cancel() end
	S.sinkTween = tw(sinkValue, 0.95, {Value = 0}, Enum.EasingStyle.Quad)
	S.atk, S.atkStart, S.atkDur, S.atkHas, S.ev = "spawn", os.clock(), 1.7, false, {}
	task.delay(0.25, function()
		if not S.mounted or S.restPose then return end
		local feet = hrp.Position - Vector3.new(0, feetOffset(), 0)
		carnage(feet + UP, UP, 70, {spread = 0.85, vmin = 30, vmax = 85})
		for _ = 1, 30 do piece("dirt", feet + UP, coneDir(UP, 0.9) * rnd(20, 55), rnd(0.4, 1.1)) end
		mist(feet + UP * 3, 60, 11)
		ring(feet, UP, 26, CONFIG.NEON_A, 0.7)
		ring(feet, UP, 18, CONFIG.NEON_C, 0.6)
		lightFlash(feet + UP * 4, CONFIG.NEON_A, 8, 40, 0.8)
		puddle(feet, UP, 9, 40, false)
		fissure(feet, UP)
		S.shake = 2.2
		impactTint(0.8)
		sfx(SND.growl, 3, 0.28)
		sfx(SND.hit, 3, 0.5)
		sfx(SND.roar, 1.6, 0.8)
	end)
	S.busy = false
	report("RIG OK / " .. rig.checkDetail .. " / " .. rig.clipSamples .. " clips. F=EXECUTE G=CRAWL PLAYERS+NPC")
end

unmount = function()
	if not S.mounted then return end
	if S.atk then finishAttack() end
	S.mounted = false
	for _, c in ipairs(morphConns) do pcall(function() c:Disconnect() end) end
	morphConns = {}
	for inst, v in pairs(S.origTransp) do
		pcall(function() if inst.Parent then inst.Transparency = v end end)
	end
	S.origTransp = setmetatable({}, {__mode = "k"})
	local hum = S.humanoid
	if hum and hum.Parent then
		pcall(function()
			hum.WalkSpeed = S.origWalk or 16
			hum.JumpPower = S.origJump or 50
			hum.CameraOffset = S.origCameraOffset or Vector3.zero
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, S.origJumpEnabled ~= false)
			hum.DisplayDistanceType = S.origDisplay or Enum.HumanoidDisplayDistanceType.Viewer
		end)
	end
	pcall(function()
		player.CameraMinZoomDistance = S.origMin or 0.5
		player.CameraMaxZoomDistance = S.origMax or 128
	end)
	if S.model then S.model:Destroy() S.model = nil end
	S.rig = nil
	if S.sinkTween then S.sinkTween:Cancel() S.sinkTween = nil end
	if tint then tint:Destroy() tint = nil end
	if savedLighting then
		for k, v in pairs(savedLighting) do pcall(function() Lighting[k] = v end) end
		savedLighting = nil
	end
	mound.Transparency = 1
	S.underground = false
	S.restPose, S.sprinting = false, false
	sinkValue.Value = 0
	report("MORPH RESET. Original character restored.")
end

local mountCore = mount
mount = function()
	local ok, err = xpcall(mountCore, debug.traceback)
	if not ok then
		S.busy = false
		if S.mounted then unmount() end
		report("Mount error: " .. tostring(err), true)
	end
end

gtrack(player.CharacterAdded:Connect(function()
	if S.mounted then
		unmount()
		task.wait(0.6)
		task.spawn(mount)
	end
end))

--====================================================================--
-- VIEWPORT + HUD UPDATE                                              --
--====================================================================--
gtrack(RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	if menuRoot.Visible then
		pGrad.Rotation = (t * 62) % 360
		vRingStroke.Transparency = 0.42 + math.sin(t * 3) * 0.22
		vRing.Rotation = (t * 16) % 360
		vGlow.BackgroundTransparency = 0.82 + math.sin(t * 2.1) * 0.06
		for _, e in ipairs(embers) do
			e.y -= e.s * dt
			if e.y < -0.05 then e.y, e.x = 1.05, math.random() end
			e.f.Position = UDim2.fromScale(e.x + math.sin(t * 1.4 + e.w) * 0.012, e.y)
			e.f.BackgroundTransparency = 0.22 + math.sin(t * 4 + e.w) * 0.32
		end
		if vpModel then
			local h = vpH
			local yaw = math.rad(((S.fallback and 0 or CONFIG.MODEL_YAW) + S.flip) % 360)
			Rig.Render(vpRig, CFrame.new(0, math.sin(t * 1.25) * h * 0.005, 0)
				* CFrame.Angles(0, yaw + math.sin(t * 0.36) * 0.3, 0), idlePose(t, 0, "idle"))
			local dist = h * 2.05 + math.sin(t * 0.5) * h * 0.05
			vcam.CFrame = CFrame.lookAt(Vector3.new(0, h * 0.44, -dist), Vector3.new(0, h * 0.52, 0))
		end
		if statLabels.HEIGHT then statLabels.HEIGHT.Text = tostring(math.floor((S.mounted and S.height or vpH or CONFIG.TARGET_HEIGHT) + 0.5)) end
		if statLabels.SPEED then
			statLabels.SPEED.Text = tostring(S.underground and CONFIG.RUN_SPEED
				or (S.mode == "crawl" and CONFIG.CRAWL_SPEED or CONFIG.WALK_SPEED))
		end
		if statLabels.STATE then
			statLabels.STATE.Text = S.mounted and (S.restPose and "BIND POSE" or (S.underground and "BURROWED" or (S.mode == "crawl" and "CRAWL" or (S.atk and string.upper(S.atk) or "MORPHED")))) or "STANDBY"
		end
	end
	if reopen.Visible then
		rGrad.Rotation = (t * 118) % 360
	end
end))
gtrack(RunService.Heartbeat:Connect(checkRespawns))

--====================================================================--
-- INPUT                                                              --
--====================================================================--
gtrack(UserInputService.InputBegan:Connect(function(input, gp)
	if UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == CONFIG.MENU_KEY then
		if menuOpen then closeMenu() else openMenu() end
		return
	end
	if input.KeyCode == CONFIG.LOAD_KEY then
		if player.Character then task.spawn(mount) end
		return
	end
	if input.KeyCode == CONFIG.STOP_KEY then
		if genv.__GUILT_V5 then genv.__GUILT_V5() end
		return
	end
	if input.KeyCode == Enum.KeyCode.H and S.mounted then
		finishAttack()
		S.restPose = not S.restPose
		S.underground, S.mode = false, "idle"
		if S.sinkTween then S.sinkTween:Cancel() end
		sinkValue.Value = 0
		S.pose, S.poseCur, S.shake = {}, {}, 0
		step(0)
		report(S.restPose and "BIND POSE ON. H resumes." or "ANIMATION RESUMED / " .. S.rig.checkDetail)
		return
	end
	if gp or menuOpen or not introDone then return end
	if input.KeyCode == Enum.KeyCode.Q then
		startCleave()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		startCleave()
	elseif input.KeyCode == Enum.KeyCode.E then
		startLunge()
	elseif input.KeyCode == Enum.KeyCode.Z then
		startSlam()
	elseif input.KeyCode == Enum.KeyCode.R then
		startDevour()
	elseif input.KeyCode == Enum.KeyCode.F then
		startExecute() -- F = EXECUTE (grab→stare→slap→throw)
	elseif input.KeyCode == Enum.KeyCode.B then
		startKick() -- B = heavy kick, launches without killing
	elseif input.KeyCode == Enum.KeyCode.X then
		startRoar() -- roar moved to X
	elseif input.KeyCode == Enum.KeyCode.C then
		if S.underground then surface() else goUnder() end
	elseif input.KeyCode == Enum.KeyCode.G then
		S.mode = (S.mode == "crawl") and "idle" or "crawl"
		if S.mode == "crawl" then
			S.drool, S.nextDrip, S.lastTrail = 0, 0, nil
			sfx(SND.splat, 1.4, 0.55)
			report("CRAWL MODE. Prone movement enabled.")
		else
			report("STANDING. Crawl mode disabled.")
		end
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.LeftControl then
		S.sprinting = true
	elseif input.KeyCode == Enum.KeyCode.V and S.mounted and not S.restPose and not S.atk then
		S.atk, S.atkStart, S.atkDur, S.atkHas, S.ev = "taunt", os.clock(), 1.7, false, {}
		S.atkLock = os.clock() + 2.4
		sfx(SND.growl, 1.6, 0.42)
	elseif input.KeyCode == Enum.KeyCode.T then
		local hrp = S.hrp or (player.Character and getRoot(player.Character))
		if hrp then
			local pos = hrp.Position + S.flat * 8
			local g = groundAt(pos, 6, 30)
			local m = Instance.new("Model")
			m.Name = "GuiltDummy"
			local position = g and (g.Position + UP * 3) or pos
			local function makePart(name, size, offset)
				local part = Instance.new("Part")
				part.Name, part.Size = name, size
				part.CFrame = CFrame.new(position + offset)
				part.Anchored = true
				part.CanCollide = false
				part.Color = Color3.fromRGB(166, 160, 152)
				part.Parent = m
				return part
			end
			local r = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero)
			r.Transparency = 1
			makePart("Torso", Vector3.new(2, 2, 1), Vector3.zero)
			makePart("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0))
			makePart("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0))
			makePart("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0))
			makePart("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0))
			makePart("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0))
			local hum = Instance.new("Humanoid")
			hum.RequiresNeck = false
			hum.BreakJointsOnDeath = false
			hum.MaxHealth = 120
			hum.Health = 120
			hum.Parent = m
			m.PrimaryPart = r
			m.Parent = dummyFolder
			report("Local dummy spawned — test F EXECUTE on it.")
		end
	end
end))
gtrack(UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.LeftControl then
		S.sprinting = false
	end
end))
gtrack(UserInputService.WindowFocusReleased:Connect(function() S.sprinting = false end))

--====================================================================--
-- CLEANUP                                                            --
--====================================================================--
local function cleanup()
	unmount()
	for _, c in ipairs(globalConns) do pcall(function() c:Disconnect() end) end
	for _, rec in pairs(victims) do pcall(restoreVictim, rec, true) end
	pcall(function() gui:Destroy() end)
	pcall(function() fxFolder:Destroy() end)
	pcall(function() dummyFolder:Destroy() end)
	pcall(function() sinkValue:Destroy() end)
	if genv.__GUILT_V5 == cleanup then genv.__GUILT_V5 = nil end
end
genv.__GUILT_V5 = cleanup

task.spawn(loadTemplate)
task.spawn(function()
	local ok, err = pcall(playIntro, function()
		menuOpen = true
		menuRoot.Visible = true
		menuRoot.BackgroundTransparency = 0
		pScale.Scale = baseScale() * 0.9
		tw(pScale, 0.5, {Scale = baseScale()}, Enum.EasingStyle.Back)
	end)
	if not ok then
		warn("[Guilt] intro failed: " .. tostring(err))
		introDone = true
		menuRoot.Visible = true
	end
end)
