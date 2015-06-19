// Requestor service to go to betfair and grab data, then send it down to the tickerplant
\d .requestor

// schemas 
metadata:([eventTypeId: `int$();eventId: `int$();marketId: `symbol$();selectionId: `int$()] 
		eventTypeName: `symbol$();competitionId: `int$();competitionName: `symbol$(); marketName: `symbol$(); 
		eventName: `symbol$();timezone: `symbol$();openDate: `timestamp$(); selectionName: `symbol$());
		
// init function
init:{[]
	.lg.o[`init;"Running initialization function"];
	sessionToken:: "";
	getSessionToken[];						/ get sessionToken
	.lg.o[`init;"Setting up timer to refresh session"];
	.timer.rep[.z.p;0Wp;0D06:00:00;(`.requestor.keepAlive;`);2h;"refresh the Session Token";1b]; / refresh it every 6 hrs
	.lg.o[`init;"Making connection the tickerplant"];
	.servers.startup[];						/ connect to the discovery and tp processes
	tp::.servers.gethandlebytype[`tickerplant;`any];
	.lg.o[`init;"Setting timer to poll betfair api for data"];  
	{.timer.rep[x`start;x`end;x`interval;(`.requestor.callGetMarketData;x`marketId);2h;"get betfair data";0b]}each markets}; / add a job for each market in config

// function to convert kdb dictionary into a string which can be passed as a command line parameter
jsonStringParam:{[d]
	/ - convert the dictionary into a json string
	jsonstr: .j.j[d];
	/ - do some platform specific formatting of the string so that it can be 
	/ - passed as a command line parameter on both DOS ans Unix-like systems
	$[.os.NT;ssr[jsonstr;"\"";"\\\""];"'",jsonstr,"'"]}
 
// function to get a new session token/id
getSessionToken:{[]
	/ - validate username, password and appKey (cannot be empty)
	$[not count username;.lg.e[`getSessionToken;"Username cannot be empty. Please check code/settings/requestor.q"];
		not count password;.lg.e[`getSessionToken;"Password cannot be empty. Please check code/settings/requestor.q"];
		not count appKey;.lg.e[`getSessionToken;"AppKey cannot be empty. Please check code/settings/requestor.q"];()];
	.lg.o[`getSessionToken;"Attempting to login to betfair api"];
	loginResp: callApi[`login;jsonStringParam `username`password!(username;password)];
	$["SUCCESS" ~ respstr:loginResp`loginStatus;
		[.lg.o[`getSessionToken;"Login successful: ",st:loginResp`sessionToken];sessionToken:: st];
		.lg.e[`getSessionToken;"Login failed. Response was: ",respstr]]};

// function to get market data and send to tp for a given marketid
getMarketData:{[id]
	/ - check if the market id exists in the metadata table, if not then get the meta data from betfair
	if[not id in exec marketId from metadata; addMetaData[id]];
	/ - get the market book data ( trades and quotes )
	r: getMarketBook[id];
	/ - format the trades from the market book data
	trades:formatTrades[id;r];
	/ - format the quotes from the market book data
	quotes:formatQuotes[id;r];
	/ - publish the data to the tickerplant
	pubDataToTp'[`trade`quote;(trades;quotes)]};
 
// function to get quote and trade data for a given market
getMarketBook:{[id]
	/ - price projection dictionary
	priceP:`priceData`virtualise`rolloverStakes!(("EX_TRADED";"EX_ALL_OFFERS");0b;0b);
	/ - parameter dictionary (includes priceP dictionary)
	paramd:`marketIds`priceProjection`orderProjection`matchProjection!(string (),id;priceP;"ALL";"ROLLED_UP_BY_PRICE");
	/ - main dictionary (includes paramd dictionary)
	reqd: buildJsonRpcDict[`listMarketBook;paramd];
	/ - call the api to get the data
	first callApi[`data;reqd][`result][`runners]}	

// functions to format trade and quote data returned from betfair
formatTrades:{[id;data]
	/ - extract the traded volumes
	trades:raze {if[98h<>type t:x[`ex;`tradedVolume];:()];update selectionId: `int$ x`selectionId from t}each data;
	/ - join on metadata
	joinMetaData[id;`trade;trades]}
formatQuotes:{[id;data]
	/ - extract the back quotes
	quotes:raze {if[98h<>type t:x[`ex;`availableToBack];:()];update selectionId: `int$ x`selectionId,side:`back from t}each data; / grab quotes data (backers)
	/ - extract the lay quotes
	quotes,:raze {if[98h<>type t:x[`ex;`availableToLay];:()];update selectionId: `int$ x`selectionId,side:`lay from t}each data; / grab quotes data (layers)
	/ - join on metadata
	joinMetaData[id;`quote;quotes]}
 
// function to data to the tickerplant
pubDataToTp:{[tabname;data] neg[tp](`.u.upd;tabname;$[type data;value flip 0!data;data])}

