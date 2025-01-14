extends Node2D

const puzzle_dir = "res://puzzles"
onready var puzzle_placeholders = $Menu/View/PuzzlePlaceHolders
onready var extra_menu = $SideMenu/Extra
onready var clear_save_button = $SideMenu/Extra/ClearSaveButton
onready var view = $Menu/View
onready var drag_start = null
onready var level_area_limit = $Menu/View/LevelAreaLimit
onready var line_map = $Menu/View/Lines
onready var light_map = $Menu/View/Lights
onready var gadget_map = $Menu/View/Gadgets
onready var light_tile_id = light_map.tile_set.find_tile_by_name('light')
onready var and_gadget_tile_id = gadget_map.tile_set.find_tile_by_name('and_gate')
onready var or_gadget_tile_id = gadget_map.tile_set.find_tile_by_name('or_gate')
onready var puzzle_counter_text = $SideMenu/PuzzleCounter
onready var menu_bar_button = $SideMenu/MenuBarButton
onready var loading_cover = $LoadingCover
var window_size = Vector2(1024, 600)
var view_origin = -window_size / 2
var view_scale = 1.0

const UNLOCK_ALL_PUZZLES = false
const LOADING_BATCH_SIZE = 10

const DIR_X = [-1, 0, 1, 0]
const DIR_Y = [0, -1, 0, 1]

func list_files(path):
    var files = {}
    var dir = Directory.new()
    dir.open(path)
    dir.list_dir_begin()
    while true:
        var file = dir.get_next()
        if (file == ''):
            return files
        if (file == '.' or file == '..'):
            continue
        files[file] = true

func _ready():
    loading_cover.visible = true
    drag_start = null
    # puzzle_placeholders.hide()
    SaveData.load_all()
    var puzzle_files = list_files(puzzle_dir)
    var files = list_files(puzzle_dir)
    var viewports = []
    var placeholders = puzzle_placeholders.get_children()
    MenuData.puzzle_grid_pos.clear()
    MenuData.grid_pos_puzzle.clear()
    var pos_points = {}
    for placeholder in placeholders:
        if (placeholder.text.begins_with('$')):
            var cell_pos = placeholder.get_position() / 96
            var int_cell_pos = [int(round(cell_pos.x)), int(round(cell_pos.y)) - 1]
            pos_points[int_cell_pos] = int(placeholder.text.substr(1))
            placeholder.get_parent().remove_child(placeholder)
        elif (placeholder.text.begins_with('#')):
            var cell_pos = placeholder.get_position() / 96
            var int_cell_pos = [int(round(cell_pos.x)), int(round(cell_pos.y))]
            var prefix = placeholder.text.substr(1)
            var child_pos = placeholder.get_position()
            for puzzle_file in files:
                if (puzzle_file.begins_with(prefix)):
                    var node = placeholder.duplicate()
                    node.text = puzzle_file.substr(0, len(puzzle_file) - 4)
                    node.set_position(child_pos)
                    placeholder.get_parent().add_child(node)
                    var pts_text = puzzle_file.substr(puzzle_file.find('(') + 1)
                    pos_points[int_cell_pos] = int(pts_text.substr(0, pts_text.find(')')))
                    child_pos += Vector2(96, 0)
                    int_cell_pos = [int_cell_pos[0] + 1, int_cell_pos[1]]
            placeholder.get_parent().remove_child(placeholder)
    placeholders = puzzle_placeholders.get_children()
    var processed_placeholder_count = 0
    var total_placeholder_count = 0
    for placeholder in placeholders:
        var puzzle_file = placeholder.text + '.wit'
        if (!placeholder.text.begins_with('$') and puzzle_file in files):
            total_placeholder_count += 1
    for placeholder in placeholders:
        var puzzle_file = placeholder.text + '.wit'
        if (!placeholder.text.begins_with('$') and puzzle_file in files):
            var target = MenuData.puzzle_preview_prefab.instance()
            MenuData.puzzle_preview_panels[puzzle_file] = target
            view.add_child(target)
            target.set_position(placeholder.get_position())
            var cell_pos = target.global_position / 96
            cell_pos = Vector2(round(cell_pos.x), round(cell_pos.y))
            if (puzzle_file in MenuData.puzzle_grid_pos):
                print('[Warning] Duplicated puzzle %s on' % puzzle_file, cell_pos)
            MenuData.puzzle_grid_pos[puzzle_file] = cell_pos
            var int_cell_pos = [int(cell_pos.x), int(cell_pos.y)]
            if (int_cell_pos in MenuData.grid_pos_puzzle):
                print('[Warning] Multiple puzzles (%s) on the same grid position (%d, %d)' % [puzzle_file, cell_pos.x, cell_pos.y])
            MenuData.grid_pos_puzzle[int_cell_pos] = puzzle_file
            MenuData.puzzle_points[puzzle_file] = 0
            if (int_cell_pos in pos_points):
                MenuData.puzzle_points[puzzle_file] = pos_points[int_cell_pos]
            target.points = MenuData.puzzle_points[puzzle_file]
            target.show_puzzle(puzzle_file, get_light_state(cell_pos))
            placeholder.get_parent().remove_child(placeholder)
            if (processed_placeholder_count % LOADING_BATCH_SIZE == 0):
                puzzle_counter_text.bbcode_text = '[right]loading puzzle: %d / %d[/right] ' % [processed_placeholder_count, total_placeholder_count]
                yield(VisualServer, "frame_post_draw")
            processed_placeholder_count += 1
    update_light(true)
    Gameplay.update_mouse_speed()
    update_mobile_constraints()

