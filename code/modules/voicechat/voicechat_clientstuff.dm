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


/datum/controller/subsystem/voicechat/proc/join_vc(mob/M)
	var/client/C = M.client
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
	// ensure unique, should almost never run
	while(userCode in userCode_client_map)
		userCode = generate_userCode(C)

	// until LummoxJR gives us a usable web browser with microphone access,
	// we use an external browser
	#ifdef DEBUG
	src << link("https://localhost:[src.node_port]?sessionId=[sessionId]")
	#else
	src << link("https://[world.internet_address]:[src.node_port]?sessionId=[sessionId]")
	#endif
	var/list/paramstuff = alist(cmd="register", userCode= userCode, sessionId= sessionId)
	send_json(paramstuff)
	link_userCode_client(userCode, C)


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
	userCode_client_map.Remove(userCode)
	client_userCode_map.Remove(client_ref)
	userCode_room_map.Remove(userCode)
	vc_clients -= userCode

	if(from_byond)
		send_json(alist(cmd="disconnect", userCode=userCode))
