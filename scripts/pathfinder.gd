extends RefCounted
## A* sur grille 2D (4 directions, heuristique de Manhattan).
##   g = coût depuis le départ, h = estimation jusqu'à l'arrivée, f = g + h.
## La liste ouverte est un tas binaire de Vector3(f, h, index_case).

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var width: int
var height: int
var _blocked: PackedByteArray


func _init(w: int, h: int) -> void:
	width = w
	height = h
	_blocked.resize(w * h)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func is_blocked(c: Vector2i) -> bool:
	return not in_bounds(c) or _blocked[_idx(c)] == 1


func set_blocked(c: Vector2i, value: bool) -> void:
	_blocked[_idx(c)] = 1 if value else 0


## Vrai si, une fois `cell` bloquée, toutes les cases libres restent reliées
## entre elles (donc une pièce posée n'importe où reste atteignable).
func stays_connected_if_blocked(cell: Vector2i, from: Vector2i) -> bool:
	var previous := _blocked[_idx(cell)]
	_blocked[_idx(cell)] = 1

	var free_total := _blocked.count(0)
	var seen := PackedByteArray()
	seen.resize(width * height)
	var stack: Array[Vector2i] = [from]
	seen[_idx(from)] = 1
	var reached := 0
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		reached += 1
		for d in DIRS:
			var nb := c + d
			if not is_blocked(nb) and seen[_idx(nb)] == 0:
				seen[_idx(nb)] = 1
				stack.append(nb)

	_blocked[_idx(cell)] = previous
	return reached == free_total


## ============================ ALGORITHME A* ============================
## Principe : pour chaque case on calcule  f = g + h
##   g = coût réel déjà parcouru depuis le départ
##   h = estimation du coût restant jusqu'à la pièce (distance de Manhattan)
##   f = estimation du coût total du chemin passant par cette case
## On explore toujours en premier la case qui a le plus petit f.
##
## Retourne [départ, ..., arrivée], ou un tableau vide si aucun chemin n'existe.
func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var n := width * height

	# --- Initialisation des tableaux (une valeur par case de la grille) ---
	var g := PackedFloat32Array()        # meilleur coût g trouvé pour chaque case
	g.resize(n)
	g.fill(INF)                          # INF = case pas encore atteinte
	var came_from := PackedInt32Array()  # case précédente : sert à reconstruire le chemin
	came_from.resize(n)
	came_from.fill(-1)
	var closed := PackedByteArray()      # LISTE FERMÉE : cases déjà traitées définitivement
	closed.resize(n)

	# LISTE OUVERTE : cases découvertes mais pas encore traitées.
	# C'est un tas binaire (min-heap) qui renvoie toujours le plus petit f en premier.
	var heap: Array[Vector3] = []
	var start_i := _idx(start)
	var goal_i := _idx(goal)
	g[start_i] = 0.0
	_heap_push(heap, Vector3(_h(start, goal), _h(start, goal), start_i))

	# --- Boucle principale ---
	while not heap.is_empty():
		# 1) On prend dans la liste ouverte la case avec le plus petit f
		var cur := int(_heap_pop(heap).z)
		if closed[cur] == 1:
			continue                     # doublon périmé : déjà traitée avec un meilleur coût
		closed[cur] = 1                  # on la passe dans la liste fermée

		# 2) Arrivée atteinte : on remonte les "came_from" pour reconstruire le chemin
		if cur == goal_i:
			var i := goal_i
			while i != -1:
				path.append(Vector2i(i % width, i / width))
				i = came_from[i]
			path.reverse()               # on l'a construit à l'envers (arrivée -> départ)
			return path

		# 3) Sinon on examine les 4 voisins de la case courante
		var cell := Vector2i(cur % width, cur / width)
		for d in DIRS:
			var nb := cell + d
			if is_blocked(nb):           # obstacle ou hors de la grille : on ignore
				continue
			var ni := _idx(nb)
			if closed[ni] == 1:          # déjà traité : on ignore
				continue

			# Passer par `cur` pour aller au voisin coûte g(cur) + 1 (un pas)
			var tentative := g[cur] + 1.0
			if tentative < g[ni]:        # meilleur chemin vers ce voisin que ceux connus ?
				g[ni] = tentative
				came_from[ni] = cur      # on retient d'où l'on vient
				var h := _h(nb, goal)
				# on l'ajoute à la liste ouverte avec sa priorité f = g + h
				_heap_push(heap, Vector3(tentative + h, h, ni))

	# Liste ouverte vide sans avoir atteint l'arrivée : aucun chemin possible
	return path


func _h(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y))


func _idx(c: Vector2i) -> int:
	return c.y * width + c.x


static func _less(a: Vector3, b: Vector3) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


func _heap_push(heap: Array[Vector3], item: Vector3) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if not _less(heap[i], heap[parent]):
			break
		var tmp := heap[i]
		heap[i] = heap[parent]
		heap[parent] = tmp
		i = parent


func _heap_pop(heap: Array[Vector3]) -> Vector3:
	var top: Vector3 = heap[0]
	var last: Vector3 = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		while true:
			var left := 2 * i + 1
			var smallest := i
			if left < heap.size() and _less(heap[left], heap[smallest]):
				smallest = left
			if left + 1 < heap.size() and _less(heap[left + 1], heap[smallest]):
				smallest = left + 1
			if smallest == i:
				break
			var tmp := heap[i]
			heap[i] = heap[smallest]
			heap[smallest] = tmp
			i = smallest
	return top
