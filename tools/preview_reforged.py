"""Render the actual Reforged exports at the Lua UI's dimensions, at 2x.

This is a deterministic Pillow reconstruction, not a game screenshot. Text
uses a local Friz font when available, otherwise explicitly reported Georgia.
No game scene, action bar, or hypothetical controls are drawn. The explicitly
labeled stress fixture uses installed-client spell icons and synthetic text.
Run after Blender has written design/reforged/manifest.json and png/:
    python tools/preview_reforged.py [--output design/reforged/preview]
"""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
NATIVE = ROOT.parent / "native-wow"
FOREVER = ROOT.parent / "forever-wow"
SCALE = 2
COLORS = {
    "title": "#F2C43C", "focus": "#FFD24A", "focusText": "#FFF3D0",
    "cream": "#EFE4C8", "cream2": "#D8CCB0", "tab": "#E6DCC4",
    "rail": "#CBBD9C", "help": "#B9AB8C", "grey": "#9D917A",
    "disabled": "#6F6452", "line1": "#5A4630", "line3": "#3A2C1D",
}


def find_fonts():
    native_friz = NATIVE / "raw" / "Fonts" / "FRIZQT__.TTF"
    friz = native_friz if native_friz.is_file() else next((p for p in ROOT.rglob("*.ttf") if p.name.lower() == "frizqt__.ttf"), None)
    if friz is None:
        friz = next((p for p in ROOT.rglob("*.TTF") if p.name.lower() == "frizqt__.ttf"), None)
    georgia = Path("C:/Windows/Fonts/georgia.ttf")
    native_body = NATIVE / "raw" / "Fonts" / "ARIALN.TTF"
    body = native_body if native_body.is_file() else Path("C:/Windows/Fonts/arial.ttf")
    heading = friz or georgia
    if not heading.is_file() or not body.is_file():
        raise ValueError("A local Friz/Windows Georgia font and Windows Arial are required.")
    label = "Installed client Friz Quadrata" if friz == native_friz else "Local Friz Quadrata" if friz else "Georgia fallback"
    label += "; installed client Arial Narrow" if body == native_body else "; Windows Arial body fallback"
    return heading, body, label


def nine_slice(source, size, source_corner, display_corner):
    """Mirror UI.lua nineSlice: fixed corners, stretched edges and center."""
    w, h = [round(v * SCALE) for v in size]
    c = round(display_corner * SCALE)
    sw, sh = source.size
    if min(w, h) < 2 * c:
        raise ValueError(f"Nine-slice destination too small: {size}")
    out = Image.new("RGBA", (w, h))
    sx, sy = (0, source_corner, sw - source_corner, sw), (0, source_corner, sh - source_corner, sh)
    dx, dy = (0, c, w - c, w), (0, c, h - c, h)
    for row in range(3):
        for col in range(3):
            part = source.crop((sx[col], sy[row], sx[col + 1], sy[row + 1]))
            part = part.resize((dx[col + 1] - dx[col], dy[row + 1] - dy[row]), Image.Resampling.BILINEAR)
            out.alpha_composite(part, (dx[col], dy[row]))
    return out


