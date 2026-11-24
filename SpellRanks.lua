local _, CK = ...

-- Highest ranks (asked: "a button in the spellbook: replace my spells with
-- the highest rank"). One press, the addon's button at the bottom of the
-- game's spellbook, or /ec ranks: each spell of a lower rank the character
-- has placed becomes the highest rank it knows. Where: the game's action slots (every gamepad bar page, the
-- stance bars), the addon's buttons, paddles, replaced buttons, wheels and
-- party spells, in every profile of the character. Never by itself: a lower
-- rank kept on purpose (its mana) stays until the button is pressed.
--
-- The game's spellbook lists every rank ("Rang 2", checked in game), each
-- its own spell ID, not in the ranks' order (Distracting Shot: rank 1 is
-- 20736, rank 2 14274): the rank's number decides.
local R = {}
CK.SpellRanks = R

local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- "Rang 3" -> 3; nil without a number
local function rankNumber(text)
    text = plain(text)
    return type(text) == "string" and tonumber(text:match("(%d+)")) or nil
end

local function subtext(id)
    local get = C_Spell and C_Spell.GetSpellSubtext or GetSpellSubtext
    if not get then return nil end
    local ok, text = pcall(get, id)
    return ok and plain(text) or nil
end

local function spellName(id)
    local get = C_Spell and C_Spell.GetSpellName
    if not get then return nil end
    local ok, name = pcall(get, id)
    name = ok and plain(name)
    return type(name) == "string" and name ~= "" and name or nil
end

-- The character's spells: by name, the highest rank learned; by ID, the
-- name, rank number and rank text of each one learned
function R:Book()
    local SB = C_SpellBook
    local book = { best = {}, byId = {} }
    if not (SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo) then
        return book
    end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local SPELL = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    for line = 1, SB.GetNumSpellBookSkillLines() or 0 do
        local info = SB.GetSpellBookSkillLineInfo(line)
        if type(info) == "table" and info.itemIndexOffset and info.numSpellBookItems then
            for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local ok, item = pcall(SB.GetSpellBookItemInfo, i, bank)
                -- (learned ranks only: a future one is listed too)
                if ok and type(item) == "table" and plain(item.itemType) == SPELL then
                    local id, name = plain(item.spellID), plain(item.name)
                    local rank = rankNumber(item.subName)
                    if type(id) == "number" and type(name) == "string" and rank then
                        book.byId[id] = { name = name, rank = rank, text = plain(item.subName) }
                        local best = book.best[name]
                        if not best or rank > best.rank then
                            book.best[name] = { id = id, rank = rank, text = plain(item.subName) }
                        end
                    end
                end
            end
        end
    end
    return book
end

-- A spell's highest rank learned, when higher than its own: its ID, then
-- its rank's text and the old one's ("Rang 4", "Rang 1"); nil otherwise
function R.Higher(book, id)
    if type(id) ~= "number" then return nil end
    local own = book.byId[id]
    local name = own and own.name or spellName(id)
    local best = name and book.best[name]
    if not best or best.id == id then return nil end
    local text = own and own.text or subtext(id)
    local rank = own and own.rank or rankNumber(text)
    if not rank or best.rank <= rank then return nil end
    return best.id, best.text, text, name
end

---------------------------------------------------------------------------
-- The press
---------------------------------------------------------------------------
local MAX_SLOT = 180

-- A slot the game keeps for itself (Mapping.lua): left alone
local function kept(slot)
    return CK.Mapping and CK.Mapping.SlotKept and CK.Mapping:SlotKept(slot) ~= nil
end

