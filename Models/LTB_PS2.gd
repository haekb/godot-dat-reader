extends Node

class LTB_PS2:
	
	# Versioning
	const LTB_PS2_VERSION_NOLF = 66
	const DAT_VERSION_NOLF = 66
	
	const PLATFORM = "PS2"
	
	# Header
	var version = 0
	var object_data_pos = 0
	var render_data_pos = 0
	
	# World Info
	var world_info = null
	
	# World Tree
	var world_tree = null
	
	# World Models
	var world_model_count = 0
	var world_models = []
	
	# Render Data
	var lightmap_data = null
	
	# Level texture list
	var texture_list = []
	
	var world_object_data = null
	
	func _init():
		pass
	# End Func
	
	# v56 and v57/v127 are pretty similar
	func is_lithtech_1(include_15 = true, include_psycho = true):
		return false
		
	func is_lithtech_15(include_psycho = true):
		return false
	
	func is_lithtech_psycho():
		return false
	# End If
	
	func is_lithtech_2():
		return false
	# End If
	
	func is_lithtech_talon():
		return false
	# End If
	
	enum IMPORT_RETURN{SUCCESS, PARTIAL, ERROR}
	
	func read(f : File, dont_import_world_models = false):
		
		self.version = f.get_32()
		
		print("LTB_PS2 Version: %d" % self.version)
				
		if [LTB_PS2_VERSION_NOLF].has(self.version) == false:
			return self._make_response(IMPORT_RETURN.ERROR, 'Unsupported file version (%d)' % self.version)
				
		
		self.object_data_pos = f.get_32()
		self.render_data_pos = f.get_32()
		
		# Skip 8 dummy ints
		f.seek(f.get_position() + 8 * 4)
		
		self.world_info = WorldInfo.new()
		self.world_info.read(self, f)
		
		print("Props: " , self.world_info.properties)
		print("Position: ",f.get_position())
		
		self.world_tree = WorldTree.new()
		self.world_tree.read(self, f)
		
		# Save the world model position, and let's read some lightmaps!
		var world_model_pos = f.get_position()
#		f.seek(self.render_data_pos)
#
#		self.lightmap_data = WorldLightMaps.new()
#		self.lightmap_data.read(self, f)
#
#		# Okay back to world models
#		f.seek(world_model_pos)

		f.seek(self.object_data_pos)
		
		world_object_data = WorldObjectHeader.new()
		world_object_data.read(self, f)
		
		# Okay back to world models
		f.seek(world_model_pos)

		var texture_count = f.get_32()
		var texture_size = f.get_32()
		
		# Read in all the textures used in this level
		for _i in range(texture_count):
			self.texture_list.append(self.read_string(f))
		
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
			var debug_ftell = f.get_position()
			var next_world_model_pos = f.get_32()

			var world_bsp = WorldBSP.new()
			world_bsp.read(self, f)
			
			#if world_bsp.section_count > 0:
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
		
		func read(ltb : LTB_PS2, f : File):
			self.properties = ltb.read_string(f, false)
			self.light_map_grid_size = f.get_float()
			self.extents_min = ltb.read_vector3(f)
			self.extents_max = ltb.read_vector3(f)
		# End Func
	
	class WorldTree:
		var root_node = null
		
		func read(ltb : LTB_PS2, f : File):
			
			var node = WorldTreeNode.new()
			node.read(ltb, f)
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
		
		func read(ltb : LTB_PS2, f : File):
			self.box_min = ltb.read_vector3(f)
			self.box_max = ltb.read_vector3(f)
			self.child_node_count = f.get_32()
			self.dummy_terrain_depth = f.get_32()
			
			# Left over from pascal port
			self.set_bounding_box(self.box_min, self.box_max)
			
			self.read_layout(f, 0, 8, 0)
		# End Func
		
		pass
		
	# To keep compat
	class WorldTexture:
		var name = ""
	# End Class
	
	class WorldPlane:
		var normal = Vector3()
		var distance = 0.0
		
		func read(ltb: LTB_PS2, f : File):
			self.normal = ltb.read_vector3(f)
			self.distance = f.get_float()
		# End Func
	# End Class
	
	class WorldLeaf:
		
		class LeafData:
			var portal_id = 0
			var size = 0
			var contents = []
			
			func read(ltb: LTB_PS2, f : File):
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
		
		func read(ltb: LTB_PS2, f : File):
			self.count = f.get_16()
			
			if self.count == 0xFFFF:
				self.index = f.get_16()
			else:
				for i in range(self.count):
					var leaf_data = WorldLeaf.LeafData.new()
					leaf_data.read(ltb, f)
					data.append(leaf_data)
				# End For
			# End If
				
			self.polygon_count = f.get_32()
			self.polygon_data = f.get_buffer(self.polygon_count * 4)
			
			self.unk_1 = f.get_32()
		# End Func
	# End Class
	
	class WorldSurface:
		var uv1 = Vector3()
		var uv2 = Vector3()
		var uv3 = Vector3()
		
		
		var unknown = 0
		var unknown2 = 0
		
		var texture_flags = 0
		var texture_index = 0
		var flags = 0
		var use_effects = 0
		var effect_name = ""
		var effect_param = ""
		
		var start_index = 0
		
		func read(ltb: LTB_PS2, f : File):
			self.uv1 = ltb.read_vector3(f)
			self.uv2 = ltb.read_vector3(f)
			self.uv3 = ltb.read_vector3(f)
			
			#self.texture_index = f.get_16()
			self.start_index = f.get_32()
			
			self.flags = f.get_32()

			self.texture_index = f.get_32()
			self.texture_flags = f.get_16()
			
			self.use_effects = f.get_16()
			
			if (self.use_effects == 1):
				self.effect_name = ltb.read_string(f)
				self.effect_param = ltb.read_string(f)
			# End If
			
		# End Func
	# End Class
	
	class WorldPoly:
		
		class DiskVert:
			var vertex_index = 0
			var dummy = []
			
			func read(ltb: LTB_PS2, f : File, is_packed = false):
				if is_packed == true:
					self.vertex_index = f.get_32()
					return
				# End
				
				self.vertex_index = f.get_16()	
				self.dummy = Array(f.get_buffer(2))
				
				var unknown_float_1 = f.get_float()
				var unknown_float_2 = f.get_float()
				
				var unk = f.get_float()
				
				var hack = f.get_32()
				
				if hack < 60000 or hack == 4294967295: # -1
					f.seek(f.get_position() - 4)
				
