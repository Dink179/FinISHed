extends Node2D

class_name Card

@export var max_size: int = 30
var cur_size: int = 0

# Piles - these can be shuffled:
# cards -> hand -> discard is the normal flow.
# some will be banished, some can go from hand to discard, etc.

var cards: Array = []
var discard: Array = []
var banished: Array = []
var hand: Array = []

# A deck is made up of x cards 
var inp: Array = [1,2,3,4,5,6,7,8]

var totals: Array = [0,0,0,0,0,0,0,0]

func _ready():
	cards = inp
	cards = shuffle(cards)
	hand += draw(cards, 3)
	print(cards, " ", hand)
	
#	for i in range(500):
#		inp = shuffle(inp)
#		for j in range(len(totals)):
#			totals[j] += inp[j]
#		print(inp)
#	for j in range(len(totals)):
#		totals[j] /= 500.0
#	print(totals)


func get_next():# -> Card:
	return cards.pop_front()

func draw(pile:Array, count:int) -> Array:
	var out: Array = []
	for i in range(count):
		out += [get_next()]
	return out

func shuffle(pile:Array) -> Array:
	# takes a pile and returns the shuffled pile - could add two pile arrays to reshuffle.
	var out: Array = []
	var card_count: int = len(pile)-1
	for i in range(card_count+1):
		out += [pile.pop_at(randi_range(0,card_count-i))]
	return out

func play(card:Card):# -> Card:
	pass
		


# External Functions:

func add_card(new_card:Card) -> void:
	pass

func remove_card(card:Card):# -> Card:
	pass
	
