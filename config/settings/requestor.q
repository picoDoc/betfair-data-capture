// Requestor config
.requestor.markets:([]market:();marketId:();start:();end:();interval:());  // Table for markets to gather data on
.servers.enabled:1b
.servers.CONNECTIONS:enlist `tickerplant         // Requestor connects to the tickerplant
.servers.HOPENTIMEOUT:30000

// betfair login details (add your own here)
.requestor.username:"";
.requestor.password:"";
.requestor.appKey:"";

///// market examples //////

// English premier league winner football 
//`.requestor.markets insert (`PremierLeague;`1.113659986;.z.p;0Wp;00:15:00.000000000);

// European champions league winner football 
//`.requestor.markets insert (`ChampionsLeague;`1.114199118;.z.p;0Wp;00:15:00.000000000);

// UK gereranl election most seats 
//`.requestor.markets insert (`UKElectionMostSeats;`1.101416473;.z.p;0Wp;00:15:00.000000000);