#				# Skip the next two variables...
#				f.seek(f.get_position() + 8)
#
#				# Small hack for later...
#				var hack_check = f.get_32()
#
#				# Go back three variables
#				f.seek(f.get_position() - 12)
#
#				# I cannot figure out why there's sometimes an extra float...
#				# So we just skip ahead, grab the value, and come back.
#				# If the value is over 60,000 then we can safely assume 
#				# it has the extra float
#				if hack_check < 60000:
#					var unknown_float_3 = f.get_float()
#
#				var unknown_ending = f.get_32()
			# End Func
		# End Class
		
		var center = Vector3()
		var lightmap_width = 0
		var lightmap_height = 0
		
		var unknown_flag = 0
		var unknown_list = []
		
		# I think they're indexes!
		var surface_index
		var plane_index
		
		var uv1 = Vector3()
		var uv2 = Vector3()
		var uv3 = Vector3()
		
		var disk_verts = []
		
		# hack
		var texture_index = 0
		
		var uv_offset_1 = 0.0
		var uv_offset_2 = 0.0
		
		var lightmap_texture = null
		
		func read(ltb: LTB_PS2, f: File, vert_count = 0, surfaces = [], planes = []):
			
			var unknown_1 = f.get_32()
			
			self.lightmap_width = f.get_8()
			self.lightmap_height = f.get_8()
			
			var unknown_2 = f.get_8()
			var unknown_3 = f.get_8()
			
			self.surface_index = f.get_32()
			self.plane_index = f.get_32()
			#var polygon_index = f.get_32()
			
			self.uv_offset_1 = f.get_float()
			
			self.center = ltb.read_vector3(f)
			
			self.uv_offset_2 = f.get_float() 
			
			var surface = surfaces[self.surface_index]
			
			# If it's translucent then it's packed
			var is_packed = ( (surface.flags & (1<<2)) != 0 )
			
			#if is_packed:
			self.uv1 = surface.uv1
			self.uv2 = surface.uv2
			self.uv3 = surface.uv3
			
			
			for _i in range(vert_count):
				# 5 bytes of usable
				#disk_verts.append(f.get_buffer(5))
				var disk_vert = WorldPoly.DiskVert.new()
				disk_vert.read(ltb, f, is_packed)
				disk_verts.append(disk_vert)
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
		
		func read(ltb: LTB_PS2, f: File, node_count = 0):
			
			self.poly_index = f.get_32()
			# TODO: polygons > WorldBSP.Poly_Count
			self.leaf_index = f.get_32()
			
			self.index = f.get_32()
			self.index_2 = f.get_32()
			
			# Determine the status?
			self.status[0] = self.get_node_status(self.index, node_count)
			self.status[1] = self.get_node_status(self.index_2, node_count)
		# End Func
	# End Class
	
	class WorldUserPortal:
		var name = ""
		var unk_int_1 = 0
		var unk_int_2 = 0
		var unk_short = 0
		
		var center = Vector3()
		var dims = Vector3()
		
		func read(ltb: LTB_PS2, f: File):
			self.name = ltb.read_string(f)
			self.unk_int_1 = f.get_32()
			self.unk_int_2 = f.get_32()
			self.unk_short = f.get_16()
			
			self.center = ltb.read_vector3(f)
			self.dims = ltb.read_vector3(f)
			
			pass
		# End Func
	# End Class
	

	
	class WorldPBlockRecord:
		var size = 0
		var unk_short = 0
		var contents = []
		
		func read(ltb: LTB_PS2, f: File):
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
		
		func read(ltb: LTB_PS2, f: File):
			
			self.unk_int_1 = f.get_32()
			self.unk_int_2 = f.get_32()
			self.unk_int_3 = f.get_32()
			
			self.size = self.unk_int_1 * self.unk_int_2 * self.unk_int_3
			
			self.unk_vector_1 = ltb.read_vector3(f)
			self.unk_vector_2 = ltb.read_vector3(f)
			
			var total_data_size = f.get_32()
			
			# Skip past the pblock data
			f.seek(f.get_position() + (total_data_size*6))
			
			# Read through the headers
			for _i in range(self.size):
				var padding = f.get_32()
				var data_size = f.get_16()
				var unk_1 = f.get_16()
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
		
		func read(ltb : LTB_PS2, f : File):
			self.world_name = ltb.read_string(f)
			print("World Name: ",self.world_name)
			
			self.world_info_flags = f.get_32()
			var unknown_value = f.get_32()
			
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
			
			var unknown_value_2 = f.get_32()
			var unknown_value_3 = f.get_32()
			
			self.min_box = ltb.read_vector3(f)
			self.max_box = ltb.read_vector3(f)
			self.world_translation = ltb.read_vector3(f)
			
			# ?
			self.name_length = f.get_8()
			self.texture_count = f.get_8()
			
			var unknown_4 = f.get_16()
			
			# Not sure why it's poly count..
			for _i in range(self.poly_count):
				var vert = f.get_8()
				var extra = f.get_8()
				# No clue what this value is, but it ain't extra!
				#vert += f.get_8()
				self.verts.append(vert)
			# End For

			for _i in range(self.leaf_count):
				var leaf = WorldLeaf.new()
				leaf.read(ltb, f)
				self.leafs.append(leaf)
			# End For
			
			var debug_ftell = f.get_position()
			
			for _i in range(self.plane_count):
				var plane = WorldPlane.new()
				plane.read(ltb, f)
				self.planes.append(plane)
			# End For
			
			for _i in range(self.surface_count):
				var surface = WorldSurface.new()
				surface.read(ltb, f)
				self.surfaces.append(surface)
			# End For
			
			debug_ftell = f.get_position()
			
			if debug_ftell == 3633:
				var hi = true
				hi = false
			
			for i in range(self.poly_count):
				var poly = WorldPoly.new()
				poly.read(ltb, f, self.verts[i], self.surfaces, self.planes)
				
				var surface = self.surfaces[poly.surface_index]
				var world_texture = WorldTexture.new()
				world_texture.name = ltb.texture_list[surface.texture_index]
				self.texture_names.append( world_texture )
				poly.texture_index = len(self.texture_names) -1
				
				self.polies.append(poly)
			# End For
			
			debug_ftell = f.get_position()
			
			for _i in range(self.node_count):
				var node = WorldNode.new()
				node.read(ltb, f, self.node_count)
				self.nodes.append(node)
			# End For
			
			for _i in range(self.user_portal_count):
				var portal = WorldUserPortal.new()
				portal.read(ltb, f)
				self.user_portals.append(portal)
			# End For
			
			if ltb.version == LTB_PS2_VERSION_NOLF:
				for _i in range(self.point_count):
					self.points.append(ltb.read_vector3(f))
					var one = f.get_float()
				# End For
				
			return
			
			self.block_table = WorldPBlockTable.new()
			self.block_table.read(ltb, f)
			
			self.root_node = WorldNode.new()
			self.root_node.index = f.get_32()
			self.root_node.status = self.root_node.get_node_status(self.root_node.index, self.node_count)
			
			self.section_count = f.get_32()
			if self.section_count > 0:
				print("WorldModel has terrain sections > 0!")

			
			pass
			
		# End Func
	# End Class
		
	class WorldLightmapFrame:
		var world_model_index = 0
		var poly_index = 0
		
		func read(ltb : LTB_PS2, f : File):
			self.world_model_index = f.get_16()
			self.poly_index = f.get_16()
		# End Func
	# End Class
	
	class WorldLightmapBatch:
		var size = 0
		var data = []
		
		func read(ltb : LTB_PS2, f : File):
			self.size = f.get_16()
			self.data = Array(f.get_buffer(self.size))
		# End Func
	# End Class
	
	class WorldLightmapColour:
		var vertex_count = 0
		var r = []
		var g = []
		var b = []
		
		func read(ltb : LTB_PS2, f : File):
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
		
		func read(ltb : LTB_PS2, f : File):
			self.name = ltb.read_string(f)
			self.type = f.get_32()
			self.batch_count = f.get_8()
			self.frame_count = f.get_16()
			
			for _i in range(self.frame_count):
				var frame = WorldLightmapFrame.new()
				frame.read(ltb, f)
				self.frames.append(frame)
			# End For
			
			for _i in range(self.frame_count):
				var batch = WorldLightmapBatch.new()
				batch.read(ltb, f)
				self.batches.append(batch)
			# End For
			
			for _i in range(self.frame_count):
				var colour = WorldLightmapColour.new()
				colour.read(ltb, f)
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
		
		func read(ltb : LTB_PS2, f : File):
			self.total_frames_1 = f.get_32()
			self.total_animations = f.get_32()
			self.total_memory = f.get_32()
			self.total_frames_2 = f.get_32()
			self.count = f.get_32()
			
			for _i in range(self.count):
				var item = WorldLightmapData.new()
				item.read(ltb, f)
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
		
		var name = ""
		var code = 0
		var data_length = 0
		# Not used?
		var flags = 0
		
		# Value is based off of code!
		var value = null
		
		func read(ltb : LTB_PS2, string_list, f : File):
			var name_index = f.get_32()
			self.name = string_list[name_index]
			self.code = f.get_8()
			self.data_length = f.get_16()
			
			if self.code == PROP_STRING:
				var index = f.get_32()
				self.value = string_list[index]
			elif self.code == PROP_VECTOR or self.code == PROP_COLOUR:
				self.value = ltb.read_vector3(f)
			elif self.code == PROP_FLOAT:
				self.value = f.get_float()
			elif self.code == PROP_BOOL:
				self.value = f.get_8()
			elif self.code == PROP_FLAGS or self.code == PROP_LONG_INT:
				self.value = f.get_32()
				
				# For some reason they have floating point data in longint?
				# Fix it manually...
				if self.value == 1065353216:
					self.value = 1
				
			elif self.code == PROP_ROTATION:
				self.value = ltb.read_vector3(f)
				var dummy = f.get_float()
				if dummy > 0:
					print("Uh-oh!")
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
				var eulers = Vector3(self.value.x, self.value.y, self.value.z)

				return [ 'rotation', self.name, '___eulerangles', eulers ]
			# End If
		# End Func
	# End Class

	class WorldObject:
		var data_length = 0
		var name = ""
		var property_count = 0
		var properties = []
		
		func read(ltb : LTB_PS2, string_list, f : File):
			self.data_length = f.get_16()
			var name_index = f.get_32()
			self.name = string_list[name_index]
			self.property_count = f.get_32()
			
			for _i in range(property_count):
				var property = ObjectProperty.new()
				property.read(ltb, string_list, f)
				self.properties.append(property)
			# End For
		# End Func
	# End Class
		

	class WorldObjectHeader:
		var count = 0
		var string_count = 0
		var string_list = []
		var world_objects = []
		
		func read(ltb : LTB_PS2, f : File):
			self.count = f.get_32()
			self.string_count = f.get_32()
			var unk_2 = f.get_32()
			var unk_3 = f.get_32()
			var unk_4 = f.get_32()
			var unk_5 = f.get_16()
			var unk_6 = f.get_16()
			
			for _i in range(self.string_count):
				self.string_list.append(ltb.read_string(f))
			# End For
			
			for _i in range(self.count):
				var world_object = WorldObject.new()
				world_object.read(ltb, self.string_list, f)
				world_objects.append(world_object)
			# End For
		# End Func
	# End Class
