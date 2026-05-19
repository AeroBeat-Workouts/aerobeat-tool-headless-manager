## Dev-only headless quit manager for AeroBeat Godot projects.
##
## This singleton intentionally exposes one tiny control surface only:
## when running a debug/headless app session, it watches for the project-local
## sentinel file at `res://.headless/quit.request`. If that file appears, the
## manager consumes it and calls `get_tree().quit()` from inside the app.
extends Node

signal quit_requested(sentinel_path: String)
signal armed(sentinel_path: String)

const VERSION: String = "0.1.0"
const SENTINEL_RESOURCE_PATH: String = "res://.headless/quit.request"
const POLL_INTERVAL_SECONDS: float = 0.25

var _sentinel_path: String = ""
var _is_armed: bool = false
var _has_consumed_quit_request: bool = false
var _poll_elapsed_seconds: float = 0.0


func _ready() -> void:
	_sentinel_path = _resolve_sentinel_path()
	set_process(false)

	if not _should_arm_for_current_runtime():
		return

	if not _prepare_sentinel_directory(_sentinel_path):
		push_warning("AeroHeadlessManager could not create the headless sentinel directory.")
		return

	if not _clear_sentinel_if_present(_sentinel_path):
		push_warning("AeroHeadlessManager could not clear a stale quit sentinel and will stay disarmed.")
		return

	_is_armed = true
	armed.emit(_sentinel_path)
	set_process(true)


func _process(delta: float) -> void:
	if not _is_armed or _has_consumed_quit_request:
		return

	_poll_elapsed_seconds += delta
	if _poll_elapsed_seconds < POLL_INTERVAL_SECONDS:
		return

	_poll_elapsed_seconds = 0.0
	_check_for_quit_request()


func _should_arm_for_current_runtime() -> bool:
	return OS.is_debug_build() and DisplayServer.get_name() == "headless"


func _resolve_sentinel_path() -> String:
	return ProjectSettings.globalize_path(SENTINEL_RESOURCE_PATH)


func _prepare_sentinel_directory(sentinel_path: String) -> bool:
	var directory_path := sentinel_path.get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(directory_path)
	return error == OK or error == ERR_ALREADY_EXISTS


func _clear_sentinel_if_present(sentinel_path: String) -> bool:
	if not FileAccess.file_exists(sentinel_path):
		return true

	return _remove_file(sentinel_path)


func _check_for_quit_request() -> void:
	if not FileAccess.file_exists(_sentinel_path):
		return

	if not _consume_quit_request(_sentinel_path):
		push_warning("AeroHeadlessManager saw the quit sentinel but could not consume it.")
		return

	_has_consumed_quit_request = true
	_is_armed = false
	set_process(false)
	quit_requested.emit(_sentinel_path)
	get_tree().quit()


func _consume_quit_request(sentinel_path: String) -> bool:
	return _remove_file(sentinel_path)


func _remove_file(file_path: String) -> bool:
	var error := DirAccess.remove_absolute(file_path)
	return error == OK or error == ERR_DOES_NOT_EXIST
