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

src, hero_path, sheet_path, out_glb, review, *hero_az = sys.argv[sys.argv.index("--") + 1:]
hero_az = float(hero_az[0]) if hero_az else None
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
bm = bmesh.new(); bm.from_mesh(me)
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


# --- Per-source, per-vertex projection: image UV, view weight (grazing fades out), occlusion.
bvh = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
n = len(me.vertices)
nrm = np.array([(o.matrix_world.to_3x3() @ v.normal).normalized() for v in me.vertices])
for name, S in sources.items():
    place(S["az"], S["el"]); d = view_dir(S["az"], S["el"]); dy, dx, k = S.get("refine", (0, 0, 1.0))
    uv = np.zeros((n, 2)); w = np.zeros(n); sz = S["size"]
    for idx in range(n):
        p = world_to_camera_view(sc, cam, Vector(co[idx]))
        wy, wx = warp_at(p.y * H5, p.x * H5) if name == "hero" else (0.0, 0.0)
        ry, rx = to_img(S, (p.y * H5 + wy) * G / H5, (p.x * H5 + wx) * G / H5, dy, dx, k)
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
    if bvh.ray_cast(Vector(cen[fi]) + d_h * size * 0.002, d_h)[0] is not None:
        hero_vis_face[fi] = False
seen_v = np.zeros(n, bool); seen_v[tri[hero_vis_face].ravel()] = True
sources["hero"]["w"] = np.where(seen_v, np.maximum(sources["hero"]["w"], 0.5), 0.0)
print("HERO faces visible", int(hero_vis_face.sum()), "of", len(tri), flush=True)

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
for idx in fi_:
    votes = np.zeros(len(cent))
    for (_, j, dist) in kd_s.find_n(Vector(co[idx]), K):
        votes[labels[j]] += share[labels[j]] ** 0.75 / (dist + 0.02 * size)  # hidden sides lean to main body colours (Rabbit's back took ear orange)
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
