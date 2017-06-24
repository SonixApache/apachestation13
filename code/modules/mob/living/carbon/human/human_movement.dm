/mob/living/carbon/human/movement_delay()
	if(isslimeperson(src))
		if (bodytemperature >= 330.23) // 135 F
			return min(..(), 1)
	return ..()

/mob/living/carbon/human/base_movement_tally()
	. = ..()

	if(flying)
		return // Calculate none of the following because we're technically on a vehicle
	if(reagents.has_any_reagents(list(HYPERZINE,COCAINE)))
		return // Hyperzine ignores slowdown
	if(istype(loc, /turf/space))
		return // Space ignores slowdown

	if (species && species.move_speed_mod)
		. += species.move_speed_mod

	var/hungry = (500 - nutrition)/5 // So overeat would be 100 and default level would be 80
	if (hungry >= 70)
		. += hungry/50

	if (isslimeperson(src))
		if (bodytemperature < 183.222)
			. += (283.222 - bodytemperature) / 10 * 175 // MAGIC NUMBERS!
	else if (undergoing_hypothermia())
		. += 2*undergoing_hypothermia()

	if(feels_pain() && !has_painkillers())
		if(pain_shock_stage >= 50)
			. += 3

		for(var/organ_name in list(LIMB_LEFT_FOOT,LIMB_RIGHT_FOOT,LIMB_LEFT_LEG,LIMB_RIGHT_LEG))
			var/datum/organ/external/E = get_organ(organ_name)
			if(!E || (E.status & ORGAN_DESTROYED))
				. += 4
			if(E.status & ORGAN_SPLINTED)
				. += 0.5
			else if(E.status & ORGAN_BROKEN)
				. += 1.5

/mob/living/carbon/human/movement_tally_multiplier()
	. = ..()

	if(!reagents.has_any_reagents(list(HYPERZINE,COCAINE)))
		if(!shoes)
			. *= NO_SHOES_SLOWDOWN
	if(M_FAT in mutations) // hyperzine can't save you, fatty!
		. *= 1.5
	if(M_RUN in mutations)
		. *= 0.8

	if(reagents.has_reagent(NUKA_COLA))
		. *= 0.8

	if(isslimeperson(src))
		if(reagents.has_any_reagents(list(HYPERZINE,COCAINE)))
			. *= 2
		if(reagents.has_reagent(FROSTOIL))
			. *= 5
	// Bomberman stuff
	var/skate_bonus = 0
	var/disease_slow = 0
	for(var/obj/item/weapon/bomberman/dispenser in src)
		disease_slow = max(disease_slow, dispenser.slow)
		skate_bonus = max(skate_bonus, dispenser.speed_bonus) // if the player is carrying multiple BBD for some reason, he'll benefit from the speed bonus of the most upgraded one

	if(skate_bonus > 1)
		. *= 1/skate_bonus
	if(disease_slow > 0)
		. *= disease_slow * 6


/mob/living/carbon/human/Process_Spacemove(var/check_drift = 0)
	//Can we act
	if(restrained())
		return 0

	//Do we have a working jetpack
	if(istype(back, /obj/item/weapon/tank/jetpack))
		var/obj/item/weapon/tank/jetpack/J = back
		if(((!check_drift) || (check_drift && J.stabilization_on)) && (!lying) && (J.allow_thrust(0.01, src)))
			inertia_dir = 0
			return 1
//		if(!check_drift && J.allow_thrust(0.01, src))
//			return 1

	//If no working jetpack then use the other checks
	return ..()


/mob/living/carbon/human/Process_Spaceslipping(var/prob_slip = 5)
	//If knocked out we might just hit it and stop.  This makes it possible to get dead bodies and such.
	if(stat)
		prob_slip = 0 // Changing this to zero to make it line up with the comment, and also, make more sense.

	//Do we have magboots or such on if so no slip
	if(CheckSlip() < 0)
		prob_slip = 0

	//Check hands and mod slip
	for(var/i = 1 to held_items.len)
		var/obj/item/I = held_items[i]

		if(!I)
			prob_slip -= 2
		else if(I.w_class <= W_CLASS_SMALL)
			prob_slip -= 1

	prob_slip = round(prob_slip)
	return(prob_slip)

