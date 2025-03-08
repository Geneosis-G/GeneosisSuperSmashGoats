class GGAIControllerSSB extends GGAIControllerPassiveGoat;

var SuperSmashFighters myMut;

var kActorSpawnable destActor;
var bool cancelNextRagdoll;
var float totalTime;
var bool isPossessing;

var float mDestinationOffset;
var vector startPos;
var rotator startRot;

var float mRagdollMomentumMultiplier;
var float mAttackMomentum;
var float mAttackDamage;
var bool mIsInAir;
var float mMaxTimeWithoutAttack;

var array<NPCAnimationInfo> mOldAnims;

event PostBeginPlay()
{
	super.PostBeginPlay();

	myMut=SuperSmashFighters(Owner);
}

/**
 * Cache the NPC and mOriginalPosition
 */
event Possess(Pawn inPawn, bool bVehicleTransition)
{
	local ProtectInfo destination;
	local GGAIController oldController;
	local GGNpcMMOAbstract MMONpc;
	local GGNpcZombieGameModeAbstract zombieNpc;

	oldController=GGAIController(inPawn.Controller);
	super.Possess(inPawn, bVehicleTransition);
	if(oldController != none) oldController.Destroy();

	isPossessing=true;
	if(mMyPawn == none)
		return;

	startPos=mMyPawn.Location;
	startRot=mMyPawn.Rotation;

	mMyPawn.mStandUpDelay=1.0f;
	mMyPawn.mTimesKnockedByGoat=0.f;
	mMyPawn.mTimesKnockedByGoatStayDownLimit=1000000.f;
	mMyPawn.EnableStandUp( class'GGNpc'.const.SOURCE_EDITOR );
	mMyPawn.mCanBeAddedToInventory=false;

	mMyPawn.RotationRate=rot(160000, 160000, 160000);
	mMyPawn.JumpZ=650.f;

	mMyPawn.SightRadius=myMut.mSSA.arenaSize*2.f;
	if(mMyPawn.mAttackRange<class'GGNpc'.default.mAttackRange) mMyPawn.mAttackRange=class'GGNpc'.default.mAttackRange;

	SetDefaultAnimations(mMyPawn);

	MMONpc = GGNpcMMOAbstract(mMyPawn);
	if(MMONpc != none)
	{
		MMONpc.mHealthMax=100000000.f;
		MMONpc.mHealth=MMONpc.mHealthMax;
		MMONpc.LifeSpan=MMONpc.default.LifeSpan;
		MMONpc.mNameTagColor=MMONpc.default.mNameTagColor;
	}
	zombieNpc = GGNpcZombieGameModeAbstract(mMyPawn);
	if(zombieNpc != none)
	{
		zombieNpc.mHealth=zombieNpc.default.mHealthMax;
		zombieNpc.mIsPendingDeath=false;
		zombieNpc.mCanDie=false;
	}

	mMyPawn.mProtectItems.Length=0;
	if(destActor == none)
	{
		destActor = Spawn(class'kActorSpawnable', mMyPawn,,,,,true);
		destActor.SetHidden(true);
		destActor.SetPhysics(PHYS_None);
		destActor.CollisionComponent=none;
	}
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " destActor=" $ destActor);
	destActor.SetLocation(mMyPawn.Location);
	destination.ProtectItem = mMyPawn;
	destination.ProtectRadius = 1000000.f;
	mMyPawn.mProtectItems.AddItem(destination);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " mMyPawn.mProtectItems[0].ProtectItem=" $ mMyPawn.mProtectItems[0].ProtectItem);
	StandUp();
}

