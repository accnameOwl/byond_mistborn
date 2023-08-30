
proc
	atan2dir(x,y)
		if(!(x||y))
			return 0
		. = (y>=0 ? arccos(x/sqrt(x*x+y*y)) : 360-arccos(x/sqrt(x*x+y*y)))
		switch(.)
			if(22.5 to 67.5)
				return NORTHEAST
			if(67.5 to 112.5)
				return NORTH
			if(112.5 to 157.5)
				return NORTHWEST
			if(157.5 to 202.5)
				return WEST
			if(202.5 to 247.5)
				return SOUTHWEST
			if(247.5 to 292.5)
				return SOUTH
			if(292.5 to 337.5)
				return SOUTHEAST
			else
				return EAST

#define KEYTAP_DURATION 2.5
var/list/__dir2padaxis = list(null,"U","D",null,
							  "R","UR","DR","R",
							  "L","UL","DL","L",
							  null,"U","D",null)
//dir2pad axis will convert a BYOND dir integer into a pad axis string U/D L/R format.
#define dir2padaxis(d) (__dir2padaxis[((d)&15)+1])

//key_name_swap is used to change some default keybind names to be more representative of the keys that they correspond with.
var/list/key_name_swap = list(
		"North"=			"ArrowU",
		"South"=			"ArrowD",
		"East"=				"ArrowR",
		"West"=				"ArrowL",
		"Northwest"=		"Home",
		"Northeast"=		"Pgup",
		"Southeast"=		"Pgdn",
		"Southwest"=		"End",
		"GamepadUp"=		"DpadU",
		"GamepadDown"=		"DpadD",
		"GamepadLeft"=		"DpadL",
		"GamepadRight"=		"DpadR",
		"GamepadUpLeft"=	"DpadUL",
		"GamepadUpRight"=	"DpadUR",
		"GamepadDownLeft"=	"DpadDL",
		"GamepadDownRight"=	"DpadDR",
		"GamepadFace1" =	"Face1",
		"GamepadFace2" =	"Face2",
		"GamepadFace3" =	"Face3",
		"GamepadFace4" =	"Face4",
		"GamepadSelect" =	"Select",
		"GamepadStart"	=	"Start",
		"GamepadL1"	=		"L1",
		"GamepadL2" =		"L2",
		"GamepadL3"	=		"L3",
		"GamepadR1"	=		"R1",
		"GamepadR2"	=		"R2",
		"GamepadR3"	=		"R3",
		"GamepadR3"	=		"R3")

var/list/key_refuse_input = list(
		"GamepadUp"=		1,
		"GamepadDown"=		1,
		"GamepadLeft"=		1,
		"GamepadRight"=		1,
		"GamepadUpLeft"=	1,
		"GamepadUpRight"=	1,
		"GamepadDownLeft"=	1,
		"GamepadDownRight"=	1)

//keybind datums house data particular to a bind. Binds correspond to controls that can use multiple keys to report a true/false state, and store time and multi-tap data.
keybind
	var
		id
		list/keys
		value = 1
		state = 0
		time = -1#INF
		taps = 1

	New(id=src.id,keys=src.keys,value=1)
		src.id = id
		src.keys = keys
		src.value = value

	proc
		getValue()
			return state>0 ? value : 0

//keyaxis datums house data particular to an axis. These correspond to gamepad analog sticks and allows you to read analog information from a stick at any time.
#define AXIS_4DIR 0
#define AXIS_8DIR 1

keyaxis
	var
		id
		x = 0
		y = 0
		dir = 0
		format = AXIS_8DIR

	New(id=src.id,format=AXIS_8DIR)
		src.id = id
		src.format = format

