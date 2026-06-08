extends Node

func get_card_stylebox() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Palette.BG_WARM_WHITE
	s.border_color = Palette.BORDER_DEFAULT
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(16)
	return s

func get_modal_stylebox() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Palette.BG_WARM_WHITE
	s.border_color = Palette.BORDER_DEFAULT
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(20)
	return s

func get_button_primary() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Palette.AMBER
	s.set_corner_radius_all(8)
	s.set_content_margin_all(12)
	return s

func get_button_secondary() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.border_color = Palette.AMBER
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(12)
	return s
