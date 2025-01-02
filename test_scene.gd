extends Node2D

@onready var curved_arrow_2d: CurvedArrow2D = $CurvedArrow2D
@onready var child_curved_arrow: CurvedArrow2D = $PolygonBackground/ChildCurvedArrow2D
@onready var spriteA: Sprite2D = $SpriteBackground/SpriteA
@onready var spriteB: Sprite2D = $SpriteBackground/SpriteB

var _arrow_follow_mouse: CurvedArrow2D = null
var _sprite_a_to_b_arrow: CurvedArrow2D
var _sprite_b_to_a_arrow: CurvedArrow2D

func _input(event: InputEvent) -> void:
    if not _arrow_follow_mouse: return

    # moving mouse? follow that mouse!
    if event is InputEventMouseMotion:
        _arrow_follow_mouse.global_end_position = event.position
        _arrow_follow_mouse.queue_redraw()

    # on click, deselect arrow
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        _arrow_follow_mouse = null


func _on_arrow_follow_mouse_button_pressed() -> void:
    _arrow_follow_mouse = curved_arrow_2d


func _on_child_arrow_follow_mouse_button_pressed() -> void:
    _arrow_follow_mouse = child_curved_arrow


func _on_arrow_ato_b_button_pressed() -> void:
    if _sprite_a_to_b_arrow:
        _sprite_a_to_b_arrow.queue_free()
        _sprite_a_to_b_arrow = null
    else:
        _sprite_a_to_b_arrow = CurvedArrow2D.new()
        add_child(_sprite_a_to_b_arrow)
        _sprite_a_to_b_arrow.set_positions(spriteA.global_position, spriteB.global_position)
        _sprite_a_to_b_arrow.color = Color.DARK_RED


func _on_arrow_bto_a_button_pressed() -> void:
    if _sprite_b_to_a_arrow:
        _sprite_b_to_a_arrow.queue_free()
        _sprite_b_to_a_arrow = null
    else:
        _sprite_b_to_a_arrow = CurvedArrow2D.new()
        add_child(_sprite_b_to_a_arrow)
        _sprite_b_to_a_arrow.set_positions(spriteB.global_position, spriteA.global_position)
        _sprite_b_to_a_arrow.color = Color.DARK_BLUE