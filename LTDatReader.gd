tool
extends EditorPlugin


var import_plugin


func _enter_tree():
	import_plugin = load("res://Addons/LTDatReader/Importer.gd").new() #preload("Importer.gd").new()
	add_import_plugin(import_plugin)


func _exit_tree():
	remove_import_plugin(import_plugin)
	import_plugin = null
