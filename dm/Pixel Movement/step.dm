#define ATOM_MOVABLE_STEP_SIZE 6
#define MOB_STEP_SIZE 6
#define OBJ_STEP_SIZE 6
#define DEFAULT_STEP_DELAY 0.25

atom/movable
	step_size = ATOM_MOVABLE_STEP_SIZE
	var
		cached_step_size = ATOM_MOVABLE_STEPSIZE
		step_delay = DEFAULT_STEP_DELAY
		tmp
			last_step = -1#INF
			next_step = -1#INF
	proc
		Step(dir, delay=step_delay)
			if(next_step - world.time >= SERVER_TICK)
				return 0
			else 
				if(step(src,dir))
					last_step = world.time
					next_step = last_step + step_delay
					return 1
				else
					return 0

mob
	step_size = MOB_STEP_SIZE
	var
		block_steps = 0

	Step(dir, delay=step_delay)
		if(block_steps)
			return 0
		if(next_step - world.time >= SERVER_TICK)
			return 0
		if(step(src,dir))
			last_step = world.time
			next_step = last_step + step_delay
			return 1
		else
			return 0

obj
	step_size = OBJ_STEP_SIZE

client
	Move(atom/loc, dir)
		walk(usr,0)
		return mob.Step(dir)
	
	proc
		move_loop()
			set waitfor = 0
			var/list/k = keybinds
			while(src)
				var/move_dir = k["DpadU"].getValue() + k["DpadU"].getValue() + k["DpadL"].getValue() + k["DpadR"].getValue()
				switch(move_dir)
					if(3) 	move_dir -= 3
					if(12)	move_dir -= 12
				if(move_dir)
					mob.Step(move_dir, mob.step_size)
				sleep(SERVER_TICK)