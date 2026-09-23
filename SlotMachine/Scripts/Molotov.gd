extends Node2D

onready var molotov_animated : SpineSprite = $MolotovAnimated
onready var sprite : Sprite = $Sprite

var defaultAnimationName : String = "explosion"

func playExplotionAnimation(animationName:String = ""):
	molotov_animated.get_animation_state().set_animation(animationName if animationName else defaultAnimationName, false, 0)
	molotov_animated.show()
	sprite.hide()
	
	molotov_animated.connect("animation_completed", self, "on_animation_completed")


func on_animation_completed(track_entry, loop_count, event) -> void:
	queue_free()
