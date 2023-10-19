extends Node

# Global Variables:

enum crd_side {
	FRONT,
	BACK,
	EXTRA
}

enum sk_type {
	PHS,	# Physical
	MAG,	# Magical
	HEL		# Heal
}

enum wpn {
	NUL,	# Classless
	DGR,	# Dagger
	SPR,	# Spear
	HMR,	# Hammer
	SHD,	# Shield
	STF,	# Staff
	GRT		# Greatsword
}

enum elm {
	NUL,	# None
	FIR,	# Fire
	ICE,	# Ice
	PSN,	# Poison
	ELC,	# Electricity
	LIF		# Life/Water
}

enum stat {
	PHS_ATK,	# Physical Attack
	PHS_DEF,	# Physical Defense
	MAG_ATK,	# Magical Attack
	MAG_DEF,	# Magical Defense
	HEALING,	# Healing
	RNG_MLT,	# Range Multiplier
	AOE_MLT,	# AOE Multiplier
	MOV_MLT		# Move Multiplier
}

var level_exp_pool: int = 0
