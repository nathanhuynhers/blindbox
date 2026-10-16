"""Blender: colour an untextured GLB from the hero image it was generated from, plus its sheet views.

Generalises build/corgi-preview/scripts (silhouette camera fit, edge refine, projection, mirror and
palette fill) and bakes a UV texture instead of vertex colours, so the result is an ordinary textured
GLB for texture_prepare.py and external.py. Geometry and normals are unchanged apart from dropping Tripo fins and lone triangles that fail the importer gate; only
UV0 and one material with an embedded albedo are added.

Textured faces come from the hero projection or its mirror across the symmetry plane; everything
else gets clean palette regions propagated over the surface (inferred, not seen). The sheet's FRONT
view is camera-fitted only to report the figure's facing; its pose can differ from the model, and
projecting sheet views produced misaligned camouflage, so they are not painted.

  blender -b --factory-startup --python tools/figures/reference_paint.py -- <in.glb> <hero.png> <sheet.webp|-> <out.glb> <review_dir> [hero_az]

Silhouettes are front/back ambiguous and the edge tie-break can pick the back (Moonrace Ox, Rooster). Check
a gray render at the fitted azimuth against the reference; if wrong, pass hero_az (degrees) to search only
within 25 degrees of it.
"""
import bpy, sys, math, json, pathlib, numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
from bpy_extras.object_utils import world_to_camera_view

src, hero_path, sheet_path, out_glb, review, *extra = sys.argv[sys.argv.index("--") + 1:]
hero_az = float(extra[0]) if extra and extra[0] != "-" else None
# Optional landmarks JSON: [{"render": [x, y], "ref" or "paint": [x, y]}, ...]. "render" is a pixel in the 768 px
# paint_hero.png / landmarks_render.png frame (fitted hero camera), "ref" a pixel in the reference image
# scaled to 768 px; both top-down. The projection is bent with a Gaussian RBF so each model feature (eye,
# nostril, mouth) samples exactly its reference feature; the correction fades out away from the landmarks.
landmarks = json.load(open(extra[1], encoding="utf-8")) if len(extra) > 1 and extra[1] != "-" else []
# Optional face camera JSON: {"az", "el", "center": [x, y], "radius": px, "landmarks": [{"render", "ref"}, ...]}.
# Tripo often turns the head relative to the body, so the body-fitted camera sees a turned face that no 2D warp
# can match to a frontal reference face. The head (sphere around the ray-cast "center", "radius" in 768 px of the
# face camera's frame) is projected from its own camera through an affine + RBF fit of >=3 landmarks, blended into
# the body mapping over the outer 35% of the radius.
face_spec = json.load(open(extra[2], encoding="utf-8")) if len(extra) > 2 and extra[2] != "-" else None
review = pathlib.Path(review); review.mkdir(parents=True, exist_ok=True)
N, V, G, TEX = 1024, 512, 256, 2048  # hero size, sheet-view size, fit grid, baked texture
PRIORITY = {"hero": 1.0, "mirror": 0.8}


def load(path, size=None):
    im = bpy.data.images.load(path)
    if size: im.scale(*size)
    w, h = im.size
    a = np.array(im.pixels[:], np.float32).reshape(h, w, 4)[:, :, :3]  # bottom-up rows
    bpy.data.images.remove(im); return a


def grow(m):
    g = m.copy(); g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]; return g


def foreground(px, b):
    """Quadratic background fit over a border band; foreground minus floor shadow (corgi_fit)."""
    h, w = px.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w] / np.array([h, w])[:, None, None]
    band = np.zeros((h, w), bool); band[:b] = band[-b:] = True; band[:, :b] = band[:, -b:] = True
    A = np.stack([np.ones_like(xx), xx, yy, xx * xx, yy * yy, xx * yy], -1)
    # Fit only border pixels near the border median (figures can reach into the band), then clamp so the
    # quadratic cannot dip inside the image (white studio backdrops).
    inl = band & (np.abs(px - np.median(px[band], 0)).max(-1) < 0.05)
    bg = A @ np.linalg.lstsq(A[inl], px[inl], rcond=None)[0]
    bg = np.clip(bg, np.percentile(px[inl], 2, 0), np.percentile(px[inl], 98, 0))
    r = px / np.maximum(bg, 1e-3)
    # Floor shadows only darken the backdrop a little; darker neutral pixels (black hats, gray fog) are figure.
    shadow = (r.max(-1) - r.min(-1) < 0.05) & (r.mean(-1) < 0.985) & (r.mean(-1) > 0.8)
    return (np.abs(px - bg).max(-1) > 0.06) & ~shadow, bg


def components(m):
    lab = np.zeros(m.shape, int); cur = 0; sizes = {}
    for y0, x0 in zip(*np.nonzero(m)):
        if lab[y0, x0]: continue
        cur += 1; st = [(y0, x0)]; lab[y0, x0] = cur; n = 0
        while st:
            y, x = st.pop(); n += 1
            for Y, X in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= Y < m.shape[0] and 0 <= X < m.shape[1] and m[Y, X] and not lab[Y, X]:
                    lab[Y, X] = cur; st.append((Y, X))
        sizes[cur] = n
    return lab, sizes


def solid(m):
    """Fill holes (flood background from the border) and keep the largest blob."""
    outside = np.zeros_like(m); outside[0] = outside[-1] = outside[:, 0] = outside[:, -1] = True; outside &= ~m
    while True:
        g = grow(outside) & ~m
        if g.sum() == outside.sum(): break
        outside = g
    lab, sizes = components(~outside)
    return lab == max(sizes, key=sizes.get)


