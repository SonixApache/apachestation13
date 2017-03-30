// The idea is to have 4 bits for coming and 4 for going.
#define TRAILS_COMING_NORTH 1
#define TRAILS_COMING_SOUTH 2
#define TRAILS_COMING_EAST  4
#define TRAILS_COMING_WEST  8
#define TRAILS_GOING_NORTH  16
#define TRAILS_GOING_SOUTH  32
#define TRAILS_GOING_EAST   64
#define TRAILS_GOING_WEST   128

// 5 seconds
#define TRAILS_CRUSTIFY_TIME   50

// color-dir-dry
var/global/list/image/bloodtrail_cache=list()

/datum/bloodtrail
	var/direction=0
	var/basecolor=DEFAULT_BLOOD
	var/wet=0
	var/fresh=1
	var/crusty=0
	var/image/overlay

/datum/bloodtrail/New(_direction,_color,_wet)
	src.direction=_direction
	src.basecolor=_color
	src.wet=_wet

// Footprints, tire trails...
/obj/effect/decal/cleanable/blood/trails
	amount = 0
	random_icon_states = null
	var/dirs=0
	icon = 'icons/effects/fluidtracks.dmi'
	icon_state = ""
	var/coming_state="blood1"
	var/going_state="blood1"
	var/updatedtrails=0

	// dir = id in stack
	var/list/setdirs=list(
		"1"=0,
		"2"=0,
		"4"=0,
		"8"=0,
		"16"=0,
		"32"=0,
		"64"=0,
		"128"=0
	)

	// List of laid trails and their colors.
	var/list/datum/bloodtrail/stack=list()


	/** DO NOT FUCKING REMOVE THIS. **/
	process()
		return PROCESS_KILL

	/**
	* Add trails to an existing trail.
	*
	* @param DNA bloodDNA to add to collection.
	* @param comingdir Direction trails come from, or 0.
	* @param goingdir Direction trails are going to (or 0).
	* @param bloodcolor Color of the blood when wet.
	*/
/obj/effect/decal/cleanable/blood/trails/resetVariables()
	stack = list()
	..("stack", "setdirs")
	setdirs=list(
		"1"=0,
		"2"=0,
		"4"=0,
		"8"=0,
		"16"=0,
		"32"=0,
		"64"=0,
		"128"=0
	)

/obj/effect/decal/cleanable/blood/trails/proc/Addtrails(var/list/DNA, var/comingdir, var/goingdir, var/bloodcolor=DEFAULT_BLOOD)
	var/updated=0
	// Shift our goingdir 4 spaces to the left so it's in the GOING bitblock.
	var/realgoing=goingdir<<4

	// When trails will start to dry out
	var/t=world.time + TRAILS_CRUSTIFY_TIME

	var/datum/bloodtrail/trail

	for (var/b in cardinal)
		// COMING BIT
		// If setting
		if(comingdir&b)
			// If not wet or not set
			if(dirs&b)
				var/sid=setdirs["[b]"]
				trail=stack[sid]
				if(trail.wet==t && trail.basecolor==bloodcolor)
					continue
				// Remove existing stack entry
				stack.Remove(trail)
			trail=new /datum/bloodtrail(b,bloodcolor,t)
			if(!istype(stack))
				stack = list()
			stack.Add(trail)
			if(!setdirs || !istype(setdirs, /list) || setdirs.len < 8 || isnull(setdirs["[b]"]))
				warning("[src] had a bad directional [b] or bad list [setdirs.len]")
				warning("Setdirs keys:")
				for(var/key in setdirs)
					warning(key)
				setdirs=list (
				"1"=0,
				"2"=0,
				"4"=0,
				"8"=0,
				"16"=0,
				"32"=0,
				"64"=0,
				"128"=0
				)
			setdirs["[b]"]=stack.Find(trail)
			updatedtrails |= b
			updated=1

		// GOING BIT (shift up 4)
		b=b<<4
		if(realgoing&b)
			// If not wet or not set
			if(dirs&b)
				var/sid=setdirs["[b]"]
				trail=stack[sid]
				if(trail.wet==t && trail.basecolor==bloodcolor)
					continue
				// Remove existing stack entry
				stack.Remove(trail)
			trail=new /datum/bloodtrail(b,bloodcolor,t)
			if(!istype(stack))
				stack = list()
			stack.Add(trail)
			if(!setdirs || !istype(setdirs, /list) || setdirs.len < 8 || isnull(setdirs["[b]"]))
				warning("[src] had a bad directional [b] or bad list [setdirs.len]")
				warning("Setdirs keys:")
				for(var/key in setdirs)
					warning(key)
				setdirs=list (
								"1"=0,
								"2"=0,
								"4"=0,
								"8"=0,
								"16"=0,
								"32"=0,
								"64"=0,
								"128"=0
							)
			setdirs["[b]"]=stack.Find(trail)
			updatedtrails |= b
			updated=1

	dirs |= comingdir|realgoing
	if(istype(DNA,/list))
		blood_DNA |= DNA.Copy()
	if(updated)
		update_icon()

/obj/effect/decal/cleanable/blood/trails/update_icon()
	// Clear everything.
	// Comment after the FIXME below is fixed.

	var/truedir=0
	//var/t=world.time

	/* FIXME: This shit doesn't work for some reason.
	   The Remove line doesn't remove the overlay given, so this is defunct.
	var/b=0
	for(var/image/overlay in overlays)
		b=overlay.dir
		if(overlay.icon_state==going_state)
			b=b<<4
		if(updatedtrails&b)
			overlays.Remove(overlay)
			//del(overlay)
	*/

	// We start with a blank canvas, otherwise some icon procs crash silently
	var/icon/flat = icon('icons/effects/fluidtracks.dmi')

	// Update ONLY the overlays that have changed.
	for(var/datum/bloodtrail/trail in stack)
		// TODO: Uncomment when the block above is fixed.
		//if(!(updatedtrails&trail.direction) && !trail.fresh)
		//	continue
		var/stack_idx=setdirs["[trail.direction]"]
		var/state=coming_state
		truedir=trail.direction
		if(truedir&240) // Check if we're in the GOING block
			state=going_state
			truedir=truedir>>4
		var/icon/add = icon('icons/effects/fluidtracks.dmi', state, truedir)
		add.SwapColor("#FFFFFF",trail.basecolor)
		overlays += add
		if(trail.basecolor == "#FF0000"||trail.basecolor == DEFAULT_BLOOD) // no dirty dumb vox scum allowed
			plane = NOIR_BLOOD_PLANE
		else
			plane = ABOVE_TURF_PLANE
		trail.fresh=0
		stack[stack_idx]=trail

	icon = flat
	updatedtrails=0 // Clear our memory of updated trails.

	
/obj/effect/decal/cleanable/blood/trails/ltrail1
	name = "wet blood trail"
	desc = "Whoops..."
	coming_state = "ltrail1"
	going_state  = ""
	desc = "Looks like someone was dragged past here."
	gender = PLURAL
	random_icon_states = null
	amount = 0
	plane = NOIR_BLOOD_PLANE

/*
/obj/effect/decal/cleanable/blood/trail
	random_icon_states = list("ltrails_1", "ltrails_2")
	absorbs_types=null
	amount = 1

/obj/effect/decal/cleanable/blood/trail/large
	random_icon_states = list("trails_1", "trails_2")
	absorbs_types=list(/obj/effect/decal/cleanable/blood/trail)
	amount = 1	
*/