event UnPossess()
{
	local GGNpcMMOAbstract MMONpc;
	local GGNpcZombieGameModeAbstract zombieNpc;

	if(mMyPawn != none)
	{
		mMyPawn.mStandUpDelay=mMyPawn.default.mStandUpDelay;
		mMyPawn.mTimesKnockedByGoat=0.f;
		mMyPawn.mTimesKnockedByGoatStayDownLimit=mMyPawn.default.mTimesKnockedByGoatStayDownLimit;
		mMyPawn.mCanBeAddedToInventory=mMyPawn.default.mCanBeAddedToInventory;
		mMyPawn.RotationRate=mMyPawn.default.RotationRate;
		mMyPawn.JumpZ=mMyPawn.default.JumpZ;
		mMyPawn.SightRadius=mMyPawn.default.SightRadius;
		mMyPawn.mProtectItems=mMyPawn.default.mProtectItems;
		mMyPawn.mAttackRange=mMyPawn.default.mAttackRange;
		mMyPawn.mRunAnimationInfo=mOldAnims[0];
		mMyPawn.mDefaultAnimationInfo=mOldAnims[1];
		mMyPawn.mAttackAnimationInfo=mOldAnims[2];
		MMONpc = GGNpcMMOAbstract(mMyPawn);
		if(MMONpc != none)
		{
			MMONpc.mHealth=MMONpc.default.mHealth;
			MMONpc.mHealthMax=MMONpc.mHealth;
		}
		zombieNpc = GGNpcZombieGameModeAbstract(mMyPawn);
		if(zombieNpc != none)
		{
			zombieNpc.mCanDie=zombieNpc.default.mCanDie;
		}
	}

	if(destActor != none)
	{
		destActor.ShutDown();
		destActor.Destroy();
	}

	isPossessing=false;
	super.UnPossess();
	if(mMyPawn != none)
	{
		mMyPawn.SpawnDefaultController();
		if(GGAIController(mMyPawn.Controller) != none) GGAIController(mMyPawn.Controller).ResumeDefaultAction();
	}
	mMyPawn=none;
}

//Kill AI if zombie is destroyed
function bool KillAIIfPawnDead()
{
	if(mMyPawn == none || mMyPawn.bPendingDelete || mMyPawn.Controller != self)
	{
		UnPossess();
		Destroy();
		return true;
	}

	return false;
}

function SetDefaultAnimations(GGNpc npc)
{
	mOldAnims.Length=0;
	mOldAnims.AddItem(mMyPawn.mRunAnimationInfo);
	mOldAnims.AddItem(mMyPawn.mDefaultAnimationInfo);
	mOldAnims.AddItem(mMyPawn.mAttackAnimationInfo);
	npc.mRunAnimationInfo=class'GGNpcAgressiveGoat'.default.mRunAnimationInfo;
	npc.mDefaultAnimationInfo=class'GGNpcAgressiveGoat'.default.mDefaultAnimationInfo;
	npc.mAttackAnimationInfo=class'GGNpcAgressiveGoat'.default.mAttackAnimationInfo;
	// Set default anims
	if(!IsAnimInSet('Idle', npc))
	{
		npc.mDefaultAnimationInfo.AnimationNames[0]='Idle_01';
		if(!IsAnimInSet('Idle_01', npc))
		{
			npc.mDefaultAnimationInfo.AnimationNames[0]='Idle_02';
		}
	}
	if(!IsAnimInSet('Sprint', npc))
	{
		npc.mRunAnimationInfo.AnimationNames[0]='Sprint_01';
		if(!IsAnimInSet('Sprint_01', npc))
		{
			npc.mRunAnimationInfo.AnimationNames[0]='Sprint_02';
			if(!IsAnimInSet('Sprint_02', npc))
			{
				npc.mRunAnimationInfo.AnimationNames[0]='Run';
				if(!IsAnimInSet('Run', npc))
				{
					npc.mRunAnimationInfo.AnimationNames[0]='Walk';
				}
			}
		}
	}
	if(!IsAnimInSet('Ram', npc))
	{
		npc.mAttackAnimationInfo.AnimationNames[0]='Attack';
		if(!IsAnimInSet('Attack', npc))
		{
			npc.mAttackAnimationInfo.AnimationNames[0]='Kick';
		}
	}
}

function bool IsAnimInSet(name animName, GGPawn gpawn)
{
	local AnimSequence animSeq;

	if(gpawn == none || gpawn.mesh.AnimSets.Length == 0)
		return false;

	foreach gpawn.mesh.AnimSets[0].Sequences(animSeq)
	{
		if(animSeq.SequenceName == animName)
		{
			return true;
		}
	}

	return false;
}

