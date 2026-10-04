-- Lua 5.1, from the addon root. Real wheel construction/rendering and shared
-- slot states; only WoW API objects and game data are substituted.
local function noop() end
local writes, combat, native = 0, false, true
local visualWrites = 0
local state = { x = 0, y = 0, len = 0 }
local methods = {}
local function region(parent)
    return setmetatable({ parent=parent, scripts={}, attrs={}, refs={}, shown=true, children={} }, { __index=methods })
end
function methods:CreateTexture() local t=region(self); self.children[#self.children+1]=t; return t end
methods.CreateFontString=methods.CreateTexture
methods.CreateMaskTexture=methods.CreateTexture
function methods:SetScript(k,f) self.scripts[k]=f end
function methods:HookScript(k,f) local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;f(...)end end
function methods:Fire(k,...)if self.scripts[k]then self.scripts[k](self,...)end end
function methods:SetAttribute(k,v) writes=writes+1;self.attrs[k]=v end
function methods:GetAttribute(k)return self.attrs[k]end
function methods:GetFrameRef(k)return self.refs[k]end
function methods:SetTexture(v)visualWrites=visualWrites+1;self.texture=v end
function methods:SetAtlas(v,...)self.atlas=v end
function methods:SetColorTexture(...)self.color={...}end
function methods:SetVertexColor(...)visualWrites=visualWrites+1;self.vertex={...}end
function methods:SetText(v)visualWrites=visualWrites+1;self.text=v end
function methods:SetSize(w,h)self.width,self.height=w,h end
function methods:SetWidth(w)self.width=w end
function methods:SetHeight(h)self.height=h end
function methods:GetWidth()return self.width or 0 end
function methods:GetHeight()return self.height or 0 end
function methods:SetPoint(...)self.point={...}end
function methods:SetAlpha(v)self.alpha=v end
function methods:AddMaskTexture(mask)self.masks=self.masks or {};self.masks[#self.masks+1]=mask end
function methods:SetDesaturated(v)self.desaturated=v end
function methods:SetCooldown(...)self.cooldown={...}end
function methods:Clear()self.cooldown=nil end
function methods:GetFrameLevel()return 1 end
function methods:SetShown(v)self.shown=not not v end
function methods:Show()self:SetShown(true)end
function methods:Hide()self:SetShown(false)end
function methods:IsShown()return self.shown end
function methods:SetWordWrap(v)self.wrap=v end
function methods:SetMaxLines(v)self.maxLines=v end
for _,n in ipairs({'SetAllPoints','SetFrameStrata','SetMovable','SetClampedToScreen','EnableMouse','RegisterForDrag',
    'ClearAllPoints','RegisterForClicks','SetTexCoord','SetDrawLayer','SetSwipeTexture','SetSwipeColor',
    'SetDrawEdge','SetDrawBling','SetFrameLevel','SetJustifyH','SetJustifyV','SetRotation','SetTextColor','SetShadowOffset',
    'SetShadowColor','SetFont','SetBlendMode','SetHorizTile','SetVertTile','SetNonSpaceWrap','EnableGamePadStick','SetOwner','SetItemByID','SetSpellByID'}) do methods[n]=noop end
local CK={L=setmetatable({}, {__index=function(_,k)return k end}),db={settings={wheel={locked=true}}},
    NewFrame=function(_,_,parent)return region(parent)end,GetFontPath=function()return 'Fonts\\FRIZQT__.TTF' end,GlyphMarkup=function(_,key)return key end,SetGlyph=function(_,texture,key)texture.glyph=key end,
    Mapping={SpellName=function(id)return 'Spell '..id end,Repair=noop},
    MyWheels={Name=function(_,id)return 'Custom wheel '..id end}}
local ticks=0;CK.Vibration={Fire=function(_,event)assert(event=='wheelTick');ticks=ticks+1 end}
local env=setmetatable({format=string.format,gmatch=string.gmatch,UIParent=region(),CreateFrame=CK.NewFrame,
    InCombatLockdown=function()return combat end,C_Timer={After=noop},KEY_BUTTON1='Mouse1',
    C_Texture={GetAtlasInfo=function()return native and {} or nil end},
    C_GamePad={GetDeviceMappedState=function()return {sticks={state}}end},
    C_Item={GetItemNameByID=function(id)return 'Long selected consumable name '..id end,GetItemIconByID=function(id)return id+1000 end,
        GetItemCount=function(id)return id==3 and 0 or 12 end},
    C_Container={GetItemCooldown=function(id)return id==2 and 10 or 0,id==2 and 30 or 0 end},
    C_Spell={GetSpellTexture=function(id)return id+2000 end,IsSpellUsable=function()return true end},
    GameTooltip=region(),GetBindingAction=function()return ''end,date=function()return ''end,
    NORMAL_FONT_COLOR={GetRGB=function()return 1,.82,0 end},DISABLED_FONT_COLOR={GetRGB=function()return .5,.5,.5 end},
    SecureHandlerWrapScript=function(button,event,owner,pre,post)button.securePre,button.securePost=pre,post end,
    SecureHandlerSetFrameRef=function(owner,key,frame)owner.refs[key]=frame end}, {__index=_G})
env._G=env
local function loadAddon(path)local f=assert(loadfile(path));setfenv(f,env);f('EasyController',CK)end
loadAddon('Paddles.lua');loadAddon('ConsumableWheel.lua')
local W=CK.ConsumableWheel;W:Build()
assert(W.view.face, 'wheel needs an opaque face beneath its native radial artwork')
assert(W.frame.height==700 and W.view.rim.atlas=='UI-HUD-Minimap-Frame-Circle' and W.view.rim.width==512)
assert(W.view.hubRim.atlas=='UI-HUD-Minimap-Frame-Circle' and W.view.hubRim.width==182 and W.view.hubFace.width==146)
assert(W.view.bottom.point[3]=='CENTER' and W.view.bottom.point[5]==-220)
assert(W.view.face.color[4]==1 and W.view.face.width==401 and W.view.faceArt.texture:find('ck_panel_bg',1,true))
assert(W.view.bannerRim.atlas=='common-insideframe' and W.view.bottom.texture:find('ck_panel_bg',1,true))
assert(W.view.bannerBack.color[4]==1 and W.view.name.wrap and W.view.name.maxLines==2)
assert(W.view.faceMask.atlas=='ui-hud-minimap-frame-generic-mask' and W.view.face.masks[1]==W.view.faceMask and W.view.faceArt.masks[1]==W.view.faceMask)
assert(W.view.bottom.height==128 and W.view.name.height==38 and W.view.count.height==18)
assert(W.view.help.point[2]==W.view.bottom and W.view.help.point[3]=='TOP' and W.view.help.point[5]==-80 and W.view.help.height==16)
assert(W.view.pages.point[2]==W.view.bottom and W.view.pages.point[3]=='TOP' and W.view.pages.point[5]==-102 and W.view.pages.height==14)
assert(220+W.view.bottom.height<=W.frame.height/2,'integrated banner and footer must stay inside the clamped wheel frame')
assert(W.view.center.width==62 and W.view.centerHint.glyph=='LS')
local crownMask=W.view.crownMask
assert(crownMask and crownMask.width==401 and crownMask.height==401,'old crown needs one contained world-aligned circle mask')
assert(crownMask.atlas=='ui-hud-minimap-frame-generic-mask' and crownMask.point[1]=='CENTER' and crownMask.point[2]==W.view.bg and crownMask.point[3]=='CENTER','crown mask must stay centered globally, independent of section offset or rotation')
assert(W.view.bg.alpha==.60 and W.view.bg.masks[1]==crownMask and W.view.highlight.masks[1]==crownMask)
assert(not W.view.rim.masks and not W.view.hubRim.masks,'native bevel artwork must remain unmasked')
for _,seg in ipairs(W.segments)do assert(seg.disabled.masks[1]==crownMask)end
local title=W.view.wheelName;local tx,ty=title.point[4],title.point[5]
assert((math.abs(tx)+title.width/2)^2+(math.abs(ty)+title.height/2)^2<=(W.view.hubFace.width/2)^2,'hub name rectangle escapes the circular face')
W.frame:Show();W.lists={c={[1]={}},['1']={[1]={n=8,[1]={kind='item',id=1},[3]={kind='spell',id=9}}}}
local buildWrites=writes
for n=1,8 do
    local list={};for i=1,n do list[i]={kind='item',id=i}end
    W.lists.c[1]=list;W:Paint()
    assert(W.paintedCount==n and W.view.bg.texture:find('ck_wheel_bg_'..n,1,true))
    assert(W.view.highlight.masks[1]==crownMask and crownMask.point[2]==W.view.bg,'page-specific overlay transforms must not retarget the shared mask')
    for i,seg in ipairs(W.segments)do
        assert(seg.slot.shown==(i<=n) and not seg.label, 'old cramped peripheral labels must not be drawn')
        if i<=n then local dx,dy=W.slotDir(i,n);assert(math.abs(seg.slot.point[4]-dx*128)<.001 and math.abs(seg.slot.point[5]-dy*128)<.001)end
    end
end
assert(writes==buildWrites,'painting pages must not mutate any secure attribute')
print('PASS: opaque native-material face/banner, readable center, and unchanged1-to8-section icon geometry')

-- Execute the real secure pre-click snippet with the same page/directions.
-- The fixture supplies GetGamePadState and the visibility APPLY_PAGE would set.
local function secureTarget()
 local list=W:PageItems();local wid=W.frame:GetAttribute('wheel')or'c';local page=W.frame:GetAttribute('page')or 1
 W.frame.attrs['ck-'..wid..'-'..page..'-n']=list.n or #list
 for i,b in ipairs(W.buttons)do b:SetShown(list[i]~=nil)end
 local f=assert(loadstring('return function(self,button,down,owner) '..W.use.securePre..' end'))
 setfenv(f,setmetatable({GetGamePadState=function()return {sticks={state}}end},{__index=env}))
 return f()(W.use,'LeftButton',true,W.frame)
end
state.x,state.y,state.len=0,1,1;W:Track()
assert(W:Aimed()==1 and W.aimed==1 and W.focused==1 and ticks==1)
assert(W.segments[1].slot.isHovered and W.view.center.icon.texture==1001)
W.buttons[2]:Fire('OnEnter')
assert(secureTarget()=='s1' and W.focused==1 and W.aimed==1,'central controller cue must describe the actual secure A target')
assert(W.hovered==2 and W.segments[2].slot.isHovered and W.view.center.icon.texture==1001,'mouse hover should still mark its own slot without replacing active controller aim')
W.buttons[2]:Fire('OnMouseDown','LeftButton')
assert(W.segments[2].slot.isPressed and W.segments[2].slot.visual.width<46 and not W.view.center.isPressed,'mouse press must not shrink a different central controller target')
W.buttons[2]:Fire('OnMouseUp','LeftButton');assert(not W.segments[2].slot.isPressed)
state.x,state.y,state.len=1,0,1;W.view:Fire('OnGamePadStick')
assert(W.hovered==nil and W.focused==3 and secureTarget()=='s3' and ticks==2,'new stick intent must clear stale mouse display focus')
W.buttons[2]:Fire('OnLeave');assert(W.focused==3 and W.segments[3].slot.isHovered,'old mouse leave must not disturb restored controller focus')
state.x,state.y,state.len=0,0,0;W:Track();assert(not W.view.center.shown and W.view.centerHint.shown)
W.buttons[2]:Fire('OnEnter')
assert(W.focused==2 and W.view.center.icon.texture==1002)
assert(W.view.help.text:find('Mouse1 WHEEL_USE',1,true) and not W.view.help.text:find('A WHEEL_USE',1,true),'mouse-only preview must advertise click, not controller A')
assert(secureTarget()==false,'neutral-stick A must retain its original no-action behavior')
W.buttons[2]:Fire('OnMouseDown','LeftButton');assert(W.view.center.isPressed)
W.use:Fire('OnClick','LeftButton',true)
assert(W.hovered==nil and W.pressed==nil and W.focused==nil and not W.view.center.shown,'A intent must clear stale mouse preview without selecting anything')
assert(ticks==2 and writes==buildWrites)
print('PASS: authoritative secure A cue, explicit neutral-stick mouse cue, stick resumption, old leave and unchanged no-action A')

combat=true;W:Paint();W.buttons[3]:Fire('OnEnter')
assert(W.segments[3].disabled.shown and W.view.center.icon.desaturated,'unavailable items must remain visually disabled')
W.buttons[3]:Fire('OnMouseDown','LeftButton');W.buttons[3]:Fire('OnMouseUp','LeftButton')
assert(writes==buildWrites,'combat hover/press/painting must never change secure attributes')
combat=false
W.frame.attrs.wheel='1';state.x,state.y,state.len=1,0,1;W:Track()
assert(W.paintedCount==8 and W.focused==3 and W.view.wheelName.text=='Custom wheel 1')
assert(not W.segments[2].slot.shown and W.segments[3].slot.shown and W.view.center.icon.texture==2009)
local previous=W.focused;W:SetPressed(2);assert(W.pressed==nil and W.focused==previous,'empty fixed slot has no press state')
W.view:Fire('OnHide');assert(W.hovered==nil and W.focused==nil and not W.view.center.isPressed)
assert(writes==buildWrites)
print('PASS: combat visual-only updates, unavailable items, fixed custom-wheel holes and close cleanup')

-- A pushed stick can point at a real empty direction of a fixed custom wheel.
W.frame:Show();W.frame.attrs.wheel='1';W.frame.attrs.page=1
state.x,state.y=W.slotDir(2,8);state.len=1;W:Paint()
assert(W:Aimed()==nil and secureTarget()==false)
W.buttons[3]:Fire('OnEnter')
assert(W.focused==3 and W.view.help.text:find('Mouse1 WHEEL_USE',1,true),'hover over an empty aimed direction must not claim A will use the mouse item')
W.view:Fire('OnGamePadStick')
assert(W.hovered==nil and W.focused==nil and secureTarget()==false,'stick intent into a fixed empty slot must clear mouse preview and execute nothing')

-- Page changes and reopening must not inherit a down/hover state from old items.
W.frame.attrs.wheel='c';W.frame.attrs.page=1;state.x,state.y,state.len=0,0,0;W:Track()
W.buttons[2]:Fire('OnEnter');W.buttons[2]:Fire('OnMouseDown','LeftButton')
W.lists.c[2]={{kind='item',id=5}};W.frame.attrs.page=2;W:Track()
assert(W.painted==2 and W.hovered==nil and W.pressed==nil and not W.view.center.shown)
for _,seg in ipairs(W.segments)do assert(not seg.slot.isPressed)end
W.frame.attrs.page=1;W:Track();W.buttons[2]:Fire('OnEnter');W.buttons[2]:Fire('OnMouseDown','LeftButton')
W.frame:Hide();W.view:Fire('OnHide');W.frame:Show();W.view:Fire('OnShow')
assert(W.hovered==nil and W.pressed==nil and W.focused==nil and not W.view.center.shown,'reopening retained mouse visual state')
local before=visualWrites
for _=1,60 do W:Track()end
assert(visualWrites==before,'stable per-frame tracking rewrote textures, colors or text')
assert(writes==buildWrites,'lifecycle or steady tracking changed secure attributes')
W.lists.c[1]={};W:Paint()
assert(W.paintedCount==1 and not W.view.highlight.shown and not W.view.center.shown and W.view.centerHint.shown,'empty wheel must retain a usable idle face without a false selection')
print('PASS: fixed holes execute nothing, page/hide/reopen clear press and hover, stable tracking performs no visual writes, empty wheel idle state')