def prepare(px):
    """Square image -> (G-grid mask, colours pushed outward so edge samples never hit the background)."""
    n = px.shape[0]; fg, _ = foreground(px, max(8, n // 25))
    i = np.arange(G) * n // G
    mask = solid(fg[i][:, i])
    full = np.repeat(np.repeat(mask, n // G, 0), n // G, 1)
    for _ in range(3): full = ~grow(~full)
    col = px.copy(); known = full.copy()
    for _ in range(n // 24):
        acc = np.zeros_like(col); cnt = np.zeros(known.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(known, (dy, dx), (0, 1)); acc += np.roll(col, (dy, dx), (0, 1)) * k[:, :, None]; cnt += k
        new = ~known & (cnt > 0); col[new] = acc[new] / cnt[new][:, None]; known |= new
    return mask, col, full


# --- Hero image.
hero_px = load(hero_path)
assert hero_px.shape[0] == hero_px.shape[1], "hero image must be square"
hero_px = load(hero_path, (N, N))
hero_mask, hero_col, hero_full = prepare(hero_px)

# --- Sheet: find the hero render (top) and the four view renders (middle row) by connected components.
views = []
if sheet_path != "-":  # "-": no sheet; facing then comes from face_patch.py alone
    sheet = load(sheet_path); SH, SW = sheet.shape[:2]
    sfg, sbg = foreground(sheet, 30)
    D = 3; small = sfg[::D, ::D]
    lab, sizes = components(small)
    boxes = []
    for c, nsz in sizes.items():
        ys, xs = np.nonzero(lab == c)
        boxes.append(dict(n=nsz, y0=ys.min() * D, y1=ys.max() * D + D, x0=xs.min() * D, x1=xs.max() * D + D, cy=1 - ys.mean() * D / SH))
    top = [b for b in boxes if b["cy"] < 0.5]  # rows are bottom-up: cy is measured from the top
    if top:
        sheet_hero = max(top, key=lambda b: b["n"])
        row = [b for b in boxes if 0.45 < b["cy"] < 0.75 and b["n"] > 0.02 * sheet_hero["n"] and b["x0"] < 0.2 * SW]
        if row:
            views = [min(row, key=lambda b: b["x0"])]  # FRONT is the leftmost view; others may merge with the hero
print("SHEET views", len(views), flush=True)


def crop(b, size):
    """Square crop around a sheet box, padded with the fitted background, resized to size."""
    cy, cx = (b["y0"] + b["y1"]) / 2, (b["x0"] + b["x1"]) / 2; half = int(max(b["y1"] - b["y0"], b["x1"] - b["x0"]) * 0.62)
    ys = np.clip(np.arange(int(cy) - half, int(cy) + half), 0, SH - 1); xs = np.clip(np.arange(int(cx) - half, int(cx) + half), 0, SW - 1)
    c = sheet[ys][:, xs]
    im = bpy.data.images.new("crop", c.shape[1], c.shape[0], alpha=False)
    im.pixels.foreach_set(np.concatenate([c, np.ones(c.shape[:2] + (1,), np.float32)], 2).ravel()); im.scale(size, size)
    out = np.array(im.pixels[:], np.float32).reshape(size, size, 4)[:, :, :3]; bpy.data.images.remove(im); return out


sources = {"hero": dict(col=hero_col, mask=hero_mask, full=hero_full, size=N)}
if views:
    # The sheet is a re-rendered, toned version of the hero: match its colours via its own hero render.
    sh_px = crop(sheet_hero, N); sh_mask, _, sh_full = prepare(sh_px)
    mu_s, sd_s = sh_px[sh_full].mean(0), sh_px[sh_full].std(0) + 1e-4
    mu_h, sd_h = hero_px[hero_full].mean(0), hero_px[hero_full].std(0) + 1e-4
    for name, b in zip(("front",), views):
        vp = np.clip((crop(b, V) - mu_s) / sd_s * sd_h + mu_h, 0, 1).astype(np.float32)
        m, c, f = prepare(vp)
        sources[name] = dict(col=c, mask=m, full=f, size=V)

# --- Model and camera fits by silhouette IoU.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
assert len(meshes) == 1, "expected one mesh"
o = meshes[0]; me = o.data
# Importer-gate repairs, as for the Tripo Cat (cat/source/prep_tripo_source.py): Tripo leaves fins (an edge
# shared by 3+ faces) and lone 1-3 triangle islands. Drop the smallest extra fin faces and islands under 8
# faces; every other triangle is untouched.
import bmesh
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
repairs = dict(fin_faces=0, island_faces=0)
while True:
    fins = set()
    for e in bm.edges:
        if len(e.link_faces) > 2:
            fins.update(sorted(e.link_faces, key=lambda f: f.calc_area())[:len(e.link_faces) - 2])
    seen_f, small = set(), []
    for f in bm.faces:
        if f in seen_f: continue
        st, isl = [f], []; seen_f.add(f)
        while st:
            g = st.pop(); isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen_f: seen_f.add(h); st.append(h)
        if len(isl) < 8: small.extend(isl)
    small = set(small) - fins
    # Zero-area slivers export zero shading normals and fail the importer's lossless reimport (Moonrace Dragon).
    bm.verts.ensure_lookup_table(); vs_ = list(bm.verts); sz2 = max((v.co - vs_[0].co).length_squared for v in vs_[:: max(1, len(vs_) // 500)]) or 1.0
    small |= {f for f in bm.faces if f.calc_area() < 1e-10 * sz2} - fins
    if not fins and not small: break
    repairs["fin_faces"] += len(fins); repairs["island_faces"] += len(small)
    bmesh.ops.delete(bm, geom=list(fins | small), context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(me); bm.free()
print("REPAIRS", repairs, flush=True)
co = np.array([o.matrix_world @ v.co for v in me.vertices])
lo, hi = co.min(0), co.max(0); centre = Vector((lo + hi) / 2); size = float((hi - lo).max())
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"; sc.render.film_transparent = True
sc.display.shading.light = "FLAT"; sc.display.shading.color_type = "SINGLE"; sc.display.shading.single_color = (1, 1, 1)
sc.view_settings.view_transform = "Standard"
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = size * 1.8; cam.data.clip_end = size * 20


def view_dir(az, el):
    a, e = math.radians(az), math.radians(el)
    return Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


def place(az, el):
    d = view_dir(az, el); cam.location = centre + d * size * 5
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler(); bpy.context.view_layer.update()


def render(path, res=G):
    sc.render.resolution_x = sc.render.resolution_y = res; sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(str(path)); a = np.array(im.pixels[:], np.float32).reshape(res, res, 4); bpy.data.images.remove(im)
    return a


Y, X = np.mgrid[0:G, 0:G]
masks = {}


def silhouette(az, el):
    key = (round(az, 2), round(el, 2))
    if key not in masks:
        place(az, el); masks[key] = render(review / "_fit.png")[:, :, 3] > 0.5
    return masks[key]


def iou(ref, az, el):
    m = silhouette(az, el); my, mx = np.nonzero(m)
    if len(my) < 50: return 0, None
    ys, xs = np.nonzero(ref); rc = np.array([ys.mean(), xs.mean()])
    s = math.sqrt(ref.sum() / len(my)); mc = np.array([my.mean(), mx.mean()])
    mm = m[np.clip(((Y - rc[0]) / s + mc[0]).round().astype(int), 0, G - 1), np.clip(((X - rc[1]) / s + mc[1]).round().astype(int), 0, G - 1)]
    return (mm & ref).sum() / (mm | ref).sum(), (s, rc, mc)


def fit(ref, azs, els=range(-30, 41, 10), keep=1):
    """Silhouette IoU grid search, then local refinement of the `keep` best distinct azimuths."""
    grid = []
    for az in azs:
        for el in els:
            v, t = iou(ref, az % 360, el)
            grid.append((v, az % 360, el))
    grid.sort(reverse=True); seeds = []
    for v, az, el in grid:
        if v < grid[0][0] - 0.04 or len(seeds) == keep: break
        if all(min(abs(az - a2), 360 - abs(az - a2)) >= 40 for _, a2, _ in seeds): seeds.append((v, az, el))
    out = []
    for v0, a0, e0 in seeds:
        best = (0, None, None)
        for step in (3, 1):
            a1, e1 = best[1] if best[1] else (a0, e0)
            for az in np.arange(a1 - 3 * step, a1 + 3 * step + 0.1, step):
                for el in np.arange(e1 - 3 * step, e1 + 3 * step + 0.1, step):
                    if not min(els) <= el <= max(els): continue  # refinement must not drift into steep views (Joy)
                    v, t = iou(ref, float(az) % 360, float(el))
                    if v > best[0]: best = (v, (float(az) % 360, float(el)), t)
        out.append(best)
    return out if keep > 1 else out[0]


def gradient(g):
    gy, gx = np.gradient(g); return np.hypot(gx, gy)


Gf = gradient(hero_px.mean(-1)); win = grow(grow(hero_full)); rows, cols = np.mgrid[0:N, 0:N]


def to_img(src, row, cl, dy=0, dx=0, k=1.0):
    """Fit-grid render position (rows bottom-up, in G units) -> source image pixels."""
    s, rc, mc = src["map"]; q = src["size"] / G
    return ((row - mc[0]) * s * k + rc[0]) * q + dy, ((cl - mc[1]) * s * k + rc[1]) * q + dx


def refine(cand):
    """corgi_refine over the whole figure: correlate shaded-render edges with reference edges.
    Interior edges (face, wings, folds) also tell apart mirror-ambiguous silhouettes."""
    v0, (az, el), mp = cand; src_ = dict(map=mp, size=N)
    place(az, el); sc.display.shading.light = "STUDIO"; sc.display.shading.single_color = (0.8, 0.8, 0.8)
    rr = render(review / "_refine.png", N); sc.display.shading.light = "FLAT"; sc.display.shading.single_color = (1, 1, 1)
    Gr = gradient(rr[:, :, :3].mean(-1) * rr[:, :, 3])

    def score(dy, dx, k):
        ry, rx = to_img(src_, rows / (N / G), cols / (N / G), dy, dx, k)
        iy, ix = np.clip(ry.round().astype(int), 0, N - 1), np.clip(rx.round().astype(int), 0, N - 1)
        w = (rr[:, :, 3] > 0.5) & win[iy, ix]
        a_, b_ = Gr[w] - Gr[w].mean(), Gf[iy[w], ix[w]] - Gf[iy[w], ix[w]].mean()
        return (a_ * b_).sum() / (np.sqrt((a_ * a_).sum() * (b_ * b_).sum()) + 1e-9)

    base = score(0, 0, 1.0); rb = (base, 0, 0, 1.0)
    for k in (0.97, 1.0, 1.03):
        for dy in range(-24, 25, 6):
            for dx in range(-24, 25, 6):
                v = score(dy, dx, k)
                if v > rb[0]: rb = (v, dy, dx, k)
    for dy in range(rb[1] - 4, rb[1] + 5, 2):
        for dx in range(rb[2] - 4, rb[2] + 5, 2):
            v = score(dy, dx, rb[3])
            if v > rb[0]: rb = (v, dy, dx, rb[3])
    return rb, base


# Hero renders are shot near eye level; steep views fit silhouettes by accident (Ares, Hera, Apollo hit 40-46 deg).
azs = range(0, 360, 10) if hero_az is None else range(int(hero_az) - 25, int(hero_az) + 26, 5)
cands = fit(hero_mask, azs, range(-15, 21, 5), keep=3 if hero_az is None else 1)
cands = cands if isinstance(cands, list) else [cands]
scored = [(refine(c), c) for c in cands]
for (rb, base), c in scored:
    print("CAND hero", round(c[0], 4), c[1], "edges", round(base, 4), "->", round(rb[0], 4), flush=True)
(rb, base), hb = max(scored, key=lambda t: t[0][0][0])
sources["hero"].update(iou=hb[0], az=hb[1][0], el=hb[1][1], map=hb[2], refine=rb[1:])
print("FIT hero", round(hb[0], 4), hb[1], "REFINE", round(base, 4), "->", round(rb[0], 4), rb[1:], flush=True)
front_az, front_iou = None, 0.0
if "front" in sources:
    # A front silhouette equals the back one; the face is visible in the hero, so search its half only.
    fb = fit(sources["front"]["mask"], range(int(hb[1][0]) - 80, int(hb[1][0]) + 81, 10), range(-10, 31, 10))
    print("FIT front", round(fb[0], 4), fb[1], flush=True)
    if fb[0] >= 0.6: front_az, front_iou = fb[1][0], float(fb[0])
for k in [k for k in sources if k != "hero"]: del sources[k]  # sheet poses differ from the model: facing only

# --- Local warp: Tripo reshapes the pose slightly and the hero is a perspective render, so one rigid camera
# leaves features doubled (Pawn's eyes) or offset. Per 16 px block (at 512 px) find the shift that best
# aligns shaded-render edges with reference edges (normalized cross-correlation), keep confident blocks,
# smooth the field, and apply it when projecting hero colours.
H5, BS, RAD = 512, 16, 10
place(sources["hero"]["az"], sources["hero"]["el"]); sc.display.shading.light = "STUDIO"; sc.display.shading.single_color = (0.8, 0.8, 0.8)
rr = render(review / "_refine.png", N)
dy0, dx0, k0 = sources["hero"]["refine"]
ry_, rx_ = to_img(sources["hero"], rows / (N / G), cols / (N / G), dy0, dx0, k0)
Gf_r = Gf[np.clip(ry_.round().astype(int), 0, N - 1), np.clip(rx_.round().astype(int), 0, N - 1)]
A5 = gradient(rr[:, :, :3].mean(-1) * rr[:, :, 3])[::2, ::2]; B5 = Gf_r[::2, ::2]
valid = grow(grow((rr[:, :, 3] > 0.5)[::2, ::2])).astype(float)
gh = H5 // BS


def bsum(X):
    return X.reshape(gh, BS, gh, BS).sum((1, 3))


Am = A5 * valid; nb = bsum(valid) + 1e-6; sa = bsum(Am); va = bsum(Am * Am) - sa * sa / nb
best = np.full((gh, gh), -2.0); fy = np.zeros((gh, gh)); fx = np.zeros((gh, gh))
for oy in range(-RAD, RAD + 1):
    for ox in range(-RAD, RAD + 1):
        Bs = np.roll(B5, (-oy, -ox), (0, 1)) * valid
        sb = bsum(Bs); cov = bsum(Am * Bs) - sa * sb / nb; vb = bsum(Bs * Bs) - sb * sb / nb
        ncc = cov / np.sqrt(np.maximum(va * vb, 1e-12)) - 0.002 * (oy * oy + ox * ox) ** 0.5  # mild preference for small shifts
        upd = ncc > best; best[upd] = ncc[upd]; fy[upd] = oy; fx[upd] = ox
conf = np.clip((best - 0.25) / 0.35, 0, 1) * (nb / BS ** 2 > 0.3)


def blur(X, wgt, r=2):
    k = np.exp(-0.5 * (np.arange(-r * 2, r * 2 + 1) / r) ** 2)
    def sep(Y):
        Y = np.apply_along_axis(lambda v: np.convolve(v, k, "same"), 0, Y)
        return np.apply_along_axis(lambda v: np.convolve(v, k, "same"), 1, Y)
    return sep(X * wgt) / np.maximum(sep(wgt), 1e-6)


fy, fx = blur(fy, conf), blur(fx, conf)
cov_ = blur(conf, np.ones_like(conf)); fy *= np.clip(cov_ * 3, 0, 1); fx *= np.clip(cov_ * 3, 0, 1)  # fade to 0 where nothing matched
print("WARP blocks", int((conf > 0).sum()), "of", int((nb / BS ** 2 > 0.3).sum()), "max shift", round(float(np.hypot(fy, fx).max()), 1), "px@512", flush=True)


def warp_at(r5, c5):
    """Bilinear sample of the block flow at a 512-res render position (rows bottom-up)."""
    gy_, gx_ = np.clip(r5 / BS - 0.5, 0, gh - 1.001), np.clip(c5 / BS - 0.5, 0, gh - 1.001)
    y0, x0 = int(gy_), int(gx_); ty, tx = gy_ - y0, gx_ - x0
    def bil(F): return (F[y0, x0] * (1 - ty) + F[y0 + 1, x0] * ty) * (1 - tx) + (F[y0, x0 + 1] * (1 - ty) + F[y0 + 1, x0 + 1] * ty) * tx
    return bil(fy), bil(fx)


def hero_map(px, py):
    """Normalized hero-camera position (x right, y up) -> hero image pixel (row bottom-up, col)."""
    S = sources["hero"]; dy, dx, k = S["refine"]
    wy, wx = warp_at(py * H5, px * H5)
    return to_img(S, (py * H5 + wy) * G / H5, (px * H5 + wx) * G / H5, dy, dx, k)


LM_SIGMA = 0.07  # normalized render units (~54 px at 768); tighter bends features into streaks (Ox right eye)
lm_pts, lm_w = np.zeros((0, 2)), np.zeros((0, 2))
if landmarks:
    lm_pts = np.array([[l["render"][0] / 768, 1 - l["render"][1] / 768] for l in landmarks])
    # "ref": the feature's pixel in the reference (768 frame). "paint": where the current paint shows that feature
    # in paint_hero.png - its reference pixel is then whatever that render point maps to without landmarks.
    want = np.array([[N - l["ref"][1] * N / 768, l["ref"][0] * N / 768] if "ref" in l else
                     hero_map(l["paint"][0] / 768, 1 - l["paint"][1] / 768) for l in landmarks])
    have = np.array([hero_map(x, y) for x, y in lm_pts])
    d2 = ((lm_pts[:, None] - lm_pts[None]) ** 2).sum(-1)
    lm_w = np.linalg.solve(np.exp(-d2 / (2 * LM_SIGMA ** 2)) + 1e-6 * np.eye(len(lm_pts)), want - have)
    print("LANDMARKS", len(landmarks), "max correction px@1024", round(float(np.abs(want - have).max()), 1), flush=True)


def lm_corr(px, py):
    if not len(lm_pts): return 0.0, 0.0
    phi = np.exp(-((lm_pts - [px, py]) ** 2).sum(1) / (2 * LM_SIGMA ** 2))
    c = phi @ lm_w; return float(c[0]), float(c[1])


# Gray render of the fitted hero view in the paint_hero frame, for picking landmarks.
place(sources["hero"]["az"], sources["hero"]["el"]); sc.display.shading.light = "STUDIO"; sc.display.shading.single_color = (0.8, 0.8, 0.8)
sc.display.shading.show_cavity = True
render(review / "landmarks_render.png", 768); sc.display.shading.show_cavity = False


# --- Per-source, per-vertex projection: image UV, view weight (grazing fades out), occlusion.
bvh = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
n = len(me.vertices)
nrm = np.array([(o.matrix_world.to_3x3() @ v.normal).normalized() for v in me.vertices])
for name, S in sources.items():
    place(S["az"], S["el"]); d = view_dir(S["az"], S["el"]); dy, dx, k = S.get("refine", (0, 0, 1.0))
    uv = np.zeros((n, 2)); w = np.zeros(n); sz = S["size"]
    for idx in range(n):
        p = world_to_camera_view(sc, cam, Vector(co[idx]))
        if name == "hero":
            ry, rx = hero_map(p.x, p.y); cy, cx = lm_corr(p.x, p.y); ry += cy; rx += cx
        else:
            ry, rx = to_img(S, p.y * G, p.x * G, dy, dx, k)
        uv[idx] = (rx / sz, ry / sz)
        nd = float(nrm[idx] @ np.array(d))
        # Grazing faces stretch a few image pixels into streaks; leave them to the clean palette fill.
        if nd < 0.2 or not (0 <= rx < sz and 0 <= ry < sz): continue
        if bvh.ray_cast(Vector(co[idx]) + d * size * 0.01 + Vector(nrm[idx]) * size * 1e-3, d)[0] is not None: continue  # smaller offsets self-hit
        w[idx] = min(1.0, (nd - 0.2) / 0.35)
    S.update(uv=uv, w=w)
    print("SEEN", name, int((w > 0).sum()), "of", n, flush=True)

# Per-triangle hero visibility: faces the hero camera and its centroid is unblocked. Tripo hair and cloaks are
# noisy thin shells whose vertex normals point every which way, so per-vertex tests left most of the visible
# side unpainted (Taurus: 15% of triangles).
loop_v = np.zeros(len(me.loops), int); me.loops.foreach_get("vertex_index", loop_v)
poly_start = np.zeros(len(me.polygons), int); me.polygons.foreach_get("loop_start", poly_start)
tri = loop_v[poly_start[:, None] + np.arange(3)]
d_h = view_dir(sources["hero"]["az"], sources["hero"]["el"]); dh = np.array(d_h)
fco = co[tri]; fn = np.cross(fco[:, 1] - fco[:, 0], fco[:, 2] - fco[:, 0])
fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12); cen = fco.mean(1)
hero_vis_face = np.abs(fn @ dh) > 0.05  # double-sided: some Tripo meshes are wound inside-out (Virgo); the ray test drops inner shells
for fi in np.nonzero(hero_vis_face)[0]:
    hit = bvh.ray_cast(Vector(cen[fi]) + d_h * size * 0.002, d_h)
    if hit[0] is not None and hit[3] > 0.015 * size:  # nearer hits are the same thin doubled shell (Virgo: 97% of rays)
        hero_vis_face[fi] = False
seen_v = np.zeros(n, bool); seen_v[tri[hero_vis_face].ravel()] = True
sources["hero"]["w"] = np.where(seen_v, np.maximum(sources["hero"]["w"], 0.5), 0.0)
print("HERO faces visible", int(hero_vis_face.sum()), "of", len(tri), flush=True)

if face_spec:
    FS = face_spec; place(FS["az"], FS["el"]); d_f = view_dir(FS["az"], FS["el"]); df = np.array(d_f)
    pf = np.array([world_to_camera_view(sc, cam, Vector(c_))[:2] for c_ in co])  # normalized x right, y up
    # Head centre: ray from the face camera through the marked pixel.
    cx_, cy_ = FS["center"][0] / 768, 1 - FS["center"][1] / 768
    q_ = cam.rotation_euler.to_quaternion(); right_, up_ = q_ @ Vector((1, 0, 0)), q_ @ Vector((0, 1, 0))
    origin_ = cam.location + right_ * (cx_ - 0.5) * cam.data.ortho_scale + up_ * (cy_ - 0.5) * cam.data.ortho_scale
    hit_ = bvh.ray_cast(origin_, -d_f)[0]; assert hit_ is not None, "face centre misses the mesh"
    R_ = FS["radius"] / 768 * cam.data.ortho_scale
    dist_ = np.linalg.norm(co - np.array(hit_), axis=1)
    t_face = np.clip((R_ - dist_) / (0.35 * R_), 0, 1)
    L_ = FS["landmarks"]; P_ = np.array([[l["render"][0] / 768, 1 - l["render"][1] / 768] for l in L_])
    W_ = np.array([[N - l["ref"][1] * N / 768, l["ref"][0] * N / 768] for l in L_])
    X_ = np.c_[P_, np.ones(len(P_))]; A_ = np.linalg.lstsq(X_, W_, rcond=None)[0]
    res_ = W_ - X_ @ A_
    # Regularized: close landmarks (mouth corners, nostrils) made an exact RBF overshoot and balloon features (Goat eyes).
    K_ = np.exp(-((P_[:, None] - P_[None]) ** 2).sum(-1) / (2 * LM_SIGMA ** 2)) + FS.get("smooth", 0.5) * np.eye(len(P_))
    Wr_ = np.linalg.solve(K_, res_)
    # "mirror": "left"/"right" copies that (near, undistorted) half of the reference face onto the other half
    # about the vertical through "center": a 3/4 reference squeezes the far eye, which looks wrong on a
    # frontal Tripo face. The copied half is mirror-imaged, which suits these symmetric faces.
    q_pf = pf.copy()
    if FS.get("mirror"):
        far = (pf[:, 0] > cx_) if FS["mirror"] == "left" else (pf[:, 0] < cx_)
        q_pf[far, 0] = 2 * cx_ - pf[far, 0]
    phi_ = np.exp(-((q_pf[:, None] - P_[None]) ** 2).sum(-1) / (2 * LM_SIGMA ** 2))
    rc_face = np.c_[q_pf, np.ones(n)] @ A_ + phi_ @ Wr_  # (row, col) in the N px reference
    uv_face = np.stack([rc_face[:, 1] / N, rc_face[:, 0] / N], 1)
    H_ = sources["hero"]; H_["uv"] = H_["uv"] * (1 - t_face[:, None]) + uv_face * t_face[:, None]
    # Visibility from the face camera inside the head region.
    fco_ = co[tri]; cen_ = fco_.mean(1); t_c = t_face[tri].mean(1)
    face_vis = (t_c > 0.5) & (np.abs(fn @ df) > 0.05)
    for fi in np.nonzero(face_vis)[0]:
        hit = bvh.ray_cast(Vector(cen_[fi]) + d_f * size * 0.002, d_f)
        if hit[0] is not None and hit[3] > 0.04 * size: face_vis[fi] = False  # a lid overhang is fine; another body part is not
    hero_vis_face = np.where(t_c > 0.5, face_vis, hero_vis_face)
    seen_v = np.zeros(n, bool); seen_v[tri[hero_vis_face].ravel()] = True
    H_["w"] = np.where(seen_v, np.maximum(H_["w"], 0.5), 0.0)
    print("FACECAM", FS["az"], FS["el"], "head verts", int((t_face > 0).sum()), "face tris", int(face_vis.sum()),
          "affine rms px", round(float(np.sqrt((res_ ** 2).sum(1).mean())), 1), flush=True)

# Mirror of the hero across X or Y through the bounding centre, whichever maps the surface onto itself.
kd_all = KDTree(n)
for idx in range(n): kd_all.insert(Vector(co[idx]), idx)
kd_all.balance()
sub = co[:: max(1, n // 2000)]


def sym_err(ax):
    m = sub.copy(); m[:, ax] = 2 * centre[ax] - m[:, ax]
    return float(np.median([kd_all.find(Vector(p))[2] for p in m]))


axis = min((0, 1), key=sym_err)
H = sources["hero"]; seen_idx = np.nonzero(H["w"] > 0)[0]
kd = KDTree(len(seen_idx))
for idx in seen_idx: kd.insert(Vector(co[idx]), int(idx))
kd.balance()
partner = np.full(n, -1)
for idx in np.nonzero(H["w"] == 0)[0]:
    m = co[idx].copy(); m[axis] = 2 * centre[axis] - m[axis]
    _, j, dist = kd.find(Vector(m))
    if j is not None and dist < 0.02 * size: partner[idx] = j
mw = np.where(partner >= 0, H["w"][np.maximum(partner, 0)], 0.0)
sources["mirror"] = dict(uv=H["uv"][np.maximum(partner, 0)], w=mw, col=H["col"], size=N)
print("MIRROR axis", "XY"[axis], round(sym_err(axis) / size, 4), int((mw > 0).sum()), flush=True)

# --- Atlas: hero (and mirror) in the left 1024 square, sheet views in 512 cells on the right.
names = list(sources)
cell = {"hero": (0, 0, 1.0), "mirror": (0, 0, 1.0)}
for i_, name in enumerate([k for k in names if k not in cell]):
    cell[name] = (N + (i_ % 2) * V, (i_ // 2) * V, 0.5)
atlas = np.zeros((N, 2 * N, 3), np.float32)
for name in names:
    x0, y0, sc_ = cell[name]; c = sources[name]["col"]; atlas[y0:y0 + c.shape[0], x0:x0 + c.shape[1]] = c


def atlas_uv(name, uv):
    x0, y0, sc_ = cell[name]
    return np.stack([(x0 + uv[:, 0] * N * sc_) / (2 * N), (y0 + uv[:, 1] * N * sc_) / N], 1)


def sample(name, uv):
    a = atlas_uv(name, uv)
    return atlas[np.clip((a[:, 1] * N).astype(int), 0, N - 1), np.clip((a[:, 0] * 2 * N).astype(int), 0, 2 * N - 1)]


# --- Textured faces come from the hero and its mirror only (exact pose). Best priority-weighted minimum corner weight.
loop_v = np.zeros(len(me.loops), int); me.loops.foreach_get("vertex_index", loop_v)
poly_start = np.zeros(len(me.polygons), int); me.polygons.foreach_get("loop_start", poly_start)
tri = loop_v[poly_start[:, None] + np.arange(3)]
assert all(len(p.vertices) == 3 for p in me.polygons), "expected triangles"
textured = ["hero", "mirror"]
score_f = np.stack([PRIORITY[nm] * sources[nm]["w"][tri].min(1) for nm in textured], 1)
choice = np.where(score_f.max(1) > 0, score_f.argmax(1), -1)
mirror_ok = sources["mirror"]["w"][tri].min(1) > 0
choice = np.where(hero_vis_face, 0, np.where(mirror_ok, 1, -1))  # face-based: never put the front image on a back face
colors = np.zeros((n, 3), np.float32); vbest = np.zeros(n)
for nm in textured:
    pw = PRIORITY[nm] * sources[nm]["w"]; better = pw > vbest
    colors[better] = sample(nm, sources[nm]["uv"][better]); vbest[better] = pw[better]
seen = vbest > 0
print("FACES", {nm: int((choice == i_).sum()) for i_, nm in enumerate(textured)}, "fill", int((choice < 0).sum()), "of", len(tri), flush=True)

# --- Palette from the hero: k-means, minus clusters that are just blends of two others (anti-aliased edges).
rng = np.random.default_rng(0)
hc = hero_col[hero_full][rng.choice(int(hero_full.sum()), 40000)]
cent = hc[rng.choice(len(hc), 10, replace=False)]
for _ in range(30):
    lab_ = ((hc[:, None] - cent[None]) ** 2).sum(-1).argmin(1)
    cent = np.array([hc[lab_ == c].mean(0) if (lab_ == c).any() else cent[c] for c in range(len(cent))])
share = np.bincount(((hc[:, None] - cent[None]) ** 2).sum(-1).argmin(1), minlength=len(cent)) / len(hc)
keep = np.ones(len(cent), bool)
for c in np.argsort(share):
    others = [j for j in range(len(cent)) if j != c and keep[j]]
    for i1 in others:
        for i2 in others:
            if i1 >= i2: continue
            seg = cent[i2] - cent[i1]; t = float(np.clip((cent[c] - cent[i1]) @ seg / (seg @ seg + 1e-9), 0, 1))
            if 0.15 < t < 0.85 and np.linalg.norm(cent[i1] + t * seg - cent[c]) < 0.03 and share[c] < 0.12:
                keep[c] = False
cent, share = cent[keep], share[keep] / share[keep].sum()
quant = lambda c: ((c[:, None] - cent[None]) ** 2).sum(-1).argmin(1)
print("PALETTE", np.round(cent * 255).astype(int).tolist(), flush=True)

# --- Hidden surfaces: palette colours chosen by spatial neighbourhood (KD-tree over the visible surface, in
# 3D), not mesh edges. Tripo hair and cloaks are thin disconnected shells, so edge propagation shattered the
# far side into shards. Each hidden vertex takes a distance-weighted vote of its nearest seen neighbours'
# palette labels, then a few rounds of spatial majority smoothing give large, calm regions.
from mathutils.kdtree import KDTree as _KD
labels = np.full(n, -1); labels[seen] = quant(colors[seen])
free = ~seen
si = np.nonzero(seen)[0]; fi_ = np.nonzero(free)[0]
kd_s = _KD(len(si))
for j in si: kd_s.insert(Vector(co[j]), int(j))
kd_s.balance()
K = 24; rad = 0.08 * size
accent = share < 0.06
lum = cent @ np.array([0.299, 0.587, 0.114])
for idx in fi_:
    votes = np.zeros(len(cent))
    for (_, j, dist) in kd_s.find_n(Vector(co[idx]), K):
        votes[labels[j]] += share[labels[j]] ** 0.75 * (0.35 + lum[labels[j]]) / (dist + 0.02 * size)  # main body colours, not shading (Rabbit's back took ear orange; Fog/Hail went charcoal)
    labels[idx] = int(votes.argmax())
kd_a = _KD(n)
for j in range(n): kd_a.insert(Vector(co[j]), j)
kd_a.balance()
nbrs = {int(i): [j for (_, j, _) in kd_a.find_range(Vector(co[i]), rad)] for i in fi_}
for _ in range(4):
    new = labels.copy()
    for i, js in nbrs.items():
        cnt_ = np.bincount(labels[js], minlength=len(cent)); new[i] = int(cnt_.argmax())
    labels = new
colors[free] = cent[labels[free]]
print("FILL hidden", len(fi_), "palette", len(cent), flush=True)


# --- Two materials. "Hero" faces map straight onto the prepared reference image: crisp, seamless, no bake.
# "Fill" faces (unseen from the hero) get a small baked texture of their smooth palette colours. Baking
# everything into one Smart-UV atlas shredded the visible side into thousands of tiny islands that Roblox's
# 1024 px texture cap turned into flat shards.
def linear(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4).astype(np.float32)


fill = me.color_attributes.new("fill", "FLOAT_COLOR", "POINT")
fill.data.foreach_set("color", np.concatenate([linear(colors), np.ones((n, 1), np.float32)], 1).ravel())
luv = np.zeros((len(me.loops), 2))
for i_, nm in enumerate(textured):
    f = np.nonzero(choice == i_)[0]
    if not len(f): continue
    ls = (poly_start[f, None] + np.arange(3)).ravel()
    luv[ls] = np.clip(sources[nm]["uv"][loop_v[ls]], 0, 1)
t_uv = luv[poly_start[:, None] + np.arange(3)]
uv_area = np.abs((t_uv[:, 1, 0] - t_uv[:, 0, 0]) * (t_uv[:, 2, 1] - t_uv[:, 0, 1]) - (t_uv[:, 1, 1] - t_uv[:, 0, 1]) * (t_uv[:, 2, 0] - t_uv[:, 0, 0]))
hero_face = (choice >= 0) & (uv_area * N * N > 1e-3)  # sub-texel slivers go to fill (importer rejects zero-area UVs)
# Majority-filter the hero/fill split over edge-adjacent faces: lone faces of the other material leave
# point-touching fans in the importer's parts that Blender reimports with zero normals (Moonrace Dragon).
_ef = {}
for p_ in me.polygons:
    for ek in p_.edge_keys: _ef.setdefault(ek, []).append(p_.index)
_adj = [[] for _ in range(len(me.polygons))]
for fs_ in _ef.values():
    for a_ in fs_:
        _adj[a_].extend(b_ for b_ in fs_ if b_ != a_)
for _ in range(2):
    nb_ = np.array([np.mean(hero_face[js]) if js else float(hero_face[i]) for i, js in enumerate(_adj)])
    hero_face = np.where(nb_ > 0.5, True, np.where(nb_ < 0.5, False, hero_face)) & (uv_area * N * N > 1e-3)
# Where one material's faces touch a vertex as separate fans (only a point in common), give the whole fan to
# fill: such point contacts reimport with zero normals in Blender and fail the lossless gate (Moonrace Dragon).
_vf = {}
for p_ in me.polygons:
    for v_ in p_.vertices: _vf.setdefault(v_, []).append(p_.index)
_fe = [set(me.polygons[i].edge_keys) for i in range(len(me.polygons))]
for _ in range(3):
    changed_ = 0
    for v_, fs_ in _vf.items():
        for mat_ in (True, False):
            sel_ = [f_ for f_ in fs_ if hero_face[f_] == mat_]
            if len(sel_) < 2: continue
            comp_ = {sel_[0]}; grew_ = True
            while grew_:
                grew_ = False
                for f_ in sel_:
                    if f_ not in comp_ and any(_fe[f_] & _fe[g_] for g_ in comp_): comp_.add(f_); grew_ = True
            if len(comp_) < len(sel_):
                for f_ in fs_:
                    if hero_face[f_]: hero_face[f_] = False; changed_ += 1
    if not changed_: break
bpy.context.view_layer.objects.active = o; o.select_set(True)
uv0 = me.uv_layers.new(name="UVMap"); me.uv_layers.active = uv0; uv0.data.foreach_set("uv", luv.ravel())
import bmesh
bpy.context.tool_settings.mesh_select_mode = (False, False, True)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="DESELECT")
bm_ = bmesh.from_edit_mesh(me); bm_.faces.ensure_lookup_table()
for f_ in bm_.faces: f_.select_set(not hero_face[f_.index])
bmesh.update_edit_mesh(me)
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
# Smart UV packs every island in the mesh; with hero faces hidden it packs only the fill islands.
bpy.ops.mesh.reveal(); bpy.ops.mesh.select_all(action="DESELECT")
bm_ = bmesh.from_edit_mesh(me); bm_.faces.ensure_lookup_table()
for f_ in bm_.faces: f_.select_set(not hero_face[f_.index])
bmesh.update_edit_mesh(me)
bpy.ops.mesh.hide(unselected=True)
bpy.context.scene.tool_settings.use_uv_select_sync = True
bpy.ops.uv.select_all(action="SELECT"); bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
bpy.ops.mesh.reveal()
bpy.ops.object.mode_set(mode="OBJECT")
fill_uv = np.zeros(len(me.loops) * 2); me.uv_layers["UVMap"].data.foreach_get("uv", fill_uv); fill_uv = fill_uv.reshape(-1, 2)
hl = (poly_start[hero_face, None] + np.arange(3)).ravel(); fill_uv[hl] = luv[hl]  # projection UVs win on hero faces
me.uv_layers["UVMap"].data.foreach_set("uv", fill_uv.ravel())
stem = pathlib.Path(out_glb).stem
hero_img = bpy.data.images.new(stem + "_hero", N, N, alpha=False)
hero_img.pixels.foreach_set(np.concatenate([np.clip(hero_col, 0, 1), np.ones((N, N, 1), np.float32)], 2).ravel()); hero_img.pack()
fill_img = bpy.data.images.new(stem + "_fill", 1024, 1024, alpha=False)
dummy = bpy.data.images.new("dummy", 8, 8)
mats = []
for nm_, img_ in (("hero", dummy), ("fill", fill_img)):
    m_ = bpy.data.materials.new("bake_" + nm_); m_.use_nodes = True; nt = m_.node_tree; nt.nodes.clear()
    vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "fill"
    em = nt.nodes.new("ShaderNodeEmission"); outn = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(vc.outputs["Color"], em.inputs["Color"]); nt.links.new(em.outputs["Emission"], outn.inputs["Surface"])
    t_ = nt.nodes.new("ShaderNodeTexImage"); t_.image = img_; nt.nodes.active = t_
    mats.append(m_)
me.materials.clear(); [me.materials.append(m_) for m_ in mats]
mi_ = np.where(hero_face, 0, 1).astype(np.int32)
me.polygons.foreach_set("material_index", mi_)
sc.render.engine = "CYCLES"; sc.cycles.samples = 4; sc.cycles.device = "CPU"
sc.render.bake.margin = 8; sc.render.bake.use_clear = True
bpy.ops.object.bake(type="EMIT")
fill_img.pack()

# --- Clean export: geometry + UV0 + two textured materials, no extra attributes.
for a in [a for a in me.color_attributes if a.name == "fill"]: me.color_attributes.remove(a)
me.materials.clear()  # clearing resets material_index to 0; restored below
for nm_, img_ in (("hero", hero_img), ("fill", fill_img)):
    m_ = bpy.data.materials.new(f"{stem}_{nm_}"); m_.use_nodes = True
    bsdf = next(x for x in m_.node_tree.nodes if x.type == "BSDF_PRINCIPLED")
    t2 = m_.node_tree.nodes.new("ShaderNodeTexImage"); t2.image = img_
    m_.node_tree.links.new(t2.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6; bsdf.inputs["Metallic"].default_value = 0.0
    me.materials.append(m_)
me.polygons.foreach_set("material_index", mi_); me.update()
# Consistent outward winding (Tripo mixes it; Roblox culls back faces) and plain smooth normals from the geometry.
# Tripo's own normals are smooth vertex normals too, but at folded spots a part boundary leaves fans where
# Blender can't store them and the glTF reimport turns them to zero (Moonrace Dragon) - a black dot in-game.
import bmesh as _bm
bmw = _bm.new(); bmw.from_mesh(me); _bm.ops.recalc_face_normals(bmw, faces=bmw.faces); bmw.to_mesh(me); bmw.free()
if me.has_custom_normals: me.normals_split_custom_set([(0.0, 0.0, 0.0)] * len(me.loops))
me.shade_smooth()
o.name = me.name = "Body"
pathlib.Path(out_glb).parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_texcoords=True,
                          export_normals=True, export_vertex_color="NONE", export_extras=False,
                          export_animations=False, export_yup=True)
print("MATERIALS hero faces", int(hero_face.sum()), "fill faces", int((~hero_face).sum()), flush=True)

# --- Review renders: albedo-only hero view, then lit views around the figure from its fitted front.
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.color_type = "TEXTURE"; sc.render.film_transparent = False
fa_ = front_az if front_az is not None else sources["hero"]["az"]
for name, (a_, e_, light) in {"hero": (sources["hero"]["az"], sources["hero"]["el"], "FLAT"), "front": (fa_, 10, "STUDIO"),
                              "three_quarter": (fa_ + 45, 15, "STUDIO"), "side": (fa_ + 90, 10, "STUDIO"),
                              "back": (fa_ + 180, 15, "STUDIO"), "other_side": (fa_ - 90, 10, "STUDIO")}.items():
    sc.display.shading.light = light; place(a_, e_); render(review / f"paint_{name}.png", 768)
json.dump(dict(source=src, hero=hero_path, sheet=sheet_path, repairs=repairs, front_az=front_az, axis="XY"[axis], refine=list(sources["hero"]["refine"]),
               fits={nm: dict(iou=float(sources[nm]["iou"]), az=sources[nm]["az"], el=sources[nm]["el"]) for nm in names if "iou" in sources[nm]},
               faces={nm: int((choice == i_).sum()) for i_, nm in enumerate(textured)}, front_iou=front_iou, fill_faces=int((~hero_face).sum()), triangles=len(tri)),
          open(review / "paint.json", "w", encoding="utf-8"), indent=1)
for f in ("_fit.png", "_refine.png"): (review / f).unlink(missing_ok=True)
print("DONE", out_glb, flush=True)
