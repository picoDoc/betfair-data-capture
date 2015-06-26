// Requestor service to go to betfair and grab data, then send it down to the tickerplant
\d .requestor

// Default Parameters
logoutonexit:@[value;`logoutonexit;1b]		/ - logout of betfair session when the process is shutdown
keepalivetime:@[value;`keepalivetime;0D03]	/ - send a keep alive every X
logonretryintv:@[value;`logonretryintv;0D00:00:10];	/ - in the event of an unsuccessful logon, this is the amount of time to wait before retrying
pubprocs:@[value;`pubprocs;(),`tickerplant1]	/ - list of processes (names not types) to publish data to.  If null symbol, then the 
						/ - the process will not publish data and will used to poll for ad-hoc data (i.e. query via gw)
pubconnsleepintv:@[value;`pubconnsleepintv;5]	/ - number of seconds to sleep before re-attempting to connection to downstream processes

username:@[value;`username;""];			/ - betfair username
password:@[value;`password;""];			/ - betfair password
appKey:@[value;`appKey;""];			/ - betfair application key

datacfgfile:@[value;`datacfgfile;hsym `$getenv[`KDBCONFIG],"/requestor.csv"]	/ - location of the requestor config file
mktdatatimerf:@[value;`mktdatatimerf;0D00:00:02]				/ - how often the timer will check if it needs to poll for market data

repubrefdatatime:@[value;`repubrefdatatime;0D00:00:01]	/ - republish reference data for active subscriptions so ref data for trades and quotes will 
							/ - stored within the same date partition
pythonex:@[value;`pythonex;"python"," w".os.NT]	/ - name of the python executable, defaults to python (osx and linux) or pythonw (windows)
						/ - useful if you have multiple versions installed i.e. "python3.3"

	
// initialization function
init:{[]
	.lg.o[`init;"Running initialization function"];
	sessionToken:: "";
	login[0b];						/ login to the betfair api
	.lg.o[`init;"Setting up timer to refresh session"];
	.timer.rep[.proc.cp[];0Wp;keepalivetime;(`.requestor.keepAlive;`);2h;"refresh the Session Token";1b]; / refresh it every 6 hrs
	$[all n:null pubprocs;
		.lg.o[`init;"pubprocs has not been configured, this process will not publish data"];
		initPublish[n]]}; 

