/*
	new_report holds the reporting department
		1 - Bridge
		2 - CE / Engineering
		3 - CMO / Medical
		4 - Pathfinder / Exploration
		5 - HoS / Security
		6 - RndD / Science
*/

#define BRIDGE 1
#define CE 2
#define CMO 3
#define Path 4
#define HoS 5
#define RnD 6

/datum/computer_file/program/star_log
	filename = "starlog"
	filedesc = "StarLog"
	extended_desc = "This program can be used to view and send StarLogs from and to external archive."
	program_icon_state = "word"
	program_key_state = "atmos_key"
	program_menu_icon = "note"
	size = 6
	requires_ntnet = 1
	available_on_ntnet = 1

	nanomodule_path = /datum/nano_module/program/star_log
	category = PROG_COMMAND

/datum/nano_module/program/star_log
	name = "StarLog"
	var/error_message = ""
	var/current_book
	var/sort_by = "id"
	var/new_report
	var/author
	var/oldtext
	var/usr
	var/up, down
	var/currentId
	var/currentReport
	var/voting = list("up" = 0, "down" = 0)

/datum/nano_module/program/star_log/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1, var/datum/topic_state/state = GLOB.default_state)
	var/list/data = host.initial_data()
	var/id = user.GetIdCard()
	author = GetNameAndAssignmentFromId(id)
	usr = user

	data["voting"] = voting
	data["author"] = author
	data["oldtext"] = oldtext

	if(error_message)
		data["error"] = error_message
	else if(current_book)
		data["current_book"] = current_book
	else if(new_report)
		data["new_report"] = new_report

	else
		var/list/all_entries[0]
		establish_old_db_connection()
		if(!dbcon_old.IsConnected())
			error_message = "Unable to contact External Archive. Please contact your system administrator for assistance."
		else
			var/DBQuery/query = dbcon_old.NewQuery("SELECT star_log.id, star_log.Bridge, SUM(star_log_vote.bridge) AS bridge, star_log.CE, SUM(star_log_vote.ce) AS ce, star_log.CMO, SUM(star_log_vote.cmo) AS cmo, star_log.Path, SUM(star_log_vote.path) AS path, star_log.HOS, SUM(star_log_vote.hos) AS hos, star_log.RND, (star_log_vote.rnd) AS rnd, (star_log_vote.bridge + star_log_vote.ce + star_log_vote.cmo + star_log_vote.path + star_log_vote.hos + star_log_vote.rnd) AS score FROM star_log, star_log_vote WHERE star_log.gameId=star_log_vote.gameId GROUP BY star_log_vote.gameId ORDER BY [sort_by] DESC") //+sanitizeSQL(sort_by))
			query.Execute()

			while(query.NextRow())
				all_entries.Add(list(list(
				"id" = query.item[1],
				"bridge" = query.item[2],
				"ce" = query.item[4],
				"cmo" = query.item[6],
				"path" = query.item[8],
				"hos" = query.item[10],
				"rnd" = query.item[12],
				"score" = query.item[14]
			)))
		data["report_list"] = all_entries

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "star_log.tmpl", "StarLog Program", 575, 700, state = state)
		ui.auto_update_layout = 1
		ui.set_initial_data(data)
		ui.open()

/datum/nano_module/program/star_log/Topic(href, href_list)
	/var/DBQuery/query

	if(..())
		return 1
	if(href_list["newReport"])
		new_report = href_list["newReport"]
		get_current_version(href_list["newReport"])
		return 1
	if(href_list["closeEdit"])
		new_report = null
		oldtext = null
		return 1
	if(href_list["editReport"])
		edit_report(href_list["editReport"])
		return 1
	if(href_list["viewReport"])
		viewReport(href_list["id"],href_list["viewReport"])
		return 1
	if(href_list["closebook"])
		current_book = null
		return 1
	if(href_list["vote"])
		vote(href_list["vote"])
		return 1

	if(href_list["printbook"])
		if(!current_book)
			error_message = "Software Error: Unable to print; book not found."
			return 1

		//Regular printing
		print_text("<i>Author: [current_book["author"]]<br>USBN: [current_book["id"]]</i><br><h3>[current_book["title"]]</h3><br>[current_book["content"]]", usr)
		return 1
	if(href_list["sortby"])
		sort_by = href_list["sortby"]
		return 1
	if(href_list["reseterror"])
		if(error_message)
			current_book = null
			sort_by = "id"
			error_message = ""
		return 1

