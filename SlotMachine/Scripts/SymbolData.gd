class_name SymbolData
extends Resource

export var image_path: String
export var image_static: Texture
export var image_blur: Texture
export var is_pseudo: bool
export var rect_size: float
export var animation_data: SpineSkeletonDataResource
export var defaultAnimationName: String

#func _init(imagePath: String = "", blurPath: String = "", animationData = null, isPseudo = false, rectSize: float = -1, defaultAnimation:String = "anim"):
#	self.image_path = load(imagePath)
#	self.blur_path = load(blurPath if not "" else image_path)
#	self.is_pseudo = isPseudo
#	self.rect_size = rectSize
#	self.animation_data = animationData
#	self.defaultAnimationName = defaultAnimation
