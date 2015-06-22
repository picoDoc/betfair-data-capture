// Requestor service to go to betfair and grab data, then send it down to the tickerplant
\d .requestor

// Default Parameters
logoutonexit:@[value;`logoutonexit;1b]		/ - logout of betfair session when the process is shutdown
keepalivetime:@[value;`keepalivetime;0D06]	/ - send a keep alive every X
pubprocs:@[value;`pubprocs;(),`tickerplant1]	/ - list of processes (names not types) to publish data to.  If null symbol, then the 
						/ - the process will not publish data and will used to poll for ad-hoc data (i.e. query via gw)
pubconnsleepintv:@[value;`pubconnsleepintv;5]	/ - number of seconds to sleep before re-attempting to connection to downstream processes

username:@[value;`username;""];			/ - betfair username
password:@[value;`password;""];			/ - betfair password
appKey:@[value;`appKey;""];			/ - betfair application key

datacfgfile:@[value;`datacfgfile;hsym `$getenv[`KDBCONFIG],"/requestor.csv"]	/ - location of the requestor config file
mktdatatimerf:@[value;`mktdatatimerf;0D00:00:02]				/ - how often the timer will check if it needs to poll for market data

// schemas 
metadata:([eventTypeId: `int$();eventId: `int$();marketId: `symbol$();selectionId: `int$()] 
		eventTypeName: `symbol$();competitionId: `int$();competitionName: `symbol$(); marketName: `symbol$(); 
		eventName: `symbol$();timezone: `symbol$();openDate: `timestamp$(); selectionName: `symbol$());
		
// init function
init:{[]
	.lg.o[`init;"Running initialization function"];
	sessionToken:: "";
	login[];						/ login to the betfair api
	.lg.o[`init;"Setting up timer to refresh session"];
	.timer.rep[.proc.cp[];0Wp;keepalivetime;(`.requestor.keepAlive;`);2h;"refresh the Session Token";1b]; / refresh it every 6 hrs
	$[all n:null pubprocs;
		.lg.o[`init;"pubprocs has not been configured, this process will not publish data"];
		initsubscription[n]]}; 

initsubscription:{[n]
	.lg.o[`initsubscription;"Making connection the tickerplant"];.servers.startup[];			/ connect to the discovery and tp processes
	while[count[pubprocs where not n] > count handles: .servers.getservers[`name;pubprocs;()!();1b;1b]`w;	/ keep looping around until all the connections have been established
		.os.sleep[pubconnsleepintv];.servers.startup[]];  						/ sleep and then run the servers startup code again (to make connection to discovery)
	@[`.requestor;`tphs;:;handles];
	.lg.o[`initsubscription;"Setting timer to poll betfair api for data"];
	@[`.requestor;`cfg;:;loadconfigfile[]];
	/ - set timer function to check cfg for whether to poll for data
	.timer.rep[.proc.cp[];0Wp;mktdatatimerf;(`.requestor.pollformarketdata;`);2h;"check if to poll for market data";0b]}
	
// function to load the config file
loadconfigfile:{[] 
	/ - read in the config file
	data: ("*S**N"; enlist ",") 0: read0 datacfgfile;
	/ - parse the start and end time columns
	data: update start: .requestor.parsetimecols[start], .requestor.parsetimecols[end] from data;
	/ - publish meta data for each of the markets that have been loaded
	publishmetadata[data`marketId];
	/ - tag on next run times for each market
	update nextruntime: .proc.cp[] + interval from data}
	
// function to convert strings into timestamps, this is to allow functional configs such as .z.p, .proc.cp[] etc...
parsetimecols:{[x] `timestamp$ value each x}
// function to identify when to poll for data for each market
pollformarketdata:{[]
	now: .proc.cp[];
	/ - if there is nothing to be run now, then just escape
	if[not count t:select from cfg where end > now, nextruntime <= now;:()]; 
	/ - cut the marketIds into groups of 6 (6 is the maximum allowable by the Betfair API otherwise a TOO_MUCH_DATA error will be returned)
	getMarketData each 6 cut t`marketId;
	/ - update the next run time 
	update nextruntime:.proc.cp[]+interval from `.requestor.cfg where end > now, nextruntime <= now}
// delete market id from requestor config
delfromcfg:{[ids] 
	.lg.o[`delfromcfg;"Removing id(s) from cfg : ","," sv string ids:(),ids];
	delete from `.requestor.cfg where marketId in ids}
	
// function to convert kdb dictionary into a string which can be passed as a command line parameter
jsonStringParam:{[api;d]
	if[not null api;d:`jsonrpc`method`params`id!("2.0";"SportsAPING/v1.0/",string api;d;1)];
	/ - convert the dictionary into a json string
	jsonstr: .j.j[d];
	/ - do some platform specific formatting of the string so that it can be 
	/ - passed as a command line parameter on both DOS ans Unix-like systems
	$[.os.NT;ssr[jsonstr;"\"";"\\\""];"'",jsonstr,"'"]}

// function to get market data and send to tp for a given marketid
getMarketData:{[id]
	/ - get the market book data ( trades and quotes )
	data: getMarketBook[id:(),id]`result;
	/ - make the keys/columns homogeneous for each marketid (so dictionaries will collapse into a queriable table)
	data: {x!y[x]}[raze distinct key each data;] each data;
	/ - remove "CLOSED" markets
	if[ any clsbool: "CLOSED" ~/: data`status;
		delfromcfg `$data[`marketId] where clsbool;	/ - remove closed markets from cfg so we don't poll for them again
		if[not count data: delete from data where clsbool;:()]];
	r: ungroup select `$marketId, selectionId:runners @'' `selectionId, ex:runners @'' `ex from data;
	/ - check if the market id exists in the metadata table, if not then get the meta data from betfair
	if[not all bools:(mdids: distinct r`marketId) in exec marketId from metadata; addMetaData[mdids where not bools]];
	/ - format the trades from the market book data
	trades:formatTrades[id;r];
	/ - format the quotes from the market book data
	quotes:formatQuotes[id;r];
	/ - publish the data to the tickerplant
	pubDataToTp'[`trade`quote;(trades;quotes)]};
	
// function to publish meta data to downstream processes	
publishmetadata:{[ids]

	}
 
// function to get quote and trade data for a given market
getMarketBook:{[id]
	/ - price projection dictionary
	priceP:`priceData`virtualise`rolloverStakes!(("EX_TRADED";"EX_ALL_OFFERS");0b;0b);
	/ - parameter dictionary (includes priceP dictionary)
	paramd:`marketIds`priceProjection`orderProjection`matchProjection!(string (),id;priceP;"ALL";"ROLLED_UP_BY_PRICE");
	/ - main dictionary (includes paramd dictionary)
	reqd: jsonStringParam[`listMarketBook;paramd];
	/ - call the api to get the data
	callApi[`data;reqd]}	

// functions to format trade and quote data returned from betfair
formatTrades:{[id;data]
	/ - extract the traded volumes
	trades:raze {if[98h<>type t:x[`ex;`tradedVolume];:()];update marketId: x`marketId, selectionId: `int$ x`selectionId from t}each data;
	/ - join on metadata
	joinMetaData[id;`trade;trades]}
formatQuotes:{[id;data]
	/ - extract the back quotes
	quotes:raze {if[98h<>type t:x[`ex;`availableToBack];:()];update marketId: x`marketId, selectionId: `int$ x`selectionId,side:`back from t}each data;
	/ - extract the lay quotes
	quotes,:raze {if[98h<>type t:x[`ex;`availableToLay];:()];update marketId: x`marketId, selectionId: `int$ x`selectionId,side:`lay from t}each data; 
	/ - join on metadata
	joinMetaData[id;`quote;quotes]}
 
// function to data to the tickerplant
pubDataToTp:{[tabname;data] neg[tphs] @\: (`.u.upd;tabname;$[type data;value flip 0!data;data])}

// function to replace selectionId with names, add in meta data, reorder cols
joinMetaData:{[id;tabname;data]
	/ - join on the meta data
	data: data lj 
	    2!select selectionId, marketId, selectionName, sym: eventName, marketName, timezone, `$string openDate, eventType: eventTypeName, id:`$string eventId 
	    from metadata;
	/ - reorder and return the data
	(cols[`. tabname] except `time) # update selectionId:selectionName from data} 

// error trapped call to getMarketData
callGetMarketData:{[id]
	e:{.lg.e[`APING_CALL_FAILED;"call to betfair failed with error ",x]};
	@[getMarketData;id;e]};

// function to get meta data about given market id
getMetaData:{[marketids] delete totalMatched from distinct ungroup getMarketCatalogue[0N;marketids;();()]}
// update the global metadata table
addMetaData:{[marketids]
	/ - call the api for meta data on marketids
	data: getMetaData[marketids];
	/ - upsert this into the global metadata table
	`.requestor.metadata upsert data}

// function to get a table of all the event types
getEventTypes:{[]
	data: callApi[`data;jsonStringParam[`listEventTypes;enlist[`filter]!enlist ()!()]];
	select eventid: `$eventType @' `id, eventname: `$eventType @' `name, marketcount: marketCount from data`result}

// function to return a table of markets for a particular sports id
getMarketCatalogue:{[sportids;marketids;text;inplay]
	/ - filter dictionary
	filter: ()!();
	if[not all null sportids; filter[`eventTypeIds]: string (),sportids];
	if[not all null marketids; filter[`marketIds]: string (), marketids];
	if[count[text] and not "*" ~ first text; filter[`textQuery]:text];
	if[count inplay; filter[`inPlayOnly]:inplay];
	/ - paramd dictionary
	paramd:`filter`maxResults`marketProjection`sort!(filter;200;("COMPETITION";"EVENT";"EVENT_TYPE";"RUNNER_DESCRIPTION";"RUNNER_METADATA");`MAXIMUM_TRADED);
	/ - build the json req dictionary
	req: jsonStringParam[`listMarketCatalogue;paramd];
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
	data: first system " " sv ("python"," w".os.NT; .os.pth getenv[`KDBBIN],"/getData.py";cmdparams);
	/ - check for errors returned by python handler
	if["ERROR:" ~ 6#data;.lg.e[`callApi;data]];
	/ - convert the json string into a q dictionary
	data:.j.k data;
	/ - check if the response has returned a result (otherwise it will have returned an error)
	$[(`error in key data) and count data`error;
		/ - pull the error code and log the error in the process log
		.lg.e[`callApi;"ERROR response received from Betfair: ",data[`error;`data;`APINGException;`errorCode]];
		:data]}

// session management code		
// function to get a new session token/id
login:{[]
	/ - validate username, password and appKey (cannot be empty)
	$[not count username;.lg.e[`login;"Username cannot be empty. Please check code/settings/requestor.q"];
		not count password;.lg.e[`login;"Password cannot be empty. Please check code/settings/requestor.q"];
		not count appKey;.lg.e[`login;"AppKey cannot be empty. Please check code/settings/requestor.q"];()];
	.lg.o[`login;"Attempting to login to betfair api"];
	loginResp: callApi[`login;jsonStringParam[`;`username`password!(username;password)]];
	$["SUCCESS" ~ respstr:loginResp`loginStatus;
		[.lg.o[`login;"Login successful: ",st:loginResp`sessionToken];sessionToken:: st];
		.lg.e[`login;"Login failed. Response was: ",respstr]];};
// function to keep session alive alive
keepAlive:{[]
	data:callApi[`keepAlive;""];
	$["SUCCESS" ~ data`status;
		.lg.o[`keepAlive;"Keep Alive call has succeeded : ",data`token];
		.lg.e[`keepAlive;"Keep Alive call failed. The error was : ",data`error]]}
// function to logout of session from betfair
logout:{[]
	/ - if there is no session token then escape
	if[not count sessionToken;:()];
	data:callApi[`logout;""];
	$["SUCCESS" ~ data`status;
		[.lg.o[`logout;"Logout call has succeeded : ",data`token]; sessionToken:: ""];
		.lg.e[`logout;"Logout call has failed.  The error was : ",data`error]]}
// add logout call to .z.exit 
if[logoutonexit;
	.z.exit:{[f;x]
		logout[];
		f[x]
		}[@[value;`.z.exit;{{}}]]];
		
// run initialization
\d .
.lg.o[`init;"Loading schema file"];
system .os.pth "l ",getenv[`KDBHOME],"/tick/database.q"; / grab schema
.requestor.init[]
