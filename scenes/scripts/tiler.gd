extends Node
class_name Tiler

# TODO - This is somehow completely broken. Not sure if I'm smart enough to add this as a feature.
# TODO - Will continue working on this...

# --- Utility functions ---

func _premultiply(c: Color) -> Color:
	return Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a)

func _unpremultiply(c: Color) -> Color:
	if c.a <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(c.r / c.a, c.g / c.a, c.b / c.a, c.a)

func _blend_weight(width: int, height: int, x: int, y: int) -> float:
	var a := 0.0
	var b := 0.0
	if width > 1:
		a = (abs(x - width) - 1.0) / float(width - 1)
	if height > 1:
		b = (abs(y - height) - 1.0) / float(height - 1)

	var w := 1.0
	if a < 1e-8 and b > 0.99999999:
		w = 1.0
	elif a > 0.99999999 and b < 1e-8:
		w = 0.0
	else:
		var denom = a * b + (1.0 - a) * (1.0 - b)
		if denom != 0.0:
			w = 1.0 - (a * b) / denom
	return w


# --- Pixel welding ---

func _weld_pixel(image: Image, x1: int, y1: int, x2: int, y2: int, width: int, height: int, col: int, row: int, asym_corr: int, has_alpha: bool) -> void:
	var sx1 := x1 + col
	var sy1 := y1 + row
	var sx2 := x2 + col
	var sy2 := y1 + height + row

	var c1 := image.get_pixelv(Vector2i(sx1, sy1))
	var c2 := image.get_pixelv(Vector2i(sx2, sy2))
	var w := _blend_weight(width, height, col + asym_corr, row)

	if has_alpha:
		var pm1 := _premultiply(c1)
		var pm2 := _premultiply(c2)
		var alpha := w * c1.a + (1.0 - w) * c2.a
		var out_c: Color
		if alpha > 0.0:
			var r = (w * pm1.r + (1.0 - w) * pm2.r) / alpha
			var g = (w * pm1.g + (1.0 - w) * pm2.g) / alpha
			var b = (w * pm1.b + (1.0 - w) * pm2.b) / alpha
			out_c = Color(r, g, b, alpha)
		else:
			out_c = Color(0, 0, 0, 0)
		image.set_pixelv(Vector2i(sx1, sy1), out_c)
		image.set_pixelv(Vector2i(sx2, sy2), out_c)
	else:
		var out_c = Color(
			w * c1.r + (1.0 - w) * c2.r,
			w * c1.g + (1.0 - w) * c2.g,
			w * c1.b + (1.0 - w) * c2.b,
			w * c1.a + (1.0 - w) * c2.a
		)
		image.set_pixelv(Vector2i(sx1, sy1), out_c)
		image.set_pixelv(Vector2i(sx2, sy2), out_c)


# --- Region operations ---

func _copy_region(image: Image, x: int, y: int, w: int, h: int) -> void:
	var tmp: Array[Color] = []
	tmp.resize(w * h)
	var i := 0
	for row in h:
		for col in w:
			tmp[i] = image.get_pixel(x + col, y + row)
			i += 1

	i = 0
	for row in h:
		for col in w:
			image.set_pixel(x + col, y + row, tmp[i])
			i += 1


func _tile_region(image: Image, left: bool, x1: int, y1: int, x2: int, y2: int, has_alpha: bool) -> void:
	var width := x2 - x1
	var height := y2 - y1

	var wodd := width & 1
	var hodd := height & 1
	var w := width / 2
	var h := height / 2

	var rgn1_x := 0
	var rgn2_x := 0
	if left:
		rgn1_x = x1
		rgn2_x = x1 + w + wodd
	else:
		rgn1_x = x1 + w + wodd
		rgn2_x = x1

	var asym_corr := (not bool(wodd)) and (not left)

	for row in h:
		for col in w:
			_weld_pixel(image, rgn1_x, y1, rgn2_x, y1, w, h, col, row, asym_corr, has_alpha)


# --- Main entry point ---

func make_seamless(original: Image) -> Image:
	if original.is_empty():
		return original

	var image := original.duplicate()
	#image.lock()

	var width = image.get_width()
	var height = image.get_height()
	var x1 := 0
	var y1 := 0
	var x2 = width
	var y2 = height
	var has_alpha = image.is_using_alpha()

	# Copy middle column/row if odd
	if (width & 1) != 0:
		_copy_region(image, x1 + width / 2, y1, 1, height)

	if (height & 1) != 0:
		_copy_region(image, x1, y1 + height / 2, width, 1)

	# Process left and right halves
	_tile_region(image, true, x1, y1, x2, y2, has_alpha)
	_tile_region(image, false, x1, y1, x2, y2, has_alpha)

	image.unlock()
	return image
