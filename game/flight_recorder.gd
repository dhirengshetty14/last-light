extends RefCounted
## The writer owns the file. Frame and physics callbacks enqueue immutable batches.
## A browser build has no threads, so there each batch is written straight away instead.
var mutex := Mutex.new()
var wake := Semaphore.new()
var worker := Thread.new()
var pending: Array = []
var opened := false
var direct: FileAccess
var in_browser := OS.has_feature("web")


func begin(path: String, header: Dictionary) -> void:
	opened = true
	if in_browser:
		direct = FileAccess.open(path, FileAccess.WRITE)
	else:
		worker.start(_write.bind(path))
	append([header])


func append(batch: Array) -> void:
	if not opened or batch.is_empty():
		return
	if in_browser:
		if direct:
			for e in batch:
				direct.store_line(JSON.stringify(e, "", true, true))
		return
	mutex.lock()
	pending.append(batch)
	mutex.unlock()
	wake.post()


func finish(footer: Dictionary) -> void:
	if not opened:
		return
	if in_browser:
		append([footer])
		if direct:
			direct.close()
			direct = null
		opened = false
		return
	append([footer])
	mutex.lock()
	pending.append(null)
	mutex.unlock()
	wake.post()
	worker.wait_to_finish()
	opened = false


func _write(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("Cannot write flight to " + path)
	while true:
		wake.wait()
		mutex.lock()
		var batch = pending.pop_front()
		mutex.unlock()
		if batch == null:
			break
		if f:
			for e in batch:
				f.store_line(JSON.stringify(e, "", true, true))
			f.flush()
	if f:
		f.close()
