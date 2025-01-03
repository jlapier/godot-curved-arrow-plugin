@tool
class_name CurvedArrow2D
extends Node2D

var curved_arrow_scene: PackedScene = load("res://addons/2d_curved_arrow/curved_arrow_2d_scene.tscn")

@export_group("Arrow Properties")
# the global position of the tip of the arrow
@export var global_end_position: Vector2 = Vector2(200, 200):
    set(value):
        global_end_position = value
        if end_star: end_star.global_position = value
        queue_redraw()
# tune this up or down to increase or decrease the amount of bend;
# setting this to a negative number will flip the bend of the curve to the opposite side
@export var curve_height_factor: float = 0.8:
    set(value):
        curve_height_factor = value
        queue_redraw()
# main color of the arrow
@export var color: Color = Color(0.7, 0.7, 0.5, 1.0):
    set(value):
        color = value
        queue_redraw()
# width of the arrow body, not including the head
@export var width: float = 30.0:
    set(value):
        width = value
        queue_redraw()
# size from the base of the arrowhead to the tip
@export var arrowhead_height: float = 60.0:
    set(value):
        arrowhead_height = value
        queue_redraw()
# size at the base of the arrowhead; note if this is smaller than half the width, the head will be inverted
@export var arrowhead_width: float = 80.0:
    set(value):
        arrowhead_width = value
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
    if global_end_position == global_position:
        warnings.append("Start and end positions must be different from each other")
    return warnings

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSFORM_CHANGED:
        # the position or something changed, so redraw the arrow
        if end_star: end_star.global_position = global_end_position
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

    if global_end_position == global_position:
        return

    # positions will be local to the parent node when the arrow Polygon is added as a child, so convert to local
    var start_position: Vector2 = Vector2.ZERO # start wherever the node's position is
    var end_position:   Vector2 = global_end_position - global_position # localize the end position

    var mid_point:      Vector2 = (start_position + end_position) / 2
    var direction:      Vector2 = (end_position - start_position).normalized()
    var perpendicular:  Vector2 = Vector2(-direction.y, direction.x)

    var diff:                 float = start_position.x - end_position.y
    if curve_height_factor < 0:
        diff = end_position.y - start_position.x
    var start_tangent_factor: float = abs(curve_height_factor)
    var calc_curve_factor:    float = lerp(-start_tangent_factor, start_tangent_factor, smoothstep(-100, 100, diff))
    # this tapers off the curve at the end - we could make it adjustable, but it kind of distorts the
    # arrow if it's too hight, so ... shrug
    var end_tangent_factor:   float = 0.1

    var control_point: Vector2 = mid_point + perpendicular * (end_position - start_position).length() * calc_curve_factor

    var curve: Curve2D = Curve2D.new()
    curve.add_point(start_position, Vector2.ZERO, (control_point - start_position) * start_tangent_factor)
    curve.add_point(end_position, (end_position - control_point) * end_tangent_factor, Vector2.ZERO)

    var all_points: PackedVector2Array = curve.get_baked_points()
    if all_points.size() < 5:
        return

    # guide points represent a line down the middle of the arrow we want
    var guide_points: Array[Vector2]
    guide_points.assign(all_points)
    # populate these with either side of the guide arrow
    var top_side_points: Array[Vector2]
    var bottom_side_points: Array[Vector2]

    var i_offset = 10
    var last_top_tip: Vector2
    var last_bottom_tip: Vector2
    for i in guide_points.size():
        var guide_point = guide_points[i]
        if guide_point.distance_to(end_position) < arrowhead_height: break
        # most likely we don't reach this point because of the height check, but this
        # is to protect us from going out of bounds
        if i+i_offset >= guide_points.size(): i_offset = max(i_offset - 1, 0)
        var dir:  Vector2 = (guide_points[i+i_offset] - guide_point).normalized()
        var perp: Vector2 = Vector2(-dir.y, dir.x)
        top_side_points.append(guide_point - perp * width / 2)
        last_top_tip = guide_point - perp * (arrowhead_width - width) / 2
        bottom_side_points.append(guide_point + perp * width / 2)
        last_bottom_tip = guide_point + perp * (arrowhead_width - width) / 2

    if top_side_points.size() < 1 or bottom_side_points.size() < 1: return

    var arrow_pts: Array[Vector2] = [
        last_top_tip,
        end_position, # tip of the arrow!
        last_bottom_tip
    ]

    bottom_side_points.reverse() # to order the points, we go up one side, over the head, then down the other side

    var arrow_poly = Polygon2D.new()
    arrow_poly.polygon = PackedVector2Array(top_side_points + arrow_pts + bottom_side_points)
    arrow_poly.color = color
    arrow_group.add_child(arrow_poly)

    if is_selected_in_editor:
        # set up bounding ref - just a visual in the editor
        var combined_points: Array[Vector2] = top_side_points + bottom_side_points + arrow_pts
        var x_vals = combined_points.map(func(p: Vector2): return p.x)
        var y_vals = combined_points.map(func(p: Vector2): return p.y)
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
    global_end_position = end
    queue_redraw()

# in some cases, you may want to change these params while the arrow is moving or something,
# so this will conveniently set them back to the original object's properties
func reset_params():
    outline_color = orig_outline_color
    transparency = orig_transparency