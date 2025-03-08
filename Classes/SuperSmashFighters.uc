class SuperSmashFighters extends GGMutator;

var SuperSmashArena mSSA;

var float mTimeBeforeDissapear;

struct BrokenApex{
	var GGApexDestructibleActor apexActor;
	var float timeBroken;
};
var array<BrokenApex> mApexToDestroy;

function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;

	goat = GGGoat( other );

	if( goat != none )
	{
		if( IsValidForPlayer( goat ) )
		{
			if(!IsTimerActive(NameOf(InitSSB)))
			{
				SetTimer(1.f, false, NameOf(InitSSB));
			}
		}
	}

	super.ModifyPlayer( other );
}

function InitSSB()
{
	local SuperSmashArena ssa;

	//Find Super Smash Goats mutator
	foreach AllActors(class'SuperSmashArena', ssa)
	{
		if(ssa != none)
		{
			break;
		}
	}

	if(ssa == none)
	{
		DisplayUnavailableMessage();
		return;
	}

	mSSA = ssa;
	mSSA.OnBattleStarted=OnBattleStarted;
	mSSA.OnBattleEnded=OnBattleEnded;
	mSSA.OnPlayerLost=OnPlayerLost;
}

function OnBattleStarted()
{
	local int i;
	local GGAIControllerSSB newSSBContr;

	for(i=0 ; i<mSSA.battlePlayers.Length ; i++)
	{
		if(GGNpc(mSSA.battlePlayers[i].gpawn) != none && PlayerController(mSSA.battlePlayers[i].gpawn.Controller) == none)
		{
			newSSBContr=Spawn(class'GGAIControllerSSB', self);
			newSSBContr.Possess(mSSA.battlePlayers[i].gpawn, false);
		}
	}
}

function OnBattleEnded()
{
	local GGAIControllerSSB SSBContr;

	foreach AllActors(class'GGAIControllerSSB', SSBContr)
	{
		SSBContr.Unpossess();
		SSBContr.Destroy();
	}
}

function OnPlayerLost(GGPawn gpawn)
{
	local GGAIControllerSSB SSBContr;

	SSBContr=GGAIControllerSSB(gpawn.Controller);
	if(SSBContr != none)
	{
		SSBContr.Unpossess();
		SSBContr.Destroy();
	}
}

function DisplayUnavailableMessage()
{
	WorldInfo.Game.Broadcast(self, "Super Smash Bots only works if combined with Super Smash Arena.");
	SetTimer(3.f, false, NameOf(DisplayUnavailableMessage));
}

function AddApexToDestroy(GGApexDestructibleActor newApex)
{
	local BrokenApex newBrokenApex;

	newBrokenApex.apexActor=newApex;
	newBrokenApex.timeBroken=WorldInfo.TimeSeconds;
	if(mApexToDestroy.Find('apexActor', newApex) == INDEX_NONE)
	{
		mApexToDestroy.AddItem(newBrokenApex);
	}
}

event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	SlowlyDestroyApex();
}

function SlowlyDestroyApex()
{
	local int i;
	local float timeNow;
	local GGApexDestructibleActor tmpApex;

	timeNow=WorldInfo.TimeSeconds;
	for(i=0 ; i<mApexToDestroy.Length ; i=i)
	{
		tmpApex=mApexToDestroy[i].apexActor;
		if(!tmpApex.mIsFractured)
		{
			tmpApex.Fracture(0, none, tmpApex.Location, vect(0, 0, 0), class'GGDamageTypeCollision');
		}
		if(timeNow-mApexToDestroy[i].timeBroken < mTimeBeforeDissapear)
		{
			i++;
			continue;
		}

		mApexToDestroy.Remove(i, 1);
		tmpApex.Shutdown();
		tmpApex.Destroy();
	}
}

DefaultProperties
{
	mTimeBeforeDissapear=5.f
}