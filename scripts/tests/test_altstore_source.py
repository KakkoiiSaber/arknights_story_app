import copy
from io import BytesIO
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from zipfile import ZipFile

from scripts.altstore_source import (
    build_name,
    fetch_previous_source,
    generate_source,
    merge_history,
    read_entitlements,
    write_source,
)


class ReleaseVersionTests(unittest.TestCase):
    def test_tag_controls_version_even_if_pubspec_is_older(self):
        self.assertEqual(build_name("refs/tags/v1.2.3", "version: 0.1.0+1\n"), "1.2.3")
        self.assertEqual(build_name("refs/tags/v0.1", ""), "0.1.0")

    def test_branch_build_uses_pubspec_without_build_number_or_comment(self):
        self.assertEqual(build_name("refs/heads/main", 'version: "1.2.3+7" # local build\n'), "1.2.3")

    def test_invalid_and_prerelease_tags_cannot_become_stable_releases(self):
        for tag in ("v1.2.3-beta.1", "v1.2.3+4", "v01.2.3", "v1", "v$(echo bad)", "1.2.3"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                build_name(f"refs/tags/{tag}", "version: 0.1.0")


class SourceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.app = self.root / "Runner.app"
        self.app.mkdir()
        self.ipa = self.root / "arknights_story_ios.ipa"
        self.info = {
            "CFBundleDisplayName": "Arknights Story",
            "CFBundleIdentifier": "com.example.arknightsStoryApp",
            "CFBundleShortVersionString": "0.1.1",
            "CFBundleVersion": "42",
            "MinimumOSVersion": "15.0",
            "NSPhotoLibraryUsageDescription": "保存图片",
        }
        self.write_ipa()

    def write_ipa(self, extension=None):
        # Real Xcode plists are commonly binary, including in unsigned IPAs.
        main_plist = plistlib.dumps(self.info, fmt=plistlib.FMT_BINARY)
        (self.app / "Info.plist").write_bytes(main_plist)
        with ZipFile(self.ipa, "w") as archive:
            archive.writestr("Payload/Runner.app/Info.plist", main_plist)
            if extension:
                directory = self.app / "PlugIns" / "Share.appex"
                directory.mkdir(parents=True, exist_ok=True)
                extension_plist = plistlib.dumps(extension)
                (directory / "Info.plist").write_bytes(extension_plist)
                archive.writestr("Payload/Runner.app/PlugIns/Share.appex/Info.plist", extension_plist)

    def generate(self):
        return generate_source(self.ipa, self.app, "KakkoiiSaber/arknights_story_app", "v0.1.1", "0.1.1", "42")

    def test_source_matches_binary_ipa_and_includes_extension_permissions(self):
        self.write_ipa({"NSCameraUsageDescription": "扫描图片"})
        with patch("scripts.altstore_source.read_entitlements", side_effect=[
            {"application-identifier": "TEAM.app", "com.apple.developer.team-identifier": "TEAM"},
            {"com.apple.security.application-groups": ["group.story"]},
        ]):
            source = self.generate()
        app = source["apps"][0]
        version = app["versions"][0]
        self.assertEqual(app["bundleIdentifier"], self.info["CFBundleIdentifier"])
        self.assertEqual((version["version"], version["buildVersion"], version["minOSVersion"]), ("0.1.1", "42", "15.0"))
        self.assertEqual(version["size"], self.ipa.stat().st_size)
        self.assertEqual(version["downloadURL"], "https://github.com/KakkoiiSaber/arknights_story_app/releases/download/v0.1.1/arknights_story_ios.ipa")
        self.assertTrue(source["sourceURL"].endswith("/releases/latest/download/apps.json"))
        self.assertEqual(app["appPermissions"], {
            "entitlements": ["com.apple.security.application-groups"],
            "privacy": {"NSPhotoLibraryUsageDescription": "保存图片", "NSCameraUsageDescription": "扫描图片"},
        })
        output = self.root / "release" / "apps.json"
        write_source(output, source)
        self.assertEqual(json.loads(output.read_text(encoding="utf-8")), source)
        self.assertNotIn("marketplaceID", app)

    def test_rejects_version_or_build_mismatch(self):
        for key, value in (("CFBundleShortVersionString", "0.1.0"), ("CFBundleVersion", "1")):
            with self.subTest(key=key):
                original = self.info[key]
                self.info[key] = value
                self.write_ipa()
                with self.assertRaisesRegex(ValueError, "does not match"):
                    self.generate()
                self.info[key] = original

    def test_rejects_unresolved_bundle_id(self):
        self.info["CFBundleIdentifier"] = "$(PRODUCT_BUNDLE_IDENTIFIER)"
        self.write_ipa()
        with patch("scripts.altstore_source.read_entitlements", return_value={}):
            with self.assertRaisesRegex(ValueError, "CFBundleIdentifier"):
                self.generate()

    def test_rejects_app_directory_from_a_different_build(self):
        (self.app / "Info.plist").write_bytes(plistlib.dumps({**self.info, "CFBundleVersion": "41"}))
        with self.assertRaisesRegex(ValueError, "metadata differ"):
            self.generate()

    def test_rejects_multiple_root_apps(self):
        with ZipFile(self.ipa, "a") as archive:
            archive.writestr("Payload/Other.app/Info.plist", plistlib.dumps(self.info))
        with self.assertRaisesRegex(ValueError, "exactly one"):
            self.generate()

    @patch("scripts.altstore_source.read_entitlements", return_value={})
    def test_merge_preserves_older_compatible_versions_and_permissions(self, _read):
        current = self.generate()
        previous = copy.deepcopy(current)
        previous_app = previous["apps"][0]
        previous_app["versions"][0].update({"version": "0.1.0", "buildVersion": "1", "minOSVersion": "13.0"})
        previous_app["appPermissions"]["entitlements"] = ["com.apple.developer.siri"]
        previous_app["appPermissions"]["privacy"]["NSSiriUsageDescription"] = "语音操作"
        old_version = copy.deepcopy(previous_app["versions"][0])
        merged = merge_history(current, previous)["apps"][0]
        self.assertEqual([version["version"] for version in merged["versions"]], ["0.1.1", "0.1.0"])
        self.assertEqual(merged["versions"][1], old_version)
        self.assertIn("com.apple.developer.siri", merged["appPermissions"]["entitlements"])
        self.assertIn("NSSiriUsageDescription", merged["appPermissions"]["privacy"])

    @patch("scripts.altstore_source.read_entitlements", return_value={})
    def test_merge_rejects_reused_tags_rollbacks_and_identity_changes(self, _read):
        source = self.generate()
        for old_version in ("0.1.1", "0.2.0"):
            previous = copy.deepcopy(source)
            previous["apps"][0]["versions"][0]["version"] = old_version
            with self.subTest(version=old_version), self.assertRaisesRegex(ValueError, "newer"):
                merge_history(copy.deepcopy(source), previous)
        previous = copy.deepcopy(source)
        previous["apps"][0]["bundleIdentifier"] = "different.app"
        with self.assertRaisesRegex(ValueError, "Bundle identifier changed"):
            merge_history(copy.deepcopy(source), previous)
        previous["identifier"] = "different.source"
        with self.assertRaisesRegex(ValueError, "different identifier"):
            merge_history(copy.deepcopy(source), previous)
        self.assertEqual(merge_history(source, None), source)


class ExternalToolTests(unittest.TestCase):
    def test_unsigned_bundle_is_allowed_but_other_codesign_errors_fail(self):
        with patch("scripts.altstore_source.subprocess.run", return_value=subprocess.CompletedProcess(
            [], 1, stdout=b"", stderr=b"Runner.app: code object is not signed at all\n"
        )):
            self.assertEqual(read_entitlements(Path("Runner.app")), {})
        with patch("scripts.altstore_source.subprocess.run", return_value=subprocess.CompletedProcess(
            [], 1, stdout=b"", stderr=b"Runner.app: No such file or directory\n"
        )):
            with self.assertRaisesRegex(ValueError, "Cannot inspect"):
                read_entitlements(Path("Runner.app"))

    def test_signed_bundle_entitlements_are_read(self):
        entitlements = {"com.apple.security.application-groups": ["group.story"]}
        with patch("scripts.altstore_source.subprocess.run", return_value=subprocess.CompletedProcess(
            [], 0, stdout=plistlib.dumps(entitlements), stderr=b"Executable=Runner.app/Runner\n"
        )):
            self.assertEqual(read_entitlements(Path("Runner.app")), entitlements)

    def test_first_release_404_is_allowed_but_network_errors_do_not_erase_history(self):
        url = "https://github.com/owner/repo/releases/latest/download/apps.json"
        with patch("scripts.altstore_source.urlopen", side_effect=HTTPError(url, 404, "not found", {}, None)):
            self.assertIsNone(fetch_previous_source(url))
        for error in (HTTPError(url, 503, "unavailable", {}, None), URLError("offline")):
            with self.subTest(error=error), patch("scripts.altstore_source.urlopen", side_effect=error):
                with self.assertRaises(URLError):
                    fetch_previous_source(url)
        with patch("scripts.altstore_source.urlopen", return_value=BytesIO(b'{"apps": []}')):
            self.assertEqual(fetch_previous_source(url), {"apps": []})


if __name__ == "__main__":
    unittest.main()
