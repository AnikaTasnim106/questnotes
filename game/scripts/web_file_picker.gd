class_name WebFilePicker
extends Node
## Opens the browser's file chooser on the web build and returns the file's bytes.
## (Godot's FileDialog can't see the user's disk in a browser.)

signal picked(filename: String, bytes: PackedByteArray)

var _callback = null  # must stay referenced or the browser drops it


func open(accept: String = ".pdf,.txt") -> void:
	if not OS.has_feature("web"):
		push_warning("WebFilePicker only works in the web build.")
		return
	_callback = JavaScriptBridge.create_callback(_on_file_loaded)
	var window = JavaScriptBridge.get_interface("window")
	window.questnotesOnFile = _callback
	var js := """
(function () {
  var input = document.createElement('input');
  input.type = 'file';
  input.accept = '%s';
  input.onchange = function (e) {
    var f = e.target.files[0];
    if (!f) return;
    var r = new FileReader();
    r.onload = function () {
      var b64 = String(r.result).split(',')[1] || '';
      window.questnotesOnFile(f.name, b64);
    };
    r.readAsDataURL(f);
  };
  input.click();
})();
""" % accept
	JavaScriptBridge.eval(js, true)


func _on_file_loaded(args: Array) -> void:
	if args.size() < 2:
		return
	var filename := str(args[0])
	var bytes := Marshalls.base64_to_raw(str(args[1]))
	picked.emit(filename, bytes)
