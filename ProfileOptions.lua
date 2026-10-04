local _, CK = ...

-- Pending choices belong to this open session; Profiles owns every save.
local C = CK.Config
local profileChoice, copySource, actionRole = nil, nil, "interrupt"
local draftOwner, drafts = nil, {}
local LAYERS = {
    { key = "", name = "No trigger" }, { key = "LT", name = "LT" },
    { key = "RT", name = "RT" }, { key = "LTRT", name = "LT + RT" },
}
local SCOPE = "Spells, items, macros and custom wheels belong to this character and profile. "
    .. "Game functions, jump/interact/back/inspect and the consumables wheel are shared, as are controller keys and settings. "
    .. "The game's native action-bar contents are not saved in profiles."

local function inCombat() return InCombatLockdown and InCombatLockdown() or false end
local function indexOf(items, key)
    for i, item in ipairs(items) do if item.key == key then return i end end
    return 1
end
local function nameOf(items, key)
    for _, item in ipairs(items) do if item.key == key then return item.name end end
    return key or "None"
end
local function nextKey(items, key, delta)
    if #items == 0 then return nil end
    return items[(indexOf(items, key) - 1 + delta) % #items + 1].key
end
local function result(ok, message, success)
    C:Toast(message or (ok and success or "Unable to apply this change."), not ok)
end
local function activeKey(P)
    for _, role in ipairs(P.ROLES) do if role.name == P:ActiveName() then return role.key end end
    return P.ROLES[1].key
end
local function ready(b)
    local P = CK.Profiles
    if P and P.ready then return P end
    b.info("Profiles are available after this character has loaded.")
end

local function profileRows(b)
    b.header("Profiles")
    local P = ready(b)
    if not P then return end
    profileChoice = profileChoice or activeKey(P)
    local target = profileChoice
    local targetName = nameOf(P.ROLES, target)
    local exists = P:Has(target)
    b.stat({ label = "Character", text = P:CharacterName() })
    b.stat({ label = "Active profile", text = P:ActiveName() })
    b.choice({ id = "profile_target", label = "Preview profile", tip = SCOPE,
        text = function() return nameOf(P.ROLES, profileChoice) end,
        step = function(delta)
            C:Disarm()
            profileChoice = nextKey(P.ROLES, profileChoice, delta)
        end })
    b.info(exists and ("Activate " .. targetName .. " to use its saved bindings and wheels.")
        or (targetName .. " will start as a copy of your current profile when activated."))
    b.button({ id = "profile_activate", label = "Activate " .. targetName, verb = "Activate",
        disabled = inCombat, tip = SCOPE,
        func = function()
            C:Disarm()
            local ok, message = P:Switch(target)
            if ok then draftOwner, drafts = nil, {} end
            result(ok, message, "Activated " .. targetName .. ".")
        end })
    b.header("Copy personal bindings and wheels")
    local sources = P:Sources()
    local validSource = false
    for _, source in ipairs(sources) do if source.key == copySource then validSource = true end end
    if not validSource then copySource = sources[1] and sources[1].key or nil end
    b.choice({ id = "profile_source", label = "Copy from", disabled = #sources == 0,
        text = function() return #sources > 0 and nameOf(sources, copySource) or "No saved source" end,
        tip = "Choose another character/profile or the preserved legacy bindings. Nothing changes until Copy is confirmed.",
        step = function(delta)
            C:Disarm()
            copySource = nextKey(sources, copySource, delta)
        end })
    local source = copySource
    b.button({ id = "profile_copy", label = "Copy into " .. P:ActiveName(), verb = "Copy",
        danger = true, armedLabel = "Press A again to copy",
        disabled = function() return not source or inCombat() end,
        tip = "Copy " .. nameOf(sources, source) .. " into " .. P:CharacterName() .. " / " .. P:ActiveName()
            .. ". This replaces the active profile's personal bindings and custom wheels. Shared utility commands keep their current settings. Press twice to confirm. " .. SCOPE,
        func = function()
            local ok, message = P:CopyFrom(source)
            if ok then draftOwner, drafts = nil, {} end
            result(ok, message, "Copied into " .. P:ActiveName() .. ".")
        end })
    b.info("Controller settings and utility bindings are shared. Native action-bar contents are not saved.")
end

local function knownSpell(action, entries)
    if type(action) ~= "string" or not action:find("^spell:%d+$") then return false end
    for _, entry in ipairs(entries) do if entry.action == action then return true end end
    return false
end
local function roleDraft(P, role, entries)
    local owner = P:CharacterName() .. ":" .. P:ActiveName()
    if owner ~= draftOwner then draftOwner, drafts = owner, {} end
    local draft = drafts[role]
    if not draft then
        local input, layer = P:RolePosition(role)
        draft = { input = input, layer = layer or "", action = P:RoleAction(role), replace = false }
        drafts[role] = draft
    end
    if not knownSpell(draft.action, entries) then draft.action = nil end
    return draft
end

-- Four persistent role cards share the same drafts as the binding editor.
-- Choosing and editing only stage changes; Apply is the sole save path.
local V = { zone = "cards", setting = 1 }
local K, KC = CK.ConfigKit, CK.ConfigKit.C
local function roleInputs()
    local inputs = {}
    for _, input in ipairs(CK.Mapping.INPUTS) do
        if not input.layer then inputs[#inputs + 1] = { key = input.id, name = input.id } end
    end
    return inputs
end
function V:Current()
    local P = CK.Profiles
    if not (P and P.ready) then return end
    local entries = CK.Mapping:Catalog("spells")
    return P, roleDraft(P, actionRole, entries), nameOf(P.ACTION_ROLES, actionRole)
end
function V:Select(index)
    local P = CK.Profiles
    if not (P and P.ready) then return end
    actionRole = P.ACTION_ROLES[math.max(1, math.min(#P.ACTION_ROLES, index))].key
    self.zone = "cards"
end
function V:Choose(page)
    local P, draft, name = self:Current()
    if not P then return end
    local role = actionRole
    page:OpenPicker({ kicker = "Role layout", title = name, current = draft.action, rows = 9,
        lists = { { key = "spells", label = "Known spells", entries = function() return CK.Mapping:Catalog("spells") end } },
        onChoose = function(entry)
            local available = CK.Mapping:Catalog("spells")
            if not knownSpell(entry.action, available) then
                C:Toast("That spell is no longer in your spellbook.", true)
                return
            end
            roleDraft(P, role, available).action = entry.action
            page.picker:Close()
            C:Render()
        end })
end
function V:Apply()
    local P, draft, name = self:Current()
    if not P then return end
    local ok, preview = P:PreviewRole(actionRole, draft.input, draft.layer, draft.action, draft.replace)
    if not ok or inCombat() then
        result(false, inCombat() and "Role assignments cannot change during combat." or preview)
        return
    end
    local applied, message = P:ApplyRole(actionRole, draft.input, draft.layer, draft.action, draft.replace)
    result(applied, message, name .. " assignment saved.")
    C:Render()
end
function V:ChangeSetting(delta)
    local P, draft = self:Current()
    if not P then return end
    if self.setting == 1 then
        draft.input = nextKey(roleInputs(), draft.input, delta)
    elseif self.setting == 2 then
        draft.layer = nextKey(LAYERS, draft.layer, delta)
    else
        draft.replace = not draft.replace
    end
    C:Render()
end
function V:Build(list, page)
    local f = CK.NewFrame("Frame", nil, list)
    f:SetAllPoints(); f:Hide()
    self.frame, self.page = f, page
    f.head = K.Text(f, 18, KC.title)
    f.head:SetPoint("TOPLEFT", 2, -3)
    f.cards, f.settings = {}, {}
    for i, role in ipairs(CK.Profiles.ACTION_ROLES) do
        local b = K.Button(f, 16, "role")
        b:SetSize(388, 72); b:SetPoint("TOPLEFT", 0, -36 - (i - 1) * 80)
        b.label:Hide()
        b.icon = K.SquareIcon(b, 36, "OVERLAY"); b.icon:SetPoint("LEFT", 12, 0)
        b.role = K.Text(b, 16, KC.cream, "OVERLAY")
        b.role:SetHeight(20)
        b.spell = K.ChatText(b, 13, KC.cream2, "OVERLAY")
        -- Cards are summaries; the full selected spell name is scrollable in
        -- the detail pane and available on mouse hover.
        b.spell:SetHeight(30); b.spell:SetWordWrap(true); b.spell:SetMaxLines(2); b.spell:SetJustifyV("TOP")
        b.combo = K.GlyphRow(b, 22); b.combo:SetPoint("RIGHT", -12, 0)
        b:SetScript("OnClick", function()
            V:Select(i); page.zone = "list"; b:Pulse(); V:Choose(page)
        end)
        b:HookScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.spell:GetText() or "")
                GameTooltip:Show()
            end
        end)
        b:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        f.cards[i] = b
    end
    for i = 1, 3 do
        local b = K.Button(f, 16)
        b:SetSize(388, 50); b:SetPoint("TOPLEFT", 0, -54 - (i - 1) * 66)
        b.label:SetWordWrap(true); b.label:SetHeight(42)
        b:SetScript("OnClick", function() V.setting = i; b:Pulse(); V:ChangeSetting(1) end)
        f.settings[i] = b
    end
    f.edit = K.Button(f, 14, "nav")
    f.edit:SetSize(388, 32); f.edit:SetPoint("TOPLEFT", 0, -364)
    f.edit:SetScript("OnClick", function()
        V.zone = V.zone == "settings" and "cards" or "settings"
        page.zone = "list"; f.edit:Pulse(); C:Render()
    end)
end
function V:Render(page, focused)
    local f = self.frame
    local P, draft = self:Current()
    page.detail:SetHeight(420)
    local editing = self.zone == "settings"
    f.head:SetText(editing and "Button and trigger" or "Role layout")
    local entries = P and CK.Mapping:Catalog("spells") or {}
    for i, b in ipairs(f.cards) do
        b:SetShown(P ~= nil and not editing)
        if P then
            local role = P.ACTION_ROLES[i]
            local d = roleDraft(P, role.key, entries)
            local selected = role.key == actionRole
            b:SetState({ active = selected, focus = focused and self.zone == "cards" and selected })
            b.role:SetText(role.name)
            b.spell:SetText(d.action and CK.Mapping:ActionName(d.action) or "Choose a known spell")
            CK.Paddles.SetIcon(b.icon, d.action and CK.Mapping:ActionIcon(d.action))
            b.icon:SetShown(d.action ~= nil)
            b.combo:Set(K.ComboKeys(d.input, d.layer))
            local textX = d.action and 60 or 16
            local textWidth = 388 - textX - b.combo:GetWidth() - 24
            b.role:ClearAllPoints(); b.role:SetPoint("TOPLEFT", textX, -12); b.role:SetWidth(textWidth)
            b.spell:ClearAllPoints(); b.spell:SetPoint("TOPLEFT", textX, -34); b.spell:SetWidth(textWidth)
        end
    end
    local labels = draft and { "Button: " .. (draft.input or "None"), "Trigger: " .. nameOf(LAYERS, draft.layer),
        "Replace existing assignment: " .. (draft.replace and "On" or "Off") } or {}
    for i, b in ipairs(f.settings) do
        b:SetShown(P ~= nil and editing)
        b.label:SetText(labels[i] or "")
        b:SetState({ focus = focused and editing and self.setting == i })
    end
    f.edit:SetShown(P ~= nil)
    f.edit.label:SetText(editing and "Back to roles" or "Button / trigger settings")
    f.edit:SetState({ active = editing })
end
function V:Detail()
    local P, draft, name = self:Current()
    if not P then return { title = "Role layout", body = "Profiles are available after this character has loaded." } end
    local ok, preview = P:PreviewRole(actionRole, draft.input, draft.layer, draft.action, draft.replace)
    return { centered = true, title = draft.action and CK.Mapping:ActionName(draft.action) or "Choose a spell",
        icon = draft.action and CK.Mapping:ActionIcon(draft.action),
        combo = K.ComboKeys(draft.input, draft.layer), tag = name, body = preview,
        action = { label = "Apply " .. name, disabled = not ok or inCombat(), focus = self.zone == "apply",
            func = function() V:Apply() end } }
end
function V:Press(page, key)
    if not (CK.Profiles and CK.Profiles.ready) then return false end
    if self.zone == "settings" then
        if key == "UP" or key == "DOWN" then
            self.setting = math.max(1, math.min(3, self.setting + (key == "UP" and -1 or 1)))
        elseif key == "LEFT" or key == "RIGHT" or key == "A" then
            self:ChangeSetting(key == "LEFT" and -1 or 1)
            return true
        elseif key == "B" or key == "X" then self.zone = "cards"
        else return false end
    elseif self.zone == "apply" then
        if key == "A" then page.detail:Activate(); return true
        elseif key == "UP" or key == "DOWN" then page.detail:Scroll(key == "UP" and -1 or 1); return true
        elseif key == "LEFT" or key == "B" then self.zone = "cards"
        elseif key == "X" then self.zone = "settings"
        else return false end
    elseif key == "UP" or key == "DOWN" then
        self:Select(indexOf(CK.Profiles.ACTION_ROLES, actionRole) + (key == "UP" and -1 or 1))
    elseif key == "A" then self:Choose(page); return true
    elseif key == "X" then self.zone = "settings"
    elseif key == "RIGHT" then self.zone = "apply"
    elseif key == "Y" then self:Apply(); return true
    else return false end
    C:Render()
    return true
end
function V:Help()
    local H = K.H
    if self.zone == "settings" then
        return { H({ "DPAD" }, "Setting"), H({ "DPAD_LR" }, "Change", "RIGHT"), H({ "B" }, "Back") }
    elseif self.zone == "apply" then
        return { H({ "A" }, "Apply"), H({ "LEFT" }, "Roles", "LEFT"), H({ "B" }, "Back") }
    end
    return { H({ "DPAD" }, "Role"), H({ "A" }, "Choose spell"), H({ "X" }, "Binding"),
        H({ "Y" }, "Apply"), H({ "B" }, "Back") }
end

local sections = C.pages.home.def.sections
sections[#sections + 1] = { key = "profiles", label = "Profiles", tip = SCOPE, rows = profileRows }
sections[#sections + 1] = { key = "role_layout", label = "Role layout",
    tip = "Place each character's interrupt, defensive, movement and heal on consistent buttons. Existing bindings are preserved unless you choose to replace them.",
    view = V }
