extends GutTest

const MANAGER_SCRIPT = preload("res://addons/aerobeat-tool-headless-manager/src/AeroHeadlessManager.gd")
const TEST_DIR := "user://gut_headless_manager"


func after_each() -> void:
	_cleanup_test_files()


func test_prepare_sentinel_directory_creates_parent_directory() -> void:
	var manager = MANAGER_SCRIPT.new()
	var sentinel_path := _test_sentinel_path()
	var ok := manager._prepare_sentinel_directory(sentinel_path)

	assert_true(ok, "manager should create the parent directory for the sentinel")
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEST_DIR)), "parent directory should exist after preparation")

	manager.free()


func test_clear_sentinel_if_present_removes_stale_file() -> void:
	var sentinel_path := _test_sentinel_path()
	_create_blank_file(sentinel_path)
	var manager = MANAGER_SCRIPT.new()

	var ok := manager._clear_sentinel_if_present(sentinel_path)

	assert_true(ok, "clearing a stale sentinel should succeed")
	assert_false(FileAccess.file_exists(sentinel_path), "stale sentinel should be removed")

	manager.free()


func test_consume_quit_request_removes_request_file() -> void:
	var sentinel_path := _test_sentinel_path()
	_create_blank_file(sentinel_path)
	var manager = MANAGER_SCRIPT.new()

	var ok := manager._consume_quit_request(sentinel_path)

	assert_true(ok, "consuming the sentinel should succeed")
	assert_false(FileAccess.file_exists(sentinel_path), "consumed sentinel should be removed")

	manager.free()


func test_sentinel_resource_path_stays_fixed_and_project_local() -> void:
	assert_eq(MANAGER_SCRIPT.SENTINEL_RESOURCE_PATH, "res://.headless/quit.request")


func _test_sentinel_path() -> String:
	return TEST_DIR.path_join("quit.request")


func _create_blank_file(file_path: String) -> void:
	var manager = MANAGER_SCRIPT.new()
	assert_true(manager._prepare_sentinel_directory(file_path), "test setup should create the sentinel directory")
	manager.free()

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	assert_true(file != null, "test setup should create the sentinel file")
	file.store_string("")
	file.close()


func _cleanup_test_files() -> void:
	DirAccess.remove_absolute(_test_sentinel_path())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
