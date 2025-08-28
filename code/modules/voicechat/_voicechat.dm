SUBSYSTEM_DEF(voicechat)
	name = "Voice Chat"
	wait = 3 //300 ms
	flags = SS_KEEP_TIMING
	init_order = INIT_ORDER_VOICECHAT
	runlevels = RUNLEVEL_GAME|RUNLEVEL_POSTGAME
	//userCodes associated thats been fully confirmed - browser paired and mic perms on
	var/list/vc_clients = list()
	//userCode to clientRef
	var/list/userCode_client_map = alist()
	var/list/client_userCode_map = alist()
	//list of all rooms to add at round start
	var/list/rooms_to_add = list("ghost")
	//a list all currnet rooms
	//change with add_rooms and remove_rooms.
	var/list/current_rooms = alist()
	// usercode to room
	var/list/userCode_room_map = alist()
	// usercode to mob only really used for the overlays
	var/list/userCode_mob_map = alist()
	// if the server and node have successfully communicated
	var/handshaked = FALSE
	//subsystem "defines"
	//which port to run the node websockets
	var/const/node_port = 3000
	//node server path
	var/const/node_path = "voicechat/node/server/main.js"
	//library path
	var/const/lib_path = "voicechat/pipes/byondsocket.so"


/datum/controller/subsystem/voicechat/fire()
	send_locations()

//shit you want byond to do after establishing communication
/datum/controller/subsystem/voicechat/proc/handshaked()
	handshaked = TRUE
	return

/datum/controller/subsystem/voicechat/proc/add_rooms(list/rooms, zlevel_mode = FALSE)
	if(!islist(rooms))
		rooms = list(rooms)
	rooms.Remove(current_rooms) //remove existing rooms
	for(var/room in rooms)
		if(isnum(room) && !zlevel_mode)
			// CRASH("rooms cannot be numbers {room: [room]}")
			continue
		current_rooms[room] = list()


/datum/controller/subsystem/voicechat/proc/remove_rooms(list/rooms)
	if(!islist(rooms))
		rooms = list(rooms)
	rooms &= current_rooms //remove nonexistant rooms
	for(var/room in rooms)
		for(var/userCode in current_rooms[room])
			userCode_room_map[userCode] = null
		current_rooms.Remove(room)


/datum/controller/subsystem/voicechat/proc/move_userCode_to_room(userCode, room)
	if(!room || !current_rooms.Find(room))
		return

	var/own_room = userCode_room_map[userCode]
	if(own_room)
		current_rooms[own_room] -= userCode

	userCode_room_map[userCode] = room
	current_rooms[room] += userCode


/datum/controller/subsystem/voicechat/proc/link_userCode_client(userCode, client)
	if(!client|| !userCode)
		// CRASH("{userCode: [userCode || "null"], client: [client  || "null"]}")
		return
	var/client_ref = ref(client)
	userCode_client_map[userCode] = client_ref
	client_userCode_map[client_ref] = userCode
	world.log << "registered userCode:[userCode] to client_ref:[client_ref]"




/datum/controller/subsystem/voicechat/proc/send_locations()
	var/list/params = alist(cmd = "loc")
	for(var/userCode in vc_clients)
		var/client/C = locate(userCode_client_map[userCode])
		var/room =  userCode_room_map[userCode]
		if(!C || !room)
			continue
		var/mob/M = C.mob
		if(!M)
			continue
		if(!params[room])
			params[room] = alist()
		params[room][userCode] = list(M.x, M.y)
	send_json(params)


/datum/controller/subsystem/voicechat/proc/generate_userCode(client/C)
	if(!C)
		// CRASH("no client or wrong type")
		return
	. = copytext(md5("[C.computer_id][C.address][rand()]"),-4)
	//ensure unique
	while(. in userCode_client_map)
		. = copytext(md5("[C.computer_id][C.address][rand()]"),-4)
	return .