// function to replace selectionId with names, add in meta data, reorder cols
joinMetaData:{[id;tabname;data]
	/ - join on the meta data
	data: data lj 
	    1!select selectionId, selectionName, sym: eventName, marketName, timezone, `$string openDate, eventType: eventTypeName, id:`$string eventId 
	    from metadata where marketId in id;
	/ - reorder and return the data
	(cols[`. tabname] except `time) # update selectionId:selectionName from data} 

// error trapped call to getMarketData
callGetMarketData:{[id]
	e:{.lg.e[`APING_CALL_FAILED;"call to betfair failed with error ",x]};
	@[getMarketData;id;e]};

// function to get meta data about given market id
getMetaData:{[marketids] delete totalMatched from distinct ungroup getMarketCatalogue[0N;marketids;()]}
// update the global metadata table
addMetaData:{[marketids]
	/ - call the api for meta data on marketids
	data: getMetaData[marketids];
	/ - upsert this into the global metadata table
	`.requestor.metadata upsert data}

buildJsonRpcDict:{[api;paramd]
	jsonStringParam `jsonrpc`method`params`id!("2.0";"SportsAPING/v1.0/",string api;paramd;1)}
 
// function to get a table of all the event types
getEventTypes:{[]
	data: callApi[`data;buildJsonRpcDict[`listEventTypes;enlist[`filter]!enlist ()!()]];
	select eventid: `$eventType @' `id, eventname: `$eventType @' `name, marketcount: marketCount from data`result}

// function to return a table of markets for a particular sports id
getMarketCatalogue:{[sportids;marketids;text]
	/ - filter dictionary
	filter: ()!();
	if[not all null sportids; filter[`eventTypeIds]: string (),sportids];
	if[not all null marketids; filter[`marketIds]: string (), marketids];
	if[count[text] and not "*" ~ first text; filter[`textQuery]:text];
	/ - paramd dictionary
	paramd:`filter`maxResults`marketProjection`sort!(filter;200;("COMPETITION";"EVENT";"EVENT_TYPE";"RUNNER_DESCRIPTION";"RUNNER_METADATA");`MAXIMUM_TRADED);
	/ - build the json req dictionary
	req: buildJsonRpcDict[`listMarketCatalogue;paramd];
	/ - call the api
	data: callApi[`data;req][`result];
	/ - some markets don't return anything for competition 
	data:{y!x[y]}[;`eventType`competition`marketId`totalMatched`marketName`event`runners] each data;
	/ - return a table with info for the markets
	select eventTypeId: "I" $ eventType @' `id, eventTypeName: `$ eventType @' `name,    competitionId: "I" $ competition @' `id, competitionName: `$ competition @' `name,
		marketId: `$ marketId, `$ marketName, totalMatched, eventId: "I" $ event @' `id, eventName: `$ event @' `name, timezone: `$event @' `timezone,
		openDate: "P" $ -1_ 'event @' `openDate, selectionName: `$runners @'' `runnerName,  selectionId: `int$ runners @'' `selectionId
		from data}

// function to call the betfair api for data requests
callApi:{[typ;req]
	/ - build the command line params to be passed to the python script
	cmdparams: " " sv (string typ;appKey;sessionToken;req);
	/ - submit the request via the python handler
	data: first system " " sv ("python",$[.os.NT;"w";()]; .os.pth getenv[`KDBBIN],"/getData.py";cmdparams);
	/ - check for errors returned by python handler
	if["ERROR:" ~ 6#data;.lg.e[`callApi;data]];
	/ - convert the json string into a q dictionary
	data:.j.k data;
	/ - check if the response has returned a result (otherwise it will have returned an error)
	$[(`error in key data) and count data`error;
		/ - pull the error code and log the error in the process log
		.lg.e[`callApi;"ERROR response received from Betfair: ",data[`error;`data;`APINGException;`errorCode]];
		:data]}
		
// function to keep session alive alive
keepAlive:{[]
	data:callApi[`keepAlive;""];
	$["SUCCESS" ~ data`status;
		.lg.o[`keepAlive;"Keep Alive call has succeeded : ",data`token];
		.lg.e[`keepAlive;"Keep Alive call failed. The error was : ",data`error]]}
	

// run initialization
\d .
.lg.o[`init;"Loading schema file"];
system .os.pth "l ",getenv[`KDBHOME],"/tick/database.q"; / grab schema
.requestor.init[]