/mob/living/carbon/human/Move(NewLoc, Dir = 0, step_x = 0, step_y = 0)
	var/old_z = src.z

	. = ..(NewLoc, Dir, step_x, step_y)

	/*if(status_flags & FAKEDEATH)
		return 0*/

	if(.)
		if (old_z != src.z)
			crewmonitor.queueUpdate(old_z)
		crewmonitor.queueUpdate(src.z)

		if(shoes && istype(shoes, /obj/item/clothing/shoes))
			var/obj/item/clothing/shoes/S = shoes
			S.step_action()

		if(wear_suit && istype(wear_suit, /obj/item/clothing/suit))
			var/obj/item/clothing/suit/SU = wear_suit
			SU.step_action()

		for(var/obj/item/weapon/bomberman/dispenser in src)
			if(dispenser.spam_bomb)
				dispenser.attack_self(src)
				
		/* Drag damage is here!*/
		if(pulledby)
			if (lying)
				var/turf/T = loc
				var/turf/simulated/TS = loc
				var/list/damaged_organs = get_broken_organs()
				var/list/bleeding_organs = get_bleeding_organs()
				if (T.has_gravity())
					if (damaged_organs) //to prevent massive runtimes
						if (damaged_organs.len) //to make sure 
							if(!isincrit())
								if(prob(getBruteLoss() / 5)) //Chance for damage based on current damage
									for(var/datum/organ/external/damagedorgan in damaged_organs)
										if((damagedorgan.brute_dam) < damagedorgan.max_damage) //To prevent organs from accruing thousands of damage
											apply_damage(2, BRUTE, damagedorgan)
											visible_message("<span class='warning'>The wounds on \the [src]'s [damagedorgan.display_name] worsen from being dragged!</span>")
											UpdateDamageIcon()
							else
								if(prob(15))
									for(var/datum/organ/external/damagedorgan in damaged_organs)
										if((damagedorgan.brute_dam) < damagedorgan.max_damage)
											apply_damage(4, BRUTE, damagedorgan)
											visible_message("<span class='warning'>The wounds on \the [src]'s [damagedorgan.display_name] worsen terribly from being dragged!</span>")
											add_logs(pulledby, src, "caused drag damage to", admin = (ckey))
											UpdateDamageIcon()
					
					if (bleeding_organs)
						if (bleeding_organs.len)
							var/blood_volume = round(src:vessel.get_reagent_amount("blood"))
							/*Sometimes species with NO_BLOOD get blood, hence weird check*/
							if(blood_volume > 0 || (species.anatomy_flags & NO_BLOOD))
								if(isturf(loc))
									if(!isincrit())
										if (prob(100)) //for testing
										//if(prob(blood_volume / 89.6)) //Chance to bleed based on blood remaining

											//var/obj/effect/decal/cleanable/blood/tracks/BTV = new(loc)
											//BTV.color = species.blood_color

											//newloc.AddTracks(/obj/effect/decal/cleanable/blood/tracks/dragtrail,get_blood_DNA(src),dir,dir,species.blood_color)
											
											if(istype(TS))
												TS.AddTracks(/obj/effect/decal/cleanable/blood/tracks/dragtrail,get_blood_DNA(),0,Dir,species.blood_color)
											vessel.remove_reagent("blood",1) //set back to 4 after testing
											visible_message("<span class='warning'>\The [src] loses some blood from being dragged!</span>")
									else
										if(prob(blood_volume / 44.8)) //Crit mode means double chance of blood loss
											
											//var/obj/effect/decal/cleanable/blood/tracks/dragtrail/large/LBTV = new(loc)
											/*if (!(inertia_dir == inertia_dir))														
												if (inertia_dir == 1 || inertia_dir == 2)
													LBTV.dir = (inertia_dir + inertia_dir)
												else															
													if (inertia_dir == 4 &&  inertia_dir == 2)
														LBTV.dir = 6
													if (inertia_dir == 4 &&  inertia_dir == 1)
														LBTV.dir = 10
													if (inertia_dir == 8 &&  inertia_dir == 2)
														LBTV.dir = 5
													if (inertia_dir == 8 &&  inertia_dir == 1)
														LBTV.dir = 9
											else
												LBTV.dir = inertia_dir*/
											//LBTV.color = species.blood_color
											vessel.remove_reagent("blood",8)
											visible_message("<span class='danger'>\The [src] loses a lot of blood from being dragged!</span>")
											add_logs(pulledby, src, "caused drag damage bloodloss to", admin = (ckey))

/mob/living/carbon/human/CheckSlip()
	. = ..()
	if(. && shoes && shoes.clothing_flags & NOSLIP)
		. = (istype(shoes, /obj/item/clothing/shoes/magboots) ? -1 : 0)
	return .