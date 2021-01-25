/obj/item/flamethrower
	name = "flamethrower"
	desc = "You are a firestarter!"
	icon = 'icons/obj/flamethrower.dmi'
	icon_state = "flamethrowerbase"
	item_state = "flamethrower_0"
	obj_flags = OBJ_FLAG_CONDUCTIBLE
	force = 3.0
	throwforce = 10.0
	throw_speed = 1
	throw_range = 5
	w_class = ITEM_SIZE_LARGE
	origin_tech = "{'combat':1}"
	material = /decl/material/solid/metal/steel
	var/status = 0
	var/throw_amount = 100
	var/lit = 0	//on or off
	var/operating = 0//cooldown
	var/turf/previousturf = null
	var/obj/item/weldingtool/weldtool = null
	var/obj/item/assembly/igniter/igniter = null
	var/obj/item/tank/tank = null


/obj/item/flamethrower/Destroy()
	QDEL_NULL(weldtool)
	QDEL_NULL(igniter)
	QDEL_NULL(tank)
	. = ..()

/obj/item/flamethrower/Process()
	if(!lit)
		STOP_PROCESSING(SSobj, src)
	else
		var/turf/location = get_turf(src)
		location?.hotspot_expose(700, 2)

/obj/item/flamethrower/on_update_icon()
	overlays.Cut()
	if(igniter)
		overlays += "+igniter[status]"
	if(tank)
		if(istype(tank, /obj/item/tank/hydrogen))
			overlays += "+htank"
		else
			overlays += "+ptank"
	if(lit)
		overlays += "+lit"
		item_state = "flamethrower_1"
	else
		item_state = "flamethrower_0"
	return

/obj/item/flamethrower/afterattack(atom/target, mob/user, proximity)
	// Make sure our user is still holding us
	if(user && user.get_active_hand() == src)
		if(user.a_intent == I_HELP) //don't shoot if we're on help intent
			to_chat(user, "<span class='warning'>You refrain from firing \the [src] as your intent is set to help.</span>")
			return
		var/turf/target_turf = get_turf(target)
		if(target_turf)
			var/turflist = getline(user, target_turf)
			flame_turf(turflist)

/obj/item/flamethrower/attackby(obj/item/W, mob/user)
	if(user.stat || user.restrained() || user.lying)	return
	if(isWrench(W) && !status)//Taking this apart
		if(weldtool)
			weldtool.dropInto(loc)
			weldtool = null
		if(igniter)
			igniter.dropInto(loc)
			igniter = null
		if(tank)
			tank.dropInto(loc)
			tank = null
		new /obj/item/stack/material/rods(get_turf(src))
		qdel(src)
		return

	if(isScrewdriver(W) && igniter && !lit)
		status = !status
		to_chat(user, "<span class='notice'>[igniter] is now [status ? "" : "un"]secured!</span>")
		update_icon()
		return

	if(isigniter(W))
		var/obj/item/assembly/igniter/I = W
		if(I.secured)	return
		if(igniter)		return
		if(!user.unEquip(I, src))
			return
		igniter = I
		update_icon()
		return

	if(istype(W,/obj/item/tank))
		if(tank)
			to_chat(user, "<span class='notice'>There appears to already be a fuel tank loaded in [src]!</span>")
			return
		if(!user.unEquip(W, src))
			return
		tank = W
		update_icon()
		return

	if(istype(W, /obj/item/scanner/gas))
		var/obj/item/scanner/gas/A = W
		A.analyze_gases(src, user)
		return
	..()
	return


/obj/item/flamethrower/attack_self(mob/user)
	if(user.stat || user.restrained() || user.lying)	return
	user.set_machine(src)
	if(!tank)
		to_chat(user, "<span class='notice'>Attach a fuel tank first!</span>")
		return
	var/dat = text("<TT><B>Flamethrower (<A HREF='?src=\ref[src];light=1'>[lit ? "<font color='red'>Lit</font>" : "Unlit"]</a>)</B><BR>\n Tank Pressure: [tank.air_contents.return_pressure()]<BR>\nAmount to throw: <A HREF='?src=\ref[src];amount=-100'>-</A> <A HREF='?src=\ref[src];amount=-10'>-</A> <A HREF='?src=\ref[src];amount=-1'>-</A> [throw_amount] <A HREF='?src=\ref[src];amount=1'>+</A> <A HREF='?src=\ref[src];amount=10'>+</A> <A HREF='?src=\ref[src];amount=100'>+</A><BR>\n<A HREF='?src=\ref[src];remove=1'>Remove fuel tank</A> - <A HREF='?src=\ref[src];close=1'>Close</A></TT>")
	show_browser(user, dat, "window=flamethrower;size=600x300")
	onclose(user, "flamethrower")
	return

/obj/item/flamethrower/return_air()
	if(tank)
		return tank.return_air()

/obj/item/flamethrower/Topic(href,href_list[])
	if(href_list["close"])
		usr.unset_machine()
		close_browser(usr, "window=flamethrower")
		return
	if(usr.stat || usr.restrained() || usr.lying)	return
	usr.set_machine(src)
	if(href_list["light"])
		if(!tank)	return
		if(tank.air_contents.get_by_flag(XGM_GAS_FUEL) <  1)	return
		if(!status)	return
		lit = !lit
		if(lit)
			START_PROCESSING(SSobj, src)
	if(href_list["amount"])
		throw_amount = throw_amount + text2num(href_list["amount"])
		throw_amount = max(50, min(5000, throw_amount))
	if(href_list["remove"])
		if(!tank)	return
		usr.put_in_hands(tank)
		tank = null
		lit = 0
		usr.unset_machine()
		close_browser(usr, "window=flamethrower")
	for(var/mob/M in viewers(1, loc))
		if((M.client && M.machine == src))
			attack_self(M)
	update_icon()
	return


//Called from turf.dm turf/dblclick
/obj/item/flamethrower/proc/flame_turf(turflist)
	if(!lit || operating)	return
	operating = 1
	for(var/turf/T in turflist)
		if(T.density || isspaceturf(T))
			break
		if(!previousturf && length(turflist)>1)
			previousturf = get_turf(src)
			continue	//so we don't burn the tile we be standin on
		if(previousturf && LinkBlocked(previousturf, T))
			break
		ignite_turf(T)
		sleep(1)
	previousturf = null
	operating = 0
	for(var/mob/M in viewers(1, loc))
		if((M.client && M.machine == src))
			attack_self(M)

/obj/item/flamethrower/proc/ignite_turf(turf/target)
	//TODO: DEFERRED Consider checking to make sure tank pressure is high enough before doing this...
	//Transfer 5% of current tank air contents to turf
	var/datum/gas_mixture/air_transfer = tank.remove_air_ratio(0.02*(throw_amount/100))
	var/obj/effect/fluid/F = locate() in target
	if(!F) F = new(target)
	F.reagents.add_reagent(/decl/material/liquid/fuel, air_transfer.get_by_flag(XGM_GAS_FUEL))
	air_transfer.remove_by_flag(XGM_GAS_FUEL, 0)
	target.assume_air(air_transfer)
	//Burn it based on transfered gas
	//target.hotspot_expose(part4.air_contents.temperature*2,300)
	target.hotspot_expose((tank.air_contents.temperature*2) + 380,500) // -- More of my "how do I shot fire?" dickery. -- TLE
	//location.hotspot_expose(1000,500,1)

/obj/item/flamethrower/full/Initialize()
	. = ..()
	weldtool = new /obj/item/weldingtool(src)
	weldtool.status = 0
	igniter = new /obj/item/assembly/igniter(src)
	igniter.secured = 0
	status = 1
	update_icon()
