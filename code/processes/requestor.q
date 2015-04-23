// Requestor service to go to betfair and grab data, then send it down to the tickerplant

// init function
.requestor.init:{[]
  .requestor.getSessionToken[];							/ get sessionToken
  .timer.rep[.z.p;0Wp;0D06:00:00;(`.requestor.getSessionToken;`);2h;"refresh the Session Token";1b]; / refresh it every 6 hrs
  .requestor.metaData:enlist[`]!();						/ initialize some dictionaries
  .requestor.selectionIds:enlist[`]!();
  .requestor.runnerIds:enlist[`]!();
  system"l ",getenv[`KDBHOME],"/tick/database.q";				/ grab schema
  .servers.startup[];								/ connect to the discovery and tp processes
  .requestor.tp:.servers.gethandlebytype[`tickerplant;`any];									
  {.timer.rep[x`start;x`end;x`interval;(`.requestor.callGetMarketData;x`marketId);2h;"get betfair data";0b]}each .requestor.markets; / add a job for each market in config
 };

// function to get a new session token/id
.requestor.getSessionToken:{[]
  .requestor.sessionToken:@[;`sessionToken].j.k first system" " sv ("bash $KDBBIN/getToken_curl.bash";.requestor.username;.requestor.password);
 };

// function to get market data and send to tp for a given marketid
.requestor.getMarketData:{[id]
  if[not(id)in key .requestor.metaData;.requestor.getMetaData string id];	/ if we don't have metadata for this market go get it
  r:system" "sv("bash $KDBBIN/marketdata_wget.bash";.requestor.appKey;.requestor.sessionToken;string id); / get market data through script
  r:.j.k 1_-1_first r;								/ remove "[]" from the data, then convert out of json
  r:r`runners;									/ we only need the stuff under this key  
  
  trades:raze {if[98h<>type t:x[`ex;`tradedVolume];:()];update selectionId:x`selectionId from t}each r; / grab trades data (if it's there)
  trades:update .requestor.selectionIds[id;selectionId] from trades;		/ replace selectionId with selection names
  trades:flip[count[trades]#/:`$.requestor.metaData[id]],'trades;		/ add in meta data
  trades:`sym xcol `name xcols trades; 						/ give it sym cols to keep kdb happy (sym is the market name)
  trades:cols[trade]#update time:.z.p from trades;				/ add time and reorder to match schema

  quotes:raze {if[98h<>type t:x[`ex;`availableToBack];:()];update selectionId:x`selectionId,side:`back from t}each r; / grab quotes data (backers)
  quotes,:raze {if[98h<>type t:x[`ex;`availableToLay];:()];update selectionId:x`selectionId,side:`lay from t}each r; / grab quotes data (layers)
  quotes:update .requestor.selectionIds[id;selectionId] from quotes;		/ replace selectionId with selection names 
  quotes:flip[count[quotes]#/:`$.requestor.metaData[id]],'quotes;		/ add in meta data
  quotes:`sym xcol `name xcols quotes;						/ give it sym cols to keep kdb happy (sym is the market name)
  quotes:cols[quote]#update time:.z.p from quotes;				/ add time and reorder to match schema
  
  {neg[.requestor.tp](`.u.upd;x;value flip y)}'[`trade`quote;(trades;quotes)];	/ push to the tp
 };

// error trapped call to getMarketData
.requestor.callGetMarketData:{[id]
  e:{.lg.e[`APING_CALL_FAILED;"call to betfair failed with error ",x]};
  @[.requestor.getMarketData;id;e];
 };

// function to get meta data about given market id
.requestor.getMetaData:{[id]
  r:system" "sv("bash $KDBBIN/metadata_wget.bash";.requestor.appKey;.requestor.sessionToken;id); / get meta data through script
  r:.j.k 1_-1_first r;								/ remove "[]" from the data, then convert out of json
  .requestor.selectionIds[`$id]:first each exec `$runnerName by selectionId from r`runners; / populate selectionIds,
  .requestor.runnerIds[`$id]:exec `$runnerName by runnerId from update runnerId:`$value each metadata from r`runners; / runnerIds
  .requestor.metaData[`$id]:r`event;						/ and some other stuff...
  .requestor.metaData[`$id],:`marketName`eventType!(r`marketName;r[`eventType;`name]);
 };

// run initialization
.requestor.init[]
