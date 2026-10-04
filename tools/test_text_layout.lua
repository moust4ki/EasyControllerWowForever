-- Run from the addon directory with Lua 5.1. Measurements below model variable
-- glyph widths and wrapping; these checks do not claim in-game font rendering.
local methods = {}
local function noop() end
local function region(parent)
    return setmetatable({ parent = parent, shown = true, scripts = {}, children = {}, points = {} }, { __index = methods })
end
function methods:CreateTexture() local r = region(self); self.children[#self.children + 1] = r; return r end
methods.CreateFontString = methods.CreateTexture
methods.CreateMaskTexture = methods.CreateTexture
function methods:SetScript(k, f) self.scripts[k] = f end
function methods:HookScript(k, f) local old = self.scripts[k]; self.scripts[k] = function(...) if old then old(...) end; f(...) end end
function methods:Fire(k, ...) if self.scripts[k] then self.scripts[k](self, ...) end end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetTexture(v) self.texture = v end
function methods:SetAtlas(v, useSize) self.atlas, self.useAtlasSize = v, useSize end
function methods:SetVertexColor(...) self.vertex = { ... } end
function methods:SetTextColor(...) self.color = { ... } end
function methods:SetFont(path, size, flags) self.font, self.fontSize, self.fontFlags = path, size, flags end
function methods:SetText(v) self.text = v or '' end
function methods:SetSpacing(v) self.spacing = v end
function methods:SetWordWrap(v) self.wrap = v end
function methods:SetMaxLines(v) self.maxLines = v end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width or 100 end
function methods:GetHeight() return self.height or 420 end
function methods:GetStringWidth()
    local s = (self.text or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
    local w = 0
    for c in s:gmatch('.') do w = w + (c == 'W' and .9 or c == 'i' and .28 or .53) * (self.fontSize or 13) end
    return w
end
function methods:GetStringHeight()
    local lines = self.wrap and math.max(1, math.ceil(self:GetStringWidth() / self:GetWidth())) or 1
    if self.maxLines and self.maxLines > 0 then lines = math.min(lines, self.maxLines) end
    return lines * (self.fontSize or 13) + (lines - 1) * (self.spacing or 0)
end
function methods:SetScrollChild(v) self.scrollChild = v end
function methods:SetVerticalScroll(v) self.verticalScroll = v end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:IsShown() return self.shown end
function methods:SetShown(v) self.shown = not not v end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:SetAlpha(v) self.alpha = v end
function methods:IsEnabled() return true end
for _, k in ipairs({ 'SetAllPoints', 'SetTexCoord', 'SetShadowOffset', 'SetShadowColor', 'SetJustifyH', 'SetJustifyV',
    'SetNonSpaceWrap', 'SetColorTexture', 'SetDrawLayer', 'SetHorizTile', 'SetVertTile', 'EnableMouseWheel',
    'SetClipsChildren', 'RegisterForClicks', 'AddMaskTexture', 'SetBlendMode' }) do methods[k] = noop end
local timers, atlases = {}, true
local CK = { L = {}, db = { settings = {} }, NewFrame = function(_, _, parent) return region(parent) end,
    GetFontPath = function() return 'Fonts\\FRIZQT__.TTF' end, SetGlyph = noop, Config = { Render = noop },
    Paddles = { SetIcon = function(t, icon) t:SetTexture(icon) end } }
local tooltip = region()
function tooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function tooltip:AddLine(text) self.sub = text end
function tooltip:IsOwned(owner) return self.owner == owner end
local env = setmetatable({ format = string.format, CreateFrame = CK.NewFrame,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_Texture = { GetAtlasInfo = function() return atlases and {} or nil end }, GameTooltip = tooltip }, { __index = _G })
env._G = env
local function loadAddon(path) local f = assert(loadfile(path)); setfenv(f, env); f('EasyController', CK) end
loadAddon('UI.lua'); loadAddon('ConfigKit.lua')
local K = CK.ConfigKit
local d = K.Detail(region(), 232); d:SetHeight(420)
assert(d.rim and d.rim.atlas == 'common-insideframe' and d.rim.useAtlasSize == false,
    'detail rim must use native slice metadata without resizing the paper panel')
local applies = 0
local content = { title = 'An unusually long localized spell name with several words',
    tag = 'An unusually long ownership label which needs wrapping', body = string.rep('Wide WWW help and narrow iii explanations. ', 30),
    extra = 'Additional instructions remain reachable.', action = { label = 'Apply', func = function() applies = applies + 1 end } }
d:Set(content)
assert(d.viewport and d.scrollChild, 'detail text must have a bounded scroll viewport above Apply')
assert(d.title:GetHeight() > 16 and d.tag:GetHeight() > 13, 'title and ownership tag must measure wrapped text')
assert(d.tag:GetWidth() <= 232 - 28 - 18, 'ownership dot must not consume tag text width')
assert(d.viewport:GetHeight() <= 420 - 14 - 60, 'scroll viewport must end above the action button')
assert(d.scrollChild:GetHeight() > d.viewport:GetHeight() and d:CanScroll(), 'long localized help must remain reachable')
d:Scroll(1); local pos = d.viewport:GetVerticalScroll(); assert(pos > 0)
d:Set(content); assert(d.viewport:GetVerticalScroll() == pos, 'ordinary redraw must retain detail reading position')
d.viewport:Fire('OnMouseWheel', -1); assert(d.viewport:GetVerticalScroll() > pos, 'mouse wheel must move the actual scroll frame')
d:Scroll(10000); assert(d.viewport:GetVerticalScroll() == d.maxScroll)
d:Scroll(-10000); assert(d.viewport:GetVerticalScroll() == 0)
d:Activate(); assert(applies == 1)
content.action.disabled = true; d:Set(content); d:Activate(); assert(applies == 1)
d:Set({ title = 'Short', body = 'One line' }); assert(not d:CanScroll() and d.viewport:GetVerticalScroll() == 0)
print('PASS: measured wrapped detail/tag bounds, pinned Apply, mouse/controller scrolling, redraw retention and activation guards')
local entries = { { header = 'A long localized spell category heading' } }
for i = 1, 25 do entries[#entries + 1] = { name = 'Extraordinarily long WWW spell name with localization ' .. i,
    sub = 'Rank ' .. i, action = 'spell:' .. i, icon = 123 } end
local chosen = {}
local p = K.Picker(region(), 232); p:SetHeight(420)
p:Open({ title = 'Choose an extraordinarily long spell category', kicker = 'Spell selection',
    lists = { { label = 'Known spells', entries = function() return entries end },
        { label = 'Other spells', entries = function() return { entries[2] } end } }, onChoose = function(e) chosen[#chosen + 1] = e.action end })
assert(p.rows[2].label.wrap and p.rows[2].label.maxLines == 2 and p.rows[2]:GetHeight() >= 36, 'picker names need bounded two-line rows')
assert(p.visibleRows < 10 and p.visibleRows >= 3, 'taller names must reduce page size to the real panel height')
assert(tooltip.text == entries[2].name and tooltip.sub == entries[2].sub, 'controller selection must expose the complete name and rank')
for i = 1, 25 do
    local selected
    for _, r in ipairs(p.rows) do
        if r.shown then
            local top = -r.points[1][5]
            assert(top + r:GetHeight() <= p:GetHeight() - 12, 'picker row escaped panel bounds')
            if r.index == p.index then selected = r end
        end
    end
    assert(selected, 'controller selection must remain on the visible page')
    p:Press('DOWN')
end
p:Press('A'); assert(#chosen == 1 and chosen[1] == 'spell:25')
p:Press('LB'); assert(p.list == 2 and p.index == 1)
p.rows[1]:Fire('OnClick'); assert(#chosen == 2 and chosen[2] == 'spell:1')
local tab = p.tabs[1]; assert(tab.label.fontSize == 13)
CK:ApplyFont(); assert(tab.label.fontSize == 13, 'live font changes must preserve picker tab size')
p:Close(); assert(not tooltip.shown, 'closing picker must remove its tooltip')
print('PASS: two-line picker bounds across 25 names, controller/mouse choice, full-name tooltip and stable registered tab font')

local role = K.Button(region(), 18, 'role'); role:SetSize(388, 72); role:SetState({ active = true })
assert(role.nativeBase.atlas == 'common-button-list-large' and role.nativeBase.useAtlasSize == false)
assert(role.nativeSelected.shown and role.nativeSelected.atlas == 'common-button-list-large-selected')
role:Fire('OnEnter'); assert(role.nativeBase.atlas == 'common-button-list-large-hover' and role.nativeSelected.shown)
role:Pulse(); assert(role.nativeBase.vertex[1] == .70)
for _, timer in ipairs(timers) do timer() end; timers = {}
assert(role.nativeBase.vertex[1] == 1 and role.nativeSelected.shown, 'pulse release must restore selected native state')
role:SetState({ disabled = true }); role:Pulse()
assert(role.nativeBase.vertex[1] == 1 and not role.nativeSelected.shown and role.alpha == .45)
local nav = K.Button(region(), 13, 'nav'); nav:SetHeight(30); nav:SetState({ active = true })
assert(nav.nativeBase.atlas == 'common-button-list-small-hover' and not nav.nativeSelected.shown, 'small navigation must not use the wide selected ornament')
nav:SetHeight(44); nav:Fire('OnSizeChanged'); assert(nav.nativeBase.atlas == 'common-button-list-mid-hover')
atlases = false
assert(not K.Detail(region(), 232).rim, 'clients without the native inset atlas keep the existing parchment')
local fallback = K.Button(region(), 18, 'role'); fallback:SetState({ active = true })
assert(not fallback.nativeBase and fallback.slice.parts[1].texture:find('ck_reforged_role_active', 1, true), 'missing native atlases retain the packaged fallback')
print('PASS: native role/nav atlas families, asymmetric selected overlay, temporary pressed brightness, disabled and fallback states')

local h = K.Hint(region()); local hint = K.H({ 'A' }, 'A long localized controller hint')
h:Set(hint); local natural = h:GetWidth(); assert(h:GetHeight() == 24 and h.verb.fontSize == 12)
h:Set(hint, 112); assert(h:GetWidth() <= 112 and h:GetHeight() == 28 and h.verb.wrap and natural > 112)
h:Set(hint); assert(h:GetWidth() == natural and h:GetHeight() == 24, 'remeasuring a clamped hint must restore its natural width')
print('PASS: compact hints retain glyphs and support bounded two-line footer labels')
