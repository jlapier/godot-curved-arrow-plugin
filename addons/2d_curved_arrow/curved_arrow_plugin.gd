@tool
extends EditorPlugin

var _selected_node: Node2D = null
var dragging_handle: int = -1  # -1 = none, 0 = start, 1 = end
var _end_handle_pos: Vector2 = Vector2.ZERO
var _transform_to_view: Transform2D
var _transform_to_base: Transform2D

func _enter_tree() -> void:
    add_custom_type("CurvedArrow2D", "Node2D", preload("res://addons/2d_curved_arrow/curved_arrow_2d.gd"), null)

func _exit_tree() -> void:
    remove_custom_type("CurvedArrow2D")

func _handles(object) -> bool:
    return object is CurvedArrow2D  # Use the actual class name

func _edit(object) -> void:
    _selected_node = object

func _make_visible(visible: bool) -> void:
    if not visible:
        _selected_node = null

func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
    if !_selected_node or !_selected_node is CurvedArrow2D:
        return

    _update_transforms()

    var pos_scale = _transform_to_view.get_scale()
    _end_handle_pos = _transform_to_view.get_origin() + _selected_node.end_pos * pos_scale
    viewport_control.draw_circle(_end_handle_pos, 15, Color.GREEN)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
    if !_selected_node or !_selected_node is CurvedArrow2D:
        return false

    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                # var mouse_pos = transform.affine_inverse() * event.position
                var mouse_pos = event.position
                if mouse_pos.distance_to(_selected_node.start_pos) < 10:
                    dragging_handle = 0
                    return true
                elif mouse_pos.distance_to(_end_handle_pos) < 20:
                    dragging_handle = 1
                    return true
            else:
                dragging_handle = -1

    elif event is InputEventMouseMotion:
        if dragging_handle >= 0:
            # math this
            var mouse_pos = event.position
            if dragging_handle == 0:
                _selected_node.start_pos = mouse_pos
            else:
                _selected_node.end_pos = _transform_to_base * event.position
            return true

    return false


## Get transform of parent node of the editable resource and updates transforms from/to view
func _update_transforms():
    var node: CurvedArrow2D = _selected_node
    var transform_viewport := node.get_viewport_transform()
    var transform_canvas := node.get_canvas_transform()
    var transform_local := node.transform
    _transform_to_view = transform_viewport * transform_canvas * transform_local
    _transform_to_base = _transform_to_view.affine_inverse()