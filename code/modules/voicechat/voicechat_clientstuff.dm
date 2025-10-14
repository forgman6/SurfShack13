// Connects a client to voice chat via an external browser
/datum/controller/subsystem/voicechat/proc/join_vc(client/C, show_link_only=FALSE)
	var/node_port = CONFIG_GET(number/port_voicechat) // I see no good reasons why admins should be able to modify the port so we check config every time
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
	var/address = src.domain || world.internet_address
	var/web_link = "https://[address]:[node_port]?sessionId=[sessionId]"
	if(!show_link_only)
		C << link(web_link)
	else
		C << browse({"
		<html>
			<body>
				<h3>[web_link]</h3>
				<p>copy and paste the link into your web browser of choice, or scan the qr code.</p>
				<img src="https://api.qrserver.com/v1/create-qr-code/?data=${encodeURIComponent([web_link])}&size=150x150">
			</body>
		</html>"}, "window=voicechat_help")


	send_json(alist(
		cmd = "register",
		userCode = userCode,
		sessionId = sessionId
	))

	// Link client to userCode
	userCode_client_map[userCode] = ref(C)
	client_userCode_map[ref(C)] = userCode
	// Confirmation handled in confirm_usekrCode


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
	if(!C)
		disconnect(userCode, from_byond = TRUE)
		return

	room_update(C)


// Updates the voice chat room based on mob status
// this needs to be moved to signals at some point
/datum/controller/subsystem/voicechat/proc/room_update(client/C)
	var/userCode = client_userCode_map[ref(C)]
	if(!C || !userCode)
		return
	var/room
	if(!C.mob || isnewplayer(C.mob))
		room = "lobby_noprox"
	else
		var/mob/M = C.mob
		switch(M.stat)
			if(CONSCIOUS to SOFT_CRIT)
				room = "living"
			if(UNCONSCIOUS to HARD_CRIT)
				room = null
			else
				room = "ghost"
	if(userCode_room_map[userCode] != room)
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
		userCode_client_map.Remove(userCode)
		client_userCode_map.Remove(client_ref)
		userCode_room_map.Remove(userCode)
		vc_clients -= userCode


	if(userCodes_speaking_icon[userCode])
		var/client/C = locate(client_ref)
		if(C && C.mob)
			C.mob.cut_overlay(userCodes_speaking_icon[userCode])

	if(from_byond)
		send_json(alist(cmd= "disconnect", userCode= userCode))
	//for lobby chat
	if(SSticker.current_state < GAME_STATE_PLAYING)
		send_locations()



// Toggles the speaker overlay for a user
/datum/controller/subsystem/voicechat/proc/toggle_active(userCode, is_active)
	if(!userCode || isnull(is_active))
		return
	var/client/C = locate(userCode_client_map[userCode])

	if(!C || !C.mob)
		return
	var/mob/M = C.mob
	if(!userCodes_speaking_icon[userCode])
		var/image/speaker = image('icons/mob/effects/talk.dmi', icon_state = "voice")
		speaker.alpha = 200
		userCodes_speaking_icon[userCode] = speaker

	var/image/speaker = userCodes_speaking_icon[userCode]
	var/mob/old_mob = userCode_mob_map[userCode]
	if(M != old_mob)
		if(old_mob)
			old_mob.overlays -= speaker
		userCode_mob_map[userCode] = M
		room_update(C)
	if(is_active && (isobserver(M) || !M.stat))
		userCodes_active |= userCode
		M.add_overlay(speaker)
	else
		userCodes_active -= userCode
		M.cut_overlay(speaker)


// Mutes or deafens a user's microphone
/datum/controller/subsystem/voicechat/proc/mute_mic(client/C, deafen = FALSE)
	if(!C)
		return
	var/userCode = client_userCode_map[ref(C)]
	if(!userCode)
		return
	send_json(list(
		cmd = deafen ? "deafen" : "mute_mic",
		userCode = userCode
	))

