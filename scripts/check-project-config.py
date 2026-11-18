#!/usr/bin/env python3
"""Check source configuration, and optionally the metadata in a built iOS app.

Uses macOS plutil to read Xcode's OpenStep project format. It does not invoke
Xcode, contact Firebase, or validate signing, credentials, or command-line
build-setting overrides.
"""

import argparse
import json
from pathlib import Path
import plistlib
import re
import shlex
import subprocess
import sys


class ConfigurationError(Exception):
    pass


VARIABLE = re.compile(r"\$\(([^)]+)\)|\$\{([^}]+)\}")
URL_SCHEME = re.compile(r"[A-Za-z][A-Za-z0-9+.-]*\Z")


def expand(value, settings, stack=()):
    if isinstance(value, list):
        return [expand(item, settings, stack) for item in value]
    if isinstance(value, dict):
        return {key: expand(item, settings, stack) for key, item in value.items()}
    if not isinstance(value, str):
        return value

    def replace(match):
        key = match.group(1) or match.group(2)
        if key in stack:
            raise ConfigurationError(f"Cyclic build setting: {' -> '.join((*stack, key))}")
        if key not in settings:
            raise ConfigurationError(f"Unresolved build setting: {key}")
        resolved = expand(settings[key], settings, (*stack, key))
        return " ".join(map(str, resolved)) if isinstance(resolved, list) else str(resolved)

    return VARIABLE.sub(replace, value)


def merge_settings(base, override):
    merged = dict(base)
    for key, value in override.items():
        inherited = merged.get(key, "")
        if isinstance(inherited, list):
            inherited = " ".join(map(str, inherited))

        def inherit(item):
            if isinstance(item, str):
                return item.replace("$(inherited)", str(inherited)).replace("${inherited}", str(inherited))
            return item

        merged[key] = [inherit(item) for item in value] if isinstance(value, list) else inherit(value)
    return merged


def configuration_map(objects, configuration_list):
    return {
        objects[identifier]["name"]: objects[identifier].get("buildSettings", {})
        for identifier in objects[configuration_list]["buildConfigurations"]
    }


def tokens(value):
    if isinstance(value, list):
        return [token for item in value for token in shlex.split(str(item))]
    return shlex.split(str(value))


