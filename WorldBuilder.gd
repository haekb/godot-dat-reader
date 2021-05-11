extends Node

var lta_writer = preload("res://Addons/LTDatReader/LTAWriter.gd").new()
var dtx_reader = preload("res://Addons/DTXReader/TextureBuilder.gd").new()
var texture_path = ""

const LIGHTMAP_ATLAS_SIZE = 2048.0#4096.0#2048.0

func chunk(array, by): 
	var chunks = []
	var i = 0
	while i < len(array):
		chunks.append( array.slice(i, i+by) )
		i += by
		
	return chunks

func build(source_file, options):
	var file = File.new()
	if file.open(source_file, File.READ) != OK:
		print("Failed to open %s" % source_file)
		return FAILED
		
	print("Opened %s" % source_file)
	
	var dat_file = load("res://Addons/LTDatReader/Models/DAT.gd")
	var ltb_file = load("res://Addons/LTDatReader/Models/LTB_PS2.gd")
	
	# Setup our new scene
	var scene = PackedScene.new()
	
	# Create our nodes
	var root = Spatial.new()
	
	# Setup the nodes
	root.name = "Root"
	
	var model = null
	var file_extension = "dat"
	# Model as in MVC model, not mesh model!
	if ".ltb" in source_file.to_lower():
		model = ltb_file.LTB_PS2.new()
		file_extension = "ltb"
	else:
		model = dat_file.DAT.new()
	
	# Batched reading
	var response = model.read(file, true)
	if response.code == model.IMPORT_RETURN.ERROR:
		print("IMPORT ERROR: %s" % response.message)
		return FAILED
		
	# Hack: Load up some config values
	var config = ConfigFile.new()
	var err = config.load("./settings.cfg")
	
	# Fallback...
	texture_path = "D:\\Games\\Aliens vs. Predator 2 - dev\\AVP2\\"
	
	var export_to_lta = false
	
	if err == OK:
		var game_path_string = "%s_v%d_game_path" % [ file_extension, model.version ]
		texture_path = config.get_value("Worlds", game_path_string, texture_path)
		export_to_lta = config.get_value("Worlds", "export_to_lta_on_load", false)
		
	var world_model_count = model.world_model_count
	
	var world_model_index = 0
	var batch_by = 1024
	
	var total_mesh_count = 0
	
	# Hack for LT1
	for world_model in model.world_models:
		var data = fill_array_mesh(model, [world_model])
		var meshes = data[0]
		var mesh_names = data[1]
		var tex_names = data[2]
		var lm_texture_array = data[3] as Image#[0] # data[3] = [ tex array, last used depth ]

		var use_lightmaps = false
		
		# Quick hack for public release
		if model.version == 55 || model.version == 56 || model.version == 127:
			use_lightmaps = true

		# Loop through our pieces, and add them to mesh instances
		# lm_texture_array.save_png("lm_null.png")
		var lm_image_texture = null
		
		if use_lightmaps:
			lm_image_texture = ImageTexture.new()
			lm_image_texture.create_from_image(lm_texture_array)
			lm_image_texture.set_flags(ImageTexture.FLAGS_DEFAULT + ImageTexture.FLAG_ANISOTROPIC_FILTER + ImageTexture.FLAG_CONVERT_TO_LINEAR)
			
		var cached_textures = {}
		
		var i = 0;
		for mesh in meshes:
			var mesh_instance = MeshInstance.new()
			
			var tex_name = tex_names[i]
			var tex = get_texture(tex_name)
			
			var mat = ShaderMaterial.new()
			mat.shader = load("res://Addons/LTDatReader/Shaders/LT1.tres") as VisualShader
			
			mat.set_shader_param("main_texture", tex)
			
			if use_lightmaps:
				mat.set_shader_param("use_lightmap", true)
				mat.set_shader_param("lm_texture", lm_image_texture)
			else:
				mat.set_shader_param("use_lightmap", false)
			

			mesh_instance.name = mesh_names[i]
			mesh_instance.mesh = mesh
			root.add_child(mesh_instance)
			mesh_instance.owner = root
			mesh_instance.set_surface_material(0, mat)
			i += 1
			total_mesh_count+=1
			
			# Mirror the world a bit to handle Lithtech's style of 3d
			mesh_instance.scale = Vector3( -1.0, 1.0, 1.0 )
		# End For
	
	while world_model_index < world_model_count:
		if (world_model_index + batch_by) > world_model_count:
			batch_by = world_model_count - world_model_index

		var world_models = model.world_model_batch_read(file, batch_by)
		world_model_index += batch_by
		
		var data = fill_array_mesh(model, world_models)
		var meshes = data[0]
		var mesh_names = data[1]
		var tex_names = data[2]
		var lm_texture_array = data[3] as Image#[0] # data[3] = [ tex array, last used depth ]

		# Loop through our pieces, and add them to mesh instances
		lm_texture_array.save_png("lm_null.png")
		
		var lm_image_texture = ImageTexture.new()
		lm_image_texture.create_from_image(lm_texture_array)
		lm_image_texture.set_flags(ImageTexture.FLAGS_DEFAULT + ImageTexture.FLAG_ANISOTROPIC_FILTER + ImageTexture.FLAG_CONVERT_TO_LINEAR)
		
		var cached_textures = {}
		
		var i = 0;
		for mesh in meshes:
			
			var mesh_instance = MeshInstance.new()
			
			var tex_name = tex_names[i]
			var tex = get_texture(tex_name)
			
			var mat = ShaderMaterial.new()
			mat.shader = load("res://Addons/LTDatReader/Shaders/LT1.tres") as VisualShader
			
			mat.set_shader_param("main_texture", tex)
			mat.set_shader_param("lm_texture", lm_image_texture)

			mesh_instance.name = mesh_names[i]
			mesh_instance.mesh = mesh
			root.add_child(mesh_instance)
			mesh_instance.owner = root
			mesh_instance.set_surface_material(0, mat)
			i += 1
			total_mesh_count+=1
			
			# Mirror the world a bit to handle Lithtech's style of 3d
			mesh_instance.scale = Vector3( -1.0, 1.0, 1.0 )
		# End For
	
	# Pack our scene!
	scene.pack(root)
	
	print("Total Meshes Generated: %d" % total_mesh_count)
	
	if export_to_lta:
		var writer = lta_writer.LTAWriter.new()

		var out_path = source_file.replacen(".ltb", ".lta")
		out_path = source_file.replacen(".dat", ".lta")

		print("Exporting LTA to %s" % out_path)

		writer.write(model, out_path, 2)

	# Now that we've packed root into the scene, it's time to clean it up!
	root.queue_free()

	clear_texture_cache()
	
	return scene