class Preview:
    def __init__(self, folder):
        self.folder = folder
        self.manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8-sig"))
        self.entries = {e["name"]: e for e in self.manifest["assets"]}
        self.assets = {}
        self.used = set()
        for name, entry in self.entries.items():
            path = folder / "png" / f"{name}.png"
            with Image.open(path) as source:
                if source.mode != "RGBA" or source.size != (entry["width"], entry["height"]):
                    raise ValueError(f"Manifest/PNG mismatch: {name}")
                if source.getchannel("A").getbbox() is None:
                    raise ValueError(f"Empty texture: {name}")
                self.assets[name] = source.copy()
        self.font_path, self.body_font_path, self.font_note = find_fonts()
        core = (ROOT / "Core.lua").read_text(encoding="utf-8-sig")
        self.labels = {}
        for key, value in re.findall(r'^\s*([A-Z][A-Z_0-9]*)\s*=\s*"([^"\n]*)"', core, re.M):
            self.labels.setdefault(key, value)
        keyboard_source = (ROOT / "StickKeyboard.lua").read_text(encoding="utf-8-sig")
        pressed = re.search(r'pressed\s*=\s*\{([\d.,\s]+)\}', keyboard_source)
        if not pressed:
            raise ValueError("Cannot read StickKeyboard.lua pressed text color")
        self.key_pressed_color = tuple(round(float(v.strip()) * 255) for v in pressed[1].split(",") if v.strip())
        self.text_checks = []
        self.native_used = {}
        self.atlas_cache = {}
        atlas_data = json.loads((FOREVER / "atlas-map.json").read_text(encoding="utf-8"))
        self.atlases = {name.lower(): value for name, value in atlas_data["atlases"].items()}
        provenance = json.loads((FOREVER / "provenance.json").read_text(encoding="utf-8-sig"))
        self.native_files = {item["fileDataId"]: item for item in provenance["assets"]}
        editor_source=(ROOT/"MyWheels.lua").read_text(encoding="utf-8-sig")
        title_size=re.search(r'f\.name:SetSize\((\d+),\s*(\d+)\)',editor_source)
        if not title_size: raise ValueError("Cannot read MyWheels editor title size")
        self.editor_title_width,self.editor_title_height=map(int,title_size.groups())
        for contract in ("f.name:SetWordWrap(true)","f.name:SetNonSpaceWrap(true)","f.name:SetMaxLines(1)"):
            if contract not in editor_source: raise ValueError("Missing editor title contract: "+contract)
        wheel_source=(ROOT/"Wheel.lua").read_text(encoding="utf-8-sig")
        wheel_sizes=re.search(r'local RIM_SIZE, FACE_SIZE, HUB_RIM_SIZE, HUB_FACE_SIZE\s*=\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)',wheel_source)
        wheel_alpha=re.search(r'local DIM_ALPHA\s*=\s*([\d.]+)',wheel_source)
        if not wheel_sizes or not wheel_alpha: raise ValueError("Cannot read native chat wheel geometry")
        self.chat_geometry=dict(zip(("rim","face","hubRim","hubFace"),map(int,wheel_sizes.groups())))
        self.chat_geometry["inactiveAlpha"]=float(wheel_alpha[1])

    def canvas(self, size, color=(15, 13, 11, 255)):
        return Image.new("RGBA", tuple(round(n * SCALE) for n in size), color)

    def asset(self, name):
        self.used.add(name)
        return self.assets[name]

    def slice(self, canvas, name, box, corner=None, alpha=1):
        x, y, w, h = box
        entry = self.entries[name]
        src = entry.get("nineSliceCorner") or 0
        part = nine_slice(self.asset(name), (w, h), src, src if corner is None else corner)
        if alpha != 1:
            part.putalpha(part.getchannel("A").point(lambda v: round(v * alpha)))
        canvas.alpha_composite(part, (round(x * SCALE), round(y * SCALE)))

    def tile(self, canvas, name, box):
        x, y, w, h = box
        tile = self.asset(name)
        tile = tile.resize((tile.width * SCALE, tile.height * SCALE), Image.Resampling.NEAREST)
        region = Image.new("RGBA", (round(w * SCALE), round(h * SCALE)))
        for yy in range(0, region.height, tile.height):
            for xx in range(0, region.width, tile.width):
                region.alpha_composite(tile, (xx, yy))
        canvas.alpha_composite(region, (round(x * SCALE), round(y * SCALE)))

    def font(self, size, body=False):
        return ImageFont.truetype(str(self.body_font_path if body else self.font_path), round(size * SCALE))

    def width(self, text, size, body=False):
        return self.font(size, body).getlength(text) / SCALE

    def text(self, canvas, text, xy, size=16, color="cream", anchor="lt", body=False, max_width=None, shadow=True, ellipsis=False):
        color = COLORS.get(color, color)
        font = self.font(size, body)
        if max_width is not None:
            measured = font.getlength(text) / SCALE
            self.text_checks.append({"text": text, "size": size, "width": round(measured, 2),
                                     "budget": max_width, "overflows": measured > max_width,
                                     "explicitEllipsis": ellipsis})
        if max_width is not None and ellipsis:
            while text and font.getlength(text) > max_width * SCALE:
                text = text[:-2].rstrip() + "…" if len(text) > 2 else ""
        pos = tuple(round(n * SCALE) for n in xy)
        draw = ImageDraw.Draw(canvas)
        if shadow:
            draw.text((pos[0] + SCALE, pos[1] + SCALE), text, font=font, fill="#000000", anchor=anchor)
        draw.text(pos, text, font=font, fill=color, anchor=anchor)

    def wrap_lines(self, text, width, size, body=False):
        lines = []
        for paragraph in text.split("\n"):
            current = ""
            for word in paragraph.split():
                trial = (current + " " + word).strip()
                if current and self.width(trial, size, body) > width:
                    lines.append(current)
                    current = word
                else:
                    current = trial
            lines.append(current)
        return lines

    def wrapped(self, canvas, text, box, size, color="cream", body=False, spacing=3,
                centered=False, shadow=True, max_lines=None):
        """Word-wrap within a real Lua text region; never silently ellipsize."""
        x, y, width, height = box
        lines = self.wrap_lines(text, width, size, body)
        required = len(lines)*size + max(0, len(lines)-1)*spacing
        self.text_checks.append({"text": text, "size": size, "height": required,
                                 "heightBudget": height, "lineCount": len(lines),
                                 "lineBudget": max_lines, "overflows": required > height or
                                 (max_lines is not None and len(lines) > max_lines)})
        # Let an actual overflow remain visible in the reconstruction and report.
        for index, line in enumerate(lines):
            self.text(canvas, line, (x+width/2 if centered else x, y+index*(size+spacing)),
                      size, color, "mt" if centered else "lt", body, width, shadow)
        return required

    def native_atlas(self, name):
        if name in self.atlas_cache:
            return self.atlas_cache[name]
        entry = self.atlases[name.lower()]
        variant = entry.get("preferredC60")
        if variant is None:
            variant = next((v for v in entry["variants"] if "2x" in v["committedName"].lower()), entry["variants"][0])
        record = self.native_files[variant["fileDataID"]]
        path = Path(record["pngFile"])
        with Image.open(path) as source:
            art = source.convert("RGBA").crop(variant["crop"])
        if not art.getchannel("A").getbbox():
            raise ValueError(f"Empty native atlas: {name}")
        display = variant["suggestedDisplaySize"]
        self.native_used[name] = {"fileDataID": variant["fileDataID"], "memberID": variant["memberID"],
                                 "crop": variant["crop"], "canvasID": variant["canvasID"],
                                 "memberCanvasID": variant["memberCanvasID"], "displaySize": display,
                                 "slice": entry.get("slice"), "pngSha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        self.atlas_cache[name] = art, display, entry
        return self.atlas_cache[name]

    def native(self, canvas, name, box, sliced=False, tile_x=False, tile_y=False, brightness=1):
        x, y, width, height = box
        source, display, entry = self.native_atlas(name)
        size = round(width*SCALE), round(height*SCALE)
        if sliced and entry.get("slice"):
            margins = entry["slice"]
            left, top, right, bottom = [margins[k] for k in ("Left", "Top", "Right", "Bottom")]
            if left+right > width or top+bottom > height:
                raise ValueError(f"Native fixed margins exceed destination: {name} -> {box}")
            fx, fy = source.width/display[0], source.height/display[1]
            sx, sy = [0, round(left*fx), source.width-round(right*fx), source.width], [0, round(top*fy), source.height-round(bottom*fy), source.height]
            dx, dy = [0, round(left*SCALE), size[0]-round(right*SCALE), size[0]], [0, round(top*SCALE), size[1]-round(bottom*SCALE), size[1]]
            part = Image.new("RGBA", size)
            for row in range(3):
                for col in range(3):
                    target = dx[col+1]-dx[col], dy[row+1]-dy[row]
                    if min(target) <= 0:
                        continue
                    crop = source.crop((sx[col], sy[row], sx[col+1], sy[row+1]))
                    part.alpha_composite(crop.resize(target, Image.Resampling.BILINEAR), (dx[col], dy[row]))
        elif tile_x or tile_y:
            tile = source.resize((round(display[0]*SCALE) if tile_x else size[0],
                                  round(display[1]*SCALE) if tile_y else size[1]), Image.Resampling.BILINEAR)
            part = Image.new("RGBA", size)
            for yy in range(0, size[1], tile.height):
                for xx in range(0, size[0], tile.width):
                    part.alpha_composite(tile, (xx, yy))
        else:
            part = source.resize(size, Image.Resampling.BILINEAR)
        if brightness != 1:
            from PIL import ImageEnhance
            rgb = ImageEnhance.Brightness(part.convert("RGB")).enhance(brightness)
            rgb.putalpha(part.getchannel("A")); part = rgb
        canvas.alpha_composite(part, (round(x*SCALE), round(y*SCALE)))

    def native_metal_frame(self):
        # ButtonFrameTemplateNoPortrait, including installed Camelot offsets.
        # Native2x atlas geometry is normalized against UiCanvas2:1 dimensions.
        im = self.canvas((830, 604))
        ox, oy = 8, 16
        self.tile(im, "ck_panel_bg", (ox+4, oy+21, 812, 555))
        pieces = [
            ("UI-Frame-Metal-CornerTopLeft", (-8,-16,95,95),False,False),
            ("UI-Frame-Metal-CornerTopRight", (727,-16,95,95),False,False),
            ("UI-Frame-Metal-CornerBottomLeft", (-8,488,95,100),False,False),
            ("UI-Frame-Metal-CornerBottomRight", (727,488,95,100),False,False),
            ("_UI-Frame-Metal-EdgeTop", (87,-16,640,95),True,False),
            ("_UI-Frame-Metal-EdgeBottom", (87,488,640,100),True,False),
            ("!UI-Frame-Metal-EdgeLeft", (-8,79,95,409),False,True),
            ("!UI-Frame-Metal-EdgeRight", (727,79,95,409),False,True),
        ]
        for name, (x,y,w,h), horizontal, vertical in pieces:
            self.native(im, name, (x+ox,y+oy,w,h), tile_x=horizontal, tile_y=vertical)
        return im

    def paragraph(self, canvas, text, xy, width, size=14, color="help", spacing=6, body=True, shadow=True):
        words, lines, current = text.split(), [], ""
        for word in words:
            trial = f"{current} {word}".strip()
            if current and self.width(trial, size, body) > width:
                lines.append(current)
                current = word
            else:
                current = trial
        if current:
            lines.append(current)
        for i, line in enumerate(lines):
            self.text(canvas, line, (xy[0], xy[1] + i * (size + spacing)), size, color, body=body, shadow=shadow)
        return len(lines) * size + max(0, len(lines) - 1) * spacing

    def line(self, canvas, box, color="line3", width=1):
        ImageDraw.Draw(canvas).line(tuple(round(n * SCALE) for n in box), fill=COLORS.get(color, color), width=round(width * SCALE))

    def well(self, canvas, box, fill="#0F0B07", edge="#6B5235"):
        x, y, w, h = box
        ImageDraw.Draw(canvas).rounded_rectangle(tuple(round(n * SCALE) for n in (x, y, x + w - 1, y + h - 1)),
                                                radius=4 * SCALE, fill=fill, outline=edge, width=SCALE)

    def panel(self, canvas, box):
        self.tile(canvas, "ck_panel_bg", box)
        self.slice(canvas, "ck_reforged_frame", box, corner=12)

    def button(self, canvas, label, box, state="normal", size=16, disabled=False):
        x, y, w, h = box
        part = self.canvas((w,h), (0,0,0,0))
        self.slice(part, f"ck_btn_{state}", (0,0,w,h))
        self.text(part, label, (w / 2, h / 2), size,
                  "disabled" if disabled else "focus" if state == "active" else "tab", "mm", max_width=w - 12)
        if disabled:
            part.putalpha(part.getchannel("A").point(lambda v:round(v*.45)))
        canvas.alpha_composite(part,(round(x*SCALE),round(y*SCALE)))

    def glyph(self, canvas, key, xy, size=30):
        # Actual fallback glyph texture used by Glyphs.lua; no invented symbols.
        key = {"dpad_down": "dpad", "dpad_left": "dpad_lr", "dpad_right": "dpad_lr"}.get(key, key)
        path = ROOT / "design" / "textures" / f"ck_g_{key.lower()}.png"
        if not path.is_file():
            raise ValueError(f"Missing repo glyph: {key}")
        with Image.open(path) as im:
            canvas.alpha_composite(im.convert("RGBA").resize((size * SCALE, size * SCALE), Image.Resampling.BILINEAR),
                                   tuple(round(n * SCALE) for n in xy))

    def flat(self, canvas, name, box):
        x,y,w,h=box
        canvas.alpha_composite(self.asset(name).resize((round(w*SCALE),round(h*SCALE)),Image.Resampling.BILINEAR),
                               (round(x*SCALE),round(y*SCALE)))

    def chip(self,canvas,label,xy,size=20,align="left"):
        # K.Glyph uses the repo's ck_chip texture for paddle names.
        font_size=max(9,int(size*.38))
        height=int(size*.72+.5)
        width=max(size*.75,self.width(label,font_size,True)+height*.6)
        x,y=xy
        if align=="center": x-=(width+1)/2
        if align=="right": x-=width+1
        path=ROOT/"textures"/"ck_chip.tga"
        with Image.open(path) as source:
            source=source.convert("RGBA")
            piece=Image.new("RGBA",(round(width*SCALE),height*SCALE))
            bounds=[0,height/2,width-height/2,width]
            for i,(left,right) in enumerate(((0,22),(22,42),(42,64))):
                start,end=round(bounds[i]*SCALE),round(bounds[i+1]*SCALE)
                piece.alpha_composite(source.crop((left,10,right,54)).resize((end-start,height*SCALE),Image.Resampling.BILINEAR),(start,0))
            canvas.alpha_composite(piece,(round(x*SCALE),round((y+(size-height)/2)*SCALE)))
        self.text(canvas,label,(x+width/2,y+size/2),font_size,"#FFFFFF","mm",body=True)
        return width

    def combo_width(self, keys, size):
        width = 0
        for key in keys:
            if key == "+":
                width += self.width("+",16) + 4
            elif key.upper() in ("L4","L5","R4","R5","SELECT","START"):
                h = int(size*.72+.5)
                width += max(size*.75,self.width(key,max(9,int(size*.38)),True)+h*.6)+1
            else:
                width += size+1
        return width

    def combo(self, canvas, keys, xy, size=22, align="left"):
        width = self.combo_width(keys,size)
        x,y = xy
        if align == "right": x -= width
        elif align == "center": x -= width/2
        for key in keys:
            if key == "+":
                self.text(canvas,"+",(x+2,y+size/2),16,"cream","lm")
                x += self.width("+",16)+4
            elif key.upper() in ("L4","L5","R4","R5","SELECT","START"):
                x += self.chip(canvas,key,(x,y),size)+1
            else:
                self.glyph(canvas,key.lower(),(x,y),size)
                x += size+1
        return width

    def native_button(self, canvas, label, box, state="normal", size=14, role=False):
        x,y,w,h = box
        family = "common-button-list-" + ("large" if role else "small" if h <= 34 else "mid")
        on = state in ("active", "active_pressed")
        pressed = state in ("pressed", "active_pressed")
        atlas = family + ("-hover" if state == "hover" or (on and not role) else "")
        self.native(canvas,atlas,box,sliced=True,brightness=.7 if pressed else 1)
        if on and role:
            self.native(canvas,family+"-selected",box,sliced=True,brightness=.7 if pressed else 1)
        if label is not None:
            self.text(canvas,label,(x+w/2,y+h/2),size,"focus" if on else "tab","mm",max_width=w-12)

    def spell_icon(self, canvas, name, box):
        with Image.open(NATIVE/"png"/"Interface"/"ICONS"/(name+".png")) as source:
            # Numeric spell icons use Paddles.SetIcon's0.08..0.92 inset.
            w,h = source.size
            source = source.convert("RGBA").crop((round(w*.08),round(h*.08),round(w*.92),round(h*.92)))
            x,y,ww,hh = box
            source=source.resize((round(ww*SCALE),round(hh*SCALE)),Image.Resampling.BILINEAR)
            mask=self.mask("SquareMask",source.size)
            source.putalpha(ImageChops.multiply(source.getchannel("A"),mask))
            canvas.alpha_composite(source,(round(x*SCALE),round(y*SCALE)))

    def mask(self,name,size):
        source=self.native_atlas(name)[0]
        # SquareMask stores its shape in RGB with opaque alpha. CircleMask has
        # meaningful alpha; its compressed off-white RGB must not weaken opacity.
        alpha=source.getchannel("A")
        shape=source.getchannel("R") if alpha.getextrema()==(255,255) else alpha
        return shape.resize(size,Image.Resampling.BILINEAR)

    def detail(self, canvas, role, keys, spell=None, icon=None, message=None, scroll=0):
        x,y,w,h = 570,104,232,420
        self.slice(canvas,"ck_reforged_parchment",(x,y,w,h),corner=12)
        self.native(canvas,"common-insideframe",(x,y,w,h),sliced=True)
        inner, viewport_h = 204,328
        child = self.canvas((inner,2400),(0,0,0,0))
        top = 0
        if icon:
            self.spell_icon(child,icon,((inner-50)/2,top,50,50)); top += 59
        def block(text,size,spacing,color="#493421",body=True,gap=9):
            nonlocal top
            if top and not (icon and top==59): top += gap
            lines = self.wrap_lines(text,inner,size,body)
            height = len(lines)*size+max(0,len(lines)-1)*spacing
            self.wrapped(child,text,(0,top,inner,height),size,color,body,spacing,True,False)
            top += height
        block(spell or "Choose a spell",16,3,"#3D2515",False,gap=0)
        top += 7
        self.combo(child,keys,(inner/2,top),26,align="center"); top += 26
        block(role,13,0,gap=7)
        block(message or "Choose an ability from this character's spellbook.",13,4)
        maximum = max(0,top-viewport_h)
        offset = min(maximum,max(0,scroll))
        viewport = child.crop((0,round(offset*SCALE),inner*SCALE,round((offset+viewport_h)*SCALE)))
        canvas.alpha_composite(viewport,((x+14)*SCALE,(y+14)*SCALE))
        if maximum:
            self.text(canvas,f"{int(offset/maximum*100+.5)}%",(x+w/2,y+h-60-11),11,"#493421","mt",body=True,shadow=False)
        self.button(canvas,"Apply "+role,(x+14,y+h-14-34,204,34),size=14,disabled=True)
        self.text_checks.append({"region":"detail viewport","contentHeight":top,"viewportHeight":viewport_h,
                                 "scrollRange":maximum,"scrollOffset":offset,"overflows":False,
                                 "policy":"Actual ScrollFrame clips its child; Apply stays outside"})
        return maximum

    def config(self, stress=False, reading=False, scroll=0):
        # Current ConfigWindow/ProfileOptions geometry; test strings are not saved game data.
        im = self.canvas((820,580),(0,0,0,0))
        self.text(im,"Easy Controller",(410,5),18,"title","mt",max_width=680)
        profile = "Profile: General" if not stress else ("Profile: synthetic long-profile text fixture — " + "Controller configuration and accessibility testing "*5)
        self.text(im,profile,(410,37),12,"cream2","mt",body=True,max_width=700,ellipsis=True)
        self.glyph(im,"lb",(49,65),24); self.glyph(im,"rb",(747,65),24)
        for i,key in enumerate(("HOME","GAMEPAD","WHEELS","KEYBOARD","ALERTS")):
            self.native_button(im,self.labels[f"TAB_{key}"],(83+i*132,62,126,30),"active" if i==0 else "normal")
        shade = self.canvas((140,420),(0,0,0,56))
        im.alpha_composite(shade,(18*SCALE,104*SCALE))
        self.line(im,(157,104,157,524),"#4A3A26")
        sections = [self.labels[k] for k in ("SEC_MODULES","SEC_SHORTCUT","SEC_LOOK","TAB_GAMEPAD","SEC_AUTOMATION")]+["Profiles","Role layout"]
        for i,label in enumerate(sections):
            yy = 112+i*48
            self.native_button(im,None,(26,yy,124,44),"active" if i==6 else "normal")
            self.text(im,label,(49,yy+22),13,"focus" if i==6 else "tab","lm",max_width=96)
            if i==6:
                ImageDraw.Draw(im).polygon([(36*SCALE,(yy+18.5)*SCALE),(43*SCALE,(yy+22)*SCALE),(36*SCALE,(yy+25.5)*SCALE)],fill=COLORS["title"])
        self.text(im,"Role layout",(172,107),18,"title")
        roles = [("Interrupt",["L4"],None,None),("Defensive",["L5"],None,None),
                 ("Movement",["R4"],None,None),("Emergency heal",["R5"],None,None)]
        if stress:
            roles = [
                ("Interrupt",["LT","+","RT","+","L4"],"Shield Bash (Rank 4) — extended label fixture","Ability_Warrior_ShieldBash"),
                ("Defensive",["LT","+","L5"],"Shield Wall — extended spell-name layout fixture","Ability_Warrior_ShieldWall"),
                ("Movement",["RT","+","R4"],"Charge (Rank 3) — long label fixture","Ability_Warrior_Charge"),
                ("Emergency heal",["LT","+","RT","+","R5"],"Synthetic long ability label for emergency healing","Ability_Warrior_ShieldWall"),
            ]
        selected = 3 if stress else 0
        for i,(role,keys,spell,icon) in enumerate(roles):
            self.role_card(im,(170,140+i*80),role,keys,"active" if i==selected else "normal",spell,icon)
        self.native_button(im,"Button / trigger settings",(170,468,388,32),size=14)
        role,keys,spell,icon = roles[selected]
        message = None if not stress else ("Occupied by a synthetic long existing assignment. Enable Replace existing to continue. "
                  "This repeated text tests the detail scroll region, not a new controller feature. "*5)
        scroll_range = self.detail(im,role,keys,spell,icon,message,scroll)
        self.line(im,(2,536,818,536))
        hints = [(["dpad"],"Role"),(["a"],"Choose spell"),(["x"],"Binding"),(["y"],"Apply"),(["b"],"Back")]
        if reading: hints = [(["dpad"],"Scroll"),(["b"],"Back")]
        elif scroll_range: hints += [(["rs"],"Read")]
        self.footer(im,hints)
        full=self.native_metal_frame()
        full.alpha_composite(im,(8*SCALE,16*SCALE))
        self.native(full,"RedButton-Exit",(802,15,24,24))
        result=self.canvas((830,628))
        result.alpha_composite(full)
        caption="Reconstruction · synthetic long-text stress fixture · not character data or an in-game screenshot" if stress else "Reconstruction of the addon layout · empty General profile · not an in-game screenshot"
        self.text(result,caption,(12,610),11,"grey",body=True,max_width=806)
        return result

    def footer(self,canvas,hints,crumb="Home › Role layout"):
        # K.Hint/ConfigWindow.RenderHelp use proportional compression, two lines,
        # and hide the crumb when fewer than24 pixels remain. No silent ellipsis.
        dimensions = [(self.combo_width(keys,20),self.width(label,12)) for keys,label in hints]
        total = sum(glyph+6+text for glyph,text in dimensions)
        minimum = sum(glyph+7 for glyph,text in dimensions)
        room = 784-max(0,len(hints)-1)*12
        right = 802
        for (keys,label),(glyph,natural) in reversed(list(zip(hints,dimensions))):
            available = natural
            if total > room and total > minimum:
                share = (natural-1)/(total-minimum)
                available = min(natural,1+max(0,room-minimum)*share)
            width = glyph+6+available
            hx=right-width
            self.combo(canvas,keys,(hx,542),20)
            lines = self.wrap_lines(label,available,12)
            height = len(lines)*12
            self.wrapped(canvas,label,(hx+glyph+6,552-height/2,available,26),12,"cream",False,0,max_lines=2)
            right=hx-12
        crumb_room=right-18
        if crumb_room >24:
            self.text(canvas,crumb,(18,552),11,"grey","lm",body=True,max_width=min(200,crumb_room))

    def role_card(self,im,xy,role,keys,state,spell=None,icon=None):
        x,y=xy
        self.native_button(im,None,(x,y,388,72),state,role=True)
        if icon: self.spell_icon(im,icon,(x+12,y+18,36,36))
        cw=self.combo(im,keys,(x+376,y+25),22,align="right")
        tx=60 if spell else 16
        width=388-tx-cw-24
        self.text(im,role,(x+tx,y+12),16,"cream",max_width=width)
        self.wrapped(im,spell or "Choose a known spell",(x+tx,y+34,width,30),13,"cream2",True,0,max_lines=2)

    def masked_stone(self,canvas,box,circular=True,mask_name="CircleMask"):
        x,y,w,h=box
        backing=self.canvas((w,h),(14,10,6,255))
        material=self.canvas((w,h),(14,10,6,255))
        self.tile(material,"ck_panel_bg",(0,0,w,h))
        r,g,b,a=material.split()
        material=Image.merge("RGBA",(r.point(lambda v:round(v*.72)),g.point(lambda v:round(v*.62)),b.point(lambda v:round(v*.48)),a))
        if circular:
            mask=self.mask(mask_name,material.size)
            material.putalpha(ImageChops.multiply(material.getchannel("A"),mask))
            backing.putalpha(mask)
        canvas.alpha_composite(backing,(round(x*SCALE),round(y*SCALE)))
        canvas.alpha_composite(material,(round(x*SCALE),round(y*SCALE)))

    def wheel_slot(self,canvas,icon,center,size=46,hover=False,pressed=False):
        # Exact Paddles.CreateSlot geometry: four-pixel shrink, two-pixel drop.
        cx,cy=center
        if pressed: size-=4; cy+=2
        x,y=cx-size/2,cy-size/2
        self.native(canvas,"gamepad-actionbar-circleslot-dropshadow",(x-4,y-4,size+8,size+8))
        with Image.open(NATIVE/"png"/"Interface"/"ICONS"/(icon+".png")) as source:
            w,h=source.size
            source=source.convert("RGBA").crop((round(w*.08),round(h*.08),round(w*.92),round(h*.92)))
            source=source.resize((round((size-6)*SCALE),round((size-6)*SCALE)),Image.Resampling.BILINEAR)
            mask=self.mask("CircleMask",source.size)
            source.putalpha(ImageChops.multiply(source.getchannel("A"),mask))
            canvas.alpha_composite(source,(round((x+3)*SCALE),round((y+3)*SCALE)))
        state="pressed" if pressed else "hover" if hover else "normal"
        self.flat(canvas,"ck_reforged_slot_"+state,(x,y,size,size))

    def wheel_layers(self,count=8,selected=None,pressed=False,holes=(),long_name=False,pages=1,page=1):
        """Actual ConsumableWheel layers, reusable in the editable Blender scene.

        The custom-wheel fixture deliberately repeats three extracted Warrior
        icons to test counts without pretending to read a character's inventory.
        Sizes are logical560×700; returned RGBA layers are at SCALE=2.
        """
        n=max(1,count); cx,cy=280,270
        face_size=401
        face_mask="ui-hud-minimap-frame-generic-mask"
        layers=[]
        def layer(name):
            im=self.canvas((560,700),(0,0,0,0)); layers.append((name,im)); return im
        stone=layer("01_opaque_native_stone_face")
        self.masked_stone(stone,(cx-face_size/2,cy-face_size/2,face_size,face_size),mask_name=face_mask)
        hub=layer("02_opaque_hub")
        mask=self.mask("CircleMask",(146*SCALE,146*SCALE))
        disk=self.canvas((146,146),(9,6,4,255)); disk.putalpha(mask)
        hub.alpha_composite(disk,((cx-73)*SCALE,(cy-73)*SCALE))
        crown=layer("03_variable_section_crown")
        self.existing(crown,f"ck_wheel_bg_{n}",(cx-256,cy-256,512,512))
        selection=layer("04_focused_section")
        if selected is not None and selected not in holes and count:
            overlays={1:(512,512,0,0),2:(512,256,0,110),3:(512,256,0,130),4:(512,256,0,137),
                      5:(256,256,0,140),6:(256,256,0,142),7:(256,256,0,142),8:(256,256,0,143)}
            w,h,dx,dy=overlays[n]
            section=self.canvas((512,512),(0,0,0,0))
            self.existing(section,f"ck_wheel_sel_{n}",(256+dx-w/2,256-dy-h/2,w,h))
            section=section.rotate(-selected*360/n,resample=Image.Resampling.BICUBIC)
            selection.alpha_composite(section,((cx-256)*SCALE,(cy-256)*SCALE))
        cut=Image.new("L",crown.size,0)
        cut.paste(self.mask(face_mask,(401*SCALE,401*SCALE)),(round((cx-200.5)*SCALE),round((cy-200.5)*SCALE)))
        crown.putalpha(ImageChops.multiply(crown.getchannel("A"),cut).point(lambda v:round(v*.6)))
        selection.putalpha(ImageChops.multiply(selection.getchannel("A"),cut))
        rim=layer("05_native_outer_and_hub_bevel")
        self.native(rim,"UI-HUD-Minimap-Frame-Circle",(cx-256,cy-256,512,512))
        self.native(rim,"UI-HUD-Minimap-Frame-Circle",(cx-91,cy-91,182,182))
        icons=layer("06_slot_icons_and_state")
        fixture=[("Shield Bash","Ability_Warrior_ShieldBash"),("Shield Wall","Ability_Warrior_ShieldWall"),("Charge","Ability_Warrior_Charge")]
        for i in range(count):
            if i in holes: continue
            name,icon=fixture[i%3]
            angle=i*math.pi*2/n
            self.wheel_slot(icons,icon,(cx+128*math.sin(angle),cy-128*math.cos(angle)),hover=i==selected,pressed=pressed and i==selected)
        center=layer("07_center_icon_and_wheel_title")
        if selected is not None and count and selected not in holes:
            self.wheel_slot(center,fixture[selected%3][1],(cx,cy-12),62,pressed=pressed)
        else: self.glyph(center,"ls",(cx-20,cy-32),40)
        self.wrapped(center,"Warrior",(cx-50,cy+31.5,100,30),13,"title",False,0,True,max_lines=2)
        banner=layer("08_native_stone_banner")
        self.masked_stone(banner,(cx-180,cy+220,360,128),False)
        self.native(banner,"common-insideframe",(cx-180,cy+220,360,128),sliced=True)
        labels=layer("09_banner_name_type_and_controller_help")
        focused=selected is not None and count and selected not in holes
        name=fixture[selected%3][0] if focused else "Warrior"
        if long_name and focused: name="Synthetic long spell name with an extended rank label (Rank4)"
        lines=self.wrap_lines(name,330,16)
        text_height=len(lines)*16+max(0,len(lines)-1)*2
        self.wrapped(labels,name,(cx-165,cy+232+(38-text_height)/2,330,38),16,"title",False,2,True,max_lines=2)
        self.text(labels,"Spell" if focused else self.labels["MYWHEEL_NOTHING_HINT"],(cx,cy+283),13,"cream","mm",max_width=330)
        hints=[("ls",self.labels["WHEEL_AIM"]),("a",self.labels["WHEEL_USE"]),("b",self.labels["WHEEL_CLOSE"])]
        total=sum(14+4+self.width(label,12)+12 for _,label in hints)-12
        x=cx-total/2
        for glyph,label in hints:
            help_y=cy+300
            self.glyph(labels,glyph,(x,help_y),14)
            self.text(labels,label,(x+18,help_y+7),12,"cream","lm")
            x+=18+self.width(label,12)+12
        if pages>1:
            x=cx-(14+4+pages*15+14)/2
            self.glyph(labels,"lb",(x,cy+322),14); x+=18
            for index in range(1,pages+1):
                self.native(labels,"gamepad-radialgamemenu-cursorbg-"+("neutral" if index==page else "inactive"),(x,cy+323.5,11,11))
                x+=15
            self.glyph(labels,"rb",(x,cy+322),14)
        return layers

    def wheel(self,count=8,selected=None,pressed=False,holes=(),light=False,long_name=False,pages=1,page=1):
        im=self.canvas((560,700),"#B9B7B1" if light else "#0F0D0B")
        for _,layer in self.wheel_layers(count,selected,pressed,holes,long_name,pages,page): im.alpha_composite(layer)
        state="activation" if pressed else "hover / focus" if selected is not None else "idle"
        self.text(im,f"Reconstruction · {count} slots · {state}"+(" · sparse custom wheel" if holes else ""),(12,658),11,"#30271E" if light else "grey",body=True,max_width=536,shadow=not light)
        self.text(im,"Native spell fixtures · not an in-game screenshot",(12,679),11,"#30271E" if light else "grey",body=True,max_width=536,shadow=not light)
        return im

    def round_icon(self,canvas,name,box):
        x,y,w,h=box
        with Image.open(NATIVE/"png"/"Interface"/"ICONS"/(name+".png")) as source:
            sw,sh=source.size
            source=source.convert("RGBA").crop((round(sw*.08),round(sh*.08),round(sw*.92),round(sh*.92)))
            source=source.resize((round(w*SCALE),round(h*SCALE)),Image.Resampling.BILINEAR)
            source.putalpha(ImageChops.multiply(source.getchannel("A"),self.mask("CircleMask",source.size)))
            canvas.alpha_composite(source,(round(x*SCALE),round(y*SCALE)))

    def editor(self,empty=False,long_title=False):
        """MyWheels.Editor at its actual480+292 body layout and native art sizes."""
        im=self.canvas((820,580),(0,0,0,0))
        self.text(im,"Easy Controller",(410,5),18,"title","mt",max_width=680)
        self.text(im,"Profile: General",(410,37),12,"cream2","mt",body=True,max_width=700,ellipsis=True)
        self.glyph(im,"lb",(49,65),24); self.glyph(im,"rb",(747,65),24)
        for i,key in enumerate(("HOME","GAMEPAD","WHEELS","KEYBOARD","ALERTS")):
            self.native_button(im,self.labels[f"TAB_{key}"],(83+i*132,62,126,30),"active" if i==2 else "normal")
        cx,cy=258,290
        mask_name="ui-hud-minimap-frame-generic-mask"
        self.masked_stone(im,(cx-136,cy-136,272,272),mask_name=mask_name)
        self.native(im,"UI-HUD-Minimap-Frame-Circle",(cx-173.5,cy-173.5,347,347))
        hub=self.canvas((100,100),(9,6,4,255)); hub.putalpha(self.mask(mask_name,hub.size))
        im.alpha_composite(hub,((cx-50)*SCALE,(cy-50)*SCALE))
        self.native(im,"UI-HUD-Minimap-Frame-Circle",(cx-64,cy-64,128,128))
        wheel_name="Long custom wheel name for stress testing" if long_title else "Warrior"
        # Mirror the explicit width/height, wrapping and one-line source bounds.
        # Full names remain visible in the real right-hand picker below.
        title=self.canvas((self.editor_title_width,self.editor_title_height),(0,0,0,0))
        title_line=self.wrap_lines(wheel_name,self.editor_title_width,14)[0]
        while title_line and self.width(title_line,14)>self.editor_title_width:
            title_line=title_line[:-1]
        self.text(title,title_line,(self.editor_title_width/2,self.editor_title_height/2),14,"title","mm",max_width=self.editor_title_width)
        im.alpha_composite(title,(round((cx-self.editor_title_width/2)*SCALE),round((cy-11-self.editor_title_height/2)*SCALE)))
        self.text(im,"0 / 8" if empty else "3 / 8",(cx,cy+12),20,"cream","mm")
        entries={0:("Shield Bash","Ability_Warrior_ShieldBash"),2:("Charge","Ability_Warrior_Charge"),5:("Shield Wall","Ability_Warrior_ShieldWall")} if not empty else {}
        positions=self.labels["MYWHEEL_POS"].split(",")
        for i in range(8):
            a=i*math.pi/4; sn,cs=math.sin(a),math.cos(a)
            x,y=cx+108*sn,cy-108*cs
            self.existing(im,"ck_slot",(x-26,y-26,52,52))
            if i in entries: self.round_icon(im,entries[i][1],(x-19,y-19,38,38))
            else: self.text(im,"+",(x,y-1),20,"#C9A25A","mm")
            if i==0:
                with Image.open(ROOT/"textures"/"ck_ring_dash.tga") as opened:
                    dash=opened.convert("RGBA").resize((62*SCALE,62*SCALE),Image.Resampling.BILINEAR)
                tint=self.canvas((62,62),"#FFD24A"); tint.putalpha(dash.getchannel("A"))
                im.alpha_composite(tint,(round((x-31)*SCALE),round((y-31)*SCALE)))
            lx=cx+150*sn if sn>.3 else cx+150*sn-100 if sn<-.3 else cx-50
            ly=cy-150*cs-16 if abs(sn)>.3 else (cy-168 if cs>0 else cy+147)-16
            label=entries[i][0] if i in entries else positions[i]
            lines=self.wrap_lines(label,100,13)
            color="focus" if i==0 else "cream" if i in entries else "grey"
            for j,line in enumerate(lines):
                px=lx if sn>.3 else lx+100 if sn<-.3 else lx+50
                self.text(im,line,(px,ly+(32-len(lines)*13)/2+j*13),13,color,"lt" if sn>.3 else "rt" if sn<-.3 else "mt",max_width=100)
        bind_label=self.labels["LBL_BUTTON"]; bind_text=self.labels["LBL_NO_BUTTON"]
        bw=self.width(bind_label,13,True)+8+self.width(bind_text,14)+16
        bx=cx-bw/2
        self.text(im,bind_label,(bx,482),13,"grey","lm",body=True)
        chip_x=bx+self.width(bind_label,13,True)+8
        self.well(im,(chip_x,472,self.width(bind_text,14)+16,20))
        self.text(im,bind_text,(chip_x+8,482),14,"#7A6E5A","lm")
        x=18
        for label,flex in zip((self.labels["V_RENAME"],self.labels["LBL_ASSIGN_BUTTON"],self.labels["LBL_DELETE"]),(1,1.3,.9)):
            width=464*flex/3.2
            self.button(im,label,(x,496,width,32),size=15); x+=width+8
        # The real lists picker is fully active while the top slot is targeted.
        px,py,pw,ph=510,104,292,424
        self.well(im,(px,py,pw,ph),fill="#050403",edge="#5A4630")
        self.text(im,"SLOT 1 · TOP",(px+12,py+12),12,"grey",body=True,max_width=268)
        title_lines=self.wrap_lines(wheel_name,268,17)
        th=len(title_lines)*17
        self.wrapped(im,wheel_name,(px+12,py+27,268,th),17,"title",spacing=0,max_lines=2)
        tab_top=27+th+8
        tw=(pw-24-8)/3
        for i,key in enumerate(("SPELLS","ITEMS","MACROS")):
            self.native_button(im,self.labels["MAP_TAB_"+key],(px+12+i*(tw+4),py+tab_top,tw,34),"active" if i==0 else "normal",size=13)
        row_top=tab_top+40
        fixture=[("Shield Bash","Ability_Warrior_ShieldBash"),("Shield Wall","Ability_Warrior_ShieldWall"),("Charge","Ability_Warrior_Charge")]
        for i,(name,icon) in enumerate(fixture):
            yy=py+row_top+i*48
            if i==0: self.slice(im,"ck_select",(px+12,yy,268,48),corner=10)
            self.round_icon(im,icon,(px+18,yy+12,24,24))
            self.text(im,name,(px+50,yy+24),15,"cream","lm",max_width=224)
            if not empty:
                ImageDraw.Draw(im).polygon([((px+15)*SCALE,(yy+34)*SCALE),((px+19)*SCALE,(yy+30)*SCALE),((px+23)*SCALE,(yy+34)*SCALE),((px+19)*SCALE,(yy+38)*SCALE)],fill="#5FC0D0")
        self.line(im,(2,536,818,536))
        self.footer(im,[(["dpad"],"Move"),(["a"],self.labels["V_CHOOSE_NEXT"]),(["lb","rb"],"List"),(["b"],"Back")],"Wheels › My wheels › "+wheel_name)
        full=self.native_metal_frame(); full.alpha_composite(im,(8*SCALE,16*SCALE))
        self.native(full,"RedButton-Exit",(802,15,24,24))
        result=self.canvas((830,628)); result.alpha_composite(full)
        note="Editor reconstruction · synthetic title stress; source bounds applied" if long_title else "My wheels editor reconstruction · native spell fixtures · not an in-game screenshot"
        self.text(result,note,(12,610),11,"grey",body=True,max_width=806)
        return result

    def keyboard(self):
        # UI.lua Layout: area starts y92; showActions=true =>600x424.
        im = self.canvas((600, 424))
        self.panel(im, (0, 0, 600, 424))
        for box in ((8, 8, 584, 44), (8, 58, 584, 28), (8, 316, 584, 26)):
            self.well(im, box, fill="#080706", edge="#3D3326")
        self.text(im, "Say:", (16, 30), 14, "#FFFFFF", "lm")
        self.text(im, "n", (49, 30), 14, "#FFFFFF", "lm")
        self.well(im, (500, 21, 58, 18), fill="#16130F", edge="#4A3F2F")
        self.text(im, "abc", (529, 30), 11, "#A8946C", "mm")
        self.glyph(im, "dpad_left", (12, 61), 22)
        self.glyph(im, "dpad_right", (566, 61), 22)
        # Blank suggestion strip: no fabricated prediction results.
        rows = [("qwertyuiop", [(n * 58 if n < 5 else 298 + (n - 5)*58, 54) for n in range(10)]),
                ("asdfghjkl'", [(n * 58 if n < 5 else 298 + (n - 5)*58, 54) for n in range(10)]),
                (["Shift", "z", "x", "c", "v", "b", "n", "m", "Backspace"], [(0,54),(58,54),(116,54),(174,54),(232,54),(298,54),(356,54),(414,54),(472,112)]),
                (["123", ",", "-", "Space", ".", "?", "!"], [(0,54),(58,54),(116,54),(174,236),(414,54),(472,54),(530,54)])]
        for ri, (labels, places) in enumerate(rows):
            for label, (xx, width) in zip(labels, places):
                state = "pressed" if label == "n" else "target_l" if label == "d" else "hover" if label == "o" else "normal"
                self.slice(im, f"ck_sk_key_{state}", (8 + xx, 96 + ri * 54, width, 50))
                self.text(im, label, (8 + xx + width/2, 121 + ri*54), 20 if len(label) == 1 else 13,
                          self.key_pressed_color if state == "pressed" else "#FFF0C8" if state == "target_l" else "#FFF5D9" if state == "hover" else "#FFD100" if len(label)==1 else "#D9C9A0", "mm", shadow=state != "pressed", max_width=width - 12)
        # Unchanged real cursor/divider textures; positions correspond to the shown keys.
        for name, box in (("ck_sk_divider", (292,96,16,158)), ("ck_sk_center", (135,186,32,32)),
                          ("ck_sk_center", (433,186,32,32)), ("ck_sk_cursor", (135,159,32,32)),
                          ("ck_sk_cursor", (375,213,32,32))):
            self.existing(im, name, box)
        channels = ["/s", "/y", "/p", "/ra", "/g", "/1", "/w", "/r", "!"]
        self.glyph(im,"dpad_down",(12,318),22)
        for i, label in enumerate(channels):
            self.text(im, label, (38 + (524/9)*i + 28, 329), 12, "#B9B2A6", "mm")
        sx = 584/324
        for label, xx, width in (("Shift",8,38),("123",49,38),("Space",90,78),("Backspace",171,58),("Send",232,71),("X",306,26)):
            self.slice(im, "ck_sk_key_normal", (8+(xx-8)*sx,346,width*sx,26), corner=8)
            self.text(im,label,(8+(xx-8)*sx+width*sx/2,359),11,"#E8D7A8","mm",max_width=width*sx-8)
        for n, (key, label) in enumerate((("ls","Left cursor"),("rs","Right cursor"),("lt","Type left"),("rt","Type right"),
                                          ("lb","Backspace"),("rb","Space"),("dpad_down","Channel"),("dpad_lr","Select"))):
            xx, yy = 10 + n%4 * 145, 382 + n//4 * 17
            self.glyph(im,key,(xx,yy),16)
            self.text(im,label,(xx+20,yy+8),11,"#D9D4CB","lm",max_width=120)
        return im

    def chat_layers(self,state="idle",native=True,inactive_alpha=None,hub_rim=None,hub_face=None,caps=False,symbols=False,petal=0,slot=1):
        """Editable layers of the complete340x508 UI.lua chat panel at2x.

        This fixture uses letters, visible action buttons, an empty suggestion
        list, unlocked placement and questLinks disabled. No live chat is read.
        Optional caps/symbols and selection fixtures exercise the real layout.
        """
        if state not in ("idle","hover","aim","pressed"): raise ValueError(state)
        inactive_alpha=self.chat_geometry["inactiveAlpha"] if inactive_alpha is None and native else .4 if inactive_alpha is None else inactive_alpha
        hub_rim=self.chat_geometry["hubRim"] if hub_rim is None else hub_rim
        hub_face=self.chat_geometry["hubFace"] if hub_face is None else hub_face
        rim_size=self.chat_geometry["rim"]; face_size=self.chat_geometry["face"]
        layers=[]
        def layer(name):
            result=self.canvas((340,508),(0,0,0,0)); layers.append((name,result)); return result
        im=layer("01_chat_panel_input_and_suggestions")
        self.panel(im,(0,0,340,508))
        for box in ((8,8,324,44),(8,58,324,28),(8,400,324,26)):
            self.well(im,box,fill="#080706",edge="#3D3326")
        self.existing(im,"ck_move",(303,18,24,24))
        self.glyph(im,"dpad_left",(12,61),22); self.glyph(im,"dpad_right",(306,61),22)
        cx,cy=170,244; scale=304/512
        selected=petal if state in ("aim","pressed") else None
        chars=(("a","b","c","d"),("e","f","g","h"),("i","j","k","l"),("m","n","o","p"),
               ("q","r","s","t"),("u","v","w","x"),("y","z","'","-"),(".",",","?","!"))
        if symbols:
            chars=(("1","2","3","4"),("5","6","7","8"),("9","0","+","="),("é","è","ê","à"),
                   ("ç","ù","â","ô"),("î","û","ë","ï"),(":",";","(",")"),("/","@",'"',"%"))
        if caps: chars=tuple(tuple(c.upper() for c in group) for group in chars)
        shown_char=chars[petal][slot]
        self.text(im,shown_char+"|" if state=="pressed" else "|",(16,14),13,"title",max_width=218)
        if caps or symbols:
            self.well(im,(240,21,58,18),fill="#E0B400" if caps else "#080706",edge="#D8B27A")
            self.text(im,"CAPS" if caps else "123",(269,30),10,"#1A1206" if caps else "#FFD100","mm",shadow=not caps,max_width=54)
        im=layer("02_chat_native_stone_face")
        if native: self.masked_stone(im,(cx-face_size/2,cy-face_size/2,face_size,face_size),mask_name="ui-hud-minimap-frame-generic-mask")
        im=layer("03_chat_crown_and_section_state")
        crown_size=rim_size if native else 304
        art_scale=crown_size/512
        crown=self.canvas((304,304),(0,0,0,0)); self.existing(crown,"ck_wheel_bg_8",((304-crown_size)/2,(304-crown_size)/2,crown_size,crown_size))
        if native:
            clip=Image.new("L",crown.size,0)
            clip.paste(self.mask("ui-hud-minimap-frame-generic-mask",(face_size*SCALE,face_size*SCALE)),(round((304-face_size)/2*SCALE),round((304-face_size)/2*SCALE)))
            crown.putalpha(ImageChops.multiply(crown.getchannel("A"),clip).point(lambda v:round(v*.60)))
        im.alpha_composite(crown,(18*SCALE,92*SCALE))
        if selected is not None:
            for i in range(8):
                section=self.canvas((304,304),(0,0,0,0))
                section_size=256*art_scale
                self.existing(section,"ck_wheel_sel_8" if i==selected else "ck_dw_dim",(152-section_size/2,152-143*art_scale-section_size/2,section_size,section_size))
                section=section.rotate(-i*45,resample=Image.Resampling.BICUBIC)
                if native: section.putalpha(ImageChops.multiply(section.getchannel("A"),clip))
                im.alpha_composite(section,(18*SCALE,92*SCALE))
        im=layer("04_chat_native_outer_bevel")
        if native: self.native(im,"UI-HUD-Minimap-Frame-Circle",(cx-rim_size/2,cy-rim_size/2,rim_size,rim_size))
        im=layer("05_chat_petals_characters_and_key_state")
        offsets=((-28*scale,0),(0,-28*scale),(28*scale,0),(0,28*scale))
        for i,group in enumerate(chars):
            angle=i*math.pi/4; px,py=cx+95*math.sin(angle),cy-95*math.cos(angle)
            dimmed=selected is not None and selected!=i
            ring=self.canvas((340,508),(0,0,0,0)); size=108*scale
            if native:
                self.native(ring,"gamepad-actionbar-circleslot-border-normal",(px-size/2,py-size/2,size,size))
                if selected==i:
                    size*=80/64
                    self.native(ring,"gamepad-actionbar-circleslot-border-selected",(px-size/2,py-size/2,size,size))
            else: self.existing(ring,"ck_dw_ring_sel" if selected==i else "ck_dw_ring",(px-size/2,py-size/2,size,size))
            if dimmed: ring.putalpha(ring.getchannel("A").point(lambda v:round(v*.55)))
            im.alpha_composite(ring)
            for j,(letter,(dx,dy)) in enumerate(zip(group,offsets)):
                x,y=px+dx,py+dy; aimed=selected==i and j==slot; hovered=state=="hover" and i==petal and j==slot
                key=self.canvas((340,508),(0,0,0,0)); key_size=54*scale
                if aimed or hovered:
                    if native:
                        atlas="gamepad-actionbar-circleslot-border-pressed" if state=="pressed" else "gamepad-actionbar-circleslot-border-hover" if hovered else "gamepad-actionbar-circleslot-border-selected"
                        if state!="pressed" and not hovered: key_size*=80/64
                        self.native(key,atlas,(x-key_size/2,y-key_size/2,key_size,key_size))
                    else: self.existing(key,"ck_dw_hover" if hovered else "ck_dw_target",(x-key_size/2,y-key_size/2,key_size,key_size))
                color="#FFF5D9" if hovered or native and aimed else "#000000" if aimed else "#FFE8A8" if selected==i else "#FFD100"
                self.text(key,letter,(x,y if native and aimed and state=="pressed" else y-1),16,color,"mm",shadow=native or not aimed)
                if dimmed: key.putalpha(key.getchannel("A").point(lambda v:round(v*inactive_alpha)))
                im.alpha_composite(key)
        hs=120*scale
        im=layer("06_chat_native_hub")
        if native:
            face=self.canvas((hub_face,hub_face),(9,6,4,255)); face.putalpha(self.mask("ui-hud-minimap-frame-generic-mask",face.size))
            im.alpha_composite(face,(round((cx-hub_face/2)*SCALE),round((cy-hub_face/2)*SCALE)))
            self.native(im,"UI-HUD-Minimap-Frame-Circle",(cx-hub_rim/2,cy-hub_rim/2,hub_rim,hub_rim))
        else: self.existing(im,"ck_dw_hub_lit" if selected is not None else "ck_dw_hub",(cx-hs/2,cy-hs/2,hs,hs))
        im=layer("07_chat_hub_character_or_layer_label")
        if selected is not None or state=="hover":
            letter_layer=self.canvas((340,508),(0,0,0,0))
            self.text(letter_layer,shown_char,(cx,cy-2),38,"#FFD100","mm",max_width=hub_face if native else hs)
            if state=="hover": letter_layer.putalpha(letter_layer.getchannel("A").point(lambda v:round(v*.55)))
            im.alpha_composite(letter_layer)
        elif symbols: self.text(im,"123",(cx,cy+24),10,"#C9A349","mm",max_width=hub_face if native else hs)
        im=layer("08_chat_channels_actions_and_help")
        self.glyph(im,"dpad_down",(12,402),22)
        channels=("/s","/y","/p","/ra","/g","/1","/w","/r")
        step=264/len(channels)
        for i,label in enumerate(channels): self.text(im,label,(38+step*i+(step-1)/2,413),12,"#99958D","mm",max_width=step-1)
        for label,xx,width in ((self.labels["SHIFT"],8,38),(self.labels["LETTERS"] if symbols else self.labels["SYMBOLS"],49,38),(self.labels["SPACE"],90,78),
                               (self.labels["BACKSPACE"],171,58),(self.labels["SEND"],232,71),("X",306,26)):
            active=(xx==8 and caps) or (xx==49 and symbols)
            self.slice(im,"ck_sk_key_active" if active else "ck_sk_key_normal",(xx,430,width,26),corner=8)
            self.text(im,label,(xx+width/2,443),11,"#FFF0C8" if active else "#E8D7A8","mm",max_width=width-4)
        im.alpha_composite(self.canvas((340,40),(0,0,0,90)),(0,462*SCALE))
        self.existing(im,"ck_filet",(0,458,340,8)); self.existing(im,"ck_filet",(0,498,340,8))
        hints=(("ls","HELP_PETAL"),("rs","HELP_LETTER"),("lb","BACKSPACE"),("rb","SPACE"),
               ("lt","SHIFT"),("rt","SYMBOLS"),("dpad_down","HELP_CHANNEL"),("dpad_lr","HELP_PICK"))
        for i,(glyph,key) in enumerate(hints):
            x,y=10+(i%4)*80,466+(i//4)*17
            self.glyph(im,glyph,(x,y),16); self.text(im,self.labels[key],(x+19,y+8),11,"#D9D4CB","lm",max_width=61)
        return [(name,part) for name,part in layers if part.getchannel("A").getbbox()]

    def chat_daisywheel(self,**fixture):
        im=self.canvas((340,508))
        for _,part in self.chat_layers(**fixture): im.alpha_composite(part)
        return im

    def existing(self, im, name, box):
        with Image.open(ROOT / "textures" / f"{name}.tga") as source:
            x,y,w,h=box
            im.alpha_composite(source.convert("RGBA").resize((round(w*SCALE), round(h*SCALE)), Image.Resampling.BILINEAR),
                               (round(x*SCALE),round(y*SCALE)))

    def states(self):
        im = self.canvas((820, 660))
        self.text(im, "Current native UI · interaction states", (20,16),20,"title")
        self.text(im, "Actual native atlas crops and exported key textures; reconstructed at2×.", (20,45),13,"help",body=True)
        for i,(state,label) in enumerate((("normal","Static"),("hover","Mouseover"),("active","Focused / active"),("active_pressed","Activation (120ms)"))):
            x=20+i*200
            self.text(im,label,(x,78),14,"cream")
            self.native_button(im,"Home",(x,104,126,30),state)
            rx,ry=20+i%2*400,182+i//2*108
            self.text(im,label,(rx,ry),13,"cream")
            self.role_card(im,(rx,ry+20),"Interrupt",["L4"],state)
        for i,(state,label) in enumerate((("normal","Static"),("hover","Mouseover"),("active","Shift /123 active"),("target_l","Left target"),("target_r","Right target"),("pressed","Pressed (120ms)"))):
            x=20+i*132
            self.text(im,label,(x,417),12,"cream",body=True,max_width=126)
            self.slice(im,f"ck_sk_key_{state}",(x,443,54,50))
            self.text(im,"a",(x+27,468),20,self.key_pressed_color if state=="pressed" else "#FFF0C8","mm",shadow=state!="pressed")
        self.text(im,"Paddle rims ·40px · separate static, focus and press",(20,520),13,"cream",body=True)
        for i,state in enumerate(("normal","hover","pressed")):
            name=f"ck_reforged_slot_{state}"
            x=20+i*132
            source=self.asset(name)
            im.alpha_composite(source.resize((40*SCALE,40*SCALE),Image.Resampling.BILINEAR),(x*SCALE,546*SCALE))
            self.text(im,state,(x+50,566),12,"help","lm",body=True)
        self.text(im,"List-button activation uses the live code's70% brightness modulation; no invented pressed atlas.",(20,612),12,"grey",body=True,max_width=780)
        self.text(im,self.font_note,(20,636),12,"grey",body=True,max_width=780)
        return im

    def contact_sheet(self):
        # Flat beauty exports only, accompanied by their actual source sizes.
        items=list(self.entries)
        im=self.canvas((820,70+((len(items)+3)//4)*196))
        self.text(im,"Blender exports · source texture contact sheet",(20,16),20,"title")
        for i,name in enumerate(items):
            x,y=20+i%4*200,64+i//4*196
            image=self.asset(name)
            self.text(im,name,(x,y),11,"cream",body=True,max_width=190)
            self.text(im,f"{image.width} × {image.height} RGBA",(x,y+17),11,"grey",body=True)
            # Checkerboard reveals alpha, contained in its own contact-sheet cell.
            ww,hh=image.size
            fit=min(1,160/max(ww,hh))
            dw,dh=round(ww*fit*SCALE),round(hh*fit*SCALE)
            cell=Image.new("RGBA",(dw,dh))
            draw=ImageDraw.Draw(cell)
            for yy in range(0,dh,16):
                for xx in range(0,dw,16):
                    draw.rectangle((xx,yy,xx+15,yy+15),fill="#55514A" if (xx//16+yy//16)%2 else "#383530")
            cell.alpha_composite(image.resize((dw,dh),Image.Resampling.BILINEAR))
            im.alpha_composite(cell,(x*SCALE,(y+36)*SCALE))
        return im

    def layers_sheet(self):
        """Show each actual independent Blender render, not a synthesized layer."""
        im=self.canvas((820,72+len(self.entries)*128))
        self.text(im,"Independent Blender layers · exported RGBA",(20,16),20,"title")
        self.text(im,"Layers remain separate; occlusion means their sum need not equal the beauty render.",(20,45),12,"help",body=True)
        for i,(name,entry) in enumerate(self.entries.items()):
            y=76+i*128
            self.text(im,name,(20,y),12,"cream",body=True)
            paths=entry.get("sourceLayers",[])
            for j,value in enumerate(paths):
                path=Path(value.get("path") if isinstance(value,dict) else value)
                path=path if path.is_absolute() else self.folder/path
                with Image.open(path) as opened:
                    source=opened.convert("RGBA")
                if source.getchannel("A").getbbox() is None:
                    raise ValueError(f"Empty source layer: {path}")
                fit=min(148/source.width,84/source.height,1)
                size=(round(source.width*fit*SCALE),round(source.height*fit*SCALE))
                x=20+j*200
                self.text(im,path.stem,(x,y+20),11,"grey",body=True,max_width=190)
                tile=Image.new("RGBA",size,"#48423B")
                tile.alpha_composite(source.resize(size,Image.Resampling.BILINEAR))
                im.alpha_composite(tile,(x*SCALE,(y+37)*SCALE))
        return im


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,default=ROOT/"design"/"reforged"/"preview")
    parser.add_argument("--chat-only",action="store_true",help="Render only the current/proposed full chat daisywheel proof.")
    parser.add_argument("--chat-compare",action="store_true",help="Include retained proposal comparisons in the chat-only batch.")
    args=parser.parse_args()
    preview=Preview(ROOT/"design"/"reforged")
    args.output.mkdir(parents=True,exist_ok=True)
    if args.chat_only:
        outputs={}
        fixtures={state:{"state":state} for state in ("idle","hover","aim","pressed")}
        fixtures["caps-w"]={"state":"aim","caps":True,"petal":5,"slot":2}
        fixtures["symbols"]={"symbols":True}
        for suffix,fixture in fixtures.items():
            labeled=preview.canvas((340,534)); labeled.alpha_composite(preview.chat_daisywheel(**fixture))
            preview.text(labeled,f"Reconstruction · {suffix} · not in-game",(8,516),10,"grey",body=True,max_width=324)
            outputs[f"reforged-chat-{suffix}.png"]=labeled
        if args.chat_compare:
            for name,variants in (("reforged-chat-contrast-1x.png",(("Previous alpha0.40",dict(inactive_alpha=.4)),("Accepted alpha0.65",dict(inactive_alpha=.65)))),
                                  ("reforged-chat-hub-1x.png",(("Previous hub90/70",dict(hub_rim=90,hub_face=70)),("Accepted hub132/103",dict(hub_rim=132,hub_face=103))))):
                sheet=preview.canvas((716,562))
                for x,(label,options) in zip((12,364),variants):
                    preview.text(sheet,label,(x,12),14,"cream",max_width=340)
                    sheet.alpha_composite(preview.chat_daisywheel(state="aim",**options),(x*SCALE,36*SCALE))
                preview.text(sheet,"1× reconstruction · design comparison, no runtime acceptance",(12,550),10,"grey",body=True,max_width=692)
                outputs[name]=sheet.resize((716,562),Image.Resampling.LANCZOS)
        rim=preview.native_atlas("UI-HUD-Minimap-Frame-Circle")[0].resize((preview.chat_geometry["rim"]*SCALE,)*2,Image.Resampling.BILINEAR)
        bounds=rim.getchannel("A").point(lambda value:255 if value>16 else 0).getbbox()
        bounds=[v/SCALE+(304-preview.chat_geometry["rim"])/2 for v in bounds]
        checks={"nativeRimAlpha16BoundsInsideArea":min(bounds)>=0 and max(bounds)<=304,"nativeRimAlpha16Bounds":bounds,
                "helpBottomInsidePanel":502<=508,"actionLabelsFit":not any(x["overflows"] for x in preview.text_checks)}
        assert checks["nativeRimAlpha16BoundsInsideArea"] and checks["helpBottomInsidePanel"] and checks["actionLabelsFit"],checks
        for name,image in outputs.items(): image.save(args.output/name); print(name)
        report={"renderer":"Pillow source-based reconstruction, not an in-game screenshot","status":"Implemented native artwork; no in-game runtime acceptance","geometry":{"panel":[340,508],"area":[18,92,304,304],"petalRadius":95,"characterOffset":16.625,"characterArt":32.0625,"groupRing":64.125,"hubFrame":71.25,"nativeArt":preview.chat_geometry,"section":[176,98.3125],"channels":[8,400,324,26],"actionsTop":430,"helpTop":458},"fixtures":fixtures,"settings":{"showActions":True,"questLinks":False,"suggestions":[],"unlocked":True,"symbolsAccents":"French accent layout from Wheel.lua"},"sourceSha256":{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in ("Wheel.lua","UI.lua","tools/preview_reforged.py")},"nativeAtlases":preview.native_used,"textChecks":preview.text_checks,"layoutChecks":checks,"outputs":list(outputs)}
        (args.output/"chat-preview-report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
        return
    outputs={"reforged-config-preview.png":preview.config(),
             "reforged-config-stress-preview.png":preview.config(stress=True),
             "reforged-config-scroll-preview.png":preview.config(stress=True,reading=True,scroll=10000),
             "reforged-editor-preview.png":preview.editor(),
             "reforged-editor-empty.png":preview.editor(empty=True),
             "reforged-keyboard-preview.png":preview.keyboard(),
             "reforged-states.png":preview.states(),"reforged-textures.png":preview.contact_sheet(),
             "reforged-layers.png":preview.layers_sheet()}
    wheel_fixtures={
        "empty":dict(count=0),"one":dict(count=1,selected=0),
        "four":dict(count=4,selected=1),"eight-idle":dict(count=8),
        "eight-focus":dict(count=8,selected=0),"eight-pressed":dict(count=8,selected=0,pressed=True),
        "custom-holes":dict(count=8,selected=2,holes=(1,4,6)),
        "long-name":dict(count=4,selected=0,long_name=True),"light-background":dict(count=8,light=True),
        "pages":dict(count=8,selected=2,pages=3,page=2),
    }
    for suffix,fixture in wheel_fixtures.items():
        outputs[f"reforged-wheel-{suffix}.png"]=preview.wheel(**fixture)
    opacity_samples=[]
    dark,light=outputs["reforged-wheel-eight-idle.png"],outputs["reforged-wheel-light-background.png"]
    for i in range(16):
        angle=i*math.pi/8
        xy=(round((280+180*math.sin(angle))*SCALE),round((270-180*math.cos(angle))*SCALE))
        opacity_samples.append({"pixel":xy,"equalOnLightAndDark":dark.getpixel(xy)==light.getpixel(xy)})
    for name,image in outputs.items():
        image.save(args.output/name)
        print(f"{name}: {image.width}x{image.height}")
    report={"renderer":"Pillow reconstruction of Lua geometry, not a game screenshot", "scale":SCALE,
            "configurationFrameSize":[820,580],"nativeFrameOverflow":{"left":8,"top":16,"right":2,"bottom":8},
            "font":preview.font_note,"fontPath":str(preview.font_path),
            "sources":["ConfigWindow.lua","ConfigKit.lua","ProfileOptions.lua","UI.lua","StickKeyboard.lua","ConsumableWheel.lua","Paddles.lua","MyWheels.lua"],
            "textures":{name:hashlib.sha256((preview.folder/"png"/f"{name}.png").read_bytes()).hexdigest() for name in sorted(preview.used)},
            "nativeAtlases":preview.native_used,"textChecks":preview.text_checks,
            "wheelGeometry":{"canvas":512,"face":401,"crownMask":401,"mask":"ui-hud-minimap-frame-generic-mask","iconRadius":128,"slot":46,"centerSlot":62,"outerRim":512,"hubRim":182,"hubTitle":[100,30],"banner":[360,128],"bannerRows":{"name":[12,38],"count":[54,18],"help":[80,16],"pages":[102,14]}},
            "editorGeometry":{"body":[480,384],"picker":[292,424],"center":[240,186],"face":272,"rim":347,"hub":100,"hubRim":128,"slot":52,"icon":38,"radius":108,"hubTitle":[preview.editor_title_width,preview.editor_title_height],"hubTitleWordWrap":True,"hubTitleNonSpaceWrap":True,"hubTitleMaxLines":1},
            "wheelOpacitySamples":opacity_samples,
            "firstWheelRenderFailure":"common-insideframe canonical top53+bottom53 exceeded the original88px banner. Final128px banner integrates help/pages and fits canonical margins; temporary fitting approximation removed",
            "outputs":list(outputs),"limitations":["No in-game runtime acceptance", "Font metrics can differ from in-game Friz",
                "Native2x artwork is normalized using the installed UiCanvas2:1 size relationship; the game remains authoritative for SetAtlas slicing",
                "Icons use installed-client CircleMask/SquareMask and actual texture insets; cooldowns are not simulated",
                "Wheel fixtures deliberately repeat three installed Warrior spell icons; no saved character inventory or bindings were read",
                "UI data is an empty General role draft, explicitly synthetic long-text fixtures, and a QWERTY key-state example"]}
    (args.output/"preview-report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")


if __name__=="__main__":
    main()
