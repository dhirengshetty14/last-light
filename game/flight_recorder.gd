extends RefCounted
## The writer owns the file. Frame and physics callbacks enqueue immutable batches.
var mutex := Mutex.new()
var wake := Semaphore.new()
var worker := Thread.new()
var pending: Array = []
var opened := false


func begin(path: String, header: Dictionary) -> void:
	opened = true
	worker.start(_write.bind(path))
	append([header])


func append(batch: Array) -> void:
	if not opened or batch.is_empty():
		return
	mutex.lock()
	pending.append(batch)
	mutex.unlock()
	wake.post()


func finish(footer: Dictionary) -> void:
	if not opened:
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
				f.store_line(JSON.stringify(e))
			f.flush()
	if f:
		f.close()
