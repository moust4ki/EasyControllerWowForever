-- Run from the addon root with Lua 5.1. Real UI/ConfigKit/ConfigWindow/
-- ProfileOptions code; only WoW frame primitives and game data are replaced.
-- The fixture models anchor constraints and variable glyph advances, not pixels.
local function noop() end
local methods, all, named = {}, {}, {}
local metricScale = 1
local function region(kind, parent, name)
    local r = setmetatable({ kind = kind or 'Frame', parent = parent, name = name,
        shown = true, scripts = {}, children = {}, points = {} }, { __index = methods })
    all[#all + 1] = r
    if parent then parent.children[#parent.children + 1] = r end
    if name then named[name] = r end
    return r
end
local function advance(c, size)
    local k = c:match('[MW@]') and .93 or c:match('[ilI%.%,%!:;]') and .28 or c == ' ' and .31 or .55
    return k * size * metricScale
end
local function plain(text)
    return tostring(text or ''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|T.-|t','  ')
end
local function textWidth(text, size)
    local sum, widest = 0, 0
    for c in plain(text):gmatch('.') do
        if c == '\n' then widest = math.max(widest, sum); sum = 0 else sum = sum + advance(c, size) end
    end
    return math.max(widest, sum)
end
local function fraction(point, axis)
    if axis == 1 then return point:find('LEFT') and 0 or point:find('RIGHT') and 1 or .5 end
    return point:find('TOP') and 0 or point:find('BOTTOM') and 1 or .5
end
local function axis(r, which, stack)
    if not r then return 0, 0 end
    stack = stack or {}; local marker = tostring(r) .. ':' .. which
    assert(not stack[marker], 'cyclic anchor constraint'); stack[marker] = true
    local values = {}
    for _, p in ipairs(r.points) do
        local rel = p[2] or r.parent
        local pos, extent = axis(rel, which, stack)
        values[#values + 1] = { fraction(p[1], which), pos + fraction(p[3], which) * extent + (which == 1 and p[4] or -p[5]) }
    end
    local extent = which == 1 and r.width or r.height
    for i = 1, #values do for j = i + 1, #values do
        if values[i][1] ~= values[j][1] then extent = (values[j][2]-values[i][2])/(values[j][1]-values[i][1]) end
    end end
    if not extent then
        if r.kind == 'FontString' then extent = which == 1 and textWidth(r.text, r.fontSize or 14) or r:GetStringHeight()
        else extent = 0 end
    end
    local pos = values[1] and values[1][2] - values[1][1] * extent or 0
    stack[marker] = nil
    return pos, extent
end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == 'number' then x, y, relative, relativePoint = relative, relativePoint, self.parent, point
    elseif relative == nil then relative, relativePoint, x, y = self.parent, point, 0, 0
    elseif type(relative) == 'table' and type(relativePoint) == 'number' then x,y,relativePoint=relativePoint,x,point end
    if type(relative) == 'string' then relative = named[relative] end
    local p = { point, relative or self.parent, relativePoint or point, x or 0, y or 0 }
    for i, old in ipairs(self.points) do if old[1] == point then self.points[i] = p; return end end
    self.points[#self.points + 1] = p
end
function methods:ClearAllPoints() self.points = {} end
function methods:SetAllPoints(relative)
    self:ClearAllPoints(); relative = relative or self.parent
    self:SetPoint('TOPLEFT',relative,'TOPLEFT',0,0); self:SetPoint('BOTTOMRIGHT',relative,'BOTTOMRIGHT',0,0)
end
function methods:GetPoint(i) return unpack(self.points[i or 1] or {}) end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() local _,v=axis(self,1); return v end
function methods:GetHeight() local _,v=axis(self,2); return v end
function methods:GetLeft() return (axis(self,1)) end
function methods:GetRight() local p,s=axis(self,1); return p+s end
function methods:GetTop() return -(axis(self,2)) end
function methods:GetBottom() local p,s=axis(self,2); return -p-s end
function methods:GetParent() return self.parent end
function methods:SetParent(p) self.parent=p end
function methods:GetName() return self.name end
function methods:GetFrameLevel() return self.level or 0 end
function methods:SetFrameLevel(n) self.level=n end
function methods:GetEffectiveScale() return 1 end
function methods:GetScale() return 1 end
function methods:SetFont(path,size) self.fontPath,self.fontSize=path,size end
function methods:GetFont() return self.fontPath or 'Fonts\\FRIZQT__.TTF',self.fontSize or 14,'' end
function methods:SetText(s) self.text=tostring(s or '') end
function methods:GetText() return self.text or '' end
function methods:SetFormattedText(fmt,...) self:SetText(string.format(fmt,...)) end
function methods:SetWordWrap(v) self.wrap=v end
function methods:SetNonSpaceWrap(v) self.nonSpaceWrap=v end
function methods:SetMaxLines(v) self.maxLines=v end
function methods:SetSpacing(v) self.spacing=v end
function methods:GetStringWidth() return textWidth(self.text,self.fontSize or 14) end
function methods:GetTextWidth() return self.Text and self.Text:GetStringWidth() or self:GetStringWidth() end
function methods:GetStringHeight()
    local text=plain(self.text); if text=='' then return 0 end
    local lines,width,size=1,0,self.fontSize or 14
    local available=self:GetWidth()
    if available<=0 then available=math.huge end
    for c in text:gmatch('.') do
        if c=='\n' then lines=lines+1;width=0
        else
            local nextWidth=width+advance(c,size)
            if self.wrap~=false and nextWidth>available and width>0 then lines=lines+1;width=0 end
            width=width+advance(c,size)
        end
    end
    if self.maxLines and self.maxLines>0 then lines=math.min(lines,self.maxLines) end
    return lines*size*1.15+(lines-1)*(self.spacing or 0)
end
function methods:IsTruncated() return self:GetStringWidth()>self:GetWidth() or self:GetStringHeight()>self:GetHeight()+.1 end
function methods:CreateTexture(name) return region('Texture',self,name) end
function methods:CreateMaskTexture(name) return region('Texture',self,name) end
function methods:CreateFontString(name) return region('FontString',self,name) end
function methods:SetScript(n,f) self.scripts[n]=f end
function methods:HookScript(n,f) local old=self.scripts[n];self.scripts[n]=function(...)if old then old(...)end;f(...)end end
function methods:Fire(n,...) if self.scripts[n]then return self.scripts[n](self,...)end end
function methods:SetShown(v) local old=self.shown;self.shown=not not v;if old~=self.shown then self:Fire(self.shown and 'OnShow' or 'OnHide')end end
function methods:Show()self:SetShown(true)end
function methods:Hide()self:SetShown(false)end
function methods:IsShown()return self.shown end
function methods:IsVisible()return self.shown and (not self.parent or self.parent:IsVisible())end
function methods:SetEnabled(v)self.enabled=not not v end
function methods:Enable()self.enabled=true end
function methods:Disable()self.enabled=false end
function methods:IsEnabled()return self.enabled~=false end
function methods:SetTexture(v)self.texture=v end
function methods:GetTexture()return self.texture end
function methods:SetAtlas(v,useSize)self.atlas=v;self.nativeSlice=true;if useSize then self:SetSize(95,95)end end
function methods:GetAtlas()return self.atlas end
function methods:SetAlpha(v)self.alpha=v end
function methods:SetTextColor(...)self.color={...}end
function methods:SetShadowColor(...)self.shadow={...}end
function methods:SetVertexColor(...)self.vertex={...}end
function methods:SetTexCoord(...)self.coords={...}end
function methods:SetScrollChild(child)self.scrollChild=child;child.parent=self end
function methods:SetVerticalScroll(v)self.verticalScroll=v end
function methods:GetVerticalScroll()return self.verticalScroll or 0 end
function methods:GetVerticalScrollRange()return math.max(0,(self.scrollChild and self.scrollChild:GetHeight()or 0)-self:GetHeight())end
for _,n in ipairs({'SetJustifyH','SetJustifyV','SetShadowOffset','SetColorTexture','SetDrawLayer','SetHorizTile','SetVertTile',
 'SetTextureSliceMargins','SetTextureSliceMode','SetClipsChildren','SetClampedToScreen','SetMovable','RegisterForDrag',
 'StartMoving','StopMovingOrSizing','RegisterEvent','RegisterForClicks','SetFrameStrata','EnableMouse','EnableMouseWheel',
 'SetRotation','AddMaskTexture','SetTexelSnappingBias','SetSnapToPixelGrid','SetPropagateKeyboardInput','SetAutoFocus',
 'SetMultiLine','SetTextInsets','SetNumeric','SetNumber','ClearFocus','SetFocus'})do methods[n]=noop end
local UIParent=region();UIParent:SetSize(1600,1000)
local CK={L=setmetatable({},{__index=function(_,k)return k end}),db={settings={}},GetFontPath=function()return 'Fonts\\FRIZQT__.TTF'end}
CK.NewFrame=function(kind,name,parent,template)local f=region(kind,parent,name);f.template=template;return f end
CK.SetGlyph=function(_,texture,key)texture:SetTexture('glyph:'..key)end
CK.Paddles={SetIcon=function(icon,texture)icon:SetShown(texture~=nil);if texture then icon:SetTexture(texture)end end,StopCapture=noop}
local chromeCalls={}
local env=setmetatable({UIParent=UIParent,format=string.format,CreateFrame=CK.NewFrame,GetTime=function()return 1 end,
 C_Timer={After=noop},InCombatLockdown=function()return false end,GetCursorPosition=function()return 0,0 end,
 C_Texture={GetAtlasInfo=function()return {width=169,height=69}end},
 Enum={UITextureSliceMode={Stretched=0}},NineSliceUtil={ApplyLayoutByName=function(f,name)chromeCalls[#chromeCalls+1]={frame=f,name=name}end},
 ClearOverrideBindings=noop,SetOverrideBindingClick=noop,IsKeyDown=function()return false end,
 GetCVar=function()return ''end,STANDARD_TEXT_FONT='Fonts\\ARIALN.TTF'}, {__index=_G})
env._G=env
local function loadAddon(path)local f=assert(loadfile(path));setfenv(f,env);f('EasyController',CK)end
loadAddon('UI.lua');loadAddon('ConfigKit.lua');loadAddon('ConfigWindow.lua')
local C,K=CK.Config,CK.ConfigKit
local errors,checks={},0
local function test(name,fn)
 local priorScale=metricScale;local ok,err=pcall(fn);metricScale=priorScale;checks=checks+1
 if ok then print('PASS: '..name)else errors[#errors+1]=name..': '..tostring(err);print('FAIL: '..errors[#errors])end
end
local function rect(r)local x,w=axis(r,1);local y,h=axis(r,2);return{x=x,y=y,w=w,h=h}end
local function inside(child,parent,label)
 local a,b=rect(child),rect(parent);assert(a.w>=0 and a.h>=0,label..' has negative extent')
 assert(a.x>=b.x-.2 and a.y>=b.y-.2 and a.x+a.w<=b.x+b.w+.2 and a.y+a.h<=b.y+b.h+.2,label..' escapes its container')
end
local function apart(a,b,label)
 a,b=rect(a),rect(b)
 assert(a.x+a.w<=b.x+.2 or b.x+b.w<=a.x+.2 or a.y+a.h<=b.y+.2 or b.y+b.h<=a.y+.2,label..' overlaps')
end
local function textFits(label,owner,description)
 if not label or not label:IsShown() or label:GetText()==''then return end
 inside(label,owner,description)
 assert(label:GetStringHeight()<=label:GetHeight()+.2,description..' clips wrapped text vertically: needs '..label:GetStringHeight()..'px in '..label:GetHeight()..'px at width '..label:GetWidth()..', metric scale '..metricScale)
end
local host=region('Frame',UIParent);host:SetSize(784,420)
local originalRender=C.Render
C.Render=noop
local rows={
 {kind='check',id='check',label='Wide WWW labels should wrap without crossing the enabled status or check box',status='Enabled for every character',get=true,set=noop},
 {kind='choice',id='choice',label='Alternate controller targeting and interaction settings with long localized wording',text='Wide selection WWW',step=noop},
 {kind='event',id='event',label='Vibration when hostile enemies begin attacking this character',on=true,pattern='Pulse twice',toggle=noop,step=noop},
 {kind='slider',id='slider',label='Intensity for both controller vibration motors and additional impact feedback',get=.5,min=0,max=1,set=noop},
 {kind='value',id='value',label='Controller shortcut with both held trigger modifiers',text='LT + RT + Right shoulder',onA=noop},
 {kind='stat',label='Current character and realm',text='WMMMM-ExtremelyWideRealmName'},
 {kind='button',id='button',label='Copy bindings into the selected character profile after checking the saved source',func=noop},
}
local page=C.NewRailPage({key='stress',sections={{key='rows',label='Settings',rows=function(b)
 for _,r in ipairs(rows)do local v={};for k,x in pairs(r)do if k~='kind'then v[k]=x end end;b[r.kind](v)end
end}}});page:Build(host)
test('variable-width wrapped rows stay inside their controls and paginate around focus',function()
 for _,scale in ipairs({1,1.3})do
  metricScale=scale
  for i=1,#rows do
   page:Rebuild();if rows[i].id then page:SetFocus(i)end;page:Render()
   local focus=page:FocusIndex();local found=false;local previous
   for _,r in ipairs(page.rowsUI)do if r:IsShown()then
    if r.index==focus then found=true end
    inside(r,page.list,'visible row');if previous then apart(previous,r,'visible rows')end;previous=r
    for _,pair in ipairs({{'label',r},{'status',r},{'stat',r},{'info',r}})do textFits(r[pair[1]],pair[2],pair[1])end
    if r.btn:IsShown()then textFits(r.btn.label,r.btn,'button label')end
    if r.label:IsShown()then for _,control in ipairs({r.box,r.choice,r.slider,r.chip,r.stat,r.status})do if control:IsShown()then apart(r.label,control,'setting label/control')end end end
   end end
   assert(found,'focused row was dropped by pagination')
  end
 end
 metricScale=1
end)
test('a truncated choice keeps its complete value and existing help reachable in detail',function()
 local priorText,priorExtra,priorTip=rows[2].text,rows[2].extra,rows[2].tip
 local complete='Selected controller behavior: '..string.rep('WWW full value with narrow iii characters. ',24)
 rows[2].text=function()return complete end
 rows[2].extra='Existing additional guidance'
 rows[2].tip='Help about choosing this controller behavior.'
 page.zone='list';page:Rebuild();page:SetFocus(2);page:Render()
 assert(page.detail.extra:GetText()==rows[2].extra..'\n\n'..complete,'detail must preserve the full resolved value and earlier extra text')
 assert(page.detail.body:GetText()==rows[2].tip,'value detail replaced the setting help')
 assert(page.detail:CanScroll(),'long full value must remain reachable below the detail viewport')
 page.detail:Scroll(10000)
 assert(page.detail.viewport:GetVerticalScroll()+page.detail.viewport:GetHeight()>=page.detail.scrollChild:GetHeight()-.1,'the final value lines cannot be reached')
 rows[2].text,rows[2].extra,rows[2].tip=priorText,priorExtra,priorTip
end)
local known={{action='spell:1',name='Windswept Wall of Unbreakable Ancient Guardian Protection'}}
CK.Mapping={INPUTS={{id='LT',layer=true},{id='L4'},{id='L5'}},Catalog=function()return known end,
 ActionName=function()return known[1].name end,ActionIcon=function()return 132219 end,TakeSnapshot=noop,DropSnapshot=noop,Apply=noop}
CK.Profiles={ready=true,ACTION_ROLES={{key='interrupt',name='Interrupt'},{key='defensive',name='Defensive'},{key='movement',name='Movement'},{key='heal',name='Heal'}},
 ROLES={{key='general',name='General'}},CharacterName=function()return 'WMMMM-ExtremelyWideRealmName'end,ActiveName=function()return 'General'end,
 RolePosition=function()return 'L4','LTRT'end,RoleAction=function()return 'spell:1'end,
 PreviewRole=function()return true,'Review this assignment before applying.'end,ApplyRole=function()return true end,
 Has=function()return true end,Sources=function()return{}end}
local rolePage=C.NewRailPage({key='home',sections={}});C.pages.home=rolePage
loadAddon('ProfileOptions.lua');rolePage:Build(host);rolePage.section=2
local cards=rolePage.def.sections[2].view
test('role cards keep long spell labels and both-trigger chords inside separate bounds',function()
 for _,scale in ipairs({1,1.2})do metricScale=scale;rolePage:Render()
  local previous
  for _,b in ipairs(cards.frame.cards)do
   inside(b,rolePage.list,'role card');if previous then apart(previous,b,'role cards')end;previous=b
   textFits(b.role,b,'role title');textFits(b.spell,b,'role spell');inside(b.combo,b,'both-trigger chord')
   apart(b.role,b.combo,'role title/chord');apart(b.spell,b.combo,'role spell/chord')
  end
  assert(rolePage.detail.title:GetText()==known[1].name,'detail must retain full spell name')
 end
 metricScale=1
end)
test('actual window delegates chrome once without changing its input owner',function()
 C.Render=originalRender;C:Build();assert(#chromeCalls==1 and chromeCalls[1].name=='ButtonFrameTemplateNoPortrait','native window chrome contract')
 assert(chromeCalls[1].frame==C.frame or chromeCalls[1].frame:GetParent()==C.frame,'chrome must belong to addon window')
 local close
 for _,child in ipairs(C.frame.children)do if child.template=='UIPanelCloseButtonNoScripts'then close=child end end
 assert(close and close.scripts.OnClick,'native close control keeps addon close callback')
 assert(named.ControllerKeyboardConfigPadPADRSTICK,'R3 must be bound through the existing addon input buttons')
 inside(C.frame.body,C.frame,'window content');apart(C.frame.title,C.frame.profile,'title/profile');apart(C.frame.profile,C.frame.tabs[1],'profile/tabs')
end)
test('R3 reads long detail text without activating the focused action or changing focus',function()
 C.tab='home';C.frame:Show();rolePage:Show();rolePage.section=1;rolePage:Render()
 rolePage.detail:Set({title='Readable long help',body=string.rep('Wide WWW explanatory text with words and line spacing. ',35),
  action={label='Apply safely',func=function()error('detail scrolling activated action')end}})
 local detail=rolePage.detail;assert(detail.CanScroll and detail:CanScroll(),'long detail requires scroll access')
 local before=rolePage:FocusIndex();C:Press('R3');assert(C.readingDetail,'R3 must enter detail reading')
 local scroll=detail.viewport:GetVerticalScroll()
 C:Press('DOWN');assert(rolePage:FocusIndex()==before,'detail scrolling moved row focus')
 local after=detail.viewport:GetVerticalScroll()
 assert(after>scroll,'D-pad down must advance detail content')
 C:Press('B');assert(not C.readingDetail and C.frame:IsShown(),'B must exit reading without closing config')
end)
test('native close exits detail reading before reopening the window',function()
 C.tab='home';C.frame:Show();rolePage:Show();rolePage.section=1;rolePage:Render()
 rolePage.detail:Set({title='Long closing help',body=string.rep('Scrollable explanatory text. ',80)})
 C:Press('R3');assert(C.readingDetail,'detail reading must enter before close test')
 local close
 for _,child in ipairs(C.frame.children)do if child.template=='UIPanelCloseButtonNoScripts'then close=child end end
 close:Fire('OnClick')
 assert(not C.frame:IsShown(),'native close did not close the addon window')
 CK.BlockedByCombat=function()return false end;C:Open('home','profiles')
 local before=rolePage:FocusIndex();C:Press('DOWN')
 assert(rolePage:FocusIndex()~=before,'reopening retained detail reading and diverted row navigation')
 assert(not C.readingDetail,'native close retained detail reading mode for the next open')
end)
if #errors>0 then error(table.concat(errors,'\n'))end
print('PASS: '..checks..' real configuration layout groups; font metrics are synthetic, not in-game screenshot acceptance')