event Tick( float deltaTime )
{
	//Kill destroyed bots
	if(isPossessing)
	{
		if(KillAIIfPawnDead())
		{
			return;
		}
	}

	// Optimisation
	if( mMyPawn.IsInState( 'UnrenderedState' ) )
	{
		return;
	}

	Super.Tick( deltaTime );

	// Fix dead attacked pawns
	if( mPawnToAttack != none )
	{
		if( mPawnToAttack.bPendingDelete )
		{
			mPawnToAttack = none;
		}
	}

	//Fix original position
	if(mOriginalPosition != startPos)
	{
		mOriginalPosition=startPos;
		mOriginalRotation=startRot;
	}

	// if pawn stuck in a wall or something
	if(mAttackIntervalInfo.LastTimeStamp != 0.f && WorldInfo.TimeSeconds-mAttackIntervalInfo.LastTimeStamp >= mMaxTimeWithoutAttack)
	{
		mAttackIntervalInfo.LastTimeStamp=WorldInfo.TimeSeconds;
		myMut.mSSA.mSSG.RespawnSSG(myMut.mSSA.mSSG.mSSGs.Find('gpawn', mMyPawn));
	}

	CollectNPCAirInfo();

	cancelNextRagdoll=false;
	if(!mMyPawn.mIsRagdoll)
	{
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " mCurrentState=" $ mCurrentState $ ", mPawnToAttack=" $ mPawnToAttack $ ", mVisibleEnemies=" $ mVisibleEnemies.Length);
		//Fix NPC with no collisions
		if(mMyPawn.CollisionComponent == none)
		{
			mMyPawn.CollisionComponent = mMyPawn.Mesh;
		}

		//Fix NPC rotation
		UnlockDesiredRotation();
		if(mPawnToAttack != none)
		{
			Pawn.SetDesiredRotation( rotator( Normal2D( GetPawnPosition(mPawnToAttack) - GetPawnPosition(Pawn) ) ) );
			mMyPawn.LockDesiredRotation( true );

			//Fix pawn stuck after attack
			if(!IsValidEnemy(mPawnToAttack) || !PawnInRange(mPawnToAttack))
			{
				EndAttack();
			}
			else if(mCurrentState == '')
			{
				GotoState( 'ChasePawn' );
			}
		}
		else
		{
			if(VSize2D(mOriginalPosition - mMyPawn.Location) == 0.f)
			{
				Pawn.SetDesiredRotation( rotator( Normal2D( mOriginalPosition - mMyPawn.Location ) ) );
			}
			else
			{
				Pawn.SetDesiredRotation(mOriginalRotation);
			}
			mMyPawn.LockDesiredRotation( true );

			//WorldInfo.Game.Broadcast(self, mMyPawn $ "(" $ mMyPawn.Physics $ ")");
			//WorldInfo.Game.Broadcast(self, mMyPawn $ "(" $ mMyPawn.mCurrentAnimationInfo.AnimationNames[0] $ ")");
			//WorldInfo.Game.Broadcast(self, mMyPawn $ "(" $ mCurrentState $ ")");

		}
		// if waited too long to before reaching some place or some target, abandon
		totalTime = totalTime + deltaTime;
		if(totalTime > 11.f)
		{
			totalTime=0.f;
			if(!mIsInAir)
			{
				mMyPawn.DoJump( true );
			}
			else
			{
				mMyPawn.SetRagdoll(true);
			}
		}
	}
	else
	{
		//Fix NPC not standing up
		if(!IsTimerActive( NameOf( StandUp ) ))
		{
			StartStandUpTimer();
		}
		//Swim
		if(mMyPawn.mInWater)
		{
			totalTime = totalTime + deltaTime;
			if(totalTime > 1.f)
			{
				totalTime=0.f;
				DoRagdollJump();
			}
		}
	}
}

