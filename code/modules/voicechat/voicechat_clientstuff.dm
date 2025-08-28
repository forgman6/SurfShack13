// Toggles the speaker overlay for a user
/datum/controller/subsystem/voicechat/proc/toggle_active(userCode, is_active)
	if(!userCode || isnull(is_active))
		return
	var/client/C = locate(userCode_client_map[userCode])
	var/mob/M = C.mob
	if(!C || !M)
		disconnect(userCode, from_byond= TRUE)
		return
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
		room_update(M)
	if(is_active)
		userCodes_active |= userCode
		M.overlays |= speaker
	else
		userCodes_active -= userCode
		M.overlays -= speaker


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
	room_update(M)

// Updates the voice chat room based on mob status
/datum/controller/subsystem/voicechat/proc/room_update(mob/source)
	var/client/C = source.client
	var/userCode = client_userCode_map[ref(C)]
	if(!C || !userCode)
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
		userCode_client_map.Remove(userCode)
		client_userCode_map.Remove(client_ref)
		userCode_room_map.Remove(userCode)
		vc_clients -= userCode

	if(from_byond)
		send_json(list("cmd" = "disconnect", "userCode" = userCode))


/mob/verb/join_vc()
	src << browse({"<html>
	<h2>proximity chat</h2>
	<p>This command should open an external broswer.<br>
	1. ignore the bad cert and continue onto the site.<br>
	2. When prompted, allow mic perms and then you should be set up.<br>
	3. To verify this is working, look for a speaker overlay over your mob in-game.</p>
	<h4>issues</h4>
	<p>To try to solve yourself, ensure browser extensions are off and if you are comfortable with it turn off your VPN.
	Additionally try setting firefox as your default browser as that usually works best</p>
	<h4>reporting bugs</h4>
	<p> If your are still having issues, its most likely with rtc connections, (roughly 10% connections fail). When reporting bugs, please tell us what OS and browser you are using, if you use a VPN, and send a screenshot of your browser console to us (ctrl + shift + I).
	Additionally I might ask you to navigate to about:webrtc/p>
	<img src='https://files.catbox.moe/mkz9tv.png'></html>"}, "window=voicechat_help")
	if(SSvoicechat)
		SSvoicechat.join_vc(client)


/mob/verb/mute()
	if(SSvoicechat)
		SSvoicechat.mute_mic(client)


/mob/verb/deafen()
	if(SSvoicechat)
		SSvoicechat.mute_mic(client, deafen=TRUE)
