@tool
class_name CurvedArrow2D
extends Node2D

@export_group("Arrow Properties")
@export var start_pos: Vector2 = Vector2(10, 10):
    set(value):
        start_pos = value
        if Engine.is_editor_hint(): queue_redraw()
@export var end_pos: Vector2 = Vector2(200, 200):
    set(value):
        end_pos = value
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

@onready var arrow_group: CanvasGroup = $ArrowGroup

@onready var orig_outline_color = outline_color
@onready var orig_transparency = transparency

func _init():
    if not has_node("ArrowGroup"):
        arrow_group = CanvasGroup.new()
        arrow_group.name = "ArrowGroup"
        # Create and set the shader material
        var material = ShaderMaterial.new()
        material.shader = preload("res://addons/2d_curved_arrow/canvas_group_outline.gdshader")
        material.set_shader_parameter("line_color", outline_color)
        material.set_shader_parameter("alpha", transparency)
        material.set_shader_parameter("line_thickness", outline_thickness)
        arrow_group.material = material
        add_child(arrow_group)

func _enter_tree():
    if Engine.is_editor_hint() and arrow_group and is_instance_valid(arrow_group):
        arrow_group.owner = get_tree().edited_scene_root

func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = []
    if end_pos == Vector2.ZERO:
        warnings.append("Start and end positions must be set")
    return warnings

# Add visual handles in the editor
func _get_item_rect() -> Rect2:
    if end_pos == Vector2.ZERO:
        return Rect2()
    var rect = Rect2(start_pos, Vector2.ZERO)
    rect = rect.expand(end_pos)
    rect = rect.grow(max(width, arrowhead_size))
    return rect

func _update_shader_params():
    if not is_node_ready():
        await ready

    arrow_group.material.set_shader_parameter("line_color", outline_color)
    arrow_group.material.set_shader_parameter("alpha", transparency)
    arrow_group.material.set_shader_parameter("line_thickness", outline_thickness)

func set_positions(start: Vector2, end: Vector2):
    start_pos = start
    end_pos = end
    queue_redraw()

func reset_params():
    outline_color = orig_outline_color
    transparency = orig_transparency

func _draw():
    # Clear previous drawings by removing all children of the CanvasGroup
    for child in arrow_group.get_children():
        child.queue_free()

    if end_pos == Vector2.ZERO:
        return

    var mid_point = (start_pos + end_pos) / 2
    var direction = (end_pos - start_pos).normalized()
    var perpendicular = Vector2(-direction.y, direction.x)

    var diff = start_pos.x - end_pos.y
    var calc_curve_factor = lerp(-curve_height_factor, curve_height_factor, smoothstep(-100, 100, diff))
    var start_tangent_factor = curve_height_factor
    var end_tangent_factor = 0.1

    var control_point = mid_point + perpendicular * (end_pos - start_pos).length() * calc_curve_factor

    var curve = Curve2D.new()
    curve.add_point(start_pos, Vector2.ZERO, (control_point - start_pos) * start_tangent_factor)
    curve.add_point(end_pos, (end_pos - control_point) * end_tangent_factor, Vector2.ZERO)

    var all_points = curve.get_baked_points()
    var points = all_points
    var modi = arrowhead_size / 4
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
    var arrow_tip_point = all_points[-7]
    var arrowhead_points = PackedVector2Array([
        arrow_tip_point,
        arrow_tip_point - tangent.rotated(PI/6) * arrowhead_size,
        arrow_tip_point - tangent.rotated(-PI/6) * arrowhead_size
    ])

    var polygon = Polygon2D.new()
    polygon.polygon = arrowhead_points
    polygon.color = color
    arrow_group.add_child(polygon)