/datum/nano_module/program/star_log/proc/get_current_version(var/bla)
	var/DBQuery/query

	switch(new_report)
		if("1")	query = dbcon_old.NewQuery("SELECT Bridge_Report FROM star_log WHERE gameId='[game_id]'")
		if("2")	query = dbcon_old.NewQuery("SELECT CE_Report FROM star_log WHERE gameId='[game_id]'")
		if("3")	query = dbcon_old.NewQuery("SELECT CMO_Report FROM star_log WHERE gameId='[game_id]'")
		if("4")	query = dbcon_old.NewQuery("SELECT Path_Report FROM star_log WHERE gameId='[game_id]'")
		if("5")	query = dbcon_old.NewQuery("SELECT HOS_Report FROM star_log WHERE gameId='[game_id]'")
		if("6")	query = dbcon_old.NewQuery("SELECT RnD_Report FROM star_log WHERE gameId='[game_id]'")

	query.Execute()

	while(query.NextRow())
		oldtext = list("content" = digitalPencode2html(query.item[1]))
		break

	if(!oldtext)
		oldtext = list(
			"content" = "No report has been written."
			)

	return 1

/datum/nano_module/program/star_log/proc/edit_report(var/bla)
	var/DBQuery/query

	var/newcontent = sanitizeSQL(replacetext(input(usr, "Editing file. You may use most tags used in paper formatting:", "Text Editor", html2pencode(oldtext["content"])) as message|null, "\n", "\[br\]"), MAX_TEXTFILE_LENGTH)
	if(!newcontent)
		return

	var/sqlauthor = sanitizeSQL(author)

	query = dbcon_old.NewQuery("SELECT * FROM star_log WHERE gameId='[game_id]'")
	query.Execute()

	if(!query.NextRow())
		query = dbcon_old.NewQuery("INSERT INTO star_log (gameId) VALUES ('[game_id]')")
		query.Execute()

		//hack to solve a problem with the GROUP BY query
		query = dbcon_old.NewQuery("INSERT INTO star_log_vote (gameId) VALUES('[game_id]')")
		query.Execute()

	switch(new_report)
		if("1")	query = dbcon_old.NewQuery("UPDATE star_log SET Bridge='[sqlauthor]', Bridge_Report='[newcontent]' WHERE gameId = '[game_id]'")
		if("2")	query = dbcon_old.NewQuery("UPDATE star_log SET CE='[sqlauthor]', CE_Report='[newcontent]' WHERE gameId = '[game_id]'")
		if("3")	query = dbcon_old.NewQuery("UPDATE star_log SET CMO='[sqlauthor]', CMO_Report='[newcontent]' WHERE gameId = '[game_id]'")
		if("4")	query = dbcon_old.NewQuery("UPDATE star_log SET Path='[sqlauthor]', Path_Report='[newcontent]' WHERE gameId = '[game_id]'")
		if("5")	query = dbcon_old.NewQuery("UPDATE star_log SET HOS='[sqlauthor]', HOS_Report='[newcontent]' WHERE gameId = '[game_id]'")
		if("6")	query = dbcon_old.NewQuery("UPDATE star_log SET RnD='[sqlauthor]', RnD_Report='[newcontent]' WHERE gameId = '[game_id]'")

	query.Execute()

	oldtext["content"] = digitalPencode2html(newcontent)
	return 1