func update_mobile_constraints():
    var height = get_viewport_rect().size.y
    var width = get_viewport_rect().size.x
    var y_offset = (height - 600) / 2
    var x_offset = (width - 1024) / 2
    $SideMenu.position.x += x_offset
    $PuzzleUI.position = Vector2(x_offset, y_offset)
    $PuzzleUI/BackButton.rect_position.y -= y_offset
    $PuzzleUI/ColorRect.rect_position.x -= x_offset
    $PuzzleUI/ColorRect.rect_position.y -= y_offset
    $PuzzleUI/ColorRect.rect_size = get_viewport_rect().size



func get_light_state(pos):
    if (light_map.get_cellv(pos) >= 0):
        return true
    else:
        return false

func update_counter():
    var puzzle_count = 0
    var solved_count = 0
    var score = 0
    var total_score = 0
    for puzzle_file in MenuData.puzzle_grid_pos:
        var pos = MenuData.puzzle_grid_pos[puzzle_file]
        if(SaveData.puzzle_solved(puzzle_file)):
            solved_count += 1
            score += MenuData.puzzle_points[puzzle_file]
        puzzle_count += 1
        total_score += MenuData.puzzle_points[puzzle_file]
    if (total_score > 0):
        puzzle_counter_text.bbcode_text = '[right]%d / %d (%d / %d pts)[/right] ' % [solved_count, puzzle_count, score, total_score]
    else:
        puzzle_counter_text.bbcode_text = '[right]%d / %d[/right] ' % [solved_count, puzzle_count]
func get_gadget_direction(tile_map: TileMap, pos: Vector2):
    var x = int(round(pos.x))
    var y = int(round(pos.y))
    if (tile_map.is_cell_transposed(x, y)):
        return Vector2(0, -1) if tile_map.is_cell_y_flipped(x, y) else Vector2(0, 1)
    else:
        return Vector2(-1, 0) if tile_map.is_cell_x_flipped(x, y) else Vector2(1, 0)