client
	var
		refuse_input = 1

		list/axisbinds
		list/keybinds
		list/bound_keys
		list/held_keys

		last_key
		key_taps
		tap_start = -1#INF
	verb
		//called when a button is pressed on the keyboard and from many gamepad buttons
		keydown(key as text|null)
			set instant = 1
			set hidden = 1
			if(refuse_input || key_refuse_input[key]) return 0

			key = key_name_swap[key]||key
			. = 0
			//store current time and attempt to locate a bound command id from the key name
			var/time = world.time
			var/keybind/bind = bound_keys[key]

			//maintain multi-tap state
			if(last_key==key && (time-tap_start)<KEYTAP_DURATION)
				++key_taps
			else
				last_key = key
				key_taps = 1
				tap_start = time

			//allow onRawPress to consume the input event to prevent keybind calling
			if(onRawPress(key))
				//associate the current key with a bind id or "none" if no bind on that key
				if(bind)
					held_keys[key] = bind
					bind.keys[key] = 1

					//only update the bind information on the first held key.
					if(++bind.state==1)
						bind.time = time
						bind.taps = key_taps
						. = onBindPress(key,bind)
					else
						return 0

			//mark the key as held to no bind if a bind hasn't claimed the keypress.
			if(!.)
				held_keys[key] = "none"

		//called when a button is released on the keyboard and from many gamepad buttons
		keyup(key as text|null)
			set instant = 1
			set hidden = 1
			if(refuse_input || key_refuse_input[key]) return 0

			key = key_name_swap[key]||key
			. = 0
			//store current time and attempt to associate a held binding
			var/time = world.time
			var/keybind/bind = held_keys[key]

			//prevent unintentional multitap sequences
			if(last_key!=key)
				tap_start = -1#INF

			//if the key is marked as held, clear the held key.
			if(bind)
				held_keys -= key

			//allow onRawRelease to consume the input event to prevent
			if(onRawRelease(key))
				//if the key is bound to a bind, update the bind state
				if(bind && bind!="none")
					bind.keys[key] = 0

					//only update the bind information on the last released key.
					if(!--bind.state)
						. = onBindRelease(key,bind)
						bind.time = time
						bind.taps = 1
					else if(bind.state<0)
						bind.state = 0

		//called when an analog stick's values change. By default, this updates bound keyaxis datum variables and then refires the impulse as though it were a button.
		padaxis(axis as text|null,x as text|null,y as text|null)
			set instant = 1
			set hidden = 1
			if(refuse_input) return

			//look up the axis by name
			var/keyaxis/a = axisbinds[axis]
			var/o,d
			if(a)
				//store useful information about the axis
				a.x = (x = text2num(x)||0)
				a.y = (y = text2num(y)||0)
				o = a.dir
				a.dir = (d = atan2dir(x,y))

				//if the direction of the axis has changed, we need to convert everything into key events
				if(o!=d)
					switch(a.format)
						//4 dir format treats axes as being bound to a 4-key input system similar to WASD input.
						if(AXIS_4DIR)
							var/s, h, v
							//determine which keys were released during this update if any
							if(o)
								s = (o ^ d) & o //binary math to get changed off bits

								//split the bitmask into horizontal components and get the axis string to build the key input
								h = s & 12; h = dir2padaxis(h)
								if(h)
									//if there are any horizontal changes, fire a key event
									keyup("[axis][h]")

								//split the bitmask into vertical components and get the axis string to build the key input
								v = s & 3; v = dir2padaxis(v)
								if(v)
									//if there are any vertical changes, fire a key event
									keyup("[axis][v]")

							//determine which keys were pressed during this update if any
							if(d)
								s = (o ^ d) & d //binary math to get changed on bits

								//split the bitmask into horizontal components and get the axis string to build the key input
								h = s & 12; h = dir2padaxis(h)
								if(h)
									//if there are any horizontal changes, fire a key event
									keydown("[axis][h]")

								//split the bitmask into vertical components and get the axis string to build the key input
								v = s & 3; v = dir2padaxis(v)
								if(v)
									//if there are any vertical changes, fire a key event
									keydown("[axis][v]")

						//8 dir format treats axes as being bound to an 8-key input system similar to numpad input.
						if(AXIS_8DIR)
							//no need for fancy math. Each dir change means a change in keybind states
							if((o = dir2padaxis(o)))
								keyup("[axis][o]")
							if((d = dir2padaxis(d)))
								keydown("[axis][d]")

		//called when the player uses the dpad.
		paddir(dir as text|null)
			set instant = 1
			set hidden = 1
			//refire the dpad input as though it were a bound axis input with the axis name "Dpad"
			dir = text2num(dir)
			padaxis("Dpad","[(dir&EAST ? 1 : 0) + (dir&WEST ? -1 : 0)]","[(dir&NORTH ? 1 : 0) + (dir&SOUTH ? -1 : 0)]")

	proc
		//hook for responding to raw button responses without any concern for binds.
		//return 1 to allow binds to grab the key, return 0 to disallow it.
		onRawPress(key)
			return 1

		//hook for responding to raw button releases without any concern for binds.
		//return 1 to allow binds to grab the key, return 0 to disallow it.
		onRawRelease(key)
			return 1

		//hook for responding to bind actions.
		onBindPress(key,keybind/bind)
			return 1

		//hook for responding to bind actions.
		onBindRelease(key,keybind/bind)
			return 1

		//Initializes default control scheme.
		buildControls()
			//TODO: Load control configurations from client-side savefile.
			axisbinds = list()
			axisbinds["Lstick"] = new/keyaxis("Lstick",AXIS_4DIR)
			axisbinds["Rstick"] = new/keyaxis("Rstick",AXIS_4DIR)
			axisbinds["Dpad"] = new/keyaxis("Dpad",AXIS_4DIR)

			keybinds = list()
			keybinds["DpadU"] = new/keybind("DpadU",list("W","ArrowU"),1)
			keybinds["DpadD"] = new/keybind("DpadD",list("S","ArrowD"),2)
			keybinds["DpadR"] = new/keybind("DpadR",list("D","ArrowR"),4)
			keybinds["DpadL"] = new/keybind("DpadL",list("A","ArrowL"),8)

			keybinds["1"] = new/keybind("1","1")

			bound_keys = list()
			var/id, keybind/k, key
			for(id in keybinds)
				k = keybinds[id]
				for(key in k.keys)
					bound_keys[key] = k

			held_keys = list()
			refuse_input = 0

	New()
		. = ..()
		if(.)
			buildControls()

	Del()
		bound_keys = null
		axisbinds = null
		keybinds = null
		held_keys = null
		..()