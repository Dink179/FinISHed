extends Node2D

class_name Deck

@onready var deck_pile: Node2D = $Deck_Pile
@onready var discard_pile: Node2D = $Discard_Pile
@onready var banished_pile: Node2D = $Banished_Pile
@onready var hand_pile: Node2D = $Hand_Pile

#! these can probably be generated on the spot as needed....
@onready var temp1_pile: Node2D = $Temp1_Pile
@onready var temp2_pile: Node2D = $Temp2_Pile
@onready var shuffle_pile: Node2D = $Shuffle_Pile
#- and these
@onready var deck_label: Label = $Deck
@onready var hand_label: Label = $Hand
@onready var discard_label: Label = $Discard

#-:
@onready var Card_: PackedScene = preload("res://Prefabs/card.tscn")


@export var max_size: int = 30
var cur_size: int = 0

# Piles - these can be shuffled:
# cards -> hand -> discard is the normal flow.
# some will be banished, some can go from hand to discard, etc.



# deck built outside dungeon
	# add card to deck
	# remove card from the deck
	# see card info...
	# know how big the deck is
	# how big it can be
	#! that's it outside the dungeon...
	
	# Card Pool in general - like a library #! not really part of a deck
		# make it so 10 is the max for now...
		# LIBRARY CLASS FOR DISPLAYING A DECK
	
	# Card Forge
		# fuse cards together

# in dungeon:
	# play card
	# discard
	# banish
	# reshuffle (remaining deck, discard+remaining deck, hand + all, etc.)
	# draw card (x cards),
	# stack
	# peek
	# replace
	
	







#var cards: Array = []
#var discard: Array = []
#var banished: Array = []
#var hand: Array = []

# A deck is made up of x cards 
var inp: Array = [1,2,3,4,5,6,7,8]

var totals: Array = [0,0,0,0,0,0,0,0]

func _ready():
#	cards = inp
#	cards = shuffle(cards)
#	hand += draw(cards, 3)
#	print(cards, " ", hand)
	for i in range(8):
		var card: Card = Card_.instantiate()
		card.value = i
		deck_pile.add_child(card)
	
	print_pile(deck_pile, deck_label)
	print_pile(hand_pile, hand_label)
	print_pile(discard_pile, discard_label)
#
#	shuffle([deck_pile], deck_pile)
#	print_pile(deck_pile)
#	shuffle([deck_pile], deck_pile)
#	print_pile(deck_pile)
#	shuffle([deck_pile], deck_pile)
#	print_pile(deck_pile)
#	shuffle([deck_pile], deck_pile)
#	print_pile(deck_pile)
#
#	draw(deck_pile, hand_pile, 3, false)
#	print_pile(deck_pile)
#	print_pile(hand_pile)
#	print_pile(discard_pile)
#
#	play_card(hand_pile.get_child(0), discard_pile)
#	play_card(hand_pile.get_child(0), discard_pile)
#	play_card(hand_pile.get_child(0), discard_pile)
#	print_pile(deck_pile)
#	print_pile(hand_pile)
#	print_pile(discard_pile)
#
#	draw(deck_pile, hand_pile, 3, false)
#	shuffle([deck_pile, discard_pile], deck_pile)
#	print_pile(deck_pile)
#	print_pile(hand_pile)
#	print_pile(discard_pile)

func _process(_delta) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		draw(deck_pile, hand_pile, 3, false)
	if Input.is_action_just_pressed("ui_up"):
		play_card(hand_pile.get_child(0), discard_pile)
	if Input.is_action_just_pressed("ui_down"):
		shuffle([deck_pile, discard_pile], deck_pile)
	if Input.is_action_just_pressed("ui_right"):
		play_card(hand_pile.get_child(0), banished_pile)
	if Input.is_action_just_pressed("ui_left"):
		print()
	print_pile(deck_pile, deck_label)
	print_pile(hand_pile, hand_label)
	print_pile(discard_pile, discard_label)
	
#- debug:
func print_pile(pile:Node2D, label:Label) -> void:
	var out: String = "["
	for card in pile.get_children():
		out += str(card.value) + " "
	out += "]"
	label.text = str(out)
	#print(out)
	
#	for i in range(500):
#		inp = shuffle(inp)
#		for j in range(len(totals)):
#			totals[j] += inp[j]
#		print(inp)
#	for j in range(len(totals)):
#		totals[j] /= 500.0
#	print(totals)

func draw(from_pile:Node2D, to_pile:Node2D, count:int, animated:bool) -> void:
	# Reparent each child in order from the from_pile to the to_pile.
	for i in range(min(count, from_pile.get_child_count())):
		if animated:
			pass
			#! CALL THE CARD ANIMATION
		move_to(from_pile.get_child(0), to_pile)
		#from_pile.get_child(0).reparent(to_pile)

func shuffle(piles:Array, to_pile:Node2D) -> void:
	# Takes in piles to shuffle - shuffled cards get added to to_pile.
	for pile in piles:
		draw(pile, shuffle_pile, pile.get_child_count(), false)
	var card_count: int = shuffle_pile.get_child_count()-1
	for i in range(card_count+1):
		#shuffle_pile.get_child(randi_range(0, card_count-i)).reparent(to_pile)
		move_to(shuffle_pile.get_child(randi_range(0, card_count-i)), to_pile)

func stack(top:Node2D, bottom:Node2D, to_pile:Node2D, animated:bool):
	# Stacks cards in the top pile on top of the bottom pile - stacked cards get added to to_pile.
	#! animated will need to be an animation key... not exactly sure how these will look working like this:
	draw(bottom, top, bottom.get_child_count(), animated)
	draw(top, to_pile, top.get_child_count(), animated)

#- dont think we'll need this - should all come directly from card...
func play_card(card:Card, to_pile:Node2D) -> void:
	card.play()
	#card.reparent(to_pile)
	move_to(card, to_pile)

func move_to(card:Card, to_pile:Node2D) -> void:
	# Moves a card to to_pile.
	if to_pile == hand_pile:
		card.flip(gb.s.FRONT, false)
	else:
		card.flip(gb.s.BACK, false)
	card.reparent(to_pile)
	card.position = card.targ_pos # force position update?

# External Functions:

func add_card(new_card:Card) -> void:
	pass

func remove_card(card:Card):# -> Card:
	pass
	
