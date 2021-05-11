tool
extends EditorImportPlugin

func get_importer_name():
	return "lithtech.dat.import"

func get_visible_name():
	return "Lithtech DAT Importer"

func get_recognized_extensions():
	return ["dat"]

func get_save_extension():
	return "tscn"

func get_resource_type():
	return "PackedScene"

func get_preset_count():
	return 1

func get_preset_name(i):
	return "Default"

func get_import_options(i):
	return []
	
func get_option_visibility(option, options):
	return true

var _world_builder = null

func _init():
	self._world_builder = load('res://Addons/LTDatReader/WorldBuilder.gd').new()
	

func import(source_file, save_path, options, platform_variants, gen_files):
	var scene = self._world_builder.build(source_file, options)
	
	var filename = save_path + "." + get_save_extension()
	print("Saving as ", filename)
	ResourceSaver.save(filename, scene)
	return OK

