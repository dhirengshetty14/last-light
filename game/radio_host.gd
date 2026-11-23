extends RefCounted
## The native client only knows a playbook URL. On the demo Mac the owner can run the service locally.
const HOST_SCRIPT = "res://host/radio.py"
var endpoint := ""
var _ready_file := ""
var _script := ""
var _pid := -1


func start() -> void:
	var url := OS.get_environment("LAST_LIGHT_RADIO_URL").strip_edges()
	if url.is_empty():
		url = str(ProjectSettings.get_setting("last_light/radio/url", "")).strip_edges()
	if url != "":
		if url.begins_with("https://") or url.begins_with("http://127.0.0.1:"):
			endpoint = url.trim_suffix("/") + "/v1/playbook"
		return
	if not OS.has_feature("macos"):
		return
	var host_key := OS.get_environment("HOME").path_join(
		"Library/Application Support/Last Light Host/gemini.key"
	)
	if (
		not FileAccess.file_exists(host_key)
		and not OS.has_environment("GEMINI_API_KEY")
		and not OS.has_environment("GOOGLE_API_KEY")
	):
		return
	var dir := OS.get_temp_dir().path_join(
		"last-light-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return
	_script = dir.path_join("radio.py")
	_ready_file = dir.path_join("port")
	var helper := FileAccess.open(_script, FileAccess.WRITE)
	if not helper:
		return
	helper.store_buffer(FileAccess.get_file_as_bytes(HOST_SCRIPT))
	helper.close()
	_pid = OS.create_process(
		"/usr/bin/python3",
		[_script, "--port", "0", "--ready", _ready_file, "--parent", str(OS.get_process_id())]
	)


func address() -> String:
	if endpoint.is_empty() and _pid > 0 and FileAccess.file_exists(_ready_file):
		var number := FileAccess.get_file_as_string(_ready_file).strip_edges().to_int()
		if number > 0 and number <= 65535:
			endpoint = "http://127.0.0.1:%d/v1/playbook" % number
	return endpoint


func stop() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	if _script != "":
		DirAccess.remove_absolute(_script)
		DirAccess.remove_absolute(_ready_file)
		DirAccess.remove_absolute(_script.get_base_dir())
