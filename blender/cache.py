"""Content-keyed cache for the slow bakes (the bounce lightmap, the per-object colour bakes).

The key is a hash of what the bake actually sees, taken inside Blender just before baking: every render-visible
object's evaluated mesh in world space (posed people included: they shade and occlude the bounce), its UVs and
materials (node values and the image contents), the lights, the world, and the Cycles / bake settings.
No table of which script feeds which bake is trusted: if anything the bake would see differs, the key differs.

FAST=1 (the quick look while fixing, never for a version that ships): when the exact key misses, reuse the last
lightmap baked for the same static geometry and UVs (so the texels still land in the right place) and say so with
"LM_STALE" in the log. build.sh turns this into a line in the check list.

Files: <WORK>/cache/<kind>/<key>.<ext>; the newest few per kind are kept.
KEYDEBUG=<file>: write the running hash before each object (two runs diffed show which object differs); the
export stops right after the key."""
import os, hashlib, shutil, glob
import numpy as np
import bpy
import paths as P

DIR = f'{P.WORK}/cache'
KEEP = 8
_file_h = {}

def _file_hash(path):
    st = os.stat(path); k = (path, st.st_size, st.st_mtime_ns)
    if k not in _file_h:
        h = hashlib.sha256()
        with open(path, 'rb') as f:
            for b in iter(lambda: f.read(1 << 22), b''): h.update(b)
        _file_h[k] = h.hexdigest()
    return _file_h[k]

def _image(h, im, skip):
    if im is None: h.update(b'noimg'); return
    if im.name in skip: h.update(b'skip'); return
    h.update(f'{im.name}|{im.source}|{im.size[:]}|{im.colorspace_settings.name}|{im.alpha_mode}'.encode())
    fp = bpy.path.abspath(im.filepath_raw or im.filepath) if (im.filepath_raw or im.filepath) else ''
    made_here = fp.startswith((f'{P.KF}/export_tex/', f'{P.TRIPO}/')) and fp.endswith(('_tinted.png', '_bake.png', '_socks.png'))
    if fp and os.path.exists(fp) and not im.is_dirty and not im.packed_file and not made_here:
        h.update(_file_hash(fp).encode())   # a file on disk (assets, prep results): its bytes
    elif im.has_data or im.source == 'GENERATED' or made_here:   # made during this export: the PNG bytes differ run to run, the pixels do not
        a = np.empty(len(im.pixels), np.float32); im.pixels.foreach_get(a); h.update(a.tobytes())
    else:
        h.update(f'missing:{fp}'.encode())   # a missing file shades as pink: still a state of its own

_SIMPLE = {'BOOLEAN', 'INT', 'FLOAT', 'STRING', 'ENUM'}
def _rna(h, obj, skip=(), depth=0):
    """Every plain property of an RNA struct (values, arrays, enums), in a fixed order."""
    for p in obj.bl_rna.properties:
        if p.identifier in ('rna_type', 'name_full', 'is_evaluated', 'original', 'users', 'session_uid', 'select', 'location', 'width', 'height', 'dimensions', 'is_active_output', 'show_options', 'show_preview', 'show_texture', 'hide', 'mute_preview') : continue
        if p.identifier in skip: continue
        if p.type in _SIMPLE:
            try: v = getattr(obj, p.identifier)
            except Exception: continue
            if isinstance(v, (set, frozenset)): v = tuple(sorted(v))   # enum flags come as a set: no fixed order
            elif hasattr(v, '__len__') and not isinstance(v, str):
                try: v = tuple(v)
                except TypeError: pass
            h.update(f'{p.identifier}={v!r};'.encode())

def _tree(h, nt, skip, seen):
    if nt is None: h.update(b'notree'); return
    if nt.name in seen: h.update(f'tree:{nt.name}'.encode()); return
    seen.add(nt.name)
    for n in sorted(nt.nodes, key=lambda n: n.name):
        h.update(f'N{n.bl_idname}:{n.name}'.encode()); _rna(h, n)
        if getattr(n, 'image', None) is not None or n.bl_idname == 'ShaderNodeTexImage': _image(h, getattr(n, 'image', None), skip)
        if getattr(n, 'node_tree', None) is not None: _tree(h, n.node_tree, skip, seen)
        for s in list(n.inputs) + list(n.outputs):
            if hasattr(s, 'default_value'):
                v = s.default_value
                try: v = tuple(v)
                except TypeError: pass
                h.update(f'{s.identifier}={v!r}{s.enabled};'.encode())
    for l in sorted(nt.links, key=lambda l: (l.from_node.name, l.from_socket.identifier, l.to_node.name, l.to_socket.identifier)):
        h.update(f'L{l.from_node.name}.{l.from_socket.identifier}>{l.to_node.name}.{l.to_socket.identifier}{l.is_muted};'.encode())

