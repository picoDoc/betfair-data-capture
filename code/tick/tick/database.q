trade:([]
  time:`timestamp$();
  sym:`$();
  selectionId:`int$();
  price:`float$();
  size:`float$());

quote:([]
  time:`timestamp$();
  sym:`$();
  selectionId:`int$();
  backs: ();
  lays: ();
  bsizes: ();
  lsizes:());
 
metadata:([]
	time:`timestamp$();
	sym:`symbol$();
	eventTypeId:`int$();
	eventTypeName:`symbol$();
	competitionId:`int$();
	competitionName: `symbol$();
	marketName: `symbol$();
	eventId: `int$();
	eventName: `symbol$();
	timezone: `symbol$();
	openDate: `timestamp$();
	selectionName: `symbol$();
	selectionId: `int$());
	
marketstatus:([] 
	time:`timestamp$();
	sym:`symbol$();
	status: `symbol$();
	inplay: `boolean$())


