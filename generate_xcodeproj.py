#!/usr/bin/env python3
"""Generate PunctoDock.xcodeproj from scratch."""

import os, hashlib, textwrap

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ_DIR = os.path.join(ROOT, "PunctoDock.xcodeproj")
os.makedirs(PROJ_DIR, exist_ok=True)

def uid(name: str) -> str:
    """24-char hex UUID derived from a stable seed (deterministic)."""
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

# ─── File catalogue ──────────────────────────────────────────────────────────
SOURCES = [
    "PunctoDock/App/AppDelegate.swift",
    "PunctoDock/App/AppState.swift",
    "PunctoDock/Insertion/InsertionManager.swift",
    "PunctoDock/LoginItem/LoginItemManager.swift",
    "PunctoDock/Model/AppSettings.swift",
    "PunctoDock/Model/ClipboardHistory.swift",
    "PunctoDock/Model/ClipboardMonitor.swift",
    "PunctoDock/Model/KeyCombo.swift",
    "PunctoDock/Model/PersistenceManager.swift",
    "PunctoDock/Model/SymbolCatalog.swift",
    "PunctoDock/Model/UsageHistory.swift",
    "PunctoDock/Panel/FloatingPanel.swift",
    "PunctoDock/Panel/PanelController.swift",
    "PunctoDock/Panel/PanelView.swift",
    "PunctoDock/Panel/PanelViewModel.swift",
    "PunctoDock/Permissions/PermissionManager.swift",
    "PunctoDock/Settings/SettingsView.swift",
    "PunctoDock/Settings/SettingsWindowController.swift",
    "PunctoDock/Triggers/HotkeyManager.swift",
    "PunctoDock/Triggers/MouseTriggerMonitor.swift",
    "PunctoDock/Triggers/TriggerManager.swift",
]
INFO_PLIST_PATH = "PunctoDock/Resources/Info.plist"
ENTITLEMENTS_PATH = "PunctoDock/Resources/PunctoDock.entitlements"
ASSETS_PATH = "PunctoDock/Resources/Assets.xcassets"

# ─── UUIDs ────────────────────────────────────────────────────────────────────
PROJECT_UID    = uid("project_root")
MAIN_GROUP_UID = uid("group_main")
TARGET_UID     = uid("target_punctodock")
PRODUCTS_GROUP = uid("group_products")
PRODUCT_REF    = uid("product_ref_app")
SOURCES_PHASE  = uid("phase_sources")
RESOURCES_PHASE = uid("phase_resources")
FRAMEWORKS_PHASE = uid("phase_frameworks")
DEBUG_BUILD    = uid("config_debug")
RELEASE_BUILD  = uid("config_release")
DEBUG_TARGET   = uid("config_target_debug")
RELEASE_TARGET = uid("config_target_release")
PROJ_CONFIGLIST = uid("configlist_project")
TARGET_CONFIGLIST = uid("configlist_target")
INFO_FILE_UID  = uid("fileref_infoplist")
ENTITLEMENTS_UID = uid("fileref_entitlements")
ASSETS_UID     = uid("fileref_assets_xcassets")
ASSETS_BUILD_UID = uid("buildfile_assets_xcassets")

# Group UUIDs
GROUP_APP        = uid("group_app")
GROUP_INSERTION  = uid("group_insertion")
GROUP_LOGIN      = uid("group_login")
GROUP_MODEL      = uid("group_model")
GROUP_PANEL      = uid("group_panel")
GROUP_PERMS      = uid("group_permissions")
GROUP_SETTINGS   = uid("group_settings")
GROUP_TRIGGERS   = uid("group_triggers")
GROUP_RESOURCES  = uid("group_resources")

def file_uid(path): return uid(f"fileref_{path}")
def build_uid(path): return uid(f"buildfile_{path}")

