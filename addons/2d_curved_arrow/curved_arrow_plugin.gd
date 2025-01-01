@tool
extends EditorPlugin

var _selected_node: Node2D = null
var _dragging_handle: bool = false
var _end_handle_pos: Vector2 = Vector2.ZERO
var _transform_to_view: Transform2D
var _transform_to_base: Transform2D

# magic so that when nodes of type CurvedArrow2D are selected, this script takes over
func _handles(object) -> bool:
    return object is CurvedArrow2D

# triggers on select and deselect (with object = null)
func _edit(object) -> void:
    # different arrow selected, deselect the first one
    if _selected_node and _selected_node != object:
        _selected_node.is_selected_in_editor = false
        _selected_node.queue_redraw()

    _selected_node = object
    if _selected_node:
        _selected_node.is_selected_in_editor = true
        _selected_node.queue_redraw()

# this seems to trigger on deselect. The docs say "Remember that you have to manage
# the visibility of all your editor controls manually."
func _make_visible(visible: bool) -> void:
    if not visible:
        _selected_node.is_selected_in_editor = false
        _selected_node.queue_redraw()
        _selected_node = null

# initially this was written to draw circles for the start and end points of the
# arrow. It works okay, but not great. But it also sets the _end_handle_pos
# which allows us to know where the handle is so we can detect when it's "grabbed"
# by the mouse.
func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
    if !_selected_node or !_selected_node is CurvedArrow2D:
        return

    _update_transforms()

    var pos_scale = _transform_to_view.get_scale()
    var end_pos_offset = (_selected_node.end_position - _selected_node.position) * pos_scale
    _end_handle_pos = _transform_to_view.get_origin() + end_pos_offset
    # XXX: this makes a circle show up at the end of the arrow, but it
    # doesn't move with the mouse, so it's not great. May come back to this.
    # viewport_control.draw_circle(_end_handle_pos, 8, Color.RED)
    # viewport_control.draw_circle(_end_handle_pos, 10, Color.WHITE, false, 2)

# capture input and check for dragging the mouse. Return true if input was handled.
func _forward_canvas_gui_input(event: InputEvent) -> bool:
    if not (_selected_node and _selected_node is CurvedArrow2D):
        return false

    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and \
                event.pressed and \
                event.position.distance_to(_end_handle_pos) < 20:
            _dragging_handle = true
            return true
        _dragging_handle = false
    elif event is InputEventMouseMotion and _dragging_handle:
        _selected_node.end_position = _transform_to_base * event.position + _selected_node.position
        return true

    return false

func _update_transforms():
    var transform_viewport: Transform2D = _selected_node.get_viewport_transform()
    var transform_canvas:   Transform2D = _selected_node.get_canvas_transform()
    var transform_local:    Transform2D = _selected_node.transform
    # adjust transform for the viewing box and scale
    _transform_to_view = transform_viewport * transform_canvas * transform_local
    # someday I hope to understand wtf an affine inverse is
    _transform_to_base = _transform_to_view.affine_inverse()