def _mesh(h, o, dg, uvs=True):
    """The evaluated surface in world space, independent of the order of its faces and corners (some modifiers do
    not give the same order on every run): every corner as (position, UVs, material, smooth), sorted; every face as
    (centre, corner count, material, smooth), sorted."""
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    try:
        n = len(me.vertices); co = np.empty(n * 3, np.float32); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
        mw = np.array(ev.matrix_world, np.float64); co = (co @ mw[:3, :3].T + mw[:3, 3]).astype(np.float32)
        nl, npo = len(me.loops), len(me.polygons)
        lv = np.empty(nl, np.int32); me.loops.foreach_get('vertex_index', lv)
        ps = np.empty(npo, np.int32); me.polygons.foreach_get('loop_start', ps)
        pt = np.empty(npo, np.int32); me.polygons.foreach_get('loop_total', pt)
        mi = np.empty(npo, np.int32); me.polygons.foreach_get('material_index', mi)
        sm = np.empty(npo, np.bool_); me.polygons.foreach_get('use_smooth', sm)
        pid = np.empty(nl, np.int32)
        pid[np.concatenate([np.arange(a, a + c) for a, c in zip(ps, pt)]) if npo else []] = np.repeat(np.arange(npo), pt) if npo else []
        cols = [co[lv]]
        if uvs:
            for uv in me.uv_layers:
                a = np.empty(nl * 2, np.float32); uv.data.foreach_get('uv', a); cols.append(a.reshape(-1, 2))
                h.update(f'uv:{uv.name}:{uv.active_render}'.encode())
        cols += [mi[pid].astype(np.float32)[:, None], sm[pid].astype(np.float32)[:, None]]
        rows = np.concatenate(cols, 1) if nl else np.zeros((0, 1), np.float32)
        h.update(f'{n} {nl} {npo}'.encode()); h.update(rows[np.lexsort(rows.T[::-1])].tobytes())
        if npo:
            cen = np.add.reduceat(co[lv][np.argsort(pid, kind='stable')], np.concatenate([[0], np.cumsum(pt)[:-1]]), axis=0) / pt[:, None]
            prow = np.concatenate([cen.astype(np.float32), pt[:, None].astype(np.float32), mi[:, None].astype(np.float32), sm[:, None].astype(np.float32)], 1)
            h.update(prow[np.lexsort(prow.T[::-1])].tobytes())
    finally:
        ev.to_mesh_clear()

def scene_key(extra='', skip_images=(), only=None):
    """Hash of everything a Cycles bake of this scene sees. `only`: hash just these objects (the static geometry key)."""
    dg = bpy.context.evaluated_depsgraph_get()
    h = hashlib.sha256(); h.update(f'blender {bpy.app.version_string}|{extra}'.encode())
    s = bpy.context.scene
    if only is None:
        _rna(h, s.cycles); _rna(h, s.render.bake); h.update(f'{s.render.engine}'.encode())
        if s.world: _rna(h, s.world); _tree(h, s.world.node_tree, skip_images, set())
    seen = set()
    objs = only if only is not None else [o for o in s.objects if o.visible_get() and not o.hide_render]
    dbg = open(os.environ['KEYDEBUG'], 'a') if os.environ.get('KEYDEBUG') else None
    if dbg: dbg.write(f'== {extra}\nscene {h.copy().hexdigest()[:12]}\n')
    for o in sorted(objs, key=lambda o: o.name):
        if dbg: dbg.write(f'{o.name} {h.copy().hexdigest()[:12]}\n')
        h.update(f'O{o.name}:{o.type}:{o.hide_render}'.encode())
        h.update(f'{o.visible_camera}{o.visible_diffuse}{o.visible_glossy}{o.visible_shadow}{o.visible_transmission}{o.visible_volume_scatter}'.encode())
        if o.type in ('MESH', 'CURVE', 'SURFACE', 'FONT', 'META'):
            _mesh(h, o, dg)
            if only is None:
                for ms in o.material_slots:
                    m = ms.material; h.update(f'M{m.name if m else None}:{ms.link}'.encode())
                    if m: _rna(h, m); _tree(h, m.node_tree if m.use_nodes else None, skip_images, seen)
        elif o.type == 'LIGHT' and only is None:
            h.update(np.array(o.matrix_world, np.float64).tobytes()); _rna(h, o.data)
            if o.data.use_nodes: _tree(h, o.data.node_tree, skip_images, seen)
    return h.hexdigest()[:24]

def _path(kind, key, ext): return f'{DIR}/{kind}/{key}{ext}'

def get(kind, key, dst, ext='.exr'):
    p = _path(kind, key, ext)
    if not os.path.exists(p): return False
    shutil.copyfile(p, dst); os.utime(p); return True

def put(kind, key, src, ext='.exr'):
    os.makedirs(f'{DIR}/{kind}', exist_ok=True)
    shutil.copyfile(src, _path(kind, key, ext))
    old = sorted(glob.glob(f'{DIR}/{kind}/*{ext}'), key=os.path.getmtime)[:-KEEP]
    for f in old: os.remove(f)

def note(kind, name, value):
    """Small text records (the geometry key -> the newest full key for that geometry)."""
    os.makedirs(f'{DIR}/{kind}', exist_ok=True); open(f'{DIR}/{kind}/{name}.txt', 'w').write(value)

def read(kind, name):
    p = f'{DIR}/{kind}/{name}.txt'
    return open(p).read().strip() if os.path.exists(p) else None