var cached_textures = {}
func get_texture(tex_name):
	# Quick texture caching
	if tex_name in cached_textures:
		return cached_textures[tex_name]
	# End If
	
	# Not cached, so grab it and cache it
	var tex = dtx_reader.build("%s%s" % [texture_path, tex_name], [])
	cached_textures[tex_name] = tex
	return tex
# End Func

func clear_texture_cache():	
	cached_textures.clear()


# TODO: Also need to handle shifting? https://github.com/Shfty/libmap/blob/6e4160924cf5373e67e8f35422b196e6e0eaa52c/src/c/geo_generator.c
func opq_to_uv(vertex : Vector3, o : Vector3, p : Vector3, q : Vector3, tex_width = 128.0, tex_height = 128.0):
	# Origin
	var point = vertex - o
	
	var u = point.dot(p) / tex_width
	var v = point.dot(q) / tex_height
	
	return Vector2(u, v)
# End Func

func get_vert_uv( vert : Vector3, poly_u : Vector3, poly_v : Vector3, lm_width, lm_height ):
	#return Vector2( vert.dot(poly_u), vert.dot(poly_v) )
	return Vector2( vert.dot(poly_u) / (lm_width), vert.dot(poly_v) / (lm_height) )

func build_array_mesh(textured_meshes):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var meshes = []
	var texture_references = []
	var mesh_names = []

	for texture in textured_meshes.keys():
		var batches = textured_meshes[texture]
		
		var commit_mesh = null
		var combined_mesh = null
		
		for mesh in batches:
			var mesh_uvs = mesh[0]
			var mesh_normals = mesh[1]
			var mesh_verts = mesh[2]
			var mesh_colours = mesh[3]
			var mesh_uvs2 = mesh[5]
			
			# Mesh is formatted in triangle fan segments per "EditPoly"
			st.add_triangle_fan( PoolVector3Array(mesh_verts), PoolVector2Array(mesh_uvs), PoolColorArray(mesh_colours), PoolVector2Array(mesh_uvs2), PoolVector3Array(mesh_normals) )
		# End For
		
		meshes.append(st.commit())
		
		st.clear()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		texture_references.append(texture)
		mesh_names.append("World Model")#world_model.world_name)
	# End For

	
	return [ meshes, mesh_names, texture_references ]


