extends Node

class DAT:
	
	# Versioning
	# Lithtech 1.0 - 1.5
	const DAT_VERSION_LT1  = 56
	const DAT_VERSION_LT15 = 57
	const DAT_VERSION_PSYCHO = 127 # Psycho Circus uses an adjusted version of 57
	# Lithtech 2.0 - Talon
	const DAT_VERSION_NOLF = 66
	const DAT_VERSION_AVP2 = 70
	# Lithtech Jupiter
	const DAT_VERSION_JUPITER = 85
	
	const PLATFORM = "PC"
	
	# Header
	var version = 0
	var object_data_pos = 0
	var render_data_pos = 0
	
	# Lithtech Jupiter only!
	var blind_object_data_pos = 0
	var light_grid_pos = 0
	var collision_data_pos = 0
	var particle_blocker_data_pos = 0
	
	# World Info
	var world_info = null
	
	# World Tree
	var world_tree = null
	
	# World Models
	var world_model_count = 0
	var world_models = []
	
	# Render Data
	var lightmap_data = null
	
	var world_object_data = null
	
	# Jupiter only!~
	var render_data = null 
	
	# Scratch
	var current_poly_index = 0
	var current_world_model_index = 0
	
	func _init():
		pass
	# End Func
	
	enum IMPORT_RETURN{SUCCESS, PARTIAL, ERROR}
	
	# v56 and v57/v127 are pretty similar
	func is_lithtech_1(include_15 = true, include_psycho = true):
		var to_check = [ DAT_VERSION_LT1 ]
		if include_15:
			to_check.append( DAT_VERSION_LT15 )
		# End If
		if include_psycho:
			to_check.append( DAT_VERSION_PSYCHO )
		# End If
		return to_check.has(self.version)
	# End If
	
	func is_lithtech_15(include_psycho = true):
		var to_check = [ DAT_VERSION_LT15 ]
		if include_psycho:
			to_check.append( DAT_VERSION_PSYCHO )
		# End If
		return to_check.has(self.version)
	# End If
	
	func is_lithtech_psycho():
		return [ DAT_VERSION_PSYCHO ].has(self.version)
	# End If
	
	func is_lithtech_2():
		return [ DAT_VERSION_NOLF ].has(self.version)
	# End If
	
	func is_lithtech_talon():
		return [ DAT_VERSION_AVP2 ].has(self.version)
	# End If
	
	func is_lithtech_jupiter():
		return [ DAT_VERSION_JUPITER ].has(self.version)
		
	func is_supported():
		return [
			DAT_VERSION_LT1, 
			DAT_VERSION_LT15, 
			DAT_VERSION_PSYCHO, 
			DAT_VERSION_NOLF, 
			DAT_VERSION_AVP2, 
			DAT_VERSION_JUPITER
			].has(self.version)
	
	func read(f : File, dont_import_world_models = false):
		
		self.version = f.get_32()
		
		print("DAT Version: %d" % self.version)
				
		if self.is_supported() == false:
			return self._make_response(IMPORT_RETURN.ERROR, 'Unsupported file version (%d)' % self.version)
		# End If
				
		self.object_data_pos = f.get_32()
		
		if is_lithtech_jupiter():
			self.blind_object_data_pos = f.get_32()
			self.light_grid_pos = f.get_32()
			self.collision_data_pos = f.get_32()
			self.particle_blocker_data_pos = f.get_32()
		
		self.render_data_pos = f.get_32()
		
		if !is_lithtech_1():
			# Skip 8 dummy ints
			f.seek(f.get_position() + 8 * 4)
		
		self.world_info = WorldInfo.new()
		self.world_info.read(self, f)
		
		print("Props: " , self.world_info.properties)
		print("Position: ",f.get_position())
		
		self.world_tree = WorldTree.new()
		if !is_lithtech_1():
			self.world_tree.read(self, f)
			
		# Save the world model position, and let's read some lightmaps!
		var world_model_pos = f.get_position()
		
		# Lithtech 1.0 --
		# Render data doesn't exist in it's own section
		# And object data comes before world models!
		if (!is_lithtech_1() && !is_lithtech_jupiter()) && self.render_data_pos != f.get_len():
			f.seek(self.render_data_pos)
			
			self.lightmap_data = WorldLightMaps.new()
			self.lightmap_data.read(self, f)
			
		if is_lithtech_jupiter():
			f.seek(self.render_data_pos)
			
			self.render_data = RenderData.new()
			self.render_data.read(self, f)
		
		# Another detour to object data...
		f.seek(self.object_data_pos)
		
		world_object_data = WorldObjectHeader.new()
		world_object_data.read(self, f)
		
		# Okay back to world models
		f.seek(world_model_pos)
			
		if is_lithtech_1():
			# Read the "root" world model
			world_model_batch_read(f, 1)
			self.world_models[0].world_name = "Root"
		
		self.world_model_count = f.get_32()
		print("World Model Count: ", self.world_model_count)
		
		if dont_import_world_models:
			return self._make_response(IMPORT_RETURN.PARTIAL)

		world_model_batch_read(f, self.world_model_count)

		return self._make_response(IMPORT_RETURN.SUCCESS)
		
	# End Func
	
	func world_model_batch_read(f : File, amount_to_read):
		var world_models = []
		for _i in range(amount_to_read):
			var next_world_model_pos = f.get_32()
			
			if !is_lithtech_jupiter():
				# Byte array?
				var unk_dummy = f.get_buffer(32)
			
			var world_bsp = WorldBSP.new()
			world_bsp.read(self, f)
			
			if world_bsp.section_count > 0:
				f.seek(next_world_model_pos)
			
			world_models.append(world_bsp)
			self.world_models.append(world_bsp)
		# End For
		return world_models
	# End Func
	
	#
	# Helpers
	# 
	func _make_response(code, message = ''):
		return { 'code': code, 'message': message }
	# End Func
	
	func read_string(file : File, is_length_a_short = true):
		var length = 0
		if is_length_a_short:
			length = file.get_16() 
		else:
			length = file.get_32() # Sometimes it's 32-bit...
		# End If
			
		return file.get_buffer(length).get_string_from_ascii()
	# End Func
	
	func read_vector2(file : File):
		var vec2 = Vector2()
		vec2.x = file.get_float()
		vec2.y = file.get_float()
		return vec2
	# End Func
		
	func read_vector3(file : File):
		var vec3 = Vector3()
		vec3.x = file.get_float()
		vec3.y = file.get_float()
		vec3.z = file.get_float()
		return vec3
	# End Func
	
	func read_quat(file : File):
		var quat = Quat()
		quat.w = file.get_float()
		quat.x = file.get_float()
		quat.y = file.get_float()
		quat.z = file.get_float()
		return quat
		
	func read_matrix(file : File):
		var matrix_4x4 = []
		for i in range(16):
			matrix_4x4.append(file.get_float())
			
		return self.convert_4x4_to_transform(matrix_4x4)
	# End Func
	
	func convert_4x4_to_transform(matrix):
		return Transform(
			Vector3( matrix[0], matrix[4], matrix[8]  ),
			Vector3( matrix[1], matrix[5], matrix[9]  ),
			Vector3( matrix[2], matrix[6], matrix[10] ),
			Vector3( matrix[3], matrix[7], matrix[11] )
		)
	
	##################
	# Internal Classes
	##################
	class WorldInfo:
		
		var properties = ""
		var light_map_grid_size = 0
		var extents_min = Vector3()
		var extents_max = Vector3()
		
		var world_offset = Vector3()
		
		func read(dat : DAT, f : File):
			self.properties = dat.read_string(f, false)
			
			if dat.is_lithtech_1():
				
				if dat.is_lithtech_15():
					self.light_map_grid_size = f.get_float()
				# End If
				
				# Skip 8 dummy ints
				f.seek(f.get_position() + 8 * 4)
				return
			
			if !dat.is_lithtech_jupiter():
				self.light_map_grid_size = f.get_float()
			
			self.extents_min = dat.read_vector3(f)
			self.extents_max = dat.read_vector3(f)
			
			if dat.is_lithtech_jupiter():
				self.world_offset = dat.read_vector3(f)
			
		# End Func
	
	class WorldTree:
		var root_node = null
		
		func read(dat : DAT, f : File):
			
			var node = WorldTreeNode.new()
			node.read(dat, f)
			root_node = node
			
			# End For
		# End Func

	# More Info: https://github.com/sionzeecz/avp2-map-parser/blob/master/src/types/WorldTree.h
	class WorldTreeNode:
		const max_world_tree_children = 4
		
		var box_min = Vector3()
		var box_max = Vector3()
		var child_node_count = 0
		var dummy_terrain_depth = 0
		
		var center_x = 0.0
		var center_y = 0.0
		var smallest_dim = 0.0
		
		var child_nodes = []
		
		func set_bounding_box(min_vec, max_vec):
			self.box_min = min_vec
			self.box_max = max_vec
			
			self.center_x = (max_vec.x + min_vec.x) * 0.5
			self.center_y = (max_vec.z + max_vec.z) * 0.5
			
			self.smallest_dim = min(max_vec.x - min_vec.x, max_vec.z - min_vec.z)
		# End For
		
		# Here's where it gets confusing...
		func read_layout(f : File, current_byte, current_bit, current_offset):
			if current_bit == 8:
				current_byte = f.get_8()
				current_bit = 0
			# End If
			
			var subdivide = (current_byte & (1 << current_bit)) != 0
			current_bit += 1
			
			if subdivide:
				self.subdivide(current_offset)
				
				for node in self.child_nodes:
					var ret = node.read_layout(f, current_byte, current_bit, current_offset)
					current_byte 	= ret[0]
					current_bit  	= ret[1]
					current_offset 	= ret[2]
				# End For
				
			return [ current_byte, current_bit, current_offset ]
		# End Func
		
		# Allocs children!
		func subdivide(current_offset):
			for i  in range(self.max_world_tree_children):
				var node = WorldTreeNode.new()
				node.set_bounding_box(self.box_min, self.box_max)
				self.child_nodes.append(node)
			# End For
		# End Func
		
		func read(dat : DAT, f : File):
			self.box_min = dat.read_vector3(f)
			self.box_max = dat.read_vector3(f)
			self.child_node_count = f.get_32()
			self.dummy_terrain_depth = f.get_32()
			
			# Left over from pascal port
			self.set_bounding_box(self.box_min, self.box_max)
			
			self.read_layout(f, 0, 8, 0)
		# End Func
		
		pass
		
	class WorldTexture:
		var name = ""
		
		# Read a null-terminated string
		func read(dat: DAT, f : File):
			var byte_array = PoolByteArray()
			var current_byte = f.get_8()
			
			while current_byte != 0x0:
				byte_array.append(current_byte)
				current_byte = f.get_8()
				
			self.name = byte_array.get_string_from_ascii()
		# End Func
	# End Class
	
	class WorldPlane:
		var normal = Vector3()
		var distance = 0.0
		
		func read(dat: DAT, f : File):
			self.normal = dat.read_vector3(f)
			self.distance = f.get_float()
		# End Func
	# End Class
	
	class WorldLeaf:
		
		class LeafData:
			var portal_id = 0
			var size = 0
			var contents = []
			
			func read(dat: DAT, f : File):
				self.portal_id = f.get_16()
				self.size = f.get_16()
				self.contents = f.get_buffer(self.size)
			# End Func
		# End Class
			
		var count = 0
		var index = -1
		var data = []
		var polygon_count = 0
		var polygon_data = []
		var unk_1
		
		func read(dat: DAT, f : File):
			self.count = f.get_16()
			
			if self.count == 0xFFFF:
				self.index = f.get_16()
			else:
				for i in range(self.count):
					var leaf_data = WorldLeaf.LeafData.new()
					leaf_data.read(dat, f)
					data.append(leaf_data)
				# End For
			# End If
			
			# No extra data here in jupiter!
			if dat.is_lithtech_jupiter():
				return
				
			if dat.is_lithtech_1():
				self.polygon_count = f.get_16()
			else:
				self.polygon_count = f.get_32()
			# End If
			self.polygon_data = f.get_buffer(self.polygon_count * 4)
			
			if dat.is_lithtech_1():
				self.unk_1 = f.get_float()
			else:
				self.unk_1 = f.get_32()
		# End Func
	# End Class
	
	class WorldSurface:
		var uv1 = Vector3()
		var uv2 = Vector3()
		var uv3 = Vector3()
		
		# Lithtech 1.0
		var uv4 = Vector3()
		var uv5 = Vector3()
		var colour = Vector3()
		
		var unknown = 0
		var unknown2 = 0
		
		var texture_flags = 0
		var texture_index = 0
		var flags = 0
		var use_effects = 0
		var effect_name = ""
		var effect_param = ""
		
		func fix_colour():
			colour.x = min(255.0, colour.x)
			colour.y = min(255.0, colour.y)
			colour.z = min(255.0, colour.z)
		# End Func
		
		func read(dat: DAT, f : File):
			
			# Short and sweet, most of the data is in render data..
			if dat.is_lithtech_jupiter():
				self.flags = f.get_32()
				self.texture_index = f.get_16()
				self.texture_flags = f.get_16()
				return
			
			self.uv1 = dat.read_vector3(f)
			self.uv2 = dat.read_vector3(f)
			self.uv3 = dat.read_vector3(f)
			
			if dat.is_lithtech_1():
				self.uv4 = dat.read_vector3(f)
				self.uv5 = dat.read_vector3(f)
				self.colour = dat.read_vector3(f)
				# Colour can be filled with 0xCDCDCDCD
				self.fix_colour()

			
			self.texture_index = f.get_16()
			
			if dat.is_lithtech_1() || dat.is_lithtech_2():
				self.unknown = f.get_32()
			# End If
			
			self.flags = f.get_32()
			
			# Maybe bytes?
			self.unknown2 = f.get_32()
			
			self.use_effects = f.get_8()
			
			if (self.use_effects == 1):
				self.effect_name = dat.read_string(f)
				self.effect_param = dat.read_string(f)
			# End If
			
			self.texture_flags = f.get_16()
			
			if dat.is_lithtech_psycho():
				var unknown_short = f.get_16()
			# End If
			
		# End Func
	# End Class
	
	class WorldPoly:
		
		class DiskVert:
			var vertex_index = 0
			var dummy = []
			var colour = Vector3(255, 255, 255)
			
			func fix_colour(dummy):
				self.colour.x = min(255.0, float(dummy[0]))
				self.colour.y = min(255.0, float(dummy[1]))
				self.colour.z = min(255.0, float(dummy[2]))
			# End Func
			
			func read(dat: DAT, f : File):
				if dat.is_lithtech_jupiter():
					self.vertex_index = f.get_32()
					return
					
				self.vertex_index = f.get_16()
				self.dummy = Array(f.get_buffer(3))
				
				if dat.is_lithtech_1():
					self.fix_colour(self.dummy)
			# End Func
		# End Class
		
		var center = Vector3()
		var lightmap_width = 0
		var lightmap_height = 0
		
		var unknown_flag = 0
		var unknown_list = []
		
		# I think they're indexes!
		var surface_index = 0
		var plane_index = 0
		
		var uv1 = Vector3()
		var uv2 = Vector3()
		var uv3 = Vector3()
		
		var disk_verts = []
		
		# Lithtech 1 for now
		var lightmap_texture = null
		
		func read(dat: DAT, f: File, vert_count = 0):
			if dat.is_lithtech_jupiter():
				self.surface_index = f.get_32()
				self.plane_index = f.get_32()
				self.disk_verts
				for _i in range(vert_count):
					var disk_vert = WorldPoly.DiskVert.new()
					disk_vert.read(dat, f)
					disk_verts.append(disk_vert)
				# End For
				return
				
			
			if !dat.is_lithtech_1():
				self.center = dat.read_vector3(f)
			# End If
			
			self.lightmap_width = f.get_16()
			self.lightmap_height = f.get_16()
			
			if !dat.is_lithtech_1():
				self.unknown_flag = f.get_16()
				for _i in range(self.unknown_flag * 2):
					self.unknown_list.append(f.get_16())
				# End If
			# End If
				
			if dat.is_lithtech_1():
				var unknown_1 = f.get_32()
				var unknown_2 = f.get_32()
				self.surface_index = f.get_32()
			elif dat.is_lithtech_2():
				self.surface_index = f.get_16()
				self.plane_index = f.get_16()
			elif dat.is_lithtech_talon():
				self.surface_index = f.get_32()
				self.plane_index = f.get_32()
				
				self.uv1 = dat.read_vector3(f)
				self.uv2 = dat.read_vector3(f)
				self.uv3 = dat.read_vector3(f)

			for _i in range(vert_count):
				# 5 bytes of usable
				#disk_verts.append(f.get_buffer(5))
				var disk_vert = WorldPoly.DiskVert.new()
				disk_vert.read(dat, f)
				disk_verts.append(disk_vert)
			# End For
			
			# Process Lightmaps
			if dat.is_lithtech_2():
				#return
				var world_model_index = dat.current_world_model_index
				
				if !(world_model_index in dat.lightmap_data.data[0].sorted_data):
					dat.current_poly_index += 1
					return
				
				var lightmap_data_list = dat.lightmap_data.data[0].sorted_data[world_model_index]
				var lightmap_data = null

				if self.lightmap_width + self.lightmap_height == 0:
					dat.current_poly_index += 1
					return
					
				for data in lightmap_data_list:
					if data.poly == dat.current_poly_index:
						lightmap_data = data
						break
						
				if lightmap_data == null:
					dat.current_poly_index += 1
					return
				
				var image = Image.new()
				
				var lm_width = self.lightmap_width
				var lm_height = self.lightmap_height
				var colour_data = lightmap_data.data

				image.create_from_data(lm_width, lm_height, false, Image.FORMAT_RGB8, colour_data)
				
				self.lightmap_texture = image
				
				image.save_png("nolf_lm.png")
			# End If
				
			dat.current_poly_index += 1
			
		# End Func
		

	# End Class
	
	class WorldNode:
		const NFI_NODE_UNDEFINED = -1
		const NFI_NODE_IN = 0
		const NFI_NODE_OUT = 1
		const NFI_ERROR = 3
		const NFI_OK = 4
		
		var index = 0
		# ?
		var index_2 = 0
		
		var poly_index = 0
		var leaf_index = 0
		
		var status = [ NFI_NODE_UNDEFINED, NFI_NODE_UNDEFINED ]
		
		# Not sure what this is used for yet, port from Pascal
		func get_node_status(index, node_count):
			if index == -1:
				return NFI_NODE_IN
			elif index == -1:
				return NFI_NODE_OUT
			elif index >= node_count:
				return NFI_ERROR
			# End If
			
			return NFI_OK
		# End Func
		
		func read(dat: DAT, f: File, node_count = 0):
			if dat.is_lithtech_1():
				var unknown_intro = f.get_32()
			# End If
			
			self.poly_index = f.get_32()
			# TODO: polygons > WorldBSP.Poly_Count
			self.leaf_index = f.get_16()
			
			self.index = f.get_32()
			self.index_2 = f.get_32()
			
			# Determine the status?
			self.status[0] = self.get_node_status(self.index, node_count)
			self.status[1] = self.get_node_status(self.index_2, node_count)
			
			if dat.is_lithtech_1():
				var unknown = dat.read_quat(f)
			# End If
		# End Func
	# End Class
	
	class WorldUserPortal:
		var name = ""
		var unk_int_1 = 0
		var unk_int_2 = 0
		var unk_short = 0
		
		var center = Vector3()
		var dims = Vector3()
		
		func read(dat: DAT, f: File):
			self.name = dat.read_string(f)
			self.unk_int_1 = f.get_32()
			
			if !dat.is_lithtech_1():
				self.unk_int_2 = f.get_32()
			# End If
			
			self.unk_short = f.get_16()
			
			self.center = dat.read_vector3(f)
			self.dims = dat.read_vector3(f)
			
			pass
		# End Func
	# End Class
	

	
	class WorldPBlockRecord:
		var size = 0
		var unk_short = 0
		var contents = []
		
		func read(dat: DAT, f: File):
			self.size = f.get_16()
			self.unk_short = f.get_16()
			
			contents = Array(f.get_buffer(6 * self.size))
		# End Func
	# End Class
	
	class WorldPBlockTable:
		# Various sizes I think!
		var unk_int_1 = 0
		var unk_int_2 = 0
		var unk_int_3 = 0
		
		var size = 0
		
		var unk_vector_1 = Vector3()
		var unk_vector_2 = Vector3()
		
		var records = []
		
		func read(dat: DAT, f: File):
			
			self.unk_int_1 = f.get_32()
			self.unk_int_2 = f.get_32()
			self.unk_int_3 = f.get_32()
			
			self.size = self.unk_int_1 * self.unk_int_2 * self.unk_int_3
			
			self.unk_vector_1 = dat.read_vector3(f)
			self.unk_vector_2 = dat.read_vector3(f)
			
			for _i in range(self.size):
				var record = WorldPBlockRecord.new()
				record.read(dat, f)
				self.records.append(record)
			# End For
			
		# End Func
	# End Class
		
	class WorldBSP:
		var world_info_flags = 0
		var world_name = ""
		
		# Geo
		var point_count = 0
		var plane_count = 0
		var surface_count = 0
		var user_portal_count = 0
		var poly_count = 0
		var leaf_count = 0
		var vert_count = 0
		var total_vis_list_size = 0
		var leaf_list_count = 0
		var node_count = 0;
		var section_count = 0
		
		var min_box = Vector3()
		var max_box = Vector3()
		var world_translation = Vector3()
		var name_length = 0
		var texture_count = 0
		
		# Lists
		var texture_names = []
		var verts = []
		var points = []
		var polies = []
		var planes = []
		var surfaces = []
		var leafs = []
		var nodes = []
		var user_portals = []
		var block_table = null
		var root_node = null
		
		func read(dat : DAT, f : File):
			var debug_ftell = f.get_position()
			
			self.world_info_flags = f.get_32()
			
			if !dat.is_lithtech_1() and !dat.is_lithtech_jupiter():
				var unknown_value = f.get_32()
			# End If
			
			self.world_name = dat.read_string(f)
			print("World Name: ",self.world_name)
			
			if dat.is_lithtech_1():
				var next_position = f.get_32()
			# End If
			
			self.point_count = f.get_32()
			self.plane_count = f.get_32()
			self.surface_count = f.get_32()
			self.user_portal_count = f.get_32()
			self.poly_count = f.get_32()
			self.leaf_count = f.get_32()
			self.vert_count = f.get_32()
			self.total_vis_list_size = f.get_32()
			self.leaf_list_count = f.get_32()
			self.node_count = f.get_32()
			
			if !dat.is_lithtech_jupiter():
				var unknown_value_2 = f.get_32()
			
			if !dat.is_lithtech_1() and !dat.is_lithtech_jupiter():
				var unknown_value_3 = f.get_32()
			# End If
			
			debug_ftell = f.get_position()
			
			self.min_box = dat.read_vector3(f)
			self.max_box = dat.read_vector3(f)
			self.world_translation = dat.read_vector3(f)
			
			debug_ftell = f.get_position()
			
			self.name_length = f.get_32()
			self.texture_count = f.get_32()
			
			# We can maybe de-class this
			for _i in range(self.texture_count):
				var texture = WorldTexture.new()
				texture.read(dat, f)
				self.texture_names.append(texture)
			# End If
			
			# Not sure why it's poly count..
			for _i in range(self.poly_count):
				var vert = f.get_8()
				if !dat.is_lithtech_jupiter():
					vert += f.get_8()
				self.verts.append(vert)
			# End For

			for _i in range(self.leaf_count):
				var leaf = WorldLeaf.new()
				leaf.read(dat, f)
				self.leafs.append(leaf)
			# End For
			
			for _i in range(self.plane_count):
				var plane = WorldPlane.new()
				plane.read(dat, f)
				self.planes.append(plane)
			# End For
			
			for _i in range(self.surface_count):
				var surface = WorldSurface.new()
				surface.read(dat, f)
				self.surfaces.append(surface)
			# End For
			
			if dat.is_lithtech_talon():
				for _i in range(self.point_count):
					self.points.append(dat.read_vector3(f))
				# End For
			# End If
			
			var biggest_lm_width = 0
			var biggest_lm_height = 0
			
			for i in range(self.poly_count):
				var poly = WorldPoly.new()
				poly.read(dat, f, self.verts[i])
				
				if poly.lightmap_width > biggest_lm_width:
					biggest_lm_width = poly.lightmap_width
				if poly.lightmap_height > biggest_lm_height:
					biggest_lm_height = poly.lightmap_height
				
				self.polies.append(poly)
			# End For
			
			for _i in range(self.node_count):
				var node = WorldNode.new()
				node.read(dat, f, self.node_count)
				self.nodes.append(node)
			# End For
			
			for _i in range(self.user_portal_count):
				var portal = WorldUserPortal.new()
				portal.read(dat, f)
				self.user_portals.append(portal)
			# End For
			
			if !dat.is_lithtech_talon():
				for _i in range(self.point_count):
					self.points.append(dat.read_vector3(f))
					
					if dat.is_lithtech_2():
						var normal = dat.read_vector3(f)
					# End If
				# End For
			# End If
			
			var debug_ftell2 = f.get_position()
			
			if !dat.is_lithtech_jupiter():
				self.block_table = WorldPBlockTable.new()
				self.block_table.read(dat, f)
			
			self.root_node = WorldNode.new()
			self.root_node.index = f.get_32()
			self.root_node.status = self.root_node.get_node_status(self.root_node.index, self.node_count)
			
			# Increment the current world model index
			dat.current_world_model_index += 1
			dat.current_poly_index = 0
			
			if !dat.is_lithtech_1():
				self.section_count = f.get_32()
				if self.section_count > 0:
					print("WorldModel has terrain sections > 0!")
			else:
				# Some additional polygons and lightmap data!
				var unknown_count = f.get_32()
				
				var polygon_list = []
				for _i in range(self.poly_count):
					polygon_list.append(dat.read_vector3(f))
				# End For
				
				var lightmap_count = f.get_32()
				#var lightmap_data = Array(f.get_buffer(lightmap_count))
				
				if lightmap_count > 0:
					
					for poly in self.polies:
						var surface = self.surfaces[poly.surface_index]
						if !(surface.flags & (1 << 7)):
							continue
						
						var image = Image.new()
						
						var lm_width = f.get_8()
						var lm_height = f.get_8()
						var colour_data = []

						for _i in range(lm_width * lm_height):
							var packed_colour = f.get_16()
							
							colour_data.append( (packed_colour & 0xF800) >> 8 )
							colour_data.append( (packed_colour & 0x07E0) >> 3 )
							colour_data.append( (packed_colour & 0x001F) << 3 )
					
						
						image.create_from_data(lm_width, lm_height, false, Image.FORMAT_RGB8, colour_data)
						
						poly.lightmap_texture = image
						#image.save_png("./lm.png")
			# End If

			pass
			
		# End Func
	# End Class
		
	class WorldLightmapFrame:
		var world_model_index = 0
		var poly_index = 0
		
		func read(dat : DAT, f : File):
			self.world_model_index = f.get_16()
			self.poly_index = f.get_16()
		# End Func
	# End Class
	
	class WorldLightmapBatch:
		var size = 0
		var data = []
		
		
		
		# TODO: Decompress via DecompressLMData
		func decompress_data(f : File):
			var current_position = 0
			var safety_break = 1024 # ?
			var colour_data = []

			while current_position < self.size:
				var copy_count = 0
				var tag = f.get_16()
				current_position += 2

				if tag & 0x8000:
					copy_count = f.get_8()
					tag = tag & 0x7FFF
					current_position += 1
				else:
					copy_count = 1
				# End If

				safety_break -= copy_count
				if safety_break < 0:
					print("[Decompress Data] LM Data over-read detected!")
					break
				# End If

				for _i in range(copy_count):

					# Unpack RGB565
					var r = (tag >> 10) & 0x001F
					var g = (tag >> 5) & 0x001F
					var b = (tag) & 0x001F
					
					#r = max(0x1f, r)
					#g = max(0x1f, g)
					#b = max(0x1f, b)
					
					#r *= 16
					#g *= 16
					#b *= 16
					
					# 
					colour_data.append( r )
					colour_data.append( g )
					colour_data.append( b )
				# End For
			# End While

			self.data = colour_data
			var pos = f.get_position()
			
			var hello = true
		# End Func
		
		func read(dat : DAT, f : File, type):
			if dat.is_lithtech_2():
				self.size = f.get_32()
			else:
				self.size = f.get_16()
				
			if type > 0:
				var data = Array(f.get_buffer(self.size))
			else:
				self.decompress_data(f)
			
			var hello = true
				
			#self.data = Array(f.get_buffer(self.size))
		# End Func
	# End Class
	
	class WorldLightmapColour:
		var vertex_count = 0
		var r = []
		var g = []
		var b = []
		
		func read(dat : DAT, f : File):
			self.vertex_count = f.get_8()
			self.r = Array(f.get_buffer(self.vertex_count))
			self.g = Array(f.get_buffer(self.vertex_count))
			self.b = Array(f.get_buffer(self.vertex_count))
		# End Func
	# End Class
	
	class WorldLightmapData:
		var name = ""
		var type = 0
		var batch_count = 0
		var frame_count = 0
		
		var frames = []
		var batches = []
		var colours = []
		
		var sorted_data = {}
		
		func read(dat : DAT, f : File):
			self.name = dat.read_string(f)
			self.type = f.get_32()
			
			if dat.is_lithtech_2():
				self.batch_count = f.get_32()
				self.frame_count = f.get_32()
			else:
				self.batch_count = f.get_8()
				self.frame_count = f.get_16()
			
			for _i in range(self.frame_count):
				var frame = WorldLightmapFrame.new()
				frame.read(dat, f)
				self.frames.append(frame)
				
				if frame.world_model_index in sorted_data:
					self.sorted_data[frame.world_model_index].append({ "poly": frame.poly_index, "data": [] })
				else:
					self.sorted_data[frame.world_model_index] = [ { "poly": frame.poly_index, "data": [] } ]
				# End If
			# End For
			
			var frame_index = 0
			
			for _i in range(self.frame_count):
				var batch = WorldLightmapBatch.new()
				batch.read(dat, f, type)
				self.batches.append(batch)
				
				var model_index = self.frames[frame_index].world_model_index
				
				for i in range(len(self.sorted_data[model_index])):
					if self.frames[frame_index].poly_index == self.sorted_data[model_index][i].poly:
						self.sorted_data[model_index][i].data = batch.data
						break
					# End If
				# End For
				
				
				frame_index += 1
			# End For
			
			if dat.is_lithtech_2():
				
				
				
				return
			
			for _i in range(self.frame_count):
				var colour = WorldLightmapColour.new()
				colour.read(dat, f)
				self.colours.append(colour)
			# End For
		# End Func
	# End Class
	
	class WorldLightMaps:
		var total_frames_1 = 0
		var total_animations = 0
		var total_memory = 0
		var total_frames_2 = 0
		var count = 0
		
		var data = []
		
		func read(dat : DAT, f : File):
			self.total_frames_1 = f.get_32()
			self.total_animations = f.get_32()
			self.total_memory = f.get_32()
			self.total_frames_2 = f.get_32()
			self.count = f.get_32()
			
			for _i in range(self.count):
				var item = WorldLightmapData.new()
				item.read(dat, f)
				data.append(item)
			# End For
		# End Func
	# End Class
	
	class ObjectProperty:
		# Codes
		const PROP_STRING	= 0
		const PROP_VECTOR	= 1
		const PROP_COLOUR	= 2
		const PROP_FLOAT	= 3
		const PROP_FLAGS	= 4
		const PROP_BOOL		= 5
		const PROP_LONG_INT = 6
		const PROP_ROTATION	= 7
		
		const PROP_UNK_INT = 9
		
		var name = ""
		var code = 0
		var data_length = 0
		var flags = 0
		
		# Value is based off of code!
		var value = null
		
		func read(dat : DAT, f : File):
			self.name = dat.read_string(f)
			self.code = f.get_8()
			self.flags = f.get_32()
			self.data_length = f.get_16()
			
			if self.code > 7:
				print("Unk!")
			
			if self.code == PROP_STRING:
				self.value = dat.read_string(f)
			elif self.code == PROP_VECTOR or self.code == PROP_COLOUR:
				self.value = dat.read_vector3(f)
			elif self.code == PROP_FLOAT:
				self.value = f.get_float()
			elif self.code == PROP_BOOL:
				self.value = f.get_8()
			elif self.code == PROP_FLAGS or self.code == PROP_LONG_INT or self.code == PROP_UNK_INT:
				self.value = f.get_32()
			elif self.code == PROP_ROTATION:
				self.value = dat.read_quat(f)
			# End If
		# End Func
		
		
		func get_lta_property_data():
			if self.code == PROP_STRING:
				return [ 'string', self.name, self.value ]
			if self.code == PROP_VECTOR:
				return [ 'vector', self.name, '___vector', self.value ]
			if self.code == PROP_COLOUR:
				return [ 'color', self.name, '___vector', self.value ]
			elif self.code == PROP_FLOAT:
				return [ 'real', self.name, self.value ]
			elif self.code == PROP_BOOL:
				return [ 'bool', self.name, int(self.value) ]
			elif self.code == PROP_FLAGS:
				# TODO: Figure out flags! For now we ignore it...
				return null
			elif self.code == PROP_LONG_INT:
				return [ 'longint', self.name, self.value ]
			elif self.code == PROP_ROTATION:
				return [ 'rotation', self.name, '___eulerangles', self.value.get_euler() ]
			# End If
		# End Func
	# End Class

	class WorldObject:
		var data_length = 0
		var name = ""
		var property_count = 0
		var properties = []
		
		func read(dat : DAT, f : File):
			self.data_length = f.get_16()
			self.name = dat.read_string(f)
			self.property_count = f.get_32()
			
			for _i in range(property_count):
				var property = ObjectProperty.new()
				property.read(dat, f)
				self.properties.append(property)
			# End For
		# End Func
	# End Class
		

	class WorldObjectHeader:
		var count = 0
		var world_objects = []
		
		func read(dat : DAT, f : File):
			self.count = f.get_32()
			
			for _i in range(self.count):
				var world_object = WorldObject.new()
				world_object.read(dat, f)
				world_objects.append(world_object)
			# End For
		# End Func
	# End Class

	class RenderData:
		# Jupiter only!
		var render_block_count = 0
		var render_blocks = []
		
		# Missing: SkyPortals, Occulders, LightGroups
		# We don't need 'em right now!
		
		class RenderSection:
			var textures = []
			var shader_code = 0
			var triangle_count = 0
			var texture_effect = ""
			var lightmap_width
			var lightmap_height
			var lightmap_size
			var lightmap_data = []
			
			func read(dat : DAT, f : File):
				self.textures = [
					dat.read_string(f),
					dat.read_string(f)
				]
				
				self.shader_code = f.get_8()
				self.triangle_count = f.get_32()
				self.texture_effect = dat.read_string(f)
				self.lightmap_width = f.get_32()
				self.lightmap_height = f.get_32()
				self.lightmap_size = f.get_32()
				self.lightmap_data = f.get_buffer(self.lightmap_size)
		
		class RenderVertex:
			var pos = Vector3()
			var uv1 = Vector2()
			var uv2 = Vector2()
			var colour = 0 # Packed colour!
			var normal = Vector3()
			
			func read(dat : DAT, f : File):
				self.pos = dat.read_vector3(f)
				self.uv1 = dat.read_vector2(f)
				self.uv2 = dat.read_vector2(f)
				self.colour = f.get_32()
				self.normal = dat.read_vector3(f)
		
		class RenderTriangle:
			var index0 = 0
			var index1 = 0
			var index2 = 0
			var poly_index = 0
			
			var render_vertices = []
			
			func read(dat : DAT, f : File, block : RenderBlock):
				self.index0 = f.get_32()
				self.index1 = f.get_32()
				self.index2 = f.get_32()
				self.poly_index = f.get_32()
				
				# Fill out some references
				self.render_vertices = [
					block.vertices[self.index0],
					block.vertices[self.index1],
					block.vertices[self.index2],
				]

		class RenderBlock:
			var center = Vector3()
			var half_dims = Vector3()
			var section_count = 0
			var vertex_count = 0
			var triangle_count = 0
			
			var sections = []
			var vertices = []
			var triangles = []
			
			func read(dat : DAT, f : File):
				self.center = dat.read_vector3(f)
				self.half_dims = dat.read_vector3(f)
				
				self.section_count = f.get_32()
				for i in range(self.section_count):
					var section = RenderSection.new()
					section.read(dat, f)
					self.sections.append(section)
				
				self.vertex_count = f.get_32()
				for i in range(self.vertex_count):
					var vertex = RenderVertex.new()
					vertex.read(dat, f)
					self.vertices.append(vertex)
				
				self.triangle_count = f.get_32()
				for i in range(self.triangle_count):
					var triangle = RenderTriangle.new()
					triangle.read(dat, f, self)
					self.triangles.append(triangle)
				
				pass
			# End Func
			
		func read(dat : DAT, f : File):
			self.render_block_count = f.get_32()
			for i in range(self.render_block_count):
				var block = RenderBlock.new()
				block.read(dat, f)
				self.render_blocks.append(block)
	# End Class
