extends Node2D

@onready var curved_arrow_2d: CurvedArrow2D = $CurvedArrow2D
@onready var child_curved_arrow: CurvedArrow2D = $Polygon2D/ChildCurvedArrow2D
@onready var arrow_follow_mouse_button: Button = $ArrowFollowMouseButton

var _arrow_follow_mouse: CurvedArrow2D = null

func _input(event: InputEvent) -> void:
    if not _arrow_follow_mouse: return

    # moving mouse? follow that mouse!
    if event is InputEventMouseMotion:
        _arrow_follow_mouse.end_pos = event.position
        _arrow_follow_mouse.queue_redraw()

    # on click, deselect arrow
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        _arrow_follow_mouse = null


func _on_arrow_follow_mouse_button_pressed() -> void:
    _arrow_follow_mouse = curved_arrow_2d


func _on_child_arrow_follow_mouse_button_pressed() -> void:
    _arrow_follow_mouse = child_curved_arrow
