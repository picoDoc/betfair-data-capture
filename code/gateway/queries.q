getActiveMarkets:{[d]
	/ determine which server to run on
	servers: (),$[d < .proc.cd[];`hdb;`rdb];
	.gw.syncexec[(`getActiveMarkets;d);servers]}
	
/ - Calculates odds based on matched trades by selection and time window.  Odds returned as implied probability
getChances:{[mktid;bucket] .gw.syncexec[(`getChances;mktid;bucket);`hdb`rdb]}

/ - get the mid price for each selection
getMid:{[mktid] .gw.syncexec[(`getMid;mktid);`hdb`rdb]}