func update_light(first_time=false):
    var stack = []
    for puzzle_file in MenuData.puzzle_grid_pos:
        var pos = MenuData.puzzle_grid_pos[puzzle_file]
        if(SaveData.puzzle_solved(puzzle_file)):
            stack.append(pos)
            light_map.set_cellv(pos, light_tile_id)
            light_map.update_bitmask_area(pos)
    while (!stack.empty()):
        var pos = stack.pop_back()
        # print('Visiting ', pos)
        var deltas = []
        for dir in range(4):
            var delta = Vector2(DIR_X[dir], DIR_Y[dir])
            var new_pos = pos + delta
            if (line_map.get_cellv(new_pos) == -1):
                continue
            deltas.append(delta)
            if (gadget_map.get_cellv(new_pos) == or_gadget_tile_id):
                deltas.append(delta + get_gadget_direction(gadget_map, new_pos))
            if (gadget_map.get_cellv(new_pos) == and_gadget_tile_id):
                var non_activated_neighbor = 0
                for dir2 in range(4):
                    var new_pos2 = new_pos + Vector2(DIR_X[dir2], DIR_Y[dir2])
                    if (line_map.get_cellv(new_pos2) != -1 and !get_light_state(new_pos2)):
                        non_activated_neighbor += 1
                if (non_activated_neighbor == 1):
                    deltas.append(delta + get_gadget_direction(gadget_map, new_pos))
        for delta in deltas:
            var new_pos = pos + delta
            if (get_light_state(new_pos)):
                continue
            light_map.set_cellv(new_pos, light_tile_id)
            light_map.update_bitmask_area(new_pos)
            if (gadget_map.get_cellv(new_pos) == -1 and
                MenuData.get_puzzle_on_cell(new_pos) == null):
                stack.append(new_pos)
    var puzzles_to_unlock = []
    for puzzle_file in MenuData.puzzle_grid_pos:
        var pos = MenuData.puzzle_grid_pos[puzzle_file]
        if((UNLOCK_ALL_PUZZLES or get_light_state(pos)) and !MenuData.puzzle_preview_panels[puzzle_file].puzzle_unlocked):
            puzzles_to_unlock.append(puzzle_file)
    var processed_rendering_count = 0
    for puzzle_file in puzzles_to_unlock:
        MenuData.puzzle_preview_panels[puzzle_file].update_puzzle(true)
        if (first_time and processed_rendering_count % LOADING_BATCH_SIZE == 0):
            puzzle_counter_text.bbcode_text = '[right]rendering puzzle: %d / %d[/right] ' % [processed_rendering_count, len(puzzles_to_unlock)]
            yield(VisualServer, "frame_post_draw")
        processed_rendering_count += 1
    if (first_time):
        loading_cover.visible = false
        MenuData.can_drag_map = true
        update_counter()
func update_view():
    view.position = window_size / 2 + (view_origin) * view_scale
    view.scale = Vector2(view_scale, view_scale)
    var limit_pos = level_area_limit.rect_global_position
    var limit_size = level_area_limit.rect_size * view_scale
    var dx = 0.0
    var dy = 0.0
    var extra_margin = 100
    if (limit_pos.x > extra_margin):
        dx += limit_pos.x - extra_margin
    elif (limit_pos.x + limit_size.x < window_size.x - extra_margin):
        dx += limit_pos.x + limit_size.x - window_size.x + extra_margin
    if (limit_pos.y > extra_margin):
        dy += limit_pos.y - extra_margin
    elif (limit_pos.y + limit_size.y < window_size.y - extra_margin):
        dy += limit_pos.y + limit_size.y - window_size.y + extra_margin
    view_origin -= Vector2(dx, dy) / view_scale
    view.position = window_size / 2 + (view_origin) * view_scale
    view.scale = Vector2(view_scale, view_scale)

func _input(event):
    if (event is InputEventMouseButton and MenuData.can_drag_map):
        if (event.button_index == BUTTON_WHEEL_DOWN):
            view_scale = max(view_scale * 0.8, 0.2097152)
        elif (event.button_index == BUTTON_WHEEL_UP):
            view_scale = min(view_scale * 1.25, 3.0)
        elif (event.pressed):
            drag_start = event.position
        else:
            drag_start = null
            return
    elif (event is InputEventMouseMotion):
        if (!MenuData.can_drag_map):
            drag_start = null
        if (drag_start != null):
            view_origin += (event.position - drag_start) / view_scale
            drag_start = event.position
    update_view()

func _on_clear_save_button_pressed():
    if (clear_save_button.text == 'Are you sure?'):
        SaveData.clear()
        clear_save_button.text = 'Clear Save'
        for puzzle_name in MenuData.puzzle_preview_panels:
            MenuData.puzzle_preview_panels[puzzle_name].update_puzzle(false)
        update_light()
    else:
        clear_save_button.text = 'Are you sure?'


func _on_menu_bar_button_mouse_entered():
    menu_bar_button.modulate = Color(menu_bar_button.modulate.r, menu_bar_button.modulate.g, menu_bar_button.modulate.b, 0.5)

func _on_menu_bar_button_mouse_exited():
    menu_bar_button.modulate = Color(menu_bar_button.modulate.r, menu_bar_button.modulate.g, menu_bar_button.modulate.b, 1.0)

func _on_menu_bar_button_pressed():
    get_tree().change_scene("res://menu_main.tscn")