function CollectNPCAirInfo()
{
	local vector hitLocation, hitNormal;
	local vector traceStart, traceEnd, traceExtent;
	local float traceOffsetZ, distanceToGround;
	local Actor hitActor;

	traceExtent = mMyPawn.GetCollisionExtent() * 0.75f;
	traceExtent.Y = traceExtent.X;
	traceExtent.Z = traceExtent.X;

	traceOffsetZ = traceExtent.Z + 10.0f;
	traceStart = mMyPawn.mesh.GetPosition() + vect( 0.0f, 0.0f, 1.0f ) * traceOffsetZ;
	traceEnd = traceStart - vect( 0.0f, 0.0f, 1.0f ) * 100000.0f;

	hitActor = mMyPawn.Trace( hitLocation, hitNormal, traceEnd, traceStart,, traceExtent );
	if(hitActor == none)
	{
		hitLocation=traceEnd;
	}

	distanceToGround = FMax( VSize( traceStart - hitLocation ) - mMyPawn.GetCollisionHeight() - traceOffsetZ, 0.0f );

	mIsInAir = !mMyPawn.mIsInWater && ( mMyPawn.Physics == PHYS_Falling || ( mMyPawn.Physics == PHYS_RigidBody && distanceToGround > class'GGGoat'.default.mIsInAirThreshold ) );
}

/**
 * Do ragdoll jump, e.g. for jumping out of water.
 */
function DoRagdollJump()
{
	local vector newVelocity;

	newVelocity = Normal2D(startPos-GetPawnPosition(mMyPawn));
	newVelocity.Z = 1.f;
	newVelocity = Normal(newVelocity) * mMyPawn.JumpZ;

	mMyPawn.mesh.SetRBLinearVelocity( newVelocity );
}

function StartProtectingItem( ProtectInfo protectInformation, GGPawn threat )
{
	StopAllScheduledMovement();
	totalTime=0.f;

	if(threat == none)
		return;

	mCurrentlyProtecting = protectInformation;

	mPawnToAttack = threat;

	StartLookAt( threat, 5.0f );

	GotoState( 'ChasePawn' );
}

/**
 * Initiate the attack chain
 * called when our pawn needs to protect a given item
 */
function StartAttack( Pawn pawnToAttack )
{
	local name animName;

	super.StartAttack(pawnToAttack);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " StartAttack playedanim=" $ mMyPawn.mAnimNodeSlot.GetPlayedAnimation());
	animName=mMyPawn.mAttackAnimationInfo.AnimationNames[0];
	if(animName == ''
	|| mMyPawn.mesh.GetAnimLength(animName) == 0.f
	|| !IsAnimInSet(animName, mMyPawn)
	|| mMyPawn.mAnimNodeSlot.GetPlayedAnimation() != animName)
	{
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " Instant Attack");
		AttackPawn();
	}
}

/**
 * Attacks mPawnToAttack using mMyPawn.mAttackMomentum
 * called when our pawn needs to protect and item from a given pawn
 */
function AttackPawn()
{
	local vector dir, hitLocation;
	local float	ColRadius, ColHeight, momentum;
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " AttackPawn");
	StartLookAt( mPawnToAttack, 5.0f );

	mPawnToAttack.GetBoundingCylinder( ColRadius, ColHeight );
	dir = Normal( GetPawnPosition(mPawnToAttack) - GetPawnPosition(mMyPawn) );
	hitLocation = GetPawnPosition(mPawnToAttack) - 0.5f * ( ColRadius + ColHeight ) *  dir;

	if( mPawnToAttack.DrivenVehicle == none )
	{
		if(Rand(2) == 0)
		{
			GGPawn(mPawnToAttack).SetRagdoll(true);
		}
		if(mPawnToAttack.Physics != PHYS_RigidBody)
		{
			mPawnToAttack.SetPhysics( PHYS_Falling );
		}
		//apply force, with a random factor (0.75 - 1.25)
		momentum=mAttackMomentum * Lerp( 0.75f, 1.25f, FRand() );
		if(mPawnToAttack.Physics == PHYS_RigidBody)
		{
			mPawnToAttack.mesh.AddImpulse( dir * momentum * mRagdollMomentumMultiplier , , , false );
		}
		else
		{
			dir.Z += 1.0f;
			mPawnToAttack.HandleMomentum( dir * momentum, hitLocation, class'GGDamageTypeAbility' );
		}
		mPawnToAttack.TakeDamage(mAttackDamage, self, hitLocation, vect(0, 0, 0), class'GGDamageTypeAbility');
	}

	ClearTimer( nameof( DelayedGoToProtect ) );
	SetTimer( 0.1f, false, nameof( DelayedGoToProtect ) );

	mAttackIntervalInfo.LastTimeStamp = WorldInfo.TimeSeconds;
	totalTime=0.f;

	//Fix pawn stuck after attack
	if(IsValidEnemy(mPawnToAttack) && PawnInRange(mPawnToAttack))
	{
		GotoState( 'ChasePawn' );
	}
	else
	{
		EndAttack();
	}
}

