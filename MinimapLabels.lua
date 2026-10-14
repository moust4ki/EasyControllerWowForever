local _, CK = ...
local L = CK.L

---------------------------------------------------------------------------
-- Labels beside the minimap's dots (asked: a hunter's tracking fills the
-- minimap with dots only a mouse could name). Each dot's name written small
-- beside it: a creature in white with its level in the game's colours (an
-- option; once one of that name was seen up close), a quest's creature in
-- gold, a player in their class colour, an enemy player (PvP) in red, a herb
-- or an ore in the colours of your skill, the rest in white.
--
-- The game draws the dots itself and tells addons only the names under the
-- minimap's hover point (C_TooltipInfo.GetMinimapMouseover, what its own
-- tooltip shows). Forever's minimap can be told where that point is
-- (Minimap:UpdateMouseoverAtPoint, in screen pixels, made for the
-- controller's soft cursor; the way Improved Forever reads its gathering
-- nodes): a grid of points over the minimap read in one go, the points
-- reading one name side by side are one dot, their middle its place.
--
-- Read twice a second. In between, each label follows its dot from where
-- the player stands and faces. While the player moves the minimap answers
-- a moment late (its dots trail by the same vector): measured on the dots
-- already placed, taken off the new ones.
---------------------------------------------------------------------------
local ML = {}
CK.MinimapLabels = ML

ML.ICON = "Interface\\Icons\\Ability_Tracking"
local TOGGLE_BUTTON = "ControllerKeyboardMinimapLabels"
local SCAN_EVERY = 0.5
local STEP = 6           -- the points read, apart (minimap units)
local MERGE = 24         -- one name closer than this on the minimap: one label (x2)
local MATCH = 25         -- yards: the same dot from one reading to the next
local MOVED = 6          -- yards: a dot that moved by itself (a creature)
local STILL_AFTER = 1    -- seconds standing before the answers are taken as they are
local MIN_SIZE = 7
local MIN_WIDTH = 30     -- a label on several lines: never narrower

local function settings() return CK.db.settings.minimapLabels end
local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

function ML.Supported()
    return Minimap ~= nil and Minimap.UpdateMouseoverAtPoint ~= nil and C_TooltipInfo ~= nil
        and C_TooltipInfo.GetMinimapMouseover ~= nil
end

---------------------------------------------------------------------------
-- What a name is: a player (class), a creature (level), a herb or an ore
---------------------------------------------------------------------------
local players = {}       -- name -> class file ("HUNTER")
local creatures = {}     -- name -> { level, elite }
local enemies = {}       -- player's name -> true: an enemy (PvP), as seen up close
local known = 0

local function forget()
    players, creatures, enemies, known = {}, {}, {}, 0
end

-- A unit seen (a nameplate, the target, the mouse, the soft targets)
local function learn(unit)
    if not UnitExists(unit) then return end
    local name = UnitName(unit)
    if type(name) ~= "string" or secret(name) or name == "" then return end
    local isPlayer = UnitIsPlayer(unit)
    if secret(isPlayer) then return end
    known = known + 1
    -- (a long session: never more than a few hundred names kept)
    if known > 600 then forget() end
    if isPlayer then
        local _, class = UnitClass(unit)
        if type(class) == "string" and not secret(class) then players[name] = class end
        local enemy = UnitIsEnemy and UnitIsEnemy("player", unit)
        if not secret(enemy) then enemies[name] = enemy and true or nil end
        return
    end
    local level = UnitLevel(unit)
    if type(level) ~= "number" or secret(level) then return end
    local kind = UnitClassification and UnitClassification(unit)
    if secret(kind) then kind = nil end
    creatures[name] = { level = level, elite = kind == "elite" or kind == "rareelite" or kind == "worldboss" }
end
ML.Learn = learn

-- The group: always known
local function learnGroup()
    local raid = IsInRaid and IsInRaid()
    for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
        learn(raid and ("raid" .. i) or ("party" .. i))
    end
end

local function classColor(class)
    local c = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if c then return c.r, c.g, c.b end
end

