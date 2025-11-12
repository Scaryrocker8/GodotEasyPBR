extends Control
class_name Main

@export_category("Components")
@export var drag_and_drop_label: Label
@export var images_container: CenterContainer
@export var new_image_container: MarginContainer
@export_category("Viewport")
@export var export_viewport: SubViewport
@export_category("Image Size")
@export var image_size_container: MarginContainer
@export var image_size_button: Button
@export_category("Albedo")
@export var albedo_rect: TextureRect
@export var tiler: Node
@export var albedo_tile_seamless_button: Button
@export var albedo_download_button: Button
@export_category("Normal")
@export var normal_rect: TextureRect
@export var bump_slider: HSlider
@export var normal_download_button: Button
@export_category("Roughness")
@export var roughness_rect: TextureRect
@export var roughness_download_button: Button

@onready var exe_dir : String = OS.get_executable_path().get_base_dir()
@onready var save_dir : String = exe_dir.path_join("textures_output")

var image_loaded: bool = false
var tile_seamless: bool = false
var normal_inverted: bool = false
var roughness_inverted: bool = false

var image_size: int = 512

var image_name: String

var original_texture: ImageTexture

func _ready():
	# Connect viewport files dropped signal.
	get_viewport().files_dropped.connect(on_files_dropped)
	# Initialize starting screen.
	drag_and_drop_label.visible = true
	images_container.visible = false
	new_image_container.visible = false
	image_size_container.visible = false

func _input(event: InputEvent) -> void:
	# Handle quitting.
	if event.is_action_pressed("quit"):
		get_tree().quit()

#region File Dropping

# When file is dropped into window.
func on_files_dropped(files):
   # Check if image is loaded and only 1 file is provided.
	if !image_loaded and files.size() == 1:
		# Create variable that holds path to dropped file.
		var path = files[0]

		# Get name of file that was dropped.
		image_name = files[0].get_basename().get_file()

		# Create a new image and set image to path of dropped file.
		var image = Image.new()
		image.load(path)
		
		# Create a new image texture and set it's image to the dropped file.
		var texture = ImageTexture.new()
		texture.set_image(image)

		# Save copy of original texture
		original_texture = texture
		
		# Load image of dropped file.
		_load_image(texture)

		#! Debug image name and path of dropped file.
		print(image_name)
		print(files)

#region Image Functions

func _load_image(texture: ImageTexture) -> void:
   # Hide drag and drop label and show image maps.
	drag_and_drop_label.visible = false
	images_container.visible = true
	new_image_container.visible = true
	image_size_container.visible = true

   # Load textures.
	albedo_rect.texture = texture
	normal_rect.texture = texture
	roughness_rect.texture = texture

   # Set image loaded
	image_loaded = true

func _save_image(texture_type: String, texture_rect: TextureRect) -> void:
	# If there is no textures_output directory, create one!
	var dir = DirAccess.open(exe_dir)
	if not DirAccess.dir_exists_absolute(save_dir):
		var err = dir.make_dir(save_dir)
		if err != OK:
			push_error("Failed to create directory: " + str(err))
		else:
			print("Created folder:", save_dir)

	var file_path = save_dir.path_join(image_name + "_" + texture_type + ".png")

	#! NOTE - In Godot debug mode this will fail to create a directory (at least when tested on linux)
	#! The engine assumes the executable is in usr/bin, which can't be accessed.
	#! The final build executable will create a working directory next to it for any images saved.

	# If there is still an image left over in the viewport, clear it.
	if export_viewport.get_child_count() != 0:
		export_viewport.get_child(0).queue_free()
	# Duplicate the texture rect to viewport
	var export_image = texture_rect.duplicate(true)
	export_viewport.add_child(export_image)
	# Set viewport and image to desired image size
	export_viewport.size = Vector2i(image_size, image_size)
	export_image.custom_minimum_size = Vector2i(image_size, image_size)
	# Await frame post draw for export viewport
	await RenderingServer.frame_post_draw
	# Export to textures_output folder
	export_viewport.get_texture().get_image().save_png(file_path)

