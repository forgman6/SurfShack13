// Toggles the speaker overlay for a user
/datum/controller/subsystem/voicechat/proc/toggle_active(userCode, is_active)
	if(!userCode || isnull(is_active))
		return
	var/client/C = locate(userCode_client_map[userCode])
	if(!C)
		return
	var/atom/movable/M = C.mob
	var/image/speaker = image('icons/hud/voicechat/speaker.dmi', M, pixel_y = 32, pixel_x = 8)
	M.overlays = is_active ? M.overlays + speaker : M.overlays - speaker

// Mutes or deafens a user's microphone
/datum/controller/subsystem/voicechat/proc/mute_mic(client/C, deafen = FALSE)
	if(!C)
		return
	var/userCode = client_userCode_map[ref(C)]
	if(!userCode)
		return
	send_json(list(
		"cmd" = deafen ? "deafen" : "mute_mic",
		"userCode" = userCode
	))

// Connects a client to voice chat via an external browser
/datum/controller/subsystem/voicechat/proc/join_vc(client/C)
	if(!C)
		return
	// Disconnect existing session if present
	var/existing_userCode = client_userCode_map[ref(C)]
	if(existing_userCode)
		disconnect(existing_userCode, from_byond = TRUE)

	// Generate unique session and user codes
	var/sessionId = md5("[world.time][rand()][world.realtime][rand(0,9999)][C.address][C.computer_id]")
	var/userCode = generate_userCode(C)
	if(!userCode)
		return

	// Open external browser with voice chat link
	C << link("https://[world.internet_address]:[node_port]?sessionId=[sessionId]")
	send_json(alist(
		cmd = "register",
		userCode = userCode,
		sessionId = sessionId
	))

	// Link client to userCode
	userCode_client_map[userCode] = ref(C)
	client_userCode_map[ref(C)] = userCode
	// Confirmation handled in confirm_userCode

// Confirms userCode when browser and mic access are granted
/datum/controller/subsystem/voicechat/proc/confirm_userCode(userCode)
	if(!userCode || (userCode in vc_clients))
		return
	var/client_ref = userCode_client_map[userCode]
	if(!client_ref)
		return

	vc_clients += userCode
	log_world("Voice chat confirmed for userCode: [userCode]")
	post_confirm(userCode)

// Sets up signals for a confirmed voice chat user
/datum/controller/subsystem/voicechat/proc/post_confirm(userCode)
	var/client/C = locate(userCode_client_map[userCode])
	if(!C || !C.mob)
		disconnect(userCode, from_byond = TRUE)
		return

	var/mob/M = C.mob
	var/list/signals = list(
		COMSIG_MOVABLE_Z_CHANGED,
		COMSIG_LIVING_DEATH,
		COMSIG_LIVING_REVIVE,
		COMSIG_LIVING_STATUS_UNCONSCIOUS
	)
	RegisterSignal(M, signals, PROC_REF(room_update))
	if(M.mind)
		RegisterSignal(M.mind, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF, PROC_REF(on_mind_change))
	RegisterSignal(C, COMSIG_CLIENT_MOB_LOGIN, PROC_REF(on_mob_change))

// Handles mob change for a client
/datum/controller/subsystem/voicechat/proc/on_mob_change(client/source, mob/M)
	var/list/signals = list(
		COMSIG_MOVABLE_Z_CHANGED,
		COMSIG_LIVING_DEATH,
		COMSIG_LIVING_REVIVE,
		COMSIG_LIVING_STATUS_UNCONSCIOUS
	)
	RegisterSignal(M, signals, PROC_REF(room_update))
	if(M.mind)
		RegisterSignal(M.mind, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF, PROC_REF(on_mind_change))
	room_update(M)

// Handles mind transfer to update voice chat
/datum/controller/subsystem/voicechat/proc/on_mind_change(datum/mind/source, mob/old_mob)
	var/mob/M = source.current
	if(!M)
		var/client/C = old_mob.client
		var/userCode = client_userCode_map[ref(C)]
		if(!C || !userCode)
			return
		disconnect(userCode, from_byond = TRUE)
		return
	UnregisterSignal(old_mob, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF)
	room_update(M)

// Updates the voice chat room based on mob status
/datum/controller/subsystem/voicechat/proc/room_update(mob/source)
	world.log << "room_update called"
	var/client/C = source.client
	var/userCode = client_userCode_map[ref(C)]
	if(!C || !userCode)
		UnregisterSignal(source, list(
			COMSIG_MOVABLE_Z_CHANGED,
			COMSIG_LIVING_DEATH,
			COMSIG_LIVING_STATUS_UNCONSCIOUS
		))
		return

	var/room
	switch(source.stat)
		if(CONSCIOUS to SOFT_CRIT)
			room = "[source.z]"
		if(UNCONSCIOUS to HARD_CRIT)
			room = null
		else
			room = "ghost"
	move_userCode_to_room(userCode, room)

// Disconnects a user from voice chat
/datum/controller/subsystem/voicechat/proc/disconnect(userCode, from_byond = FALSE)
	if(!userCode)
		return

	toggle_active(userCode, FALSE)
	var/room = userCode_room_map[userCode]
	if(room)
		current_rooms[room] -= userCode

	var/client_ref = userCode_client_map[userCode]
	if(client_ref)
		UnregisterSignal(locate(client_ref), COMSIG_CLIENT_MOB_LOGIN)
		userCode_client_map.Remove(userCode)
		client_userCode_map.Remove(client_ref)
		userCode_room_map.Remove(userCode)
		vc_clients -= userCode

	if(from_byond)
		send_json(list("cmd" = "disconnect", "userCode" = userCode))


/mob/verb/join_vc()
	src << browse(@'<html><h2>proximity chat</h2> <p>this command should open an external broswer, ignore the bad cert and continue onto the site. when prompted, allow mic perms and then you should be set up. Verify this is working by looking for a speaker overlay over your mob ingame</p> <h4>issues</h4> <p>to try to solve yourself, ensure browser extensions are off and if you are using a vpn, try without. additionally try running on firefox as thats usually works best</p> <h4>reporting bugs</h4> <p> If your having issues please tell us what OS and browser you are using, if you use a VPN, and send a screenshot of your browser console to us (ctrl + shift + I). </p> <h4>contact</h4> <p>a_forg on discord</p> <img src="https://files.catbox.moe/mkz9tv.png"></html>')
	if(SSvoicechat)
		SSvoicechat.join_vc(client)


/mob/verb/mute()
	if(SSvoicechat)
		SSvoicechat.mute_mic(client)


/mob/verb/deafen()
	if(SSvoicechat)
		SSvoicechat.mute_mic(client, deafen=TRUE)