-- A creature's level in the game's colours (its own function when there)
local function levelColor(level)
    local get = GetCreatureDifficultyColor or GetQuestDifficultyColor
    local c = get and get(level)
    if c and c.r then return c.r, c.g, c.b end
    local diff = (level < 0 and 99 or level) - (UnitLevel("player") or 1)
    if diff >= 5 then return 1, 0.1, 0.1 end
    if diff >= 3 then return 1, 0.5, 0.25 end
    if diff >= -2 then return 1, 1, 0 end
    if diff >= -8 then return 0.25, 0.75, 0.25 end
    return 0.5, 0.5, 0.5
end

-- Herbs and ore (MinimapNodes.lua): their names in the game's language
-- (compared without case, either apostrophe: the game writes both)
local nodes
local function nodeKey(name) return (name:lower():gsub("\226\128\153", "'")) end
local function nodeOf(name)
    if not nodes then
        nodes = {}
        local locale = GetLocale and GetLocale() or "enUS"
        if locale == "esMX" then locale = "esES" end
        for _, n in ipairs(CK.MINIMAP_NODES or {}) do
            for _, key in ipairs({ "enUS", locale }) do
                if n[key] then nodes[nodeKey(n[key])] = n end
            end
        end
    end
    return nodes[nodeKey(name)]
end

local SKILL_LINE = { herb = 182, ore = 186 }    -- Herbalism, Mining
local skills
local function skillOf(kind)
    if not skills then
        skills = {}
        for k, id in pairs(SKILL_LINE) do
            local info = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID and C_SkillInfo.GetSkillLineInfoByID(id)
            local rank = info and info.rank
            if type(rank) == "number" and not secret(rank) and rank > 0 then
                skills[k] = rank + (type(info.modifier) == "number" and not secret(info.modifier) and info.modifier or 0)
            end
        end
    end
    return skills[kind]
end

-- As the game colours a gathering: red can't, orange always a point,
-- yellow mostly, green rarely, grey never
ML.SKILL_COLORS = {
    red = { 1, 0.1, 0.1 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 },
    green = { 0.25, 0.75, 0.25 }, grey = { 0.5, 0.5, 0.5 },
}
function ML.SkillState(node)
    local skill = node and skillOf(node.kind)
    if not skill then return nil end
    if skill < node.skill then return "red" end
    if skill < node.skill + 25 then return "orange" end
    if skill < node.skill + 50 then return "yellow" end
    if skill < node.skill + 100 then return "green" end
    return "grey"
end

-- The quests in the log: their titles (a quest's area names them on the
-- minimap: never a label) and what their kill objectives name, not done yet
-- (read again when the log changes)
local quests
local function questLog()
    if quests then return quests end
    quests = { titles = {}, kill = "" }
    local QL = C_QuestLog
    if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo) then return quests end
    local kills = {}
    for i = 1, QL.GetNumQuestLogEntries() or 0 do
        local info = QL.GetInfo(i)
        if type(info) == "table" and not info.isHeader then
            if type(info.title) == "string" and not secret(info.title) then quests.titles[info.title] = true end
            local objectives = info.questID and QL.GetQuestObjectives and QL.GetQuestObjectives(info.questID)
            for _, o in ipairs(type(objectives) == "table" and objectives or {}) do
                if o.type == "monster" and not o.finished and type(o.text) == "string" and not secret(o.text) then
                    kills[#kills + 1] = o.text:lower()
                end
            end
        end
    end
    quests.kill = table.concat(kills, "\n")
    return quests
end

-- A creature a quest asks to kill (asked: shown apart)
function ML.QuestTarget(name)
    local kill = questLog().kill
    return kill ~= "" and kill:find(name:lower(), 1, true) ~= nil
end

local function hex(r, g, b)
    local function byte(v) return math.floor((v or 1) * 255 + 0.5) end
    return string.format("%02x%02x%02x", byte(r), byte(g), byte(b))
end
-- A quest's creatures: the game's quest colour; enemy players (PvP): red
local QUEST_COLOR = "ffd100"
local ENEMY_COLOR = "ff4040"

-- An enemy player (asked: PvP, not the hostile creatures), as seen up close
function ML.Enemy(name)
    return enemies[name] == true
end

-- A label's text, its colours in it: the name (a player's class, an enemy
-- player's red, a herb's or an ore's skill, gold for a quest's creature,
-- else white), then a creature's level in the game's colours (an option),
-- then how many
function ML.Describe(name, count)
    local color, level = "ffffff", nil
    local class = players[name]
    local creature = not class and creatures[name]
    if class then
        color = ML.Enemy(name) and ENEMY_COLOR or hex(classColor(class))
    elseif creature then
        if settings().level then
            level = creature.level < 0 and "??" or (creature.level .. (creature.elite and "+" or ""))
            level = "|cff" .. hex(levelColor(creature.level)) .. level .. "|r"
        end
    elseif settings().skill then
        local c = ML.SKILL_COLORS[ML.SkillState(nodeOf(name)) or ""]
        if c then color = hex(c[1], c[2], c[3]) end
    end
    if not class and ML.QuestTarget(name) then color = QUEST_COLOR end
    local text = "|cff" .. color .. name .. "|r"
    if level then text = text .. " " .. level end
    if count and count > 1 then text = text .. " x" .. count end
    return text
