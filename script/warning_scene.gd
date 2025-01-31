extends Node2D

onready var checkbox = $MarginContainer/VBoxContainer/CheckBox

func _ready():
    SaveData.load_all()
    var setting = SaveData.get_setting()
    if ('skip_spoiler' in setting):
        get_tree().change_scene("res://level_map.tscn")
    update_mobile_constraints()

func update_mobile_constraints():
    var height = get_viewport_rect().size.y
    var width = get_viewport_rect().size.x
    var y_offset = (height - 600) / 2
    var x_offset = (width - 1024) / 2
    $MarginContainer.rect_position = Vector2(x_offset, y_offset)


func _on_RichTextLabel2_meta_clicked(meta):
    OS.shell_open(meta)


func _on_ContinueButton_pressed():
    if (checkbox.is_pressed()):
        var setting = SaveData.get_setting()
        setting['skip_spoiler'] = 1
        SaveData.save_setting(setting)
    get_tree().change_scene("res://level_map.tscn")


func _on_ExitButton_pressed():
    get_tree().change_scene("res://menu_main.tscn")