# ─── Build sections ───────────────────────────────────────────────────────────
def pbx_file_references():
    lines = []
    # Swift sources
    for s in SOURCES:
        name = os.path.basename(s)
        lines.append(f'\t\t{file_uid(s)} /* {name} */ = '
                     f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
                     f'path = "{name}"; sourceTree = "<group>"; }};')
    # Info.plist
    lines.append(f'\t\t{INFO_FILE_UID} /* Info.plist */ = '
                 f'{{isa = PBXFileReference; lastKnownFileType = text.plist.xml; '
                 f'path = Info.plist; sourceTree = "<group>"; }};')
    # Entitlements
    lines.append(f'\t\t{ENTITLEMENTS_UID} /* PunctoDock.entitlements */ = '
                 f'{{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; '
                 f'path = PunctoDock.entitlements; sourceTree = "<group>"; }};')
    # Assets catalog
    lines.append(f'\t\t{ASSETS_UID} /* Assets.xcassets */ = '
                 f'{{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; '
                 f'path = Assets.xcassets; sourceTree = "<group>"; }};')
    # Product
    lines.append(f'\t\t{PRODUCT_REF} /* PunctoDock.app */ = '
                 f'{{isa = PBXFileReference; explicitFileType = wrapper.application; '
                 f'includeInIndex = 0; path = PunctoDock.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    return "\n".join(lines)

def pbx_build_files():
    lines = []
    for s in SOURCES:
        name = os.path.basename(s)
        lines.append(f'\t\t{build_uid(s)} /* {name} in Sources */ = '
                     f'{{isa = PBXBuildFile; fileRef = {file_uid(s)} /* {name} */; }};')
    # Asset catalog as a resource
    lines.append(f'\t\t{ASSETS_BUILD_UID} /* Assets.xcassets in Resources */ = '
                 f'{{isa = PBXBuildFile; fileRef = {ASSETS_UID} /* Assets.xcassets */; }};')
    return "\n".join(lines)

def by_group(prefix):
    return [s for s in SOURCES if s.startswith(prefix)]

def group_children(paths):
    return "\n".join(f"\t\t\t\t{file_uid(p)} /* {os.path.basename(p)} */," for p in paths)

def pbx_groups():
    def make_group(uid_, name, paths=None, children_extra="", path=None):
        ch = group_children(paths) if paths else ""
        if children_extra: ch = ch + "\n" + children_extra if ch else children_extra
        path_attr = f'path = {path};' if path else f'name = {name};'
        return (f'\t\t{uid_} /* {name} */ = {{\n'
                f'\t\t\tisa = PBXGroup;\n'
                f'\t\t\tchildren = (\n{ch}\n\t\t\t);\n'
                f'\t\t\t{path_attr}\n'
                f'\t\t\tsourceTree = "<group>";\n'
                f'\t\t}};')

    src_app      = by_group("PunctoDock/App/")
    src_ins      = by_group("PunctoDock/Insertion/")
    src_login    = by_group("PunctoDock/LoginItem/")
    src_model    = by_group("PunctoDock/Model/")
    src_panel    = by_group("PunctoDock/Panel/")
    src_perms    = by_group("PunctoDock/Permissions/")
    src_settings = by_group("PunctoDock/Settings/")
    src_triggers = by_group("PunctoDock/Triggers/")

    res_children = (f"\t\t\t\t{ASSETS_UID} /* Assets.xcassets */,\n"
                    f"\t\t\t\t{INFO_FILE_UID} /* Info.plist */,\n"
                    f"\t\t\t\t{ENTITLEMENTS_UID} /* PunctoDock.entitlements */,")

    subgroups = (f"\t\t\t\t{GROUP_APP} /* App */,\n"
                 f"\t\t\t\t{GROUP_INSERTION} /* Insertion */,\n"
                 f"\t\t\t\t{GROUP_LOGIN} /* LoginItem */,\n"
                 f"\t\t\t\t{GROUP_MODEL} /* Model */,\n"
                 f"\t\t\t\t{GROUP_PANEL} /* Panel */,\n"
                 f"\t\t\t\t{GROUP_PERMS} /* Permissions */,\n"
                 f"\t\t\t\t{GROUP_SETTINGS} /* Settings */,\n"
                 f"\t\t\t\t{GROUP_TRIGGERS} /* Triggers */,\n"
                 f"\t\t\t\t{GROUP_RESOURCES} /* Resources */,")

    main_children = (f"\t\t\t\t{uid('group_punctodock_src')} /* PunctoDock */,\n"
                     f"\t\t\t\t{PRODUCTS_GROUP} /* Products */,")

    src_group_uid = uid('group_punctodock_src')

    parts = [
        # Main group
        (f'\t\t{MAIN_GROUP_UID} = {{\n'
         f'\t\t\tisa = PBXGroup;\n'
         f'\t\t\tchildren = (\n{main_children}\n\t\t\t);\n'
         f'\t\t\tsourceTree = "<group>";\n'
         f'\t\t}};'),
        # Products group
        (f'\t\t{PRODUCTS_GROUP} /* Products */ = {{\n'
         f'\t\t\tisa = PBXGroup;\n'
         f'\t\t\tchildren = (\n\t\t\t\t{PRODUCT_REF} /* PunctoDock.app */,\n\t\t\t);\n'
         f'\t\t\tname = Products;\n'
         f'\t\t\tsourceTree = "<group>";\n'
         f'\t\t}};'),
        # PunctoDock source root group
        (f'\t\t{src_group_uid} /* PunctoDock */ = {{\n'
         f'\t\t\tisa = PBXGroup;\n'
         f'\t\t\tchildren = (\n{subgroups}\n\t\t\t);\n'
         f'\t\t\tpath = PunctoDock;\n'
         f'\t\t\tsourceTree = "<group>";\n'
         f'\t\t}};'),
        make_group(GROUP_APP, "App", src_app, path="App"),
        make_group(GROUP_INSERTION, "Insertion", src_ins, path="Insertion"),
        make_group(GROUP_LOGIN, "LoginItem", src_login, path="LoginItem"),
        make_group(GROUP_MODEL, "Model", src_model, path="Model"),
        make_group(GROUP_PANEL, "Panel", src_panel, path="Panel"),
        make_group(GROUP_PERMS, "Permissions", src_perms, path="Permissions"),
        make_group(GROUP_SETTINGS, "Settings", src_settings, path="Settings"),
        make_group(GROUP_TRIGGERS, "Triggers", src_triggers, path="Triggers"),
        # Resources group (Info.plist + entitlements)
        (f'\t\t{GROUP_RESOURCES} /* Resources */ = {{\n'
         f'\t\t\tisa = PBXGroup;\n'
         f'\t\t\tchildren = (\n{res_children}\n\t\t\t);\n'
         f'\t\t\tpath = Resources;\n'
         f'\t\t\tsourceTree = "<group>";\n'
         f'\t\t}};'),
    ]
    return "\n".join(parts)

def sources_build_phase():
    files = "\n".join(f"\t\t\t\t{build_uid(s)} /* {os.path.basename(s)} in Sources */,"
                      for s in SOURCES)
    return (f'\t\t{SOURCES_PHASE} /* Sources */ = {{\n'
            f'\t\t\tisa = PBXSourcesBuildPhase;\n'
            f'\t\t\tbuildActionMask = 2147483647;\n'
            f'\t\t\tfiles = (\n{files}\n\t\t\t);\n'
            f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
            f'\t\t}};')

def resources_build_phase():
    return (f'\t\t{RESOURCES_PHASE} /* Resources */ = {{\n'
            f'\t\t\tisa = PBXResourcesBuildPhase;\n'
            f'\t\t\tbuildActionMask = 2147483647;\n'
            f'\t\t\tfiles = (\n'
            f'\t\t\t\t{ASSETS_BUILD_UID} /* Assets.xcassets in Resources */,\n'
            f'\t\t\t);\n'
            f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
            f'\t\t}};')

def frameworks_build_phase():
    return (f'\t\t{FRAMEWORKS_PHASE} /* Frameworks */ = {{\n'
            f'\t\t\tisa = PBXFrameworksBuildPhase;\n'
            f'\t\t\tbuildActionMask = 2147483647;\n'
            f'\t\t\tfiles = (\n\t\t\t);\n'
            f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
            f'\t\t}};')

# ─── Build configurations ─────────────────────────────────────────────────────
COMMON_PROJECT_SETTINGS = """\
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++17";
\t\t\t\tCLANG_CXX_LIBRARY = "libc++";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_DECL = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 26.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";"""

COMMON_RELEASE_PROJECT_SETTINGS = """\
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 26.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";"""

TARGET_SETTINGS = """\
				APP_CATEGORY = public.app-category.productivity;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSTCAT_COMPILER_SKIP_APP_STORE_DEPLOYMENT = YES;
				COMBINE_HIDPI_IMAGES = YES;
				CODE_SIGN_ENTITLEMENTS = PunctoDock/Resources/PunctoDock.entitlements;
				CODE_SIGN_IDENTITY = "PunctoDock Self-Signed";
				CODE_SIGN_STYLE = Manual;
				DEVELOPMENT_TEAM = "";
				ENABLE_APP_SANDBOX = NO;
				INFOPLIST_FILE = PunctoDock/Resources/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 26.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.punctodock.app";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;"""

TARGET_SETTINGS_DEBUG = TARGET_SETTINGS  # same — no team configured
def build_configurations():
    return f"""
\t\t{DEBUG_BUILD} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{COMMON_PROJECT_SETTINGS}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{RELEASE_BUILD} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{COMMON_RELEASE_PROJECT_SETTINGS}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{DEBUG_TARGET} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{TARGET_SETTINGS_DEBUG}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{RELEASE_TARGET} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{TARGET_SETTINGS}
\t\t\t}};
\t\t\tname = Release;
\t\t}};"""

def config_lists():
    return f"""
\t\t{PROJ_CONFIGLIST} /* Build configuration list for PBXProject "PunctoDock" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{DEBUG_BUILD} /* Debug */,
\t\t\t\t{RELEASE_BUILD} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{TARGET_CONFIGLIST} /* Build configuration list for PBXNativeTarget "PunctoDock" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{DEBUG_TARGET} /* Debug */,
\t\t\t\t{RELEASE_TARGET} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};"""

# ─── Assemble project.pbxproj ─────────────────────────────────────────────────
pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{pbx_build_files()}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{pbx_file_references()}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
{frameworks_build_phase()}
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{pbx_groups()}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{TARGET_UID} /* PunctoDock */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {TARGET_CONFIGLIST} /* Build configuration list for PBXNativeTarget "PunctoDock" */;
\t\t\tbuildPhases = (
\t\t\t\t{SOURCES_PHASE} /* Sources */,
\t\t\t\t{FRAMEWORKS_PHASE} /* Frameworks */,
\t\t\t\t{RESOURCES_PHASE} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = PunctoDock;
\t\t\tproductName = PunctoDock;
\t\t\tproductReference = {PRODUCT_REF} /* PunctoDock.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{PROJECT_UID} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tORGANIZATIONNAME = "PunctoDock";
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{TARGET_UID} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {PROJ_CONFIGLIST} /* Build configuration list for PBXProject "PunctoDock" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = de;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\tde,
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {MAIN_GROUP_UID};
\t\t\tproductRefGroup = {PRODUCTS_GROUP} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{TARGET_UID} /* PunctoDock */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{resources_build_phase()}
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{sources_build_phase()}
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
{build_configurations()}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
{config_lists()}
/* End XCConfigurationList section */

\t}};
\trootObject = {PROJECT_UID} /* Project object */;
}}
"""

out = os.path.join(PROJ_DIR, "project.pbxproj")
with open(out, "w", encoding="utf-8") as f:
    f.write(pbxproj)

print(f"Generated: {out}")
print("UIDs:")
print(f"  Project:  {PROJECT_UID}")
print(f"  Target:   {TARGET_UID}")
print(f"  Sources:  {len(SOURCES)} files")
