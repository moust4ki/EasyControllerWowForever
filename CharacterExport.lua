local ADDON, CK = ...
local L = CK.L

-- /ec dump (asked; left out of the help): everything about the character
-- and its pet, written for an assistant to read and advise from ("how do I
-- get new pet spells?"). Addons can't write files: it goes to the addon's
-- saved variables, which the game writes on a reload, so the command reloads
-- the interface. Where: WTF/Account/<account>/SavedVariables/EasyController.lua,
-- ControllerKeyboardDB.export["Name-Realm"].
--   .dump      who, stats, talents, the spell book (future spells too), gear,
--              bags, skills, reputations, quests; the pet: family, level,
--              loyalty, happiness, training points, food, stats, its spells
--   .trainers  what each trainer last showed, kept as it opens (the lists
--              exist only while its window is open): a class trainer's
--              spells, Beast Training's abilities (Forever shows it as a
--              pet trainer: costs in training points); learned, available
--              and not yet, with what each one asks
--   .stable    the stable master's pets, their abilities, as last opened
-- Read only: nothing of the game's is changed (a trainer's filters, set to
-- show everything while it is read, are put back).
local X = {}
CK.Export = X

local MAX_DEPTH = 6

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end

-- A value fit for the saved variables: no secret value, function or frame
local function clean(v, depth)
    depth = depth or 0
    if secret(v) then return nil end
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then return v end
    if t ~= "table" or depth >= MAX_DEPTH then return nil end
    -- (a frame or a region: its methods through its metatable)
    if rawget(v, 0) ~= nil or (getmetatable(v) ~= nil and type(v.SetPoint) == "function") then return nil end
    local out = {}
    for k, x in pairs(v) do
        if (type(k) == "string" or type(k) == "number") and not secret(k) then out[k] = clean(x, depth + 1) end
    end
    return out
end
X.Clean = clean

-- A call that never breaks the export: its results, or nothing
local function pack(...) return { n = select("#", ...), ... } end
local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local r = pack(pcall(fn, ...))
    if not r[1] then return end
    return unpack(r, 2, r.n)
end

local function plain(v) if not secret(v) then return v end end

local function spellName(id)
    if not id then return nil end
    local name = C_Spell and C_Spell.GetSpellName and call(C_Spell.GetSpellName, id)
    if not name and GetSpellInfo then name = call(GetSpellInfo, id) end
    return plain(name)
end

local function spellRank(id)
    local sub = id and C_Spell and C_Spell.GetSpellSubtext and call(C_Spell.GetSpellSubtext, id)
    if not sub and id and GetSpellSubtext then sub = call(GetSpellSubtext, id) end
    sub = plain(sub)
    return sub ~= "" and sub or nil
end

local function itemOf(link)
    if type(link) ~= "string" or secret(link) then return nil end
    local id = tonumber(link:match("item:(%d+)"))
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name, _, quality, ilvl, minLevel, kind, subKind = call(get, link)
    return { id = id, name = plain(name) or link:match("%[(.-)%]"), quality = quality, ilvl = ilvl,
        minLevel = minLevel, type = kind, subType = subKind }
end

---------------------------------------------------------------------------
-- The character
---------------------------------------------------------------------------
local function who()
    local name, realm = call(UnitFullName, "player")
    local race, raceFile = call(UnitRace, "player")
    local class, classFile = call(UnitClass, "player")
    local guild, guildRank = call(GetGuildInfo, "player")
    local w = {
        name = plain(name) or plain(call(UnitName, "player")), realm = plain(realm) or plain(call(GetRealmName)),
        race = race, raceFile = raceFile, class = class, classFile = classFile, sex = call(UnitSex, "player"),
        level = call(UnitLevel, "player"), xp = call(UnitXP, "player"), xpMax = call(UnitXPMax, "player"),
        rested = call(GetXPExhaustion), faction = call(UnitFactionGroup, "player"),
        guild = guild, guildRank = guildRank, money = call(GetMoney),
        zone = call(GetZoneText), subZone = call(GetSubZoneText), home = call(GetBindLocation),
        locale = call(GetLocale), client = call(GetBuildInfo),
        talentPoints = call(UnitCharacterPoints, "player"),
    }
    local map = C_Map and call(C_Map.GetBestMapForUnit, "player")
    if map then
        local info = call(C_Map.GetMapInfo, map)
        w.mapID, w.mapName = map, info and info.name
        local pos = call(C_Map.GetPlayerMapPosition, map, "player")
        if type(pos) == "table" and pos.GetXY then
            local x, y = call(pos.GetXY, pos)
            if x then w.x, w.y = math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10 end
        end
    end
    return clean(w)
