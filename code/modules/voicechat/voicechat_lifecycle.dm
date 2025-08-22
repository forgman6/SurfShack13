

/datum/controller/subsystem/voicechat/Initialize()
	. = ..()
	test_library()
	add_rooms(rooms_to_add)
	add_zlevels()
	start_node()


/datum/controller/subsystem/voicechat/proc/start_node()
	// used for topic calls
	var/byond_port = world.port
	spawn() shell("node [src.node_path] --node-port=[src.node_port] --byond-port=[byond_port]")


//run at start and whenever new zlevel is added
/datum/controller/subsystem/voicechat/proc/add_zlevels()
    var/list/rooms_to_add = list()
    for(var/zlevel=1, zlevel<=world.maxz, zlevel++)
        rooms_to_add += num2text(zlevel)
	//add rooms handles duplicates
    add_rooms(rooms_to_add, zlevel_mode = TRUE)
    // world.log << json_encode(current_rooms)


/datum/controller/subsystem/voicechat/Del()
	send_json(alist(cmd= "stop_node"))
	. = ..()
