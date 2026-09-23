extends Control


signal tween_ended

export var texture : Texture
## Reused tween for molotov effect
var molotovTween : SceneTreeTween


func aminEffect(wild: Array, molotov_src: PackedScene, pos_start: Vector2, pos_end: Vector2, multiplier: int) -> void:
	var molotov = molotov_src.instance()
	molotov.scale = Vector2.ZERO
	
	randomize()
	molotov.rotation = rand_range(0.0, TAU)

	molotov.global_position = pos_start - rect_global_position
	var start = pos_start - rect_global_position
	var end = pos_end - rect_global_position
	molotov.z_index = 100
	add_child(molotov)
	
	molotovTween = create_tween()
	molotovTween.set_parallel(true)
	molotovTween.tween_property(
		molotov,
		"position",
		end,
		1.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).from(start)
	
	
	molotovTween.tween_property(
		molotov,
		"scale",
		Vector2(0.5, 0.5),
		0.1
	).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN).from_current()
	
	
	molotovTween.tween_property(
		molotov,
		"rotation",
		molotov.rotation + TAU * 1.3,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).from_current()
	
	molotovTween.connect("finished", self, 'onTweenFinished', [wild, molotov, multiplier])


func onTweenFinished(wild: Array, molotov: Node2D, multiplier: int) -> void:
	if molotovTween == null: return
	molotov.playExplotionAnimation()
	emit_signal("tween_ended", wild, multiplier)


func clearEffect() -> void:
	if molotovTween == null: return
	molotovTween.kill()
	molotovTween = null
	
	for x in get_children():
		x.queue_free()