end

local STATS = { "strength", "agility", "stamina", "intellect", "spirit" }
local SCHOOLS = { [1] = "holy", [2] = "fire", [3] = "nature", [4] = "frost", [5] = "shadow", [6] = "arcane" }

local function stats(unit)
    local s = { resistances = {} }
    for i, n in ipairs(STATS) do
        local base, total = call(UnitStat, unit, i)
        s[n] = { base = base, total = total }
    end
    local armorBase, armor = call(UnitArmor, unit)
    s.armor = armor or armorBase
    s.health, s.power = call(UnitHealthMax, unit), call(UnitPowerMax, unit)
    local _, powerType = call(UnitPowerType, unit)
    s.powerType = powerType
    local apBase, apPos, apNeg = call(UnitAttackPower, unit)
    if type(apBase) == "number" then s.attackPower = apBase + (apPos or 0) + (apNeg or 0) end
    local rapBase, rapPos, rapNeg = call(UnitRangedAttackPower, unit)
    if type(rapBase) == "number" then s.rangedAttackPower = rapBase + (rapPos or 0) + (rapNeg or 0) end
    local minDmg, maxDmg = call(UnitDamage, unit)
    s.melee = { min = minDmg, max = maxDmg, speed = call(UnitAttackSpeed, unit) }
    local rSpeed, rMin, rMax = call(UnitRangedDamage, unit)
    s.ranged = { speed = rSpeed, min = rMin, max = rMax }
    for i, n in pairs(SCHOOLS) do
        local base, total = call(UnitResistance, unit, i)
        s.resistances[n] = total or base
    end
    if unit == "player" then
        s.crit, s.rangedCrit = call(GetCritChance), call(GetRangedCritChance)
        s.spellCrit = call(GetSpellCritChance, 2)
        s.dodge, s.parry, s.block = call(GetDodgeChance), call(GetParryChance), call(GetBlockChance)
        s.hit = call(GetHitModifier)
    end
    return clean(s)
end

-- The spell book's items: spells, passives, future ones (the level they come at)
local function bankOf(kind)
    local banks = Enum and Enum.SpellBookSpellBank
    if kind == "pet" then return banks and banks.Pet or 1 end
    return banks and banks.Player or 0
end