/**
 * We have to disable the notifications for changing states, since there are so many npcs which all have hundreds of calls.
 */
state MasterState
{
	function BeginState( name prevStateName )
	{
		mCurrentState = GetStateName();
	}
}

state ChasePawn extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );

	while(mPawnToAttack != none && !KillAIIfPawnDead() && (VSize( GetPawnPosition(mMyPawn) - GetPawnPosition(mPawnToAttack) ) > mMyPawn.mAttackRange || !ReadyToAttack()))
	{
		MoveToward( mPawnToAttack,, mDestinationOffset );
	}

	if(mPawnToAttack == none)
	{
		ReturnToOriginalPosition();
	}
	else
	{
		FinishRotation();
		GotoState( 'Attack' );
	}
}

state Attack extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	Focus = mPawnToAttack;

	StartAttack( mPawnToAttack );
	FinishRotation();
}

state ProtectItem
{
Begin:
	if(!IsValidEnemy(mPawnToAttack))
	{
		EndAttack();
	}

	UnlockDesiredRotation();

	if( !mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mRunAnimationInfo ) )
	{
		mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );
	}

	if( VSize( GetPawnPosition(mMyPawn) - GetPawnPosition(mPawnToAttack) ) > mMyPawn.mAttackRange )
	{
		MoveToward( mPawnToAttack,, mMyPawn.mAttackRange );
	}

	if( !mMyPawn.mIsRagdoll && VSize( GetPawnPosition(mPawnToAttack) - GetPawnPosition(mMyPawn) ) <= mMyPawn.GetCollisionRadius() + mPawnToAttack.GetCollisionRadius() + mMyPawn.mAttackRange && ReadyToAttack() )
	{
		StartAttack( mPawnToAttack );
		FinishRotation();
	}
	else
	{
		ClearTimer( nameof( DelayedGoToProtect ) );
		SetTimer( 0.1f, false, nameof( DelayedGoToProtect ) );
	}
}

function vector GetPawnPosition(Pawn aPawn)
{
	return 	aPawn.Physics==PHYS_RigidBody?aPawn.mesh.GetPosition():aPawn.Location;
}

/**
 * Helper function to determine if the last seen goat is near a given protect item
 * @param  protectInformation - The protectInfo to check against
 * @return true / false depending on if the goat is near or not
 */
function bool EnemyNearProtectItem( ProtectInfo protectInformation, out GGPawn enemyNear )
{
	local int i;
	local GGPawn gpawn;
	local float dist, minDist;

	//if(mMyPawn.mIsRagdoll || mPawnToAttack != none)
	//	return false;
	//Find closest pawn to attack
	minDist=-1;
	for(i=0 ; i<myMut.mSSA.battlePlayers.Length ; i++)
	{
		gpawn=myMut.mSSA.battlePlayers[i].gpawn;
		if(gpawn == mMyPawn)
			continue;

		dist=VSize(GetPawnPosition(mMyPawn)-GetPawnPosition(gpawn));
		if(minDist == -1 || dist<minDist)
		{
			minDist=dist;
			enemyNear=gpawn;
		}
	}

	return (enemyNear != none);
}

/**
 * Helper function to determine if our pawn is close to a protect item, called when we arrive at a pathnode
 * @param currentlyAtNode - The pathNode our pawn just arrived at
 * @param out_ProctectInformation - The info about the protect item we are near if any
 * @return true / false depending on if the pawn is near or not
 */
function bool NearProtectItem( PathNode currentlyAtNode, out ProtectInfo out_ProctectInformation )
{
	out_ProctectInformation=mMyPawn.mProtectItems[0];
	return true;
}

