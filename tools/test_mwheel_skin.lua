-- Actual MyWheels editor Build: native material/rim selection and the existing
-- eight click targets; frame primitives are the only rendering substitute.
local function noop()end
local methods={}
local function region(parent)return setmetatable({parent=parent,scripts={},children={},shown=true},{__index=methods})end
function methods:CreateTexture()local t=region(self);self.children[#self.children+1]=t;return t end
methods.CreateMaskTexture=methods.CreateTexture
methods.CreateFontString=methods.CreateTexture
function methods:SetTexture(v)self.texture=v end
function methods:SetAtlas(v,useSize)self.atlas,self.useAtlasSize=v,useSize end
function methods:SetColorTexture(...)self.color={...}end
function methods:SetVertexColor(...)self.vertex={...}end
function methods:SetSize(w,h)self.width,self.height=w,h end
function methods:SetWidth(w)self.width=w end
function methods:SetHeight(h)self.height=h end
function methods:SetPoint(...)self.point={...}end
function methods:SetText(v)self.text=v end
function methods:SetScript(k,f)self.scripts[k]=f end
function methods:Fire(k,...)self.scripts[k](self,...)end
function methods:Hide()self.shown=false end
function methods:Show()self.shown=true end
function methods:GetFrameLevel()return 1 end
for _,n in ipairs({'SetAllPoints','SetJustifyH','SetMaxLines','SetWordWrap','SetFrameLevel','EnableMouse',
    'SetFont','SetTextColor','SetTextInsets','SetAutoFocus','SetMaxLetters','SetSpacing','SetPoints','SetColors',
    'SetHorizTile','SetVertTile','AddMaskTexture'})do methods[n]=noop end
function methods:SetWordWrap(v)self.wordWrap=v end
function methods:SetNonSpaceWrap(v)self.nonSpaceWrap=v end
function methods:SetMaxLines(v)self.maxLines=v end
local native=true
local K={C=setmetatable({},{__index=function()return {1,1,1}end}),TEX='textures/',Upper=function(v)return v end}
for _,n in ipairs({'Text','ChatText','Solid','Box','Slot','Button','Picker'})do K[n]=function(p)return region(p)end end
K.Picker=function(parent,width)local r=region(parent);r:SetWidth(width);return r end
local CK={L=setmetatable({},{__index=function(_,k)return k end}),ConfigKit=K,Config={Disarm=noop},
    GetFontPath=function()return 'Fonts/FRIZQT__.TTF'end,NewFrame=function(_,_,p)return region(p)end}
local env=setmetatable({C_Texture={GetAtlasInfo=function()return native and {} or nil end}},{__index=_G});env._G=env
local chunk=assert(loadfile('MyWheels.lua'));setfenv(chunk,env);chunk('EasyController',CK)
local E=CK.MyWheels.Editor;E:Build(region())
assert(E.frame.face and E.frame.face.color[4]==1,'editor needs an opaque face instead of the old transparent disc')
local f=E.frame
assert(f.face.width==272 and f.faceArt.texture=='textures/ck_panel_bg' and f.faceMask.atlas=='ui-hud-minimap-frame-generic-mask',
    'editor face needs the native minimap mask sized inside the bronze rim, without square edge cuts')
assert(f.rim.atlas=='UI-HUD-Minimap-Frame-Circle' and f.rim.useAtlasSize==false and f.rim.width==347)
assert(f.hub.width==100 and f.hub.atlas=='ui-hud-minimap-frame-generic-mask' and f.hubRim.width==128 and f.hubRim.atlas=='UI-HUD-Minimap-Frame-Circle')
assert(f.face.point[4]==240 and f.face.point[5]==-186 and f.rim.point[4]==240 and f.rim.point[5]==-186)
assert(#f.slots==8 and #f.labels==8 and #f.buttons==3 and E.picker.width==292 and E.picker.height==424)
assert(f.slots[1].point[4]==240 and f.slots[1].point[5]==-78)
assert(math.abs(f.slots[3].point[4]-348)<.001 and math.abs(f.slots[3].point[5]+186)<.001)
assert(f.labels[1].width==100 and f.labels[1].height==32)
assert(f.name.width==86 and f.name.height==18 and f.name.wordWrap and f.name.nonSpaceWrap and f.name.maxLines==1,
    'editor hub title must remain inside the inner bevel even for a long unbroken name')
local aimed,emptied=0,0
E.Aim=function()aimed=aimed+1 end;E.Empty=function()emptied=emptied+1 end
f.slots[3]:Fire('OnClick','LeftButton');assert(E.slot==3 and aimed==1 and emptied==0)
f.slots[8]:Fire('OnClick','RightButton');assert(E.slot==8 and aimed==1 and emptied==1)
CK.MyWheels.renaming=true;f.slots[1]:Fire('OnClick','LeftButton');assert(E.slot==8 and aimed==1)
print('PASS: actual editor opaque native material, padded rims, unchanged eight slot positions/labels and mouse/rename guards')
native=false;E:Build(region());f=E.frame
assert(f.face.color[4]==1 and f.faceArt.texture=='textures/ck_panel_bg')
assert(not f.rim.atlas and f.faceMask.texture=='Interface\\CharacterFrame\\TempPortraitAlphaMask')
print('PASS: clients missing the native atlas retain an opaque masked editor face without invalid atlas calls')
