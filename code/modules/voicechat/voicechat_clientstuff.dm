/datum/controller/subsystem/voicechat/proc/toggle_active(userCode, is_active)
	if(!userCode || isnull(is_active))
		// CRASH("null params {userCode: [userCode || "null"], is_active: [is_active || "null"]}")
		return
	var/client/C = locate(userCode_client_map[userCode])
	var/atom/M = C.mob
	var/image/speaker = image('icons/hud/voicechat/speaker.dmi', pixel_y=32, pixel_x=8)
	if(is_active)
		M.overlays += speaker
	else
		M.overlays -= speaker

// cant unmute from ingame for security reasons
/datum/controller/subsystem/voicechat/proc/mute_mic(mob_ref, deafen=FALSE)
	if(!mob_ref)
		return
	var/userCode = client_userCode_map[mob_ref]
	if(!userCode)
		return
	var/params = alist(cmd = deafen ? "deafen" : "mute_mic", userCode = userCode)
	send_json(params)


/datum/controller/subsystem/voicechat/proc/join_vc(client/C)
	if(!C)
		return
	//check if client already connected
	var/check_userCode = client_userCode_map[ref(C)]
	if(check_userCode)
		disconnect(check_userCode, from_byond= TRUE)

	//so we want something somewhat random as the player can modify this easily
	var/sessionId = md5("[world.time][rand()][world.realtime][rand(0,9999)][C.address][C.computer_id]")
	//the user code cant be modified because its associated session id server side, so its somewhat secure.
	var/userCode = generate_userCode(C)
	if(!userCode)
		return
	// until LummoxJR gives us a usable web browser with microphone access,
	// we use an external browser
	C << link("https://[world.internet_address]:[src.node_port]?sessionId=[sessionId]")
	var/list/paramstuff = alist(cmd="register", userCode= userCode, sessionId= sessionId)
	send_json(paramstuff)
	link_userCode_client(userCode, C)
	/// once page is loaded and user allows mic perms, confirm_userCode gets called

//called with both browser is paired and mic access granted
/datum/controller/subsystem/voicechat/proc/confirm_userCode(userCode)
	if(!userCode || (userCode in vc_clients))
		return

	// sanity check
	if(!locate(userCode_client_map[userCode]))
		return

	vc_clients += userCode
	world.log << "confirmed [userCode]"
	post_confirm(userCode)


/datum/controller/subsystem/voicechat/proc/post_confirm(userCode)
	//move_user to zlevel as default room
	var/client/C = userCode_client_map[userCode]
	var/mob/M = C.mob
	if(!C || !M)
		disconnect(userCode, from_byond= TRUE)
		return
	// there is no explicit signal when a client switches mob, so check client.mob everytime
	RegisterSignal(M, COMSIG_MOVABLE_Z_CHANGED, COMSIG_LIVING_DEATH, COMSIG_LIVING_REVIVE, COMSIG_LIVING_STATUS_UNCONSCIOUS, PROC_REF(room_update))
	var/datum/mind/mind = M.mind
	if(mind)
		RegisterSignal(mind, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF, PROC_REF(on_mind_change))

	RegisterSignal(C, COMSIG_CLIENT_MOB_LOGIN, PROC_REF(on_mob_change))

/datum/controller/subsystem/voicechat/proc/on_mob_change(client/source, mob/M)
	RegisterSignal(M, COMSIG_MOVABLE_Z_CHANGED, COMSIG_LIVING_DEATH, COMSIG_LIVING_REVIVE, COMSIG_LIVING_STATUS_UNCONSCIOUS, PROC_REF(room_update))
	var/datum/mind/mind = M.mind
	if(mind)
		RegisterSignal(mind, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF, PROC_REF(on_mind_change))
	room_update(mob/source)

/datum/controller/subsystem/voicechat/proc/on_mind_change(datum/mind/source, mob/old_mob)
	var/mob/M = source.current
	if(!M)
		//somethings fucked so we try to find a client to disconnect
		var/client/C = old_mob.client
		var/userCode = client_userCode_map[ref(C)]
		if(!C || !userCode)
			// CRASH("couldnt find mob, and no client found to disconnect {M: [M || "null"], C: [C || "null"]}")
			return
		disconnect(userCode, from_byond= TRUE)
	UnregisterSignal(old_mob, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF)
	room_update(M)


/datum/controller/subsystem/voicechat/proc/room_update(mob/source)
	///first check the client and ensure the client is in the list
	var/client/C = source.client
	var/userCode = client_userCode_map[ref(C)]
	if(!C || !userCode)
		UnregisterSignal(source, list(COMSIG_MOVABLE_Z_CHANGED, COMSIG_LIVING_DEATH, COMSIG_LIVING_STATUS_UNCONSCIOUS))
		return
	var/room
	switch(source.stat)
		if(CONSCIOUS to SOFT_CRIT)
			room = num2text(source.z)
		if(UNCONSCIOUS to HARD_CRIT)
			room = null
		else //dead
			room = "ghost"
	move_userCode_to_room(userCode, room)


// usually called from node if the client closes the browser.
// if from_byond tell node to disconnect the browser and clean up
/datum/controller/subsystem/voicechat/proc/disconnect(userCode, from_byond= FALSE)
	if(!userCode)
		// CRASH("{userCode: [userCode || "null"]}")
		return

	toggle_active(userCode, FALSE)
	var/room = userCode_room_map[userCode]
	if(room)
		current_rooms[room] -= userCode

	var/client_ref = userCode_client_map[userCode]

	UnregisterSignal(locate(client_ref), COMSIG_CLIENT_MOB_LOGIN)
	userCode_client_map.Remove(userCode)
	client_userCode_map.Remove(client_ref)
	userCode_room_map.Remove(userCode)
	vc_clients -= userCode

	if(from_byond)
		send_json(alist(cmd="disconnect", userCode=userCode))


// quick and DIRTY stuff for test play
/mob/living/verb/join_vc()
	to_chat(src, span_info("This should open up your webbrowser and give you a warning about a bad certificate. ignore and continue to the site, then allow mic perms. If your having issues please tell us what OS and browser you are using, if you use a VPN, and send a screenshot of your browser console to us."))
	if(!SSvoicechat)
		to_chat(src, span_warning("wait until voicechat initialized! {SSvoicechat: [SSvoicechat || "null"]}"))
		return
	SSvoicechat.join_vc(client)
	RegisterSignal(src, COMSIG_LIVING_DEATH, PROC_REF(move_to_ghost_room))
	RegisterSignal(src, COMSIG_LIVING_REVIVE, PROC_REF(move_to_normal_room))
	RegisterSignal(src, COMSIG_MOVABLE_Z_CHANGED, PROC_REF(move_to_normal_room))




/mob/living/proc/move_to_ghost_room()
	if(!SSvoicechat || !client)
		return
	var/userCode = SSvoicechat.client_userCode_map[ref(client)]
	SSvoicechat.move_userCode_to_room(userCode, "ghost")


/mob/living/proc/move_to_normal_room()
	if(!SSvoicechat || !client || stat)
		return
	var/userCode = SSvoicechat.client_userCode_map[ref(client)]
	SSvoicechat.move_userCode_to_room(userCode, "[src.z]")