initPublish:{[n]
	.lg.o[`initPublish;"Making connection the tickerplant"];.servers.startup[];				/ connect to the discovery and tp processes
	while[count[pubprocs where not n] > count handles: .servers.getservers[`name;pubprocs;()!();1b;1b]`w;	/ keep looping around until all the connections have been established
		.os.sleep[pubconnsleepintv];.servers.startup[]];  						/ sleep and then run the servers startup code again (to make connection to discovery)
	@[`.requestor;`tphs;:;handles];
	.lg.o[`initPublish;"Setting timer to poll betfair api for data"];
	@[`.requestor;`cfg;:;1!loadConfigFile[]];
	/ - set a global tradeSnapshot table, this is to be used for publishing traded deltas (because betfair only provides the 
	/ - cumulative total traded volumes)
	@[`.requestor;`tradeSnapshot;:;`sym`selectionId`price xkey delete time from `. `trade];	
	/ - set a global marketstatusSnapshot table
	@[`.requestor;`marketstatusSnapshot;:;`sym xkey delete time from `. `marketstatus];
	/ - publish meta data for each of the markets that have been loaded
	if[count cfg;publishMetadata[(0!cfg)`marketId]];
	/ - set timer function to check cfg for whether to poll for data
	.timer.rep[.proc.cp[];0Wp;mktdatatimerf;(`.requestor.pollForMarketDataErrorTrap;`);2h;"check if to poll for market data";0b];
	/ - set timer function to re-publish metadata after the system has rolled}
	.timer.rep[.proc.cd[] + repubrefdatatime;0Wp;1D;(`.requestor.republishRefData;`);2h;"republish metadata";0b]}
	
// function to load the config file
loadConfigFile:{[] 
	/ - read in the config file
	data: delete from (("S***N"; enlist ",") 0: datacfgfile) where null marketId;
	/ - parse the start and end time columns
	data: update start: .requestor.parseTimeCols[start], .requestor.parseTimeCols[end] from data;
	/ - tag on next run times for each market
	update nextruntime: .proc.cp[] + interval from data}
	
// function to convert strings into timestamps, this is to allow functional configs such as .z.p, .proc.cp[] etc...
parseTimeCols:{[x] `timestamp$ value each x}
// function to identify when to poll for data for each market
pollForMarketData:{[]
	now: .proc.cp[];
	/ - if there is nothing to be run now, then just escape
	if[not count t:select from cfg where end > now, nextruntime <= now;:()]; 
	/ - cut the marketIds into groups of 6 (6 is the maximum allowable by the Betfair API otherwise a TOO_MUCH_DATA error will be returned)
	publishMarketData each 6 cut (0!t)`marketId;
	/ - update the next run time 
	update nextruntime:.proc.cp[]+interval from `.requestor.cfg where end > now, nextruntime <= now}
// error trap the pollForMarketData
pollForMarketDataErrorTrap:{[] @[pollForMarketData;`;{.lg.e[`pollForMarketData;"Function call failed with error code : ",x]}]}
// delete market id from requestor config and snapshot tables
delFromCfg:{[ids] 
	.lg.o[`delFromCfg;"Removing id(s) from cfg : ","," sv string ids:(),ids];
	delete from `.requestor.cfg where marketId in ids;
	/ - removed id(s) from snapshot tables
	delete from `.requestor.tradeSnapshot where sym in ids;
	delete from `.requestor.marketstatusSnapshot where sym in ids}
	
addSubscription:{[name;id;end;interval]
	if[all null id:(),id;:()];
	/ - update the .requestor.cfg table
	`.requestor.cfg upsert ([] marketId: id;market: {$[10h = type[x];enlist x;x]} name;start: .proc.cp[];end: end;interval: interval;nextruntime: .proc.cp[]);
	/ - publish meta data for new id(s)
	publishMetadata[id]}

// function to convert kdb dictionary into a string which can be passed as a command line parameter
jsonStringParam:{[api;d]
	if[not null api;d:`jsonrpc`method`params`id!("2.0";"SportsAPING/v1.0/",string api;d;1)];
	/ - convert the dictionary into a json string
	jsonstr: .j.j[d];
	/ - do some platform specific formatting of the string so that it can be 
	/ - passed as a command line parameter on both DOS ans Unix-like systems
	$[.os.NT;ssr[jsonstr;"\"";"\\\""];"'",jsonstr,"'"]}

// function to get market data and send to tp for a given marketid
publishMarketData:{[id]
	/ - get the market book data ( trades and quotes )
	data: getMarketBook[id:(),id]`result;
	/ - make the keys/columns homogeneous for each marketid (so dictionaries will collapse into a queriable table)
	data: {x!y[x]}[raze distinct key each data;] each data;
	/ - get market status messages
	marketstatuses: statusDelta[select sym: `$marketId, `$status, inplay from data];
	/ - remove "CLOSED" markets
	if[ any clsbool: "CLOSED" ~/: data`status;
		delFromCfg `$data[`marketId] where clsbool;	/ - remove closed markets from cfg so we don't poll for them again
		if[not count data: delete from data where clsbool;:()]];
	r: ungroup select sym:`$marketId, selectionId:`int$runners @'' `selectionId, ex:runners @'' `ex from data;
	/ - format the trades from the market book data
	trades: ungroup select sym, selectionId, price:.requestor.extractPricesSizes[`tradedVolume`price;ex], size:.requestor.extractPricesSizes[`tradedVolume`size;ex] from r;
	/ - get deltas for traded volumes (between the last tick and the current tick)
	trades: calcTradedDelta[trades];
	/ - format the quotes from the market book data
	quotes: select sym, selectionId, backs: .requestor.extractPricesSizes[`availableToBack`price;ex], lays: `s#'.requestor.extractPricesSizes[`availableToLay`price;ex],
			bsizes: .requestor.extractPricesSizes[`availableToBack`size;ex],lsizes: .requestor.extractPricesSizes[`availableToLay`size;ex] from r;
	/ - remove quotes that don't have data on either side
	quotes: delete from quotes where all each 0 =(count'') flip (backs;lays);
	/ - publish the data to the tickerplant
	pubDataToTp'[`marketstatus`trade`quote;(marketstatuses;trades;quotes)]};

// function to determine deltas in traded volumes
calcTradedDelta:{[data]
	/ - upsert any markets that aren't already present in tradesSnapshot
	`.requestor.tradeSnapshot upsert select from data where not sym in exec sym from .requestor.tradeSnapshot;
	/ - get the delta values, where size is greater than 0
	deltaData: 0! select from ((`sym`selectionId`price xkey data) - tradeSnapshot) where size > 0;
	/ - upsert the trade data (data) into tradeSnapshot to calculate the next tick
	`.requestor.tradeSnapshot upsert data;
	/ - return the delta data	
	deltaData}

// function to determine if there is any change in status of a particular market, we only want to publish deltas
statusDelta:{[data]
	/ - get any status messages that aren't already present
	deltaData: data except 0!marketstatusSnapshot;
	/ - update the snapshot
	`.requestor.marketstatusSnapshot upsert data;
	/ - return the delta data
	deltaData}

// function for pulling out prices and size of quotes and trades
extractPricesSizes:{[x;y] @[@/[;x];;`float$()] each y}
	
// function to publish meta data to downstream processes	
publishMetadata:{[ids]
	if[not count t:getMetadata[ids];:()]; / - escape if not meta data returned
	/ - publish the data to the tickerplant
	pubDataToTp[`metadata; (cols[`. `metadata] except `time) # t]}
	
// function to republish ref data for all active markets
republishRefData:{[] publishMetadata (0!cfg)`marketId;
			pubDataToTp[`marketstatus;0!marketstatusSnapshot]}
 
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

// function to data to the tickerplant
pubDataToTp:{[tabname;data] if[not count data;:()]; neg[tphs] @\: (`.u.upd;tabname;$[type data;value flip 0!data;data])}

// function to get meta data about given market id
getMetadata:{[marketids] distinct ungroup getMarketCatalogue[0N;marketids;();()]}

// function to get a table of all the event types
getEventTypes:{[]
	data: callApi[`data;jsonStringParam[`listEventTypes;enlist[`filter]!enlist ()!()]];
	select eventid: `$eventType @' `id, eventname: `$eventType @' `name, marketcount: marketCount from data`result}

// function to return a table of markets for a particular sports id
marketCatalogue:([] eventTypeId:`int$();eventTypeName:`symbol$();competitionId:`int$();competitionName:`symbol$();sym:`symbol$();marketName:`symbol$();
		totalMatched:`float$();eventId: `int$();eventName: `symbol$();timezone: `symbol$();openDate: `timestamp$();selectionName: ();selectionId: ())
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
	if[ not count data: callApi[`data;req][`result];:0#marketCatalogue];	/ - if nothing returned, then escape returning an empty schema
	/ - some markets don't return anything for competition 
	data:{y!x[y]}[;`eventType`competition`marketId`totalMatched`marketName`event`runners] each data;
	/ - return a table with info for the markets
	select eventTypeId: "I" $ eventType @' `id, eventTypeName: `$ eventType @' `name,    competitionId: "I" $ {@[@[;x];;""]@'y}[`id;competition], 
		competitionName: `$ {@[@[;x];;""]@'y}[`name;competition],sym: `$ marketId, `$ marketName, totalMatched, eventId: "I" $ event @' `id, 
		eventName: `$ event @' `name, timezone: `$event @' `timezone,	openDate: "P" $ -1_ 'event @' `openDate, 
		selectionName: `$runners @'' `runnerName,  selectionId: `int$ runners @'' `selectionId from data}

// function to call the betfair api for data requests
callApi:{[typ;req]
	/ - build the command line params to be passed to the python script
	cmdparams: " " sv (string typ;appKey;sessionToken;req);
	/ - submit the request via the python handler
	data: first system " " sv (pythonex; .os.pth getenv[`KDBBIN],"/getData.py";cmdparams);
	/ - check for errors returned by python handler
	if["ERROR:" ~ 6#data;.lg.e[`callApi;data]];
	/ - convert the json string into a q dictionary
	data:.j.k data;
	/ - check if the response has returned a result (otherwise it will have returned an error)
	$[(`error in key data) and count data`error;
		/ - pull the error code and log the error in the process log
		[.lg.e[`callApi;"ERROR response received from Betfair: ",errorCode:data[`error;`data;`APINGException;`errorCode]];
		if[errorCode ~ "INVALID_SESSION_INFORMATION"; login[0b]]]; / - if INVALID_SESSION_INFORMATION error returned, attempt to login again
		:data]}

// session management code		
// function to get a new session token/id
login:{[retry]
	/ - validate username, password and appKey (cannot be empty)
	$[not count username;.lg.e[`login;"Username cannot be empty. Please check code/settings/requestor.q"];
		not count password;.lg.e[`login;"Password cannot be empty. Please check code/settings/requestor.q"];
		not count appKey;.lg.e[`login;"AppKey cannot be empty. Please check code/settings/requestor.q"];()];
	.lg.o[`login;"Attempting to login to betfair api..."];
	/ - if the call to login throws an error, keep retrying 
	loginResp: .[callApi;(`login;jsonStringParam[`;`username`password!(username;password)]);{[e] retrylogin[e]}];
	if[retry;: loginResp]; / - if this is a retry attempt, then escape here
	/ - if the login response was not SUCCESS, then retry
	$["SUCCESS" ~ respstr:loginResp`loginStatus;
		[.lg.o[`login;"Login successful: ",st:loginResp`sessionToken]; sessionToken:: st];
		retrylogin[respstr]]}; 
retrylogin:{[errMsg]
		.lg.o[`login;"Login failed. Response was: ",respstr,". Retrying login in ",string logonretryintv];
		.os.sleep `int$`second$logonretryintv; login[1b]}; / - sleep for while and then retry login
// function to keep session alive alive
keepAlive:{[]
	data:callApi[`keepAlive;""];
	$["SUCCESS" ~ data`status;
		.lg.o[`keepAlive;"Keep Alive call has succeeded : ",data`token];
		/ - if it fails, log an error and login again
		[.lg.e[`keepAlive;"Keep Alive call failed. The error was : ",data`error];login[0b]]]}
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
