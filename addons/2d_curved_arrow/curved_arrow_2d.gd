@tool
class_name CurvedArrow2D
extends Node2D

var curved_arrow_scene: PackedScene = load("res://addons/2d_curved_arrow/curved_arrow_2d_scene.tscn")

@export_group("Arrow Properties")
@export var end_pos: Vector2 = Vector2(200, 200):
    set(value):
        end_pos = value
        if end_star: end_star.position = value
        if Engine.is_editor_hint(): queue_redraw()
@export var curve_height_factor: float = 0.8:
    set(value):
        curve_height_factor = value
        if Engine.is_editor_hint(): queue_redraw()
@export var color: Color = Color(0.7, 0.7, 0.5, 1.0):
    set(value):
        color = value
        queue_redraw()
@export var width: float = 30.0:
    set(value):
        width = value
        queue_redraw()
@export var arrowhead_size: float = 80.0:
    set(value):
        arrowhead_size = value
        queue_redraw()

@export_group("Outline Properties")
@export var outline_color: Color = Color(1.0, 1.0, 1.0, 1.0):
    set(value):
        outline_color = value
        _update_shader_params()
@export_range(0.0, 1.0) var transparency: float = 0.8:
    set(value):
        transparency = value
        _update_shader_params()
@export_range(0, 10) var outline_thickness: int = 1:
    set(value):
        outline_thickness = value
        _update_shader_params()

var arrow_group: CanvasGroup
var end_star: Polygon2D
var reference_rect: ReferenceRect
var is_selected_in_editor: bool = false

@onready var orig_outline_color = outline_color
@onready var orig_transparency = transparency

func _init():
    set_notify_transform(true)
    # custom node types in Godot can't have their own scenes, so this is the workaround:
    # have another scene, and add it as a child
    var arrow_scene = curved_arrow_scene.instantiate()
    add_child(arrow_scene)
    arrow_group    = arrow_scene.get_node("ArrowGroup")
    end_star       = arrow_scene.get_node("EndStar")
    reference_rect = arrow_scene.get_node("ReferenceRect")

func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = []
    if end_pos == Vector2.ZERO:
        warnings.append("Start and end positions must be set")
    return warnings

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSFORM_CHANGED:
        # the position or something changed, so redraw the arrow
        queue_redraw()

func _update_shader_params():
    if not is_node_ready():
        await ready

    arrow_group.material.set_shader_parameter("line_color", outline_color)
    arrow_group.material.set_shader_parameter("alpha", transparency)
    arrow_group.material.set_shader_parameter("line_thickness", outline_thickness)

func _draw():
    if !arrow_group: return
    # Clear previous drawings by removing all children of the CanvasGroup
    for child in arrow_group.get_children():
        child.queue_free()

    if end_pos == Vector2.ZERO:
        return

    var start_pos:     Vector2 = position # start wherever the node's position is
    var mid_point:     Vector2 = (start_pos + end_pos) / 2
    var direction:     Vector2 = (end_pos - start_pos).normalized()
    var perpendicular: Vector2 = Vector2(-direction.y, direction.x)

    var diff:                 float = start_pos.x - end_pos.y
    var calc_curve_factor:    float = lerp(-curve_height_factor, curve_height_factor, smoothstep(-100, 100, diff))
    var start_tangent_factor: float = curve_height_factor
    var end_tangent_factor:   float = 0.1

    var control_point: Vector2 = mid_point + perpendicular * (end_pos - start_pos).length() * calc_curve_factor

    var curve: Curve2D = Curve2D.new()
    curve.add_point(start_pos, Vector2.ZERO, (control_point - start_pos) * start_tangent_factor)
    curve.add_point(end_pos, (end_pos - control_point) * end_tangent_factor, Vector2.ZERO)

    var all_points: PackedVector2Array = curve.get_baked_points()
    var points:     PackedVector2Array = all_points
    var modi:       float              = arrowhead_size / 4
    if all_points.size() > modi:
        points = all_points.slice(0, -modi)

    if points.size() < 2:
        return

    var last_point: Vector2 = points[-1]

    # Draw the main curve
    var line = Line2D.new()
    line.points = points
    line.width = width
    line.default_color = color
    arrow_group.add_child(line)

    if all_points.size() < 7:
        return

    var tangent: Vector2
    if points.size() >= 5:
        tangent = (points[-1] - points[-5]).normalized()
    else:
        tangent = (last_point - start_pos).normalized()

    # Draw arrowhead as a filled triangle
    var arrow_tip_point: Vector2 = all_points[-7]
    var arrowhead_points: PackedVector2Array = PackedVector2Array([
        arrow_tip_point,
        arrow_tip_point - tangent.rotated(PI/6) * arrowhead_size,
        arrow_tip_point - tangent.rotated(-PI/6) * arrowhead_size
    ])

    var polygon: Polygon2D = Polygon2D.new()
    polygon.polygon = arrowhead_points
    polygon.color = color
    arrow_group.add_child(polygon)

    # set up bounding ref - note: this doesn't do a good job of covering the curved line
    # but once rewritten to be a single polygon it should be better
    var combined_points: Array[Vector2]
    combined_points.assign(Array(points + arrowhead_points))
    var x_vals: Array[float]
    x_vals.assign(combined_points.map(func(p): return p.x))
    var y_vals: Array[float]
    y_vals.assign(combined_points.map(func(p): return p.y))
    reference_rect.position = Vector2(x_vals.min(), y_vals.min())
    reference_rect.size     = Vector2(x_vals.max() - x_vals.min(), y_vals.max() - y_vals.min())

    # set visibility of editor helpers
    reference_rect.visible = is_selected_in_editor
    end_star.visible       = is_selected_in_editor


### Public functions

# is a given position within the boundary box (which is a rectangle)
func in_boundary_box(pos: Vector2) -> bool:
    return  pos.x >= reference_rect.position.x and \
            pos.x <= reference_rect.position.x + reference_rect.size.x and \
            pos.y >= reference_rect.position.y and \
            pos.y <= reference_rect.position.y + reference_rect.size.y

# useful for setting to the coords of other nodes, or following the mouse
func set_positions(start: Vector2, end: Vector2):
    position = start
    end_pos = end
    queue_redraw()

# in some cases, you may want to change these params while the arrow is moving or something,
# so this will conveniently set them back to the original object's properties
func reset_params():
    outline_color = orig_outline_color
    transparency = orig_transparency