def compiler_conditions(settings):
    conditions = set(tokens(expand(settings.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", ""), settings)))
    flags = tokens(expand(settings.get("OTHER_SWIFT_FLAGS", ""), settings))
    for index, flag in enumerate(flags):
        if flag == "-D" and index + 1 < len(flags):
            conditions.add(flags[index + 1])
        elif flag.startswith("-D") and len(flag) > 2:
            conditions.add(flag[2:])
    return conditions


def require(condition, message):
    if not condition:
        raise ConfigurationError(message)


def validate_metadata(info, settings, label):
    required = [
        "CFBundleDevelopmentRegion", "CFBundleDisplayName", "CFBundleExecutable",
        "CFBundleIdentifier", "CFBundleInfoDictionaryVersion", "CFBundleName",
        "CFBundlePackageType", "CFBundleShortVersionString", "CFBundleVersion",
    ]
    for key in required:
        value = info.get(key)
        require(isinstance(value, str) and bool(value.strip()), f"{label}: missing or empty {key}")
        require(VARIABLE.search(value) is None, f"{label}: unexpanded variable in {key}")
    require(info["CFBundleIdentifier"] == expand(settings["PRODUCT_BUNDLE_IDENTIFIER"], settings),
            f"{label}: bundle identifier does not match the app target")
    require(info["CFBundleExecutable"] == expand(settings["EXECUTABLE_NAME"], settings),
            f"{label}: executable does not match the app target")
    require(info["CFBundlePackageType"] == "APPL", f"{label}: package is not an iOS application")
    require(info["CFBundleShortVersionString"] == str(expand(settings.get("MARKETING_VERSION", ""), settings)),
            f"{label}: marketing version does not match its build setting")
    require(info["CFBundleVersion"] == str(expand(settings.get("CURRENT_PROJECT_VERSION", ""), settings)),
            f"{label}: build version does not match its build setting")
    require(info.get("LSRequiresIPhoneOS") is True, f"{label}: LSRequiresIPhoneOS must be enabled")
    require(isinstance(info.get("UILaunchScreen"), dict), f"{label}: missing launch-screen configuration")
    require(isinstance(info.get("UIApplicationSceneManifest"), dict), f"{label}: missing SwiftUI scene manifest")

    schemes = [scheme for item in info.get("CFBundleURLTypes", [])
               for scheme in item.get("CFBundleURLSchemes", [])]
    require(bool(schemes), f"{label}: missing Google callback URL scheme")
    require(all(isinstance(scheme, str) and URL_SCHEME.fullmatch(scheme) for scheme in schemes),
            f"{label}: an empty or invalid URL scheme would make the app bundle invalid")
    configured_scheme = expand(settings.get("GOOGLE_REVERSED_CLIENT_ID", ""), settings)
    require(configured_scheme in schemes, f"{label}: Google callback setting is absent from the bundle")
    return schemes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1] / "201AutoGarage.xcodeproj")
    parser.add_argument("--built-app", type=Path, help="Also inspect an existing .app without rebuilding it")
    parser.add_argument("--configuration", choices=("Debug", "Release"), default="Debug",
                        help="Configuration used to produce --built-app (default: Debug)")
    args = parser.parse_args()
    project_file = args.project / "project.pbxproj"
    result = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(project_file)],
                            check=True, capture_output=True, text=True)
    project_data = json.loads(result.stdout)
    objects = project_data["objects"]
    project = objects[project_data["rootObject"]]
    app_targets = [objects[identifier] for identifier in project["targets"]
                   if objects[identifier].get("productType") == "com.apple.product-type.application"]
    require(len(app_targets) == 1, "Expected exactly one iOS application target")
    target = app_targets[0]
    project_configs = configuration_map(objects, project["buildConfigurationList"])
    target_configs = configuration_map(objects, target["buildConfigurationList"])
    validated = {}

    for name in ("Debug", "Release"):
        require(name in project_configs and name in target_configs, f"Missing {name} configuration")
        settings = {
            "TARGET_NAME": target["name"],
            "PRODUCT_NAME": target.get("productName", target["name"]),
            "EXECUTABLE_NAME": "$(PRODUCT_NAME)",
            "DEVELOPMENT_LANGUAGE": project.get("developmentRegion", "en"),
            "SRCROOT": str(args.project.resolve().parent),
        }
        settings = merge_settings(merge_settings(settings, project_configs[name]), target_configs[name])
        require(("DEBUG" in compiler_conditions(settings)) == (name == "Debug"),
                f"{name}: DEBUG must be defined only in the Debug configuration")
        info_path = Path(expand(settings["INFOPLIST_FILE"], settings))
        if not info_path.is_absolute():
            info_path = args.project.parent / info_path
        with info_path.open("rb") as handle:
            source_info = plistlib.load(handle)
        info = expand(source_info, settings)
        schemes = validate_metadata(info, settings, name)

        google_plist = info_path.parent / "GoogleService-Info.plist"
        if google_plist.exists():
            with google_plist.open("rb") as handle:
                google_info = plistlib.load(handle)
            require(google_info.get("REVERSED_CLIENT_ID") in schemes,
                    f"{name}: replace the Google callback placeholder with the Firebase plist's REVERSED_CLIENT_ID")
        validated[name] = (settings, info)
        print(f"PASS {name}: valid bundle metadata, URL scheme, and compiler conditions")

    if args.built_app:
        settings, expected_info = validated[args.configuration]
        with (args.built_app / "Info.plist").open("rb") as handle:
            built_info = plistlib.load(handle)
        validate_metadata(built_info, settings, f"Built {args.configuration}")
        for key in ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleShortVersionString", "CFBundleVersion"):
            require(built_info[key] == expected_info[key], f"Built app has unexpected {key}")
        require((args.built_app / built_info["CFBundleExecutable"]).is_file(), "Built app executable is missing")
        print(f"PASS built {args.configuration}: expanded metadata and executable exist")

    print("Checked local project settings; signing, live Firebase, and external build-setting overrides are outside this check.")


if __name__ == "__main__":
    try:
        main()
    except (ConfigurationError, KeyError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