local function spellBook(kind)
    local SB = C_SpellBook
    local out = {}
    if not (SB and SB.GetSpellBookItemInfo) then return out end
    -- (the item types by name: "Spell", "FutureSpell", "PetAction"...)
    local ITEM_TYPES = {}
    for k, v in pairs(Enum and Enum.SpellBookItemType or {}) do ITEM_TYPES[v] = k end
    local bank = bankOf(kind)
    local function add(i, tab)
        local item = call(SB.GetSpellBookItemInfo, i, bank)
        if type(item) ~= "table" then return end
        local sub = plain(item.subName)
        local e = { name = plain(item.name), rank = sub ~= "" and sub or nil, spellID = plain(item.spellID),
            tab = tab, kind = ITEM_TYPES[item.itemType] or item.itemType,
            passive = item.isPassive or nil, offSpec = item.isOffSpec or nil }
        if e.kind == "FutureSpell" and SB.GetSpellBookItemLevelLearned then
            e.level = call(SB.GetSpellBookItemLevelLearned, i, bank)
        end
        out[#out + 1] = clean(e)
    end
    if kind == "pet" then
        for i = 1, call(SB.HasPetSpells) or 0 do add(i) end
    else
        for line = 1, call(SB.GetNumSpellBookSkillLines) or 0 do
            local info = call(SB.GetSpellBookSkillLineInfo, line)
            if type(info) == "table" and info.itemIndexOffset and info.numSpellBookItems then
                for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do add(i, plain(info.name)) end
            end
        end
    end
    return out
end

-- Talents: Forever's trait trees (the game's talent window), else the
-- classic tabs
local function talents()
    local out = {}
    local spec = C_SpecializationInfo and call(C_SpecializationInfo.GetSpecialization)
    if type(spec) == "number" and spec > 0 then
        out.spec = { index = spec, name = select(2, call(C_SpecializationInfo.GetSpecializationInfo, spec)) }
    end
    local T = C_Traits
    local config = C_ClassTalents and call(C_ClassTalents.GetActiveConfigID)
    local info = config and T and call(T.GetConfigInfo, config)
    if type(info) == "table" and type(info.treeIDs) == "table" then
        out.configID, out.trees = config, {}
        for _, tree in ipairs(info.treeIDs) do
            local t = { treeID = tree, points = clean(call(T.GetTreeCurrencyInfo, config, tree, false)), nodes = {} }
            for _, nodeID in ipairs(call(T.GetTreeNodes, tree) or {}) do
                local node = call(T.GetNodeInfo, config, nodeID)
                if type(node) == "table" and node.ID and node.ID ~= 0 then
                    local entries = type(node.entryIDs) == "table" and node.entryIDs or {}
                    local active = type(node.activeEntry) == "table" and node.activeEntry.entryID
                    local function describe(entryID)
                        local entry = entryID and call(T.GetEntryInfo, config, entryID)
                        local def = type(entry) == "table" and entry.definitionID and call(T.GetDefinitionInfo, entry.definitionID)
                        local id = type(def) == "table" and (def.spellID or def.overriddenSpellID) or nil
                        return { entry = entryID, spellID = id, name = spellName(id) or (type(def) == "table" and def.overrideName) or nil }
                    end
                    local n = describe(active or entries[1])
                    n.node, n.rank, n.max = nodeID, node.activeRank or node.currentRank, node.maxRanks
                    n.x, n.y = node.posX, node.posY
                    if #entries > 1 then
                        n.choices = {}
                        for _, e in ipairs(entries) do n.choices[#n.choices + 1] = describe(e) end
                    end
                    t.nodes[#t.nodes + 1] = clean(n)
                end
            end
            out.trees[#out.trees + 1] = t
        end
    end
    if GetNumTalentTabs and GetTalentInfo then
        out.tabs = {}
        for tab = 1, call(GetNumTalentTabs) or 0 do
            local ti = { call(GetTalentTabInfo, tab) }
            local modern = type(ti[1]) == "number"
            local entry = { name = modern and ti[2] or ti[1], points = modern and ti[5] or ti[3], talents = {} }
            for i = 1, call(GetNumTalents, tab) or 0 do
                local name, _, tier, column, rank, maxRank = call(GetTalentInfo, tab, i)
                if type(name) == "string" then
                    entry.talents[#entry.talents + 1] = { name = name, tier = tier, column = column, rank = rank, max = maxRank }
                end
            end
            out.tabs[#out.tabs + 1] = clean(entry)
        end
    end
    return out
end

local SLOTS = { [0] = "ammo", "head", "neck", "shoulder", "shirt", "chest", "waist", "legs", "feet", "wrist",
    "hands", "finger1", "finger2", "trinket1", "trinket2", "back", "mainHand", "offHand", "ranged", "tabard" }

local function gear()
    local out = {}
    for slot = 0, 19 do
        local item = itemOf(call(GetInventoryItemLink, "player", slot))
        if item then
            item.slot = SLOTS[slot]
            if slot == 0 then item.count = call(GetInventoryItemCount, "player", 0) end
            out[#out + 1] = clean(item)
        end
    end
    return out
end

-- The bags: each one (a quiver counts), then every item, by kind
local function bags()
    local out = { bags = {}, items = {} }
    local C = C_Container
    if not C then return out end
    local byID = {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
        local size = call(C.GetContainerNumSlots, bag) or 0
        if size > 0 then
            local free = call(C.GetContainerNumFreeSlots, bag)
            out.bags[#out.bags + 1] = clean({ bag = bag, name = call(C.GetBagName, bag), size = size, free = free })
            for slot = 1, size do
                local info = call(C.GetContainerItemInfo, bag, slot)
                local id = type(info) == "table" and plain(info.itemID)
                if id then
                    local e = byID[id]
                    if not e then
                        e = itemOf(plain(info.hyperlink) or ("item:" .. id)) or { id = id }
                        e.count = 0
                        byID[id] = e
                        out.items[#out.items + 1] = e
                    end
                    e.count = e.count + (plain(info.stackCount) or 1)
                end
            end
        end
    end
    out.items = clean(out.items)
    return out
end

-- Forever's skills (weapons, First Aid, professions...): C_SkillInfo; its
-- folded headers unfolded while read, folded again after
local function skillInfo()
    local S = C_SkillInfo
    local out = {}
    local unfolded = {}
    for i = call(S.GetNumSkillLines) or 0, 1, -1 do
        local s = call(S.GetSkillLineInfo, i)
        if type(s) == "table" and s.isHeader and s.isCollapsed then
            unfolded[#unfolded + 1] = s.skillID
            call(S.ExpandSkillHeader, i)
        end
    end
    for i = 1, call(S.GetNumSkillLines) or 0 do
        local s = call(S.GetSkillLineInfo, i)
        if type(s) == "table" and s.name then
            local bonus = (s.modifier or 0) + (s.tempPoints or 0)
            out[#out + 1] = clean({ name = s.name, id = s.skillID, header = s.isHeader or nil,
                rank = not s.isHeader and s.rank or nil, max = not s.isHeader and s.maxRank or nil,
                bonus = bonus ~= 0 and bonus or nil })
        end
    end
    if #unfolded > 0 then
        local fold = {}
        for _, id in ipairs(unfolded) do fold[id] = true end
        for i = call(S.GetNumSkillLines) or 0, 1, -1 do
            local s = call(S.GetSkillLineInfo, i)
            if type(s) == "table" and s.isHeader and fold[s.skillID] then call(S.CollapseSkillHeader, i) end
        end
    end
    return out
end

local function skills()
    local out = {}
    if C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
        return skillInfo()
    elseif GetNumSkillLines and GetSkillLineInfo then
        for i = 1, call(GetNumSkillLines) or 0 do
            local name, header, _, rank, temp, modifier, maxRank = call(GetSkillLineInfo, i)
            if type(name) == "string" then
                out[#out + 1] = clean({ name = name, header = header or nil, rank = not header and rank or nil,
                    max = not header and maxRank or nil, bonus = (modifier or 0) + (temp or 0) ~= 0 and (modifier or 0) + (temp or 0) or nil })
            end
        end
    end
    return out
end

local function reputations()
    local out = {}
    local R = C_Reputation
    if R and R.GetNumFactions and R.GetFactionDataByIndex then
        for i = 1, call(R.GetNumFactions) or 0 do
            local f = call(R.GetFactionDataByIndex, i)
            if type(f) == "table" and f.name then
                out[#out + 1] = clean({ name = f.name, header = f.isHeader or nil, standing = f.reaction,
                    value = f.currentStanding, from = f.currentReactionThreshold, to = f.nextReactionThreshold, id = f.factionID })
            end
        end
    elseif GetNumFactions and GetFactionInfo then
        for i = 1, call(GetNumFactions) or 0 do
            local name, _, standing, from, to, value, _, _, header = call(GetFactionInfo, i)
            if type(name) == "string" then
                out[#out + 1] = clean({ name = name, header = header or nil, standing = standing, value = value, from = from, to = to })
            end
        end
    end
    return out
end

local function quests()
    local out = {}
    local Q = C_QuestLog
    if not (Q and Q.GetNumQuestLogEntries and Q.GetInfo) then return out end
    local zone
    for i = 1, call(Q.GetNumQuestLogEntries) or 0 do
        local info = call(Q.GetInfo, i)
        if type(info) == "table" then
            if info.isHeader then
                zone = info.title
            elseif info.questID then
                local q = { id = info.questID, title = info.title, level = info.level, zone = zone,
                    complete = call(Q.IsComplete, info.questID) or nil, objectives = {} }
                for _, o in ipairs(call(Q.GetQuestObjectives, info.questID) or {}) do
                    q.objectives[#q.objectives + 1] = { text = o.text, done = o.finished or nil, type = o.type }
                end
                out[#out + 1] = clean(q)
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- The pet
---------------------------------------------------------------------------
-- A stable's pet info, its abilities by name and rank
local function petInfo(p)
    if type(p) ~= "table" then return nil end
    local e = clean(p) or {}
    e.icon, e.displayID, e.uiModelSceneID = nil, nil, nil
    for _, key in ipairs({ "petAbilities", "specAbilities" }) do
        if type(p[key]) == "table" then
            local list = {}
            for _, id in ipairs(p[key]) do
                if not secret(id) then list[#list + 1] = { spellID = id, name = spellName(id), rank = spellRank(id) } end
            end
            e[key] = list
        end
    end
    return e
end

local function pet()
    local out = { hasPetUI = call(HasPetUI) }
    local PI = C_PetInfo or {}
    if not call(UnitExists, "pet") then
        out.none = true
        return clean(out)
    end
    out.name, out.family = plain(call(UnitName, "pet")), plain(call(UnitCreatureFamily, "pet"))
    out.level = call(UnitLevel, "pet")
    out.xp, out.xpMax = call(GetPetExperience)
    out.loyalty = call(PI.GetPetLoyalty or GetPetLoyalty)
    local happiness, damage, loyaltyRate = call(PI.GetPetHappiness or GetPetHappiness)
    out.happiness = { level = happiness, damagePercent = damage, loyaltyRate = loyaltyRate }
    local total, used = call(PI.GetPetTrainingPoints or GetPetTrainingPoints)
    if type(total) == "number" then out.trainingPoints = { total = total, used = used, free = total - (used or 0) } end
    local food = PI.GetPetFoodTypes and call(PI.GetPetFoodTypes)
    out.food = type(food) == "table" and food or { call(GetPetFoodTypes) }
    out.talentTree = call(PI.GetPetTalentTree)
    out.stats = stats("pet")
    out.spells = spellBook("pet")
    -- The game's own record of the active pet (its abilities by spell ID)
    local S = C_StableInfo
    local active = S and S.GetActivePetList and call(S.GetActivePetList)
    if type(active) == "table" then
        out.active = {}
        for _, p in ipairs(active) do out.active[#out.active + 1] = petInfo(p) end
    end
    return clean(out)
end

---------------------------------------------------------------------------
-- Saved where the game writes it
---------------------------------------------------------------------------
local function store()
    local db = CK.db
    if not db then return nil end
    db.export = type(db.export) == "table" and db.export or {}
    local name, realm = call(UnitFullName, "player")
    name = plain(name) or plain(call(UnitName, "player")) or "?"
    realm = plain(realm) or plain(call(GetRealmName)) or "?"
    local key = name .. "-" .. realm
    db.export[key] = type(db.export[key]) == "table" and db.export[key] or {}
    return db.export[key]
end

function X:Collect()
    local meta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return {
        when = date and date("%Y-%m-%d %H:%M:%S") or nil, time = call(GetServerTime),
        addonVersion = call(meta, ADDON, "Version"),
        character = who(), stats = stats("player"), talents = talents(), spells = spellBook("player"),
        gear = gear(), bags = bags(), skills = skills(), reputations = reputations(), quests = quests(),
        pet = pet(),
    }
end

-- /ec dump: collected, saved, the interface reloaded (the file written)
function X:Dump()
    if InCombatLockdown() then
        CK:Print(L.DUMP_COMBAT)
        return false
    end
    local slot = store()
    if not slot then return false end
    slot.dump = self:Collect()
    CK:Print(L.DUMP_SAVED)
    local reload = C_UI and C_UI.Reload or ReloadUI
    if reload then reload() end
    return true
end

---------------------------------------------------------------------------
-- What a trainer shows (a class trainer, Beast Training), as it opens
---------------------------------------------------------------------------
local FILTERS = { "available", "unavailable", "used" }

function X:ReadTrainer()
    if self.reading or not GetNumTrainerServices then return end
    local slot = store()
    if not slot then return end
    -- Every service shown while it is read (the window's own filters back after)
    self.reading = true
    local was = {}
    if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
        for _, f in ipairs(FILTERS) do
            was[f] = call(GetTrainerServiceTypeFilter, f) and true or false
            if not was[f] then call(SetTrainerServiceTypeFilter, f, 1) end
        end
    end
    local kind = C_Trainer and call(C_Trainer.GetTrainerType)
    local pets = Enum and Enum.TrainerType and kind == Enum.TrainerType.Pet
    local snap = { when = date and date("%Y-%m-%d %H:%M:%S") or nil, npc = plain(call(UnitName, "npc")),
        kind = pets and "pet" or kind, services = {} }
    if pets then
        local total, used = call((C_PetInfo or {}).GetPetTrainingPoints or GetPetTrainingPoints)
        snap.trainingPoints = { total = total, used = used }
    end
    for i = 1, call(GetNumTrainerServices) or 0 do
        local name, status, _, reqLevel, rank = call(GetTrainerServiceInfo, i)
        if type(name) == "string" then
            local cost, isProfession = call(GetTrainerServiceCost, i)
            local s = { name = name, status = status, level = reqLevel ~= 0 and reqLevel or nil,
                rank = rank ~= "" and rank or nil }
            if pets then s.trainingPoints = cost else s.cost = cost end
            s.profession = isProfession or nil
            local skill, skillRank, hasSkill = call(GetTrainerServiceSkillReq, i)
            if skill then s.skill = { name = skill, rank = skillRank, met = hasSkill and true or false } end
            local abilities = call(GetTrainerServiceNumAbilityReq, i) or 0
            for a = 1, abilities do
                local ability, has = call(GetTrainerServiceAbilityReq, i, a)
                if ability then
                    s.needs = s.needs or {}
                    s.needs[#s.needs + 1] = { name = ability, met = has and true or false }
                end
            end
            snap.services[#snap.services + 1] = clean(s)
        end
    end
    for f, on in pairs(was) do
        if not on then call(SetTrainerServiceTypeFilter, f, 0) end
    end
    self.reading = nil
    -- (the updates our filters cause: not read again)
    self.quietUntil = GetTime() + 1
    slot.trainers = type(slot.trainers) == "table" and slot.trainers or {}
    slot.trainers[pets and "pet" or (snap.npc or "trainer")] = clean(snap)
end

-- The stable master's pets
function X:ReadStable()
    local S = C_StableInfo
    if not S then return end
    local slot = store()
    if not slot then return end
    local snap = { when = date and date("%Y-%m-%d %H:%M:%S") or nil, pets = {} }
    local lists = { call(S.GetActivePetList), call(S.GetStabledPetList) }
    local seen = {}
    for _, list in ipairs(lists) do
        for _, p in ipairs(type(list) == "table" and list or {}) do
            local e = petInfo(p)
            local key = e and (e.petNumber or e.slotID)
            if e and not (key and seen[key]) then
                if key then seen[key] = true end
                snap.pets[#snap.pets + 1] = e
            end
        end
    end
    -- (no lists: by slot)
    if #snap.pets == 0 and S.GetStablePetInfo then
        for i = 1, (call(S.GetNumStableSlots) or 0) + 5 do
            local e = petInfo(call(S.GetStablePetInfo, i))
            if e then snap.pets[#snap.pets + 1] = e end
        end
    end
    slot.stable = snap
end

function X:Init()
    local f = CreateFrame("Frame")
    self.events = f
    for _, e in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE", "PET_STABLE_SHOW", "PET_STABLE_UPDATE" }) do
        pcall(f.RegisterEvent, f, e)
    end
    f:SetScript("OnEvent", function(_, event)
        if event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
            -- (a burst of updates as it opens: read once, a moment later)
            if X.reading or X.trainerSoon then return end
            if event == "TRAINER_UPDATE" and X.quietUntil and GetTime() < X.quietUntil then return end
            X.trainerSoon = true
            C_Timer.After(0.3, function()
                X.trainerSoon = nil
                xpcall(function() X:ReadTrainer() end, geterrorhandler())
            end)
        else
            if X.stableSoon then return end
            X.stableSoon = true
            C_Timer.After(0.3, function()
                X.stableSoon = nil
                xpcall(function() X:ReadStable() end, geterrorhandler())
            end)
        end
    end)
end
