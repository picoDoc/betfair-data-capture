/ - map date to server
mapDateToServer:{[]    
	exec date!servertype from 
		ungroup select date:last attributes@' `date by servertype from .gw.servers where servertype in `hdb`rdb}

getActiveMarkets:{[d]
	/ determine which server to run on
	servers: (),mapDateToServer[][d];
	.gw.syncexec[(`getActiveMarkets;d);servers]}
	
/ - Calculates odds based on matched trades by selection and time window.  Odds returned as implied probability
getOdds:{[mktid;bucket;pivot] data:.gw.syncexec[(`getOdds;mktid;bucket);`hdb`rdb];
		$[count[data] and pivot;
		0!piv[data;`time`sym`eventTypeName`competitionName`marketName`eventName;(),`selectionName;`chance`size];data]}

/ - get the mid price for each selection
getMid:{[mktid;pivot] data:.gw.syncexec[(`getMid;mktid);`hdb`rdb];
		$[count[data] and pivot;
		0!piv[data;`time`sym`eventTypeName`competitionName`marketName`eventName;(),`selectionName;`mid`chance`spread];data]}

/ - get vwaps of each quote tick in specified buckets
getVwap:{[mktid;bkt] .gw.syncexec[(`getVwap;mktid;bkt);`hdb`rdb]}

/ - pivot the data (borrowed from code.kx.com; http://code.kx.com/wiki/Pivot#A_very_general_pivot_function.2C_and_an_example_usage)
piv:{[t;k;p;v;f;g]
 v:(),v;
 G:group flip k!(t:.Q.v t)k;
 F:group flip p!t p;
 count[k]!g[k;P;C]xcols 0!key[G]!flip(C:f[v]P:flip value flip key F)!raze
  {[i;j;k;x;y]
   a:count[x]#x 0N;
   a[y]:x y;
   b:count[x]#0b;
   b[y]:1b;
   c:a i;
   c[k]:first'[a[j]@'where'[b j]];
   c}[I[;0];I J;J:where 1<>count'[I:value G]]/:\:[t v;value F]}[;;;;{[v;P] .Q.id each `$raze each string raze P[;0],'/:(`$"_",'string v),/:\:P[;1]};{[k;P;c]k,c}]