/datum/nano_module/program/star_log/proc/vote(var/voteUpDown)
	var/DBQuery/query
	var/voted

	query = dbcon_old.NewQuery("SELECT gameId FROM star_log WHERE id=[currentId]")
	query.Execute()
	query.NextRow()
	var/gameId = query.item[1]

	query = dbcon_old.NewQuery("SELECT * FROM star_log_vote WHERE gameId='[gameId]' AND ckey ='[usr.key]'")
	query.Execute()

	if(voteUpDown == "up")
		voted = 1
		voting = list("up" = 1, "down" = 0)
	else
		voted = -1
		voting = list( "up" = 0, "down" = 1)

	if(!query.NextRow())
		query = dbcon_old.NewQuery("INSERT INTO star_log_vote (gameId, ckey) VALUES ('[gameId]', '[usr.key]')")
		query.Execute()

	switch(currentReport)
		if("1")	query = dbcon_old.NewQuery("UPDATE star_log_vote SET bridge='[voted]' WHERE gameId = '[gameId]' AND ckey ='[usr.key]'")
		if("2")	query = dbcon_old.NewQuery("UPDATE star_log_vote SET ce='[voted]' WHERE gameId = '[gameId]' AND ckey ='[usr.key]'")
		if("3")	query = dbcon_old.NewQuery("UPDATE star_log_vote SET cmo='[voted]' WHERE gameId = '[gameId]' AND ckey ='[usr.key]'")
		if("4")	query = dbcon_old.NewQuery("UPDATE star_log_vote SET path='[voted]' WHERE gameId = '[gameId]' AND ckey ='[usr.key]'")
		if("5")	query = dbcon_old.NewQuery("UPDATE star_log_vote SET hos='[voted]' WHERE gameId = '[gameId]' AND ckey ='[usr.key]'")
		if("6")	query = dbcon_old.NewQuery("UPDATE star_log_vote SET rnd='[voted]' WHERE gameId = '[gameId]' AND ckey ='[usr.key]'")

	query.Execute()

	return 1

/datum/nano_module/program/star_log/proc/viewReport(var/id, var/report)
	var/sqlid = sanitizeSQL(id)
	var/DBQuery/query
	var/gameId
	currentId = sqlid
	currentReport = report
	establish_old_db_connection()
	if(!dbcon_old.IsConnected())
		error_message = "Network Error: Connection to the Archive has been severed."
		return 1

	switch(report)
		if("1")	query = dbcon_old.NewQuery("SELECT id, Bridge, Bridge_Report, gameId FROM star_log WHERE id=[sqlid]")
		if("2")	query = dbcon_old.NewQuery("SELECT id, CE, CE_Report, gameId FROM star_log WHERE id=[sqlid]")
		if("3")	query = dbcon_old.NewQuery("SELECT id, CMO, CMO_Report, gameId FROM star_log WHERE id=[sqlid]")
		if("4")	query = dbcon_old.NewQuery("SELECT id, Path, Path_Report, gameId FROM star_log WHERE id=[sqlid]")
		if("5")	query = dbcon_old.NewQuery("SELECT id, HOS, HOS_Report, gameId FROM star_log WHERE id=[sqlid]")
		if("6")	query = dbcon_old.NewQuery("SELECT id, RND, RND_Report, gameId FROM star_log WHERE id=[sqlid]")

	query.Execute()

	while(query.NextRow())
		current_book = list(
			"id" = query.item[1],
			"author" = query.item[2],
			"content" = digitalPencode2html(query.item[3])
			)
		gameId = query.item[4]
		break

	switch(report)
		if("1")	current_book["title"] = "Bridge Report"
		if("2")	current_book["title"] = "Engineering Report"
		if("3")	current_book["title"] = "Medical Report"
		if("4")	current_book["title"] = "Exploration Report"
		if("5")	current_book["title"] = "Security Report"
		if("6")	current_book["title"] = "Science Report"

	switch(report)
		if("1")	query = dbcon_old.NewQuery("SELECT bridge FROM star_log_vote WHERE ckey='[usr.key]' AND gameId = '[gameId]'")
		if("2")	query = dbcon_old.NewQuery("SELECT ce FROM star_log_vote WHERE ckey='[usr.key]' AND gameId = '[gameId]'")
		if("3")	query = dbcon_old.NewQuery("SELECT cmo FROM star_log_vote WHERE ckey='[usr.key]' AND gameId = '[gameId]'")
		if("4")	query = dbcon_old.NewQuery("SELECT path FROM star_log_vote WHERE ckey='[usr.key]' AND gameId = '[gameId]'")
		if("5")	query = dbcon_old.NewQuery("SELECT hos FROM star_log_vote WHERE ckey='[usr.key]' AND gameId = '[gameId]'")
		if("6")	query = dbcon_old.NewQuery("SELECT rnd FROM star_log_vote WHERE ckey='[usr.key]' AND gameId = '[gameId]'")
	query.Execute()

	if(query.NextRow())
		if(query.item[1] == 1)
			voting = list("up" = 1, "down" = 0)
		else
			voting = list("up" = 0, "down" = 1)
	else
		voting = list("up" = 0, "down" = 0)

	return 1