func fill_array_mesh(model, world_models = []):
	var mesh_names = []
	var meshes = []
	var texture_references = []
	
	var lightmap_textures = {}
	var big_lightmap_image = Image.new()
	var last_lm_uv = Vector2(0,0)#2, 0)

	
	var textured_meshes = {}
	var lightmap_frame_index = 0
	
	var white_image = Image.new()
	white_image.create(2,2, false, Image.FORMAT_RGB8)
	white_image.fill(Color(1.0, 1.0, 1.0, 1.0))
	
	big_lightmap_image.create(LIGHTMAP_ATLAS_SIZE, LIGHTMAP_ATLAS_SIZE, false, Image.FORMAT_RGB8)
	
	# Make a tiny white square for parts of the mesh that don't use lightmaps
	big_lightmap_image.blit_rect(white_image, Rect2(Vector2(0,0), Vector2(2,2)), Vector2(LIGHTMAP_ATLAS_SIZE - 2, LIGHTMAP_ATLAS_SIZE - 2))

	for world_model_index in range(len(world_models)): #model.world_models:
		var world_model = world_models[world_model_index]
		
		var verts = []#PoolVector3Array()
		var uvs = []#PoolVector2Array()
		var uvs2 = []
		var normals = []#PoolVector3Array()
		var colours = []
		var indices = PoolIntArray()
		var polies = []
		
		# Skip the physics mesh
		if world_model.world_name == "VisBSP":# or world_model.world_name == "PhysicsBSP":
			print("Skipping %s" % world_model.world_name)
			continue

		#print("Processing %s" % world_model.world_name)
		
		#
		# TODO: Needs to be split by texture 
		#
		
		# Figure out the total lm width/height and the largest sizes
		var total_lms = 0
		var total_lm_width = 0
		var total_lm_height = 0
		var largest_lm_width = 0
		var largest_lm_height = 0
		for poly in world_model.polies:
			var surface = world_model.surfaces[poly.surface_index]
			if poly.lightmap_texture != null:
				total_lms += 1
				
				var poly_width = poly.lightmap_texture.get_width()
				var poly_height = poly.lightmap_texture.get_height()
				
				if total_lm_width + poly_width > LIGHTMAP_ATLAS_SIZE:
					total_lm_height += 16 # Max lm height for shogo
					total_lm_width = 0
				
				total_lm_width += poly_width
				
				#total_lm_height += poly_height
				largest_lm_width = max(largest_lm_width, poly_width)
				largest_lm_height = max(largest_lm_height, poly_height)
			# End If
		# End If
		
		

		for poly_index in range(len(world_model.polies)):
			var poly = world_model.polies[poly_index]
			var texture_index = 0

			var surface = world_model.surfaces[poly.surface_index]
			
			if model.PLATFORM == "PS2":
				texture_index = poly.texture_index
			else:
				texture_index = surface.texture_index
			
			var texture_name = world_model.texture_names[texture_index].name
			
			var tex = get_texture(texture_name)
			var tex_width = 256
			var tex_height = 256
			
			if tex != null:
				tex_width = tex.get_width()
				tex_height = tex.get_height()
			
			var plane
			
			if model.is_lithtech_1():
				plane = world_model.planes[surface.unknown]
			else:
				plane = world_model.planes[poly.plane_index]
			
			#var lm_frame = model.lightmap_data.data[0].frames[lightmap_frame_index]
			#var lm_colours = model.lightmap_data.data[0].colours[lightmap_frame_index]
			
			#assert(world_model_index == lm_frame.world_model_index)
			#assert(poly_index == lm_frame.poly_index)
			
			var lm_image = poly.lightmap_texture as Image
			
			var depth_uv = Vector2(0, 0)
			
			if lm_image != null:
				# Manually stitch them together...
				
				if last_lm_uv.x + lm_image.get_width() > LIGHTMAP_ATLAS_SIZE:
					# TODO: Read in maxlmsize ; default is 16 (max for shogo)
					last_lm_uv.y += 32
					last_lm_uv.x = 0
					
				var lm_size = lm_image.get_size()
				
				big_lightmap_image.blit_rect(lm_image, Rect2(Vector2(0,0), lm_size), last_lm_uv)

				depth_uv = last_lm_uv
				
				last_lm_uv.x += lm_image.get_width()# + 2
			# End If
				
			var v_width = 0
			var v_height = 0
			
			var last_vert = Vector3()
			# Get the vertices used for this polygon
			for disk_vert_index in range(len(poly.disk_verts)):
				var disk_vert = poly.disk_verts[disk_vert_index]
				
				var vert = world_model.points[disk_vert.vertex_index]
				
				var uv1 = Vector2()
				var uv2 = Vector2()
				var uv3 = Vector2()
				
				if model.PLATFORM == "PC" and model.is_lithtech_1() or model.is_lithtech_2():
					uv1 = surface.uv1
					uv2 = surface.uv2
					uv3 = surface.uv3
				else:
					uv1 = poly.uv1
					uv2 = poly.uv2
					uv3 = poly.uv3

				#var vcolour = Color( lm_colours.r[disk_vert_index], lm_colours.g[disk_vert_index], lm_colours.b[disk_vert_index] )
				
				verts.append(vert)
				normals.append(plane.normal)
				
				if model.is_lithtech_1():
					#var normalized = surface.colour * ( 1.0 / 255.0 )
					var normalized = disk_vert.colour * ( 1.0 / 255.0 )
					
					var colour = Color(normalized.x, normalized.y, normalized.z, 1.0)
					
					colours.append(colour)
				# End If
				
				var uv = opq_to_uv(vert, uv1, uv2, uv3, tex_width, tex_height)
				uvs.append(uv)
				
			# End For
			
			# Start UV 2
			
			if lm_image != null and lm_image.get_width() > 0 and lm_image.get_height() > 0:
				
				var lm_width = lm_image.get_width()
				var lm_height = lm_image.get_height()

				# Project our face to a flat surface, so we slap it on a uv map
				var poly_u = plane.normal.cross( Vector3.UP )
				if poly_u.dot(poly_u) < 0.001:
					poly_u = Vector3.RIGHT
				else:
					poly_u = poly_u.normalized()
				var poly_v = plane.normal.cross(poly_u).normalized()

				#
				# FIRST PASS - Find bounds
				#

				var top_left = Vector2(999.0, 999.0)
				var bottom_right = Vector2(-999.0, -999.0)

				# Figure out the bounds of our lightmap face
				for disk_vert_index in range(len(poly.disk_verts)):
					var disk_vert = poly.disk_verts[disk_vert_index]
					var vert = world_model.points[disk_vert.vertex_index]

					var vert_uv = get_vert_uv(vert, poly_u, poly_v, LIGHTMAP_ATLAS_SIZE, LIGHTMAP_ATLAS_SIZE)
					
					if vert_uv.x < top_left.x:
						top_left.x = vert_uv.x
					if vert_uv.y < top_left.y:
						top_left.y = vert_uv.y
					
					if vert_uv.x > bottom_right.x:
						bottom_right.x = vert_uv.x
					if vert_uv.y > bottom_right.y:
						bottom_right.y = vert_uv.y

				# End For
				
				# Make sure we don't bleed onto our neighbours
				# TODO: This needs to be adjusted if we increase atlas size!
				top_left += Vector2(-0.0035, -0.0035)
				bottom_right += Vector2(0.0035, 0.0035)
				
				#
				var uv_offset = (Vector2(0,0) - top_left)
				var uv_scale = (bottom_right - top_left)
				
