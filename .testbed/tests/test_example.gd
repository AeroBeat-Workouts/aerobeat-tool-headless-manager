extends GutTest

const MANAGER_SCRIPT = preload("res://addons/aerobeat-tool-headless-manager/src/AeroHeadlessManager.gd")
const README_PATH := "../README.md"
const PLUGIN_CFG_PATH := "../plugin.cfg"
const ADDONS_MANIFEST_PATH := "addons.jsonc"
const EXPECTED_PLUGIN_NAME := "AeroBeat Headless Manager"
const EXPECTED_PLUGIN_DESCRIPTION := "Dev-only headless quit sentinel manager for AeroBeat Godot projects."


func _read_repo_file(relative_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path("res://%s" % relative_path)
	assert_true(FileAccess.file_exists(absolute_path), "Expected repo file to exist: %s" % absolute_path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	assert_true(file != null, "Expected repo file to open: %s" % absolute_path)
	return file.get_as_text()


func test_readme_describes_the_minimal_headless_quit_contract_truthfully() -> void:
	var readme_text := _read_repo_file(README_PATH)
	assert_true(readme_text.contains("res://.headless/quit.request"), "README should document the fixed project-local sentinel path")
	assert_true(readme_text.contains("get_tree().quit()"), "README should describe the in-app quit call")
	assert_true(readme_text.contains("claim equivalence to the Godot editor's Stop Running Project behavior"), "README should keep the editor-stop caveat explicit")
	assert_true(readme_text.contains("GodotEnv"), "README should document the intended consumer installation path")


func test_plugin_cfg_matches_repo_identity() -> void:
	var config := ConfigFile.new()
	var error := config.load(ProjectSettings.globalize_path("res://%s" % PLUGIN_CFG_PATH))
	assert_eq(error, OK, "plugin.cfg should parse cleanly")
	assert_eq(config.get_value("plugin", "name", ""), EXPECTED_PLUGIN_NAME)
	assert_eq(config.get_value("plugin", "description", ""), EXPECTED_PLUGIN_DESCRIPTION)
	assert_eq(config.get_value("plugin", "version", ""), MANAGER_SCRIPT.VERSION)


func test_addons_manifest_installs_self_package_and_gut_only() -> void:
	var manifest_text := _read_repo_file(ADDONS_MANIFEST_PATH)
	assert_true(manifest_text.contains('"aerobeat-tool-headless-manager"'), "addons manifest should install this package into the testbed")
	assert_true(manifest_text.contains('"source": "symlink"'), "self package should be installed through a local symlink for the workbench")
	assert_true(manifest_text.contains('"gut"'), "addons manifest should keep gut for repo-local tests")
	assert_false(manifest_text.contains('"aerobeat-tool-core"'), "minimal headless manager testbed should not retain unused template dependencies")
