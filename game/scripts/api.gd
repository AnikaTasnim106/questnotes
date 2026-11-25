extends Node
## Autoload "Api": talks to the FastAPI backend.
## Every call returns {"ok": bool, "code": int, "data": Variant, "error": String}.

const GEN_TIMEOUT := 120.0   # generation + possible Render cold start
const HINT_TIMEOUT := 10.0   # never keep the player waiting long for a hint


func _ready() -> void:
	# Hints are requested while the game is paused, so this must keep running.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _request(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET,
		headers: PackedStringArray = PackedStringArray(), body: PackedByteArray = PackedByteArray(),
		timeout: float = GEN_TIMEOUT) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	var err := http.request_raw(Game.api_url + path, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": null, "error": "Couldn't start the request."}
	var res: Array = await http.request_completed
	http.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var raw: PackedByteArray = res[3]
	if result == HTTPRequest.RESULT_TIMEOUT:
		return {"ok": false, "code": 0, "data": null, "error": "The server took too long. Try again."}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": 0, "data": null, "error": "Can't reach the dungeon server."}
	var data = JSON.parse_string(raw.get_string_from_utf8())
	if code >= 200 and code < 300:
		return {"ok": true, "code": code, "data": data, "error": ""}
	var msg := "Server error %d" % code
	if data is Dictionary and (data as Dictionary).has("detail"):
		msg = str(data["detail"])
	return {"ok": false, "code": code, "data": data, "error": msg}


func health() -> Dictionary:
	return await _request("/health", HTTPClient.METHOD_GET, PackedStringArray(), PackedByteArray(), 75.0)


## Fire-and-forget: wakes a sleeping free-tier server so hints are fast later.
func wake() -> void:
	await health()


func generate_text(text: String) -> Dictionary:
	var body := ("text=" + text.uri_encode()).to_utf8_buffer()
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	return await _request("/generate", HTTPClient.METHOD_POST, headers, body)


func generate_file(filename: String, bytes: PackedByteArray) -> Dictionary:
	var boundary := "----QuestNotes%d" % Time.get_ticks_usec()
	var mime := "application/pdf" if filename.to_lower().ends_with(".pdf") else "text/plain"
	var safe_name := filename.replace("\"", "").replace("\r", "").replace("\n", "")
	var body := PackedByteArray()
	body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n"
		% [boundary, safe_name, mime]).to_utf8_buffer())
	body.append_array(bytes)
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	var headers := PackedStringArray(["Content-Type: multipart/form-data; boundary=" + boundary])
	return await _request("/generate", HTTPClient.METHOD_POST, headers, body)


func hint(concept_name: String, q: Dictionary, picked_index: int) -> Dictionary:
	var payload := {
		"concept": concept_name,
		"prompt": q.get("prompt", ""),
		"choices": q.get("choices", []),
		"answer_index": int(q.get("answer_index", 0)),
		"picked_index": picked_index,
		"source_quote": q.get("source_quote", ""),
	}
	var headers := PackedStringArray(["Content-Type: application/json"])
	return await _request("/hint", HTTPClient.METHOD_POST, headers,
		JSON.stringify(payload).to_utf8_buffer(), HINT_TIMEOUT)
