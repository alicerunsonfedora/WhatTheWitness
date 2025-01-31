extends Node2D

onready var custom_level_button = $MarginContainer/VBoxContainer/CustomLevelButton

func _on_start_button_pressed():
    get_tree().change_scene("res://warning_scene.tscn")


func _ready():
    if (!Gameplay.loaded_from_command_line):
        var args = OS.get_cmdline_args()
        Gameplay.drag_custom_levels(args, null)
        Gameplay.loaded_from_command_line = true
    if (!Gameplay.ALLOW_CUSTOM_LEVELS):
        custom_level_button.visible = false
    else:
        get_tree().connect("files_dropped", Gameplay, "drag_custom_levels")
    update_mobile_constraints()

func update_mobile_constraints():
    var height = get_viewport_rect().size.y
    var width = get_viewport_rect().size.x
    var y_offset = (height - 600) / 2
    var x_offset = (width - 1024) / 2
    $MarginContainer.rect_position = Vector2(x_offset, y_offset)



func _on_custom_level_button_pressed():
    get_tree().change_scene("res://custom_level_scene.tscn")


func _on_CreditsButton_pressed():
    get_tree().change_scene("res://credit_scene.tscn")


func _on_SettingButton_pressed():
    get_tree().change_scene("res://setting_scene.tscn")