-- The game's action slots: every one the bars may show, the gamepad bar's
-- pages and the stance bars included
local function actionSlots()
    local list, seen = {}, {}
    local function add(slot)
        if type(slot) == "number" and slot > 0 and not seen[slot] then
            seen[slot] = true
            list[#list + 1] = slot
        end
    end
    for slot = 1, MAX_SLOT do add(slot) end
    local Slots = CK.Profiles and CK.Profiles.Slots
    if Slots and Slots.List then
        local ok, more = pcall(Slots.List, Slots)
        for _, slot in ipairs(ok and type(more) == "table" and more or {}) do add(slot) end
    end
    return list
end

-- A spell put in a slot (out of combat); true when it is there
local function place(slot, id)
    ClearCursor()
    local pickup = C_Spell and C_Spell.PickupSpell or PickupSpell
    if not (pickup and pcall(pickup, id)) or not GetCursorInfo() then
        ClearCursor()
        return false
    end
    PlaceAction(slot)
    ClearCursor()
    local kind, now = GetActionInfo(slot)
    return kind == "spell" and now == id
end

function R:Upgrade()
    local L = CK.L
    if InCombatLockdown() then
        CK:Print(L.RANKS_COMBAT)
        return 0
    end
    local book = self:Book()
    -- What changed, by spell (its name): { the old ranks' texts, the new
    -- one's, places }
    local done, order = {}, {}
    local function note(old, new, newText, oldText, name)
        name = name or spellName(old) or "?"
        local d = done[name]
        if not d then
            d = { name = name, olds = {}, seen = {}, new = newText or "?", count = 0 }
            done[name] = d
            order[#order + 1] = name
        end
        oldText = oldText or "?"
        if not d.seen[oldText] then
            d.seen[oldText] = true
            d.olds[#d.olds + 1] = oldText
        end
        d.count = d.count + 1
    end
    -- An action of the addon's: "spell:ID" or "wheel:party:ID" at its new rank
    local function action(value)
        if type(value) ~= "string" then return nil end
        local prefix, id = value:match("^(spell:)(%d+)$")
        if not prefix then prefix, id = value:match("^(wheel:party:)(%d+)$") end
        id = tonumber(id)
        local new, newText, oldText, name = R.Higher(book, id)
        if not new then return nil end
        note(id, new, newText, oldText, name)
        return prefix .. new
    end
    local changed = false
    local function assigned(t)
        if type(t) ~= "table" then return end
        for k, v in pairs(t) do
            local new = action(v)
            if new then
                t[k] = new
                changed = true
            end
        end
    end
    local function wheels(w)
        local list = type(w) == "table" and w.list
        for _, wheel in ipairs(type(list) == "table" and list or {}) do
            if type(wheel) == "table" then assigned(wheel.slots) end
        end
    end
    -- A profile's record of the game's slots ({ t = "spell", id })
    local function record(r)
        if type(r) ~= "table" then return end
        for _, v in pairs(r) do
            if type(v) == "table" and v.t == "spell" then
                local new = R.Higher(book, v.id)
                if new then v.id = new end
            end
        end
    end
    -- The game's slots
    for _, slot in ipairs(actionSlots()) do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and not kept(slot) then
            local new, newText, oldText, name = R.Higher(book, id)
            if new and place(slot, new) then note(id, new, newText, oldText, name) end
        end
    end
    -- The addon's: the settings in use (the profile in use's tables), then
    -- the character's other profiles
    local s = CK.db.settings
    assigned(s.mapping)
    assigned(s.replaced)
    wheels(s.myWheels)
    local Pr = CK.Profiles
    local p = Pr and Pr.Profile and Pr:Profile()
    if p then
        record(p.data and p.data.slots)
        for _, set in ipairs(type(p.sets) == "table" and p.sets or {}) do
            local data = type(set) == "table" and set.data
            if type(data) == "table" then
                assigned(data.mapping)
                assigned(data.replaced)
                wheels(data.myWheels)
                record(data.slots)
            end
        end
    end
    if changed and Pr and Pr.Reread then Pr.Reread() end
    if #order == 0 then
        CK:Print(L.RANKS_NONE)
        return 0
    end
    CK:Print(format(L.RANKS_DONE, #order))
    for _, name in ipairs(order) do
        local d = done[name]
        DEFAULT_CHAT_FRAME:AddMessage("  " .. format(L.RANKS_LINE, d.name, table.concat(d.olds, ", "), d.new, d.count))
    end
    return #order
end

---------------------------------------------------------------------------
-- In the game's spellbook: a button of the addon's, at the bottom left of
-- its pages (where the paging is, on the right). Not an entry in the
-- game's settings menu (its cog): that menu runs under the gamepad's focus
-- and an addon's entry in it made the game's own code fail when it closed
-- (seen in game: ADDON_ACTION_FORBIDDEN SetPreferredGamepadInteractTarget,
-- and the game's "blocked" window). The game's smart navigation reaches a
-- button of the spellbook and clicks it behind its own barrier.
---------------------------------------------------------------------------
local BOOK_ADDON = "Blizzard_PlayerSpells"

function R:Button()
    local book = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
    if self.button or not book then return self.button end
    local L = CK.L
    local b = CK.NewFrame("Button", "ControllerKeyboardSpellRanks", book, "UIPanelButtonTemplate")
    b:SetText(L.RANKS_BUTTON)
    local label = b.GetFontString and b:GetFontString()
    local width = label and label:GetStringWidth()
    b:SetSize(math.max(180, (type(width) == "number" and width or 0) + 40), 26)
    b:SetPoint("BOTTOMLEFT", book.PagedSpellsFrame or book, "BOTTOMLEFT", 75, 34)
    b:SetScript("OnClick", function() R:Upgrade() end)
    b:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:SetText(L.RANKS_MENU, 1, 1, 1)
        GameTooltip:AddLine(L.RANKS_TIP, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.button = b
    return b
end

-- The spellbook is loaded the first time it is opened: the button made then
function R:Init()
    if self.events then return end
    local f = CreateFrame("Frame")
    self.events = f
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, _, name)
        if name == BOOK_ADDON then R:Button() end
    end)
    -- Already loaded (a /reload after opening it)
    self:Button()
end
