"""Offline batch identity, GLB, partition, resume and publication safety tests."""
import copy
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/figures'))
import external
import external_glb
from partition import partition


def entry():
    return {'source': 'manual-download.glb', 'figure_id': 'tide.bubble', 'collection_id': 'tide',
            'rarity': 'Common', 'collection_slug': 'tidepool-tales', 'figure_slug': 'bubble-bean',
            'root': 'BubbleBean', 'alias': 'bubble_bean', 'asset_key': 'Models.TidepoolTales.BubbleBean',
            'height_studs': 3, 'eyes': {'object': 'SourceMesh'}}


def glb(path, change=None):
    """One textured static triangle with complete accessors, using stdlib only."""
    binary = bytearray()
    views, accessors = [], []
    def append(data):
        while len(binary) % 4:
            binary.append(0)
        views.append({'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(data)})
        binary.extend(data)
        return len(views) - 1
    for values, kind, count, component in (
        ([0, 0, 0, 1, 0, 0, 0, 1, 0], 'VEC3', 3, 5126),
        ([0, 0, 1] * 3, 'VEC3', 3, 5126),
        ([0, 0, 1, 0, 0, 1], 'VEC2', 3, 5126),
        ([0, 1, 2], 'SCALAR', 3, 5123),
    ):
        fmt = 'f' if component == 5126 else 'H'
        view = append(struct.pack('<' + fmt * len(values), *values))
        accessors.append({'bufferView': view, 'componentType': component, 'count': count, 'type': kind})
    # Header is sufficient for offline metadata tests; Blender integration uses real images.
    image_view = append(b'\x89PNG\r\n\x1a\n' + b'\0' * 8 + struct.pack('>II', 16, 16))
    doc = {'asset': {'version': '2.0'}, 'buffers': [{'byteLength': len(binary)}],
           'bufferViews': views, 'accessors': accessors, 'images': [{'bufferView': image_view, 'mimeType': 'image/png'}],
           'textures': [{'source': 0}], 'materials': [{'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}}}],
           'meshes': [{'name': 'SourceMesh', 'primitives': [{'indices': 3, 'material': 0, 'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2}}]}],
           'nodes': [{'name': 'SourceMesh', 'mesh': 0}], 'scenes': [{'nodes': [0]}], 'scene': 0}
    if change:
        change(doc, binary)
    document = json.dumps(doc).encode()
    document += b' ' * (-len(document) % 4)
    binary += b'\0' * (-len(binary) % 4)
    data = struct.pack('<4sII', b'glTF', 2, 28 + len(document) + len(binary))
    data += struct.pack('<II', len(document), 0x4E4F534A) + document
    data += struct.pack('<II', len(binary), 0x004E4942) + binary
    path.write_bytes(data)
    return doc


class BatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ('src/shared', 'assets', 'incoming'):
            (self.root / directory).mkdir(parents=True)
        (self.root / 'src/shared/Catalog.luau').write_bytes((ROOT / 'src/shared/Catalog.luau').read_bytes())
        (self.root / 'src/shared/FigureAssetEntries.luau').write_bytes((ROOT / 'src/shared/FigureAssetEntries.luau').read_bytes())
        self.manifest = self.root / 'batch.json'
        external.write_json(self.root / 'assets/manifest.json', {'creator': {'userId': '1'}, 'assets': {}})
        external.write_json(self.root / 'assets/uploads.json', {})
        glb(self.root / 'incoming/manual-download.glb')

    def load(self, entries=None):
        external.write_json(self.manifest, {'schema_version': 1, 'batch_id': 'test-batch', 'figures': entries or [entry()]})
        return external.load_batch(self.manifest, self.root / 'incoming', self.root)

    def test_exact_catalog_mapping_and_unknown_file(self):
        batch, entries, errors = self.load()
        self.assertEqual(errors, [])
        self.assertEqual(entries[0]['title'], 'Bubble Bean')
        glb(self.root / 'incoming/unmatched.glb')
        self.assertEqual(self.load()[2], ['unmatched file: unmatched.glb'])

    def test_catalog_and_runtime_mismatches_fail_closed(self):
        for field, value in (('figure_id', 'missing.figure'), ('collection_id', 'grove'), ('rarity', 'Rare'),
                             ('asset_key', 'Models.Tripo.BubbleBean'), ('root', 'Bad_Name'), ('height_studs', float('inf'))):
            e = entry()
            e[field] = value
            if field == 'height_studs':
                with self.assertRaises(ValueError):
                    self.load([e])
            else:
                self.assertTrue(self.load([e])[2], field)

    def test_duplicate_and_path_escape_rejected(self):
        self.assertTrue(self.load([entry(), entry()])[2])
        for source in ('../escape.glb', 'C:/escape.glb', 'bad\\name.glb'):
            e = entry()
            e['source'] = source
            self.assertTrue(self.load([e])[2])

    def test_eyes_selector_is_required(self):
        e = entry()
        e['eyes'] = {}
        self.assertTrue(self.load([e])[2])
        e['eyes'] = {'object': 'SourceMesh', 'region': [[0, 0, .4], [1, .2, .9]]}
        self.assertFalse(self.load([e])[2])

    def test_invalid_optimize_and_region_policies(self):
        for override in ({'max_parts': True}, {'texture_limit': 8192}, {'rotation_degrees': [0, 0, float('nan')]},
                         {'eyes': {'object': 'SourceMesh', 'region': [[0, 0, 0], [1, 0, 1]]}},
                         {'optimization': {'SourceMesh': {'target_triangles': 100}}}):
            e = entry() | override
            if override.get('rotation_degrees'):
                with self.assertRaises(ValueError):
                    self.load([e])
            else:
                self.assertTrue(self.load([e])[2])

    def test_dry_run_has_no_side_effects_or_blender(self):
        self.load()
        before = (self.root / 'assets/manifest.json').read_bytes()
        with patch.object(external, 'ROOT', self.root), patch.object(external.subprocess, 'run', side_effect=AssertionError('Blender')):
            self.assertEqual(external.main([str(self.root / 'incoming'), '--manifest', str(self.manifest), '--dry-run']), 0)
        self.assertFalse((self.root / 'build').exists())
        self.assertEqual(before, (self.root / 'assets/manifest.json').read_bytes())

    def test_validation_only_does_not_convert_and_clears_stale_plan(self):
        self.load()
        folder = self.root / 'build/figures/external/test-batch'
        external.write_json(folder / 'plan.json', {'stale': True})
        with patch.object(external, 'ROOT', self.root), patch.object(external.subprocess, 'run', side_effect=AssertionError('Blender')):
            self.assertEqual(external.main([str(self.root / 'incoming'), '--manifest', str(self.manifest), '--validate-only', '--blender', str(Path(sys.executable))]), 1)
        self.assertFalse((folder / 'plan.json').exists())
        self.assertTrue((folder / 'report.html').exists())

    def test_fingerprint_binds_source_options_and_tooling(self):
        source = self.root / 'incoming/manual-download.glb'
        a = external.fingerprint(source, entry(), resolution=64, samples=1)
        self.assertEqual(a, external.fingerprint(source, entry(), resolution=64, samples=1))
        self.assertNotEqual(a, external.fingerprint(source, entry() | {'height_studs': 4}, resolution=64, samples=1))
        self.assertNotEqual(a, external.fingerprint(source, entry(), resolution=128, samples=1))
        source.write_bytes(source.read_bytes() + b'change')
        self.assertNotEqual(a, external.fingerprint(source, entry(), resolution=64, samples=1))

    def test_publish_requires_exact_plan_approval_before_any_effects(self):
        plan = {'kind': 'external_figure_review', 'schema_version': 1, 'figures': [{'placeholder': True}]}
        external.write_json(self.root / 'plan.json', plan)
        with patch.object(external, 'uploader', side_effect=AssertionError('credentials or uploads')):
            with self.assertRaises(external.ImportError):
                external.publish_plan(self.root / 'plan.json', 'wrong digest', False)

    def staged(self):
        _, entries, _ = self.load()
        e = entries[0]
        folder = self.root / 'build/figures/external/test/figures/bubble-bean' / ('a' * 64)
        for name in ('source', 'model', 'renders', 'validation'):
            (folder / name).mkdir(parents=True)
        model = folder / 'model/bubble_bean_roblox.glb'
        def nodes(doc, binary):
            doc['nodes'] = [{'name': 'BubbleBean', 'children': [1]}, {'name': 'BubbleBean_Eyes', 'mesh': 0}]
            doc['scenes'] = [{'nodes': [0]}]
            doc['meshes'][0]['name'] = 'BubbleBean_Eyes'
        glb(model, nodes)
        (folder / 'source/original.glb').write_bytes(model.read_bytes())
        source_views = ['source_' + v + '.png' for v in external.VIEWS]
        fidelity_views = ['fidelity_' + v + '.png' for v in external.VIEWS]
        for name in source_views + fidelity_views:
            (folder / 'renders' / name).write_bytes(b'Offline fake render - no visual acceptance claimed')
        report = {'schema_version': 3, 'pipeline': 'external_glb', 'fingerprint': 'a' * 64,
                  'catalog': 'tide.bubble', 'root': 'BubbleBean', 'title': 'Bubble Bean', 'face': 'BubbleBean_Eyes',
                  'components': {'BubbleBean_Eyes': {'tris': 1, 'finite_vertices': True, 'finite_uvs': True, 'materials': 1}},
                  'meshes': 1, 'triangles': 1, 'source_triangles': 1, 'material_mismatches': [],
                  'size_xyz_studs': [1, 1, 3], 'facing_valid': True, 'grounded': True,
                  'glb': external_glb.inspect(model, production=True),
                  'reimport': {'meshes': 1, 'geometry_mismatches': {}, 'triangle_mismatches': {}, 'unexpected_parts': []},
                  'previews': {'source_views': source_views, 'fidelity_views': fidelity_views, 'view_names': external.VIEWS,
                               'fidelity_sha256': external.digest(model), 'fidelity_source': 'exported_reimported_glb'},
                  'visual_comparison': {v: {'pass': True, 'silhouette_iou': 1, 'foreground_rgb_mae': 0} for v in external.VIEWS}}
        report['artifacts'] = {p.relative_to(folder).as_posix(): external.digest(p) for p in folder.rglob('*') if p.is_file()}
        external.write_json(folder / 'validation/bubble_bean_validation.json', report)
        plan = external.proposal([{'entry': e, 'report': report, 'folder': str(folder)}], self.root)
        file = self.root / 'plan.json'
        external.write_json(file, plan)
        return file, plan, folder, e

    def publish_mocks(self):
        api = external.uploader()
        return api

    def test_visual_loss_material_and_geometry_gates_fail_even_with_pass_label(self):
        _, _, folder, e = self.staged()
        report = external.read_json(folder / 'validation/bubble_bean_validation.json')
        self.assertEqual(external.gate(report, e), [])
        for mutate in (
            lambda r: r['visual_comparison']['front'].update(silhouette_iou=.8),
            lambda r: r['visual_comparison']['side'].update(foreground_rgb_mae=.2),
            lambda r: r.update(material_mismatches=['missing normal map']),
            lambda r: r['components']['BubbleBean_Eyes'].update(tris=20000),
            lambda r: r.update(source_triangles=2),
            lambda r: r.update(facing_valid=False),
        ):
            broken = copy.deepcopy(report)
            mutate(broken)
            self.assertTrue(external.gate(broken, e))

    def test_fixture_plans_cannot_upload_even_if_digest_approved(self):
        file, plan, _, _ = self.staged()
        plan['technical_fixture'] = True
        external.write_json(file, plan)
        sha = external.hashlib.sha256(external.canonical(plan)).hexdigest()
        with patch.object(external, 'uploader', side_effect=AssertionError('upload')):
            with self.assertRaises(external.ImportError):
                external.publish_plan(file, sha, False)

    def test_approved_publish_reuses_uploader_and_preserves_sources(self):
        api = self.publish_mocks()
        file, plan, folder, e = self.staged()
        source_before = (folder / 'source/original.glb').read_bytes()
        def upload(root, items, creator, cloud, replace, timeout):
            self.assertTrue(replace)
            external.write_json(root / 'assets/uploads.json', {items[0]['key']: {'assetId': '123', 'sha256': items[0]['sha256'], 'source': items[0]['source'], 'creator': creator, 'assetType': 'Model'}})
        with patch.object(external, 'ROOT', self.root), patch.object(external, 'uploader', return_value=api), patch.object(external.publish, 'ROOT', self.root), patch.object(external.publish, 'checks'), patch.object(external.publish, 'run'), patch.object(api, 'load_api_key', return_value='synthetic'), patch.object(api, 'Cloud'), patch.object(api, 'upload', side_effect=upload) as send:
            sha = external.hashlib.sha256(external.canonical(plan)).hexdigest()
            external.publish_plan(file, sha, False)
            self.assertEqual(send.call_count, 1)
        self.assertEqual((folder / 'source/original.glb').read_bytes(), source_before)
        destination = self.root / plan['figures'][0]['destination']
        self.assertTrue((destination / 'model/bubble_bean_roblox.glb').exists())
        self.assertFalse((destination / 'job.json').exists())
        self.assertIn('tide.bubble', (self.root / 'src/shared/FigureAssetEntries.luau').read_text())

    def test_dry_publish_no_credentials_no_promotion_no_mapping_changes(self):
        api = self.publish_mocks()
        file, plan, _, _ = self.staged()
        before = (self.root / 'assets/manifest.json').read_bytes()
        with patch.object(external, 'ROOT', self.root), patch.object(external, 'uploader', return_value=api), patch.object(api, 'load_api_key', side_effect=AssertionError('credentials')), patch.object(api, 'upload', side_effect=AssertionError('upload')):
            external.publish_plan(file, None, True)
        self.assertEqual((self.root / 'assets/manifest.json').read_bytes(), before)
        self.assertFalse((self.root / plan['figures'][0]['destination']).exists())

    def test_creator_and_lock_failures_are_reported_without_uploads(self):
        api = self.publish_mocks()
        file, plan, _, _ = self.staged()
        sha = external.hashlib.sha256(external.canonical(plan)).hexdigest()
        with patch.object(external, 'ROOT', self.root), patch.object(external, 'uploader', return_value=api), patch.object(api, 'load_api_key', side_effect=AssertionError('credentials')):
            lock = self.root / 'build/assets/upload.lock'
            lock.parent.mkdir(parents=True)
            lock.write_text('another uploader')
            with self.assertRaises(external.ImportError):
                external.publish_plan(file, sha, False)
            lock.unlink()
            plan['creator'] = {'userId': 'invalid'}
            external.write_json(file, plan)
            external.write_json(self.root / 'assets/manifest.json', {'creator': plan['creator'], 'assets': {}})
            with self.assertRaises(external.ImportError):
                external.publish_plan(file, None, True)

    def test_changed_artifact_report_or_production_mapping_stops_publication(self):
        api = self.publish_mocks()
        file, plan, folder, e = self.staged()
        sha = external.hashlib.sha256(external.canonical(plan)).hexdigest()
        with patch.object(external, 'ROOT', self.root), patch.object(external, 'uploader', return_value=api), patch.object(api, 'load_api_key', side_effect=AssertionError('credentials')):
            preview = folder / 'renders/source_front.png'
            before = preview.read_bytes()
            preview.write_bytes(b'changed after review')
            with self.assertRaises(external.ImportError):
                external.publish_plan(file, sha, False)
            preview.write_bytes(before)
            external.write_json(self.root / 'assets/uploads.json', {e['asset_key']: {'assetId': '999'}})
            with self.assertRaises(external.ImportError):
                external.publish_plan(file, sha, False)

    def test_upload_failure_restores_old_manifest_and_runtime_then_can_resume(self):
        api = self.publish_mocks()
        file, plan, folder, e = self.staged()
        old_folder = self.root / 'assets/figures/old/bubble-bean'
        (old_folder / 'model').mkdir(parents=True)
        (old_folder / 'validation').mkdir()
        old_report = external.read_json(folder / 'validation/bubble_bean_validation.json')
        old_report['meshes'] = 9
        external.write_json(old_folder / 'validation/bubble_bean_validation.json', old_report)
        old = {'key': e['asset_key'], 'source': 'assets/figures/old/bubble-bean/model/bubble_bean_roblox.glb', 'assetType': 'Model'}
        external.write_json(self.root / 'assets/manifest.json', {'creator': {'userId': '1'}, 'assets': {e['alias']: old}})
        mapping = {e['asset_key']: {'assetId': '88', 'sha256': 'b' * 64}}
        external.write_json(self.root / 'assets/uploads.json', mapping)
        plan = external.proposal([{'entry': e, 'report': external.read_json(folder / 'validation/bubble_bean_validation.json'), 'folder': str(folder)}], self.root)
        external.write_json(file, plan)
        sha = external.hashlib.sha256(external.canonical(plan)).hexdigest()
        with patch.object(external, 'ROOT', self.root), patch.object(external, 'uploader', return_value=api), patch.object(external.publish, 'ROOT', self.root), patch.object(external.publish, 'checks'), patch.object(external.publish, 'run'), patch.object(api, 'load_api_key', return_value='synthetic'), patch.object(api, 'Cloud'), patch.object(api, 'upload', side_effect=api.PipelineError('interrupted')):
            with self.assertRaises(external.ImportError):
                external.publish_plan(file, sha, False)
            self.assertEqual(external.read_json(self.root / 'assets/manifest.json')['assets'][e['alias']], old)
            self.assertIn('parts = 9', (self.root / 'src/shared/FigureAssetEntries.luau').read_text())
            external.publish_plan(file, None, True)  # Same reviewed plan remains resumable.

    def test_resume_skips_blender_and_rechecks_artifacts(self):
        file, plan, folder, e = self.staged()
        source = self.root / 'incoming/manual-download.glb'
        # Align this synthetic receipt to the real fingerprint computed by the command.
        fp = external.fingerprint(source, e, resolution=64, samples=1, blender_sha256=external.digest(Path(sys.executable)))
        output = self.root / 'build/figures/external/test-batch/figures/bubble-bean' / fp
        import shutil
        shutil.copytree(folder, output)
        report_file = output / 'validation/bubble_bean_validation.json'
        report = external.read_json(report_file)
        report['fingerprint'] = fp
        external.write_json(report_file, report)
        with patch.object(external, 'ROOT', self.root), patch.object(external.subprocess, 'run', side_effect=AssertionError('Blender')):
            args = [str(self.root / 'incoming'), '--manifest', str(self.manifest), '--blender', str(Path(sys.executable)), '--resolution', '64', '--samples', '1']
            self.assertEqual(external.main(args), 0)
            self.assertEqual(external.read_json(output.parents[2] / 'batch.json')['rows'][0]['status'], 'unchanged')
            (output / 'model/bubble_bean_roblox.glb').write_bytes(b'changed')
            self.assertEqual(external.main(args + ['--validate-only']), 1)


class GLBTests(unittest.TestCase):
    def test_complete_static_texture_glb(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'source.glb'
            glb(file)
            self.assertEqual(external_glb.inspect(file)['triangles'], 1)
            self.assertEqual(external_glb.inspect(file, production=True)['errors'], [])

    def test_malformed_accessors_extensions_rigs_textures_and_indices(self):
        changes = [
            lambda d, b: d.update(extensionsUsed=['KHR_draco_mesh_compression']),
            lambda d, b: d.update(skins=[{}]),
            lambda d, b: d['buffers'][0].update(uri='external.bin'),
            lambda d, b: d['accessors'][0].update(count=999),
            lambda d, b: d['images'][0].update(uri='https://example.invalid/texture.png'),
            lambda d, b: d['meshes'][0]['primitives'][0]['attributes'].pop('NORMAL'),
            lambda d, b: struct.pack_into('<f', b, 0, float('nan')),
            lambda d, b: struct.pack_into('<H', b, d['bufferViews'][3]['byteOffset'], 99),
        ]
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'source.glb'
            for change in changes:
                glb(file, change)
                with self.assertRaises((ValueError, KeyError)):
                    external_glb.inspect(file)

    def test_production_texture_budget_and_uv_bounds(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'source.glb'
            glb(file, lambda d, b: struct.pack_into('>II', b, d['bufferViews'][4]['byteOffset'] + 16, 8192, 8192))
            with self.assertRaises(ValueError):
                external_glb.inspect(file, production=True)
            self.assertEqual(external_glb.inspect(file, texture_limit=16384)['textures'][0]['width'], 8192)
            glb(file, lambda d, b: struct.pack_into('<f', b, d['bufferViews'][2]['byteOffset'], 2))
            with self.assertRaises(ValueError):
                external_glb.inspect(file, production=True)


class PartitionTests(unittest.TestCase):
    def test_connected_large_mesh_preserves_every_triangle_deterministically(self):
        positions = [(i, j, 0) for i in range(31) for j in range(31)]
        faces = []
        for i in range(30):
            for j in range(30):
                a = i * 31 + j
                faces.extend([(a, a + 31, a + 1), (a + 1, a + 31, a + 32)])
        result = partition(faces, positions, 120)
        self.assertEqual(sorted(i for part in result for i in part), list(range(len(faces))))
        self.assertLessEqual(max(map(len, result)), 120)
        self.assertEqual(result, partition(faces, positions, 120))

    def test_logical_islands_stay_whole_and_tiny_details_are_kept(self):
        faces = [(0, 1, 2), (0, 2, 3), (4, 5, 6), (4, 6, 7), (8, 9, 10)]
        result = partition(faces, [(i, 0, 0) for i in range(11)], 3)
        self.assertEqual(result, [[0, 1], [2, 3, 4]])


if __name__ == '__main__':
    unittest.main()
