// this job takes the trades table as it is saved down and writes to a cache called "activeDates", which
// keeps track of what syms are active on each date.  This makes API calls much faster as they know what dates
// to put in the where clause in hdb queries
.wdb.savedownmanipulation:()!();

.wdb.savedownmanipulation[`trade]:{[x]
  hdb:hsym `$getenv[`KDBHOME],"/hdb/database";
  if[not `activeDates in key hdb;set[` sv hdb,`activeDates;()!()]];		/ if activeDates cache doesn't exist, make it  
  ad:get ` sv hdb,`activeDates;							/ get the current activeDates cache from disk
  ds:exec distinct sym from x;							/ what syms were active today
  ad:@[ad;ds;,;.wdb.getpartition[]];						/ write the date into the cache
  ad:distinct each ad								/ make sure there's no dupes
  set[` sv hdb,`activeDates;ad];						/ save it to the hdb
  :x;										/ return the trades table unaltered
 };