#				print("LMSize: ", lm_image.get_size())
#				print("Top Left: ", top_left)
#				print("Bottom Right: ", bottom_right)
#				print("UV Offset: ", uv_offset)
#				print("UV Scale: ", uv_scale)
				
				#
				# SECOND PASS - Calc uv and scale
				# 
				
				for disk_vert_index in range(len(poly.disk_verts)):
					var disk_vert = poly.disk_verts[disk_vert_index]
					var vert = world_model.points[disk_vert.vertex_index]

					var vert_uv = get_vert_uv(vert, poly_u, poly_v, LIGHTMAP_ATLAS_SIZE, LIGHTMAP_ATLAS_SIZE)
					var vert_offset = (depth_uv / Vector2(LIGHTMAP_ATLAS_SIZE, LIGHTMAP_ATLAS_SIZE))
					
					# Bring everything to (0,0)
					vert_uv += uv_offset
					
					# Scale could be 0 in cases where...it doesn't need to be scaled.
					if uv_scale.x > 0.0:
						vert_uv.x /= uv_scale.x
					if uv_scale.y > 0.0:
						vert_uv.y /= uv_scale.y
					
					# Scale it to lightmap size
					var new_vert_uv = Vector2( vert_uv.x * (float(lm_width) / LIGHTMAP_ATLAS_SIZE), vert_uv.y * (float(lm_height) / LIGHTMAP_ATLAS_SIZE) )
					
					# Move it to the right place
					new_vert_uv += vert_offset

					# Fix any nans
					if (is_nan(new_vert_uv.x)):
						new_vert_uv.x = 0.0
					if (is_nan(new_vert_uv.y)):
						new_vert_uv.y = 0.0
					
					uvs2.append( new_vert_uv )
				# End For
			else:
				# Assign them to the tiny white square on the lower right of the lightmap image
				for disk_vert_index in range(len(poly.disk_verts)):
					uvs2.append(Vector2(1,0))
				# End For
			# End If
			
			# End UV 2
			
			verts.invert()
			normals.invert()
			uvs.invert()
			uvs2.invert()
			colours.invert()

			# Add it to the batch!
			if texture_name in textured_meshes:
				textured_meshes[texture_name].append([ uvs, normals, verts, colours, lightmap_textures, uvs2 ])
			else:
				textured_meshes[texture_name] = [[ uvs, normals, verts, colours, lightmap_textures, uvs2 ]]
			
			#print("MEM: ", OS.get_static_memory_usage() / 1000000)
			
			verts = [] #PoolVector3Array()
			uvs = [] #PoolVector2Array()
			uvs2 = []
			normals = [] #PoolVector3Array()
			colours = []
			
			lightmap_frame_index += 1
		# End For
		
		# If you want things split up on per world model call build_array_mesh here!
		big_lightmap_image.save_png("./lm_atlas.png")
	# End For
		
	var data = build_array_mesh(textured_meshes)
	meshes += data[0]
	mesh_names += data[1]
	texture_references += data[2]

	var obj_exporter = load("res://Src/obj_exporter.gd").OBJExporter.new()
	
	#print("Exporting obj...")
	#obj_exporter.export_mesh(meshes, "./test.obj", true)
	#print("Finished!")

	# Texture References is polygon aligned
	return [ meshes, mesh_names, texture_references, big_lightmap_image ]
# End Func