end

---------------------------------------------------------------------------
-- Reading the minimap
---------------------------------------------------------------------------
-- The points read: inside the circle, STEP apart, every other row shifted
-- half a step (no gap a dot can sit in). { x1, y1, x2, y2... } by radius
local grids = {}
local function gridFor(radius)
    local key = math.floor(radius)
    if grids[key] then return grids[key] end
    local grid, rowStep, r = {}, STEP * 0.866, key - 2
    local rows, n = math.floor(r / rowStep), math.floor(r / STEP) + 1
    for j = -rows, rows do
        local shift = (j % 2) * STEP / 2
        for i = -n, n do
            local x, y = i * STEP + shift, j * rowStep
            if x * x + y * y <= r * r then
                grid[#grid + 1] = x
                grid[#grid + 1] = y
            end
        end
    end
    grids[key] = grid
    return grid
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- A quest's area, not a dot (reported: "- Bog Crawler: 4/12 slain" over
-- the minimap): its title, its objectives ("- ...", "4/12")
local LINE_TYPE = Enum and Enum.TooltipDataLineType or {}
local QUEST_LINES = {
    [LINE_TYPE.QuestObjective or 8] = true, [LINE_TYPE.QuestTitle or 17] = true,
    [LINE_TYPE.QuestPlayer or 18] = true,
}
local function questLine(name)
    return name:find("^%-") ~= nil or name:find("%d+%s*/%s*%d+") ~= nil or questLog().titles[name] == true
end

-- The names a point reads into `out` (name -> how many dots of it: two of
-- one herb under the point list it twice). The player's own arrow and pet
-- left out
local function namesAt(sx, sy, skip, out)
    Minimap:UpdateMouseoverAtPoint(sx, sy)
    local data = C_TooltipInfo.GetMinimapMouseover()
    local lines = type(data) == "table" and data.lines
    if type(lines) ~= "table" then return end
    for _, line in ipairs(lines) do
        local text = line.leftText
        if type(text) == "string" and not secret(text) and not QUEST_LINES[line.type] then
            for piece in text:gmatch("[^\n]+") do
                local name = trim(piece:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
                    :gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1"))
                if name ~= "" and not skip[name] and not questLine(name) then out[name] = (out[name] or 0) + 1 end
            end
        end
    end
end

-- The points reading one name side by side: one dot, at their middle
local function group(hits)
    local near = (STEP * 1.6) ^ 2
    local groups = {}
    for _, hit in ipairs(hits) do
        local home
        for gi = #groups, 1, -1 do
            local g = groups[gi]
            if g.name == hit.name then
                local touches = false
                for _, other in ipairs(g) do
                    if (other.x - hit.x) ^ 2 + (other.y - hit.y) ^ 2 <= near then
                        touches = true
                        break
                    end
                end
                if touches then
                    -- Two groups it touches: one
                    if home then
                        for _, other in ipairs(g) do home[#home + 1] = other end
                        home.count = math.max(home.count, g.count)
                        table.remove(groups, gi)
                    else
                        home = g
                    end
                end
            end
        end
        if not home then
            home = { name = hit.name, count = 0 }
            groups[#groups + 1] = home
        end
        home[#home + 1] = hit
        home.count = math.max(home.count, hit.count)
    end
    local dots = {}
    for _, g in ipairs(groups) do
        local x, y = 0, 0
        for _, hit in ipairs(g) do x, y = x + hit.x, y + hit.y end
        dots[#dots + 1] = { name = g.name, count = g.count, x = x / #g, y = y / #g }
    end
    return dots
end

-- Every dot on the minimap now: name, count, x / y in minimap units from
-- its centre (nil: it can't be read now)
function ML:Read()
    if not ML.Supported() or not Minimap:IsVisible() then return nil end
    local radius = Minimap:GetWidth() / 2
    local mx, my = Minimap:GetCenter()
    if not (mx and radius > 4) then return nil end
    local scale = Minimap:GetEffectiveScale()
    local skip = {}
    for _, unit in ipairs({ "player", "pet" }) do
        local name = UnitExists(unit) and UnitName(unit)
        if type(name) == "string" and not secret(name) then skip[name] = true end
    end
    if Minimap.SetUsingSoftCursor then Minimap:SetUsingSoftCursor(true) end
    local hits, grid, names = {}, gridFor(radius), {}
    for i = 1, #grid, 2 do
        local x, y = grid[i], grid[i + 1]
        namesAt((mx + x) * scale, (my + y) * scale, skip, names)
        if next(names) then
            for name, count in pairs(names) do
                hits[#hits + 1] = { name = name, count = count, x = x, y = y }
                names[name] = nil
            end
        end
    end
    -- The hover point off the minimap again, as the game had it
    Minimap:UpdateMouseoverAtPoint(-10000, -10000)
    if Minimap.SetUsingSoftCursor then Minimap:SetUsingSoftCursor(false) end
    return group(hits)
end

---------------------------------------------------------------------------
-- Where the dots are: yards east / north on the zone's map, from the
-- player's own place (none in an instance: then from the player as read)
---------------------------------------------------------------------------
local function playerPlace()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetMapWorldSize) then
        return nil
    end
    local map = C_Map.GetBestMapForUnit("player")
    if type(map) ~= "number" or secret(map) then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    local x, y = pos and pos.x, pos and pos.y
    if type(x) ~= "number" or type(y) ~= "number" or secret(x) or secret(y) then return nil end
    local w, h = C_Map.GetMapWorldSize(map)
    if type(w) ~= "number" or type(h) ~= "number" or secret(w) or w <= 0 or h <= 0 then return nil end
    return x * w, -y * h, map
end

-- The minimap turning with the player: the way they face (radians from
-- north, anticlockwise), else nil
local function facing()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    if not get or get("rotateMinimap") ~= "1" then return nil end
    local f = GetPlayerFacing and GetPlayerFacing()
    if type(f) ~= "number" or secret(f) then return nil end
    return f
end

-- Yards for one minimap unit (1: the minimap's size unknown)
local function yardsPerUnit()
    local view = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
    local radius = Minimap:GetWidth() / 2
    if type(view) ~= "number" or secret(view) or view <= 0 or radius <= 0 then return 1 end
    return view / radius
end

local function median(list)
    table.sort(list)
    local n = #list
    if n == 0 then return 0 end
    if n % 2 == 1 then return list[(n + 1) / 2] end
    return (list[n / 2] + list[n / 2 + 1]) / 2
end

-- A reading taken in: each dot's place in yards. The dots already placed
-- keep theirs unless it moved by itself; while the player moves, the trail
-- of the answers (the same for all, measured on those) taken off the others
function ML:Take(read)
    local ypu = yardsPerUnit()
    local f = facing()
    local c, s = f and math.cos(f) or 1, f and math.sin(f) or 0
    local px, py, map = playerPlace()
    local old = self.dots or {}
    local still = GetTime() - (self.movedAt or 0) >= STILL_AFTER
    local jitter = math.max(2, STEP * ypu)
    local dxs, dys = {}, {}
    for _, d in ipairs(read) do
        local ex, ny = d.x * ypu, d.y * ypu
        d.east, d.north = ex * c - ny * s, ex * s + ny * c
        if px then
            d.wx, d.wy, d.map = px + d.east, py + d.north, map
            -- The same dot as before: the nearest of its name
            local best, bestD
            for _, o in ipairs(old) do
                if o.name == d.name and o.wx and o.map == map then
                    local dd = (o.wx - d.wx) ^ 2 + (o.wy - d.wy) ^ 2
                    if dd <= MATCH * MATCH and (not bestD or dd < bestD) then best, bestD = o, dd end
                end
            end
            d.was = best
            if best and not still then
                dxs[#dxs + 1] = d.wx - best.wx
                dys[#dys + 1] = d.wy - best.wy
            end
        end
    end
    local tx, ty = median(dxs), median(dys)
    for _, d in ipairs(read) do
        if d.wx then
            d.wx, d.wy = d.wx - tx, d.wy - ty
            local o = d.was
            -- (a reading's own jitter, a grid step: the label stays put)
            local keep = still and jitter or math.max(jitter, MOVED)
            if o and (d.wx - o.wx) ^ 2 + (d.wy - o.wy) ^ 2 <= keep * keep then d.wx, d.wy = o.wx, o.wy end
        end
        d.was = nil
    end
    self.dots = read
end

function ML:Scan()
    local ok, read = pcall(self.Read, self)
    if not ok then
        -- Never again this session (the game refused it): said once
        self.broken = true
        self:Apply()
        CK:Print(L.MML_UNREADABLE)
        return
    end
    if read then self:Take(read) end
end

---------------------------------------------------------------------------
-- The labels
---------------------------------------------------------------------------
function ML:Build()
    if self.frame then return end
    local f = CK.NewFrame("Frame", nil, Minimap)
    f:SetAllPoints(Minimap)
    f:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    f.labels = {}
    f:SetScript("OnUpdate", function() ML:OnUpdate() end)
    f:Hide()
    self.frame = f
end

local function labelAt(i)
    local f = ML.frame
    local fs = f.labels[i]
    if not fs then
        fs = f:CreateFontString(nil, "OVERLAY")
        fs:SetTextColor(1, 1, 1)
        fs:SetWordWrap(true)
        if fs.SetMaxLines then fs:SetMaxLines(3) end
        f.labels[i] = fs
    end
    return fs
end

-- The labels' font at a size: the one chosen in the panel for the Latin
-- alphabet, the game's own for the others (reported: a name in boxes)
local families, familyCount = {}, 0
local function fontFamily(size)
    local path = CK:GetFontPath()
    local key = path .. size
    if families[key] ~= nil then return families[key] end
    local family = false
    if CreateFontFamily then
        familyCount = familyCount + 1
        local function member(alphabet, file, height)
            return { alphabet = alphabet, file = file, height = height, flags = "OUTLINE" }
        end
        local ok, made = pcall(CreateFontFamily, "ControllerKeyboardMinimapFont" .. familyCount, {
            member("roman", path, size), member("russian", "Fonts\\FRIZQT___CYR.TTF", size),
            member("korean", "Fonts\\2002.TTF", size + 1),
            member("simplifiedchinese", "Fonts\\ARKai_T.ttf", size + 3),
            member("traditionalchinese", "Fonts\\blei00d.TTF", size + 3),
        })
        if ok and made then family = made end
    end
    families[key] = family
    return family
end

local function setSize(fs, size)
    local key = CK:GetFontPath() .. size
    if fs.fontKey == key then return end
    fs.fontKey = key
    local family = fontFamily(size)
    if family then fs:SetFontObject(family) else fs:SetFont(CK:GetFontPath(), size, "OUTLINE") end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    -- (measured again)
    fs.natural = nil
end

-- Half the circle's width at a height from its middle
local function halfAt(r, y)
    local v = r * r - y * y
    return v > 0 and math.sqrt(v) or 0
end

-- The text's size: smaller as the minimap zooms out
function ML:Size()
    local size = settings().size or 10
    local zoom, levels = Minimap:GetZoom(), Minimap:GetZoomLevels()
    if type(zoom) == "number" and type(levels) == "number" and levels > 1 then
        size = size * (0.8 + 0.2 * zoom / (levels - 1))
    end
    return math.max(MIN_SIZE, math.floor(size + 0.5))
end

-- Each dot where it is now, the same names close together merged, the
-- nearest first, none over another, at most the number set
function ML:Place()
    local f = self.frame
    local dots = self.dots or {}
    local radius = Minimap:GetWidth() / 2
    local upy = 1 / yardsPerUnit()
    local fa = facing()
    local c, s = fa and math.cos(fa) or 1, fa and math.sin(fa) or 0
    local px, py, map = playerPlace()
    local shown = {}
    for _, d in ipairs(dots) do
        local east, north = d.east, d.north
        if d.wx and px and d.map == map then east, north = d.wx - px, d.wy - py end
        local x, y = (east * c + north * s) * upy, (-east * s + north * c) * upy
        if x * x + y * y <= (radius - 3) ^ 2 then
            shown[#shown + 1] = { name = d.name, count = d.count, x = x, y = y, far = x * x + y * y }
        end
    end
    table.sort(shown, function(a, b) return a.far < b.far end)
    -- One name close together: one label, counted
    local kept = {}
    for _, d in ipairs(shown) do
        local into
        for _, k in ipairs(kept) do
            if k.name == d.name and (k.x - d.x) ^ 2 + (k.y - d.y) ^ 2 <= MERGE * MERGE then
                into = k
                break
            end
        end
        if into then into.count = into.count + d.count else kept[#kept + 1] = d end
    end
    local size = self:Size()
    local max = settings().max or 12
    local inner = radius - 2
    local boxes, n = {}, 0
    for _, d in ipairs(kept) do
        if n >= max then break end
        local fs = labelAt(n + 1)
        setSize(fs, size)
        local text = ML.Describe(d.name, d.count)
        if fs.text ~= text or not fs.natural then
            fs:SetWidth(0)
            fs.wrap = nil
            fs:SetText(text)
            fs.text = text
            fs.natural, fs.lineH = fs:GetStringWidth() or 0, fs:GetStringHeight() or size
        end
        -- Beside its dot, toward the minimap's middle; too wide for the
        -- circle there, on several lines (reported: past the frame)
        local toLeft = d.x > 0
        local function room(h)
            local half = halfAt(inner, math.max(math.abs(d.y - h / 2), math.abs(d.y + h / 2)))
            return toLeft and (d.x - 5 + half) or (half - d.x - 5)
        end
        local w, h = fs.natural, fs.lineH
        if w > room(h) then
            local width = math.max(MIN_WIDTH, math.floor(room(h)))
            if fs.wrap ~= width then
                fs:SetWidth(width)
                fs.wrap = width
            end
            h = fs:GetStringHeight() or h
            -- (taller now: where the circle is narrower)
            local again = math.max(MIN_WIDTH, math.floor(room(h)))
            if again < width then
                width = again
                fs:SetWidth(width)
                fs.wrap = width
                h = fs:GetStringHeight() or h
            end
            w = width
        elseif fs.wrap then
            fs:SetWidth(0)
            fs.wrap = nil
        end
        local left = toLeft and (d.x - 5 - w) or (d.x + 5)
        local bottom = d.y - h / 2
        local free = true
        for _, box in ipairs(boxes) do
            if left < box[3] and left + w > box[1] and bottom < box[4] and bottom + h > box[2] then
                free = false
                break
            end
        end
        if free then
            n = n + 1
            boxes[#boxes + 1] = { left - 1, bottom - 1, left + w + 1, bottom + h + 1 }
            fs:SetJustifyH(toLeft and "RIGHT" or "LEFT")
            fs:ClearAllPoints()
            fs:SetPoint("BOTTOMLEFT", f, "CENTER", left, bottom)
            fs:Show()
        end
    end
    for i = n + 1, #f.labels do f.labels[i]:Hide() end
end

function ML:OnUpdate()
    local now = GetTime()
    local px, py = playerPlace()
    if px and self.lastX and ((px - self.lastX) ^ 2 + (py - self.lastY) ^ 2) > 0.01 then self.movedAt = now end
    self.lastX, self.lastY = px, py
    -- (a mouse over the minimap: its own tooltip is the game's)
    if now >= (self.scanAt or 0) and not Minimap:IsMouseOver() then
        self.scanAt = now + SCAN_EVERY
        self:Scan()
        if not self.frame:IsShown() then return end
    end
    self:Place()
end

---------------------------------------------------------------------------
-- On and off; its button (Gamepad tab: Macros, Minimap labels)
---------------------------------------------------------------------------
function ML:Active()
    local s = settings()
    if not (s.enabled and ML.Supported()) or self.broken then return false end
    if s.mode == "hold" then return self.held and true or false end
    return not self.hidden
end

local EVENTS = {
    "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_SOFT_ENEMY_CHANGED",
    "PLAYER_SOFT_FRIEND_CHANGED", "PLAYER_SOFT_INTERACT_CHANGED", "GROUP_ROSTER_UPDATE", "SKILL_LINES_CHANGED",
    "QUEST_LOG_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
}
local UNIT_OF = {
    PLAYER_TARGET_CHANGED = "target", UPDATE_MOUSEOVER_UNIT = "mouseover",
    PLAYER_SOFT_ENEMY_CHANGED = "softenemy", PLAYER_SOFT_FRIEND_CHANGED = "softfriend",
    PLAYER_SOFT_INTERACT_CHANGED = "softinteract",
}

-- The labels shown or not, the names learnt only while the option is on
function ML:Apply()
    local s = settings()
    local events = self.events
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", function(_, event, unit)
            if event == "NAME_PLATE_UNIT_ADDED" then
                learn(unit)
            elseif UNIT_OF[event] then
                learn(UNIT_OF[event])
            elseif event == "GROUP_ROSTER_UPDATE" then
                learnGroup()
            elseif event == "SKILL_LINES_CHANGED" then
                skills = nil
            elseif event == "QUEST_LOG_UPDATE" then
                quests = nil
            else
                -- Another place: its dots read anew
                ML.dots = nil
            end
        end)
        self.events = events
    end
    local on = s.enabled and ML.Supported() and not self.broken
    if on and not self.listening then
        for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
        learnGroup()
    elseif not on and self.listening then
        events:UnregisterAllEvents()
        forget()
    end
    self.listening = on
    local active = self:Active()
    if active then
        self:Build()
        if not self.frame:IsShown() then
            self.dots, self.scanAt = nil, 0
            self.frame:Show()
        end
    elseif self.frame then
        self.frame:Hide()
        self.dots = nil
    end
end

function ML:Press()
    local s = settings()
    if not s.enabled then
        CK:Print(L.MML_OFF)
        return
    end
    if s.mode == "hold" then
        self.held = true
    else
        self.hidden = not self.hidden
    end
    self:Apply()
end

function ML:Release()
    if not self.held then return end
    self.held = nil
    self:Apply()
end

-- What a button of the controller clicks (Mapping.lua, "wheel:minimap"),
-- as a wheel's key: a key bound to it sends a press and a release; a
-- router one click on the press (no "down") and its release as a "ckup"
-- click
function ML:ToggleButton()
    if self.toggle then return self.toggle end
    local b = CK.NewFrame("Button", TOGGLE_BUTTON, UIParent)
    b:SetSize(1, 1)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetScript("OnClick", function(self, button, down)
        local release = (type(button) == "string" and button:sub(1, 4) == "ckup") or (not down and self.down)
        self.down = down and true or false
        if release then ML:Release() else ML:Press() end
    end)
    self.toggle = b
    return b
end

-- At login, the character's settings read (Chat.lua); the binding's
-- button exists from the start (Bindings.xml)
function ML:Init()
    self:ToggleButton()
    self:Apply()
end
