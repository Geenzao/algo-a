extends Node2D
## Le personnage (rond blanc) va chercher la pièce avec A*.
## À chaque pièce ramassée : un obstacle rouge apparaît, une nouvelle pièce
## apparaît, et le chemin est recalculé.

const Pathfinder = preload("res://scripts/pathfinder.gd")

const GRID := 10
const CELL := 64
const ORIGIN := Vector2(20, 20)
const SPEED := 260.0

var pathfinder := Pathfinder.new(GRID, GRID)
var player := Vector2i.ZERO
var coin := Vector2i.ZERO
var path: Array[Vector2i] = []   # path[0] = case du joueur
var pos := Vector2.ZERO          # position en pixels (pour l'animation)
var finished := false


func _ready() -> void:
	player = Vector2i(randi_range(0, GRID - 1), randi_range(0, GRID - 1))
	pos = _center(player)
	coin = _random_free_cell()
	path = pathfinder.find_path(player, coin)


func _process(delta: float) -> void:
	if finished or path.size() < 2:
		return

	var target := _center(path[1])
	pos = pos.move_toward(target, SPEED * delta)
	if pos.is_equal_approx(target):
		player = path[1]
		path.pop_front()
		if player == coin:
			_on_coin_collected()
	queue_redraw()


# Appelée à chaque fois que le personnage ramasse une pièce.
# C'est ici que se fait le RECALCUL du chemin avec A*.
func _on_coin_collected() -> void:
	# 1) Un obstacle apparaît sur une case libre au hasard.
	#    On refuse les cases qui couperaient la grille en deux zones séparées :
	#    ainsi la prochaine pièce est toujours atteignable.
	var cells := _free_cells()
	cells.shuffle()
	var obstacle := Vector2i(-1, -1)
	for c in cells:
		if pathfinder.stays_connected_if_blocked(c, player):
			obstacle = c
			break
	if obstacle == Vector2i(-1, -1):
		finished = true  # plus de place : fin de la simulation
		return
	pathfinder.set_blocked(obstacle, true)

	# 2) Une nouvelle pièce apparaît sur une case libre.
	coin = _random_free_cell()

	# 3) La grille a changé : on relance A* depuis la position actuelle du joueur.
	path = pathfinder.find_path(player, coin)


func _free_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in GRID:
		for x in GRID:
			var c := Vector2i(x, y)
			if c != player and not pathfinder.is_blocked(c):
				cells.append(c)
	return cells


func _random_free_cell() -> Vector2i:
	return _free_cells().pick_random()


func _center(c: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func _draw() -> void:
	for y in GRID:
		for x in GRID:
			var c := Vector2i(x, y)
			var color := Color.RED if pathfinder.is_blocked(c) else Color.GREEN
			draw_rect(Rect2(ORIGIN + Vector2(c) * CELL, Vector2(CELL, CELL)).grow(-1.0), color)

	if path.size() >= 2:
		var points := PackedVector2Array([pos])
		for i in range(1, path.size()):
			points.append(_center(path[i]))
		draw_polyline(points, Color.CYAN, 4.0)

	draw_circle(_center(coin), 14.0, Color.GOLD)
	draw_circle(pos, 22.0, Color.WHITE)