func _new_image() -> void:
	# Initialize for a new image.
	drag_and_drop_label.visible = true
	images_container.visible = false
	new_image_container.visible = false
	image_size_container.visible = false

	# Reset Inverts
	normal_rect.get_material().set_shader_parameter("invertX", false)
	normal_rect.get_material().set_shader_parameter("invertY", false)
	normal_inverted = false

	roughness_rect.get_material().set_shader_parameter("invert", false)
	roughness_inverted = false

	# Reset bump slider
	bump_slider.value = 0.1

	# Reset download button texts
	albedo_download_button.text = "Download"
	normal_download_button.text = "Download"
	roughness_download_button.text = "Download"

   # Set image unloaded.
	image_loaded = false


#region Button and Slider Presses

# Image Size
func _on_image_size_button_pressed() -> void:
	# Change image size.
	match image_size:
		64:
			image_size = 128
			image_size_button.text = "Image Size: 128x128"
		128:
			image_size = 256
			image_size_button.text = "Image Size: 256x256"
		256:
			image_size = 512
			image_size_button.text = "Image Size: 512x512"
		512:
			image_size = 1024
			image_size_button.text = "Image Size: 1024x1024"
		1024:
			image_size = 2048
			image_size_button.text = "Image Size: 2048x2048"
		2048:
			image_size = 4096
			image_size_button.text = "Image Size: 4096x4096"
		4096:
			image_size = 64
			image_size_button.text = "Image Size: 64x64"

# Albedo Tile Seamless
# TODO - need to add this as a feature at some point...
#func _on_albedo_tile_seamless_button_pressed() -> void:
#	if !tile_seamless:
#		# Change font to green for enabled.
#		albedo_tile_seamless_button.add_theme_color_override("font_color", Color.GREEN)
#		albedo_tile_seamless_button.add_theme_color_override("font_focus_color", Color.GREEN)
#		# Create a seamless image and image texture
#		var seamless_image : Image = original_texture.get_image()
#		tiler.make_seamless(seamless_image)
#		var seamless_texture : ImageTexture = ImageTexture.new()
#		# Set texture map textures as new seamless texture.
#		albedo_rect.texture = seamless_texture
#		normal_rect.texture = seamless_texture
#		roughness_rect.texture = seamless_texture
#		# Set tile seamless boolean.
#		tile_seamless = true
#	else:
#		# Change font back to black.
#		albedo_tile_seamless_button.add_theme_color_override("font_color", Color.BLACK)
#		albedo_tile_seamless_button.add_theme_color_override("font_focus_color", Color.BLACK)
#		# Change texture maps back to original albedo texture
#		albedo_rect.texture = original_texture
#		normal_rect.texture = original_texture
#		roughness_rect.texture = original_texture
#		tile_seamless = false

# Albedo Download
func _on_albedo_download_button_pressed() -> void:
	_save_image("albedo", albedo_rect)
	albedo_download_button.text = "Saved!"

# Normal Invertation
func _on_normal_invert_button_pressed() -> void:
	if !normal_inverted:
		normal_rect.get_material().set_shader_parameter("invertX", true)
		normal_rect.get_material().set_shader_parameter("invertY", true)
		normal_inverted = true
	else:
		normal_rect.get_material().set_shader_parameter("invertX", false)
		normal_rect.get_material().set_shader_parameter("invertY", false)
		normal_inverted = false

# Normal Bump Slider
func _on_bump_slider_value_changed(value: float) -> void:
	normal_rect.get_material().set_shader_parameter("emboss_height", value)

# Normal Download
func _on_normal_download_button_pressed() -> void:
	_save_image("normal", normal_rect)
	normal_download_button.text = "Saved!"

# Roughness Invertation
func _on_roughness_invert_button_pressed() -> void:
	if !roughness_inverted:
		roughness_rect.get_material().set_shader_parameter("invert", true)
		roughness_inverted = true
	else:
		roughness_rect.get_material().set_shader_parameter("invert", false)
		roughness_inverted = false

# Roughness Download
func _on_roughness_download_button_pressed() -> void:
	_save_image("roughness", roughness_rect)
	roughness_download_button.text = "Saved!"

# New Image Button
func _on_new_image_button_pressed() -> void:
   # Ready for new image.
	_new_image()