function bool IsValidEnemy( Pawn newEnemy )
{
	local GGPawn gpawn;

	gpawn=GGPawn(newEnemy);
	return gpawn != none
		&& gpawn != mMyPawn
		&& myMut.mSSA.IsPawnFighting(gpawn);
}

/**
 * Helper functioner for determining if the goat is in range of uur sightradius
 * if other is not specified mLastSeenGoat is checked against
 */
function bool PawnInRange( optional Pawn other )
{
	if(mMyPawn.mIsRagdoll)
	{
		return false;
	}
	else
	{
		return super.PawnInRange(other);
	}
}

/**
 * Called when an actor takes damage
 */
function OnTakeDamage( Actor damagedActor, Actor damageCauser, int damage, class< DamageType > dmgType, vector momentum )
{
	if(damagedActor == mMyPawn)
	{
		if(dmgType == class'GGDamageTypeCollision' && !mMyPawn.mIsRagdoll)
		{
			cancelNextRagdoll=true;
		}
	}
	else if(damageCauser == mMyPawn && damage != 1000000)
	{
		//DestroyNearbyApex()
	}
}

function OnCollision( Actor actor0, Actor actor1 )
{
	//Destroy breakable items on contact
	if(actor0 == mMyPawn)
	{
		DestroyNearbyApex();
	}
}

function DestroyNearbyApex()
{
	local GGApexDestructibleActor tmpApex;
	local float r, h;

	mMyPawn.GetBoundingCylinder(r, h);
	foreach mMyPawn.OverlappingActors(class'GGApexDestructibleActor', tmpApex, FMax(r, h) + 1.f, GetPawnPosition(mMyPawn))
	{
		tmpApex.TakeDamage(1000000, self, GetPawnPosition(mMyPawn), mMyPawn.Velocity, class'GGDamageTypeCollision',, mMyPawn);
		myMut.AddApexToDestroy(tmpApex);
	}
}

/**
 * Helper function for when we see the goat to determine if it is carrying a scary object
 */
function bool GoatCarryingDangerItem()
{
	return false;
}

function bool PawnUsesScriptedRoute()
{
	return false;
}

//--------------------------------------------------------------//
//			GGNotificationInterface								//
//--------------------------------------------------------------//

/**
 * Called when an actor begins to ragdoll
 */
function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	if(ragdolledActor == mMyPawn)
	{
		if(isRagdoll)
		{
			DestroyNearbyApex();
			if(cancelNextRagdoll)
			{
				cancelNextRagdoll=false;
				StandUp();
				//mMyPawn.SetPhysics( PHYS_Falling);
				//mMyPawn.Velocity+=pushVector;
			}
			else
			{
				if( IsTimerActive( NameOf( StopPointing ) ) )
				{
					StopPointing();
					ClearTimer( NameOf( StopPointing ) );
				}

				if( IsTimerActive( NameOf( StopLookAt ) ) )
				{
					StopLookAt();
					ClearTimer( NameOf( StopLookAt ) );
				}

				if( mCurrentState == 'ProtectItem' )
				{
					ClearTimer( nameof( AttackPawn ) );
					ClearTimer( nameof( DelayedGoToProtect ) );
				}
				StopAllScheduledMovement();
				StartStandUpTimer();
				EndAttack();
			}
		}
	}
}

event GoatPickedUpDangerItem( GGGoat goat )
{
	super.GoatPickedUpDangerItem(goat);

	if(goat.mGrabbedItem == none || goat.mGrabbedItem != mMyPawn)
		return;

	goat.DropGrabbedItem();
	mMyPawn.StandUp();
}

function bool StandUpAllowed()
{
	if(mIsInAir || mMyPawn.mIsInWater) return false;
	mMyPawn.mForceRagdollByVolume=false;
	return mMyPawn.CanStandUp();
}

DefaultProperties
{
	bIsPlayer=true

	mDestinationOffset=100.f
	mIgnoreGoatMaus=true

	mRagdollMomentumMultiplier=90.f;
	mAttackMomentum=750.f
	mAttackDamage=200.f;
	mMaxTimeWithoutAttack=60.f

	mAttackIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mCheckProtItemsThreatIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mVisibilityCheckIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
}