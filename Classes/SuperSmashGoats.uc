class SuperSmashGoats extends GGMutator;

struct SSG
{
	var GGPawn gpawn;
	var vector startLocation;
	var int percent;
	var vector lastVelocity;
	var float lastSpeedCap;
	var GGPawn lastDamageDealer;
};
var array<SSG> mSSGs;
var bool postRenderSet;

var vector mSpeechBubbleOffset;
var float mSpeechBubbleLength;
var float mSpeechBubbleHeight;
var() name mNameTagBoneName;

var bool isVelocityRespawnActive;
var bool shouldComputeDamageDealer;
delegate OnSSGRespawn(GGPawn gpawn);

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local SSG newSSG;

	goat = GGGoat( other );

	if( goat != none )
	{
		if(mSSGs.Find('gpawn', goat) == INDEX_NONE)
		{
			newSSG.gpawn = goat;
			newSSG.startLocation = goat.Location;
			mSSGs.AddItem(newSSG);
		}
		if( IsValidForPlayer( goat ) )
		{
			if( !WorldInfo.bStartup )
			{
				SetPostRenderFor();
			}
			else
			{
				SetTimer( 1.0f, false, NameOf( SetPostRenderFor ));
			}
		}
	}

	super.ModifyPlayer( other );
}

/**
 * Sets post render for on all local player controllers.
 */
function SetPostRenderFor()
{
	local PlayerController PC;

	if(postRenderSet)
		return;

	postRenderSet=true;
	foreach WorldInfo.LocalPlayerControllers( class'PlayerController', PC )
	{
		if( GGHUD( PC.myHUD ) == none )
		{
			// OKAY! THIS IS REALLY LAZY! This assume all PC's is initialized at the same time
			SetTimer( 0.5f, false, NameOf( SetPostRenderFor ));
			postRenderSet=false;
			break;
		}
		GGHUD( PC.myHUD ).mPostRenderActorsToAdd.AddItem( self );
	}
}

simulated event PostRenderFor( PlayerController PC, Canvas c, vector cameraPosition, vector cameraDir )
{
	local vector locationToUse, speechScreenLocation;
	local bool isCloseEnough, isOnScreen, isVisible;
	local float cameraDistScale, cameraDist, cameraDistMax, cameraDistMin, speechScale;
	local int i;

	for(i = 0 ; i<mSSGs.Length ; i++)
	{
		locationToUse = mSSGs[i].gpawn.mesh.GetBoneLocation( mNameTagBoneName );

		if( IsZero( locationToUse ) )
		{
			locationToUse = mSSGs[i].gpawn.Location;
		}

		if( mSSGs[i].gpawn.mesh.DetailMode > class'WorldInfo'.static.GetWorldInfo().GetDetailMode() )
		{
			return;
		}

		cameraDist = VSize( cameraPosition - locationToUse );
		cameraDistMin = 500.0f;
		cameraDistMax = 4000.0f;
		cameraDistScale = GetScaleFromDistance( cameraDist, cameraDistMin, cameraDistMax );

		isCloseEnough = cameraDist < cameraDistMax;
		isOnScreen = cameraDir dot Normal( locationToUse - cameraPosition ) > 0.0f;

		if( isOnScreen && isCloseEnough )
		{
			// An extra check here as LastRenderTime is for all viewports (coop).
			isVisible = FastTrace( locationToUse + mSpeechBubbleOffset, cameraPosition );
		}

		c.Font = Font'UI_Fonts.InGameFont';
		c.PushDepthSortKey( int( cameraDist ) );

		if( isOnScreen && isCloseEnough && isVisible)
		{
			// The scale from distance must be at least 0.2 but the scale from time can go all the way to 0.
			speechScale = FMax( 0.2f, cameraDistScale );
			speechScreenLocation = c.Project( locationToUse + mSpeechBubbleOffset );
			RenderSpeechBubble( c, speechScreenLocation, speechScale, mSSGs[i].percent);
		}

		c.PopDepthSortKey();
	}
}

function float GetScaleFromDistance( float cameraDist, float cameraDistMin, float cameraDistMax )
{
	return FClamp( 1.0f - ( ( FMax( cameraDist, cameraDistMin ) - cameraDistMin ) / ( cameraDistMax - cameraDistMin ) ), 0.0f, 1.0f );
}

function RenderSpeechBubble( Canvas c, vector screenLocation, float screenScale, int damagePercent)
{
	local FontRenderInfo renderInfo;
	local float textScale, XL, YL, maxTextScale, midX, midY;
	local string message;
	local float ratio;

	renderInfo.bClipText = true;

	maxTextScale = 1.5f;
	textScale = Lerp( 0.0f, maxTextScale, screenScale );

	message = damagePercent @ "%";

	c.DrawColor = MakeColor(142, 142, 142, 127);
	c.TextSize( "X", XL, YL, maxTextScale, maxTextScale );

	midX = screenLocation.X - (( mSpeechBubbleLength * screenScale ) / 2.f);
	midY = screenLocation.Y - (( mSpeechBubbleHeight * screenScale ) / 2.f);
	c.SetPos(midX, midY);
	c.DrawBox(mSpeechBubbleLength * screenScale, mSpeechBubbleHeight * screenScale);

	ratio = FMin(damagePercent/200.f, 1.f);
	c.DrawColor = MakeColor( Lerp(255, 139, ratio), Lerp(255, 0, ratio), Lerp(255, 0, ratio), 255 );

	c.TextSize(message, XL, YL, textScale, textScale);
	c.SetPos(screenLocation.X, screenLocation.Y + ( mSpeechBubbleHeight * screenScale ) / 2.f);
	c.DrawAlignedShadowText(message,, textScale, textScale, renderInfo,,, 0.5f, 1.0f);
}

function int AddSSGPawn(GGPawn gpawn)
{
	local SSG newSSG;

	newSSG.gpawn = gpawn;
	newSSG.startLocation = gpawn.Location;
	mSSGs.AddItem(newSSG);

	return mSSGs.Length-1;
}

/**
 * Called when an actor takes damage
 */
function OnTakeDamage( Actor damagedActor, Actor damageCauser, int damage, class< DamageType > dmgType, vector momentum )
{
	local GGPawn damagedPawn, damagingPawn;
	local int index;
	local int percentDamage;

	damagedPawn = GGPawn(damagedActor);
	if(damagedPawn == none)
		return;
	// Find the SSG in the list, or create it
	index = mSSGs.Find('gpawn', damagedPawn);
	if(index == INDEX_NONE)
	{
		index=AddSSGPawn(damagedPawn);
	}
	// Apply damages if needed
	percentDamage=damage/100;
	if(percentDamage == 0)
	{
		if(GGInterpActor(damageCauser) != none)
		{
			//WorldInfo.Game.Broadcast(self, "interp velocity=" $ VSize(damageCauser.Velocity));
			percentDamage=VSize(damageCauser.Velocity)/1000;
		}
	}
	damagingPawn = GGPawn(damageCauser);
	if(shouldComputeDamageDealer && damagingPawn != none)
	{
		mSSGs[index].lastDamageDealer = damagingPawn;
		//WorldInfo.Game.Broadcast(self, "lastDamageDealer=" $ mSSGs[index].lastDamageDealer);
	}
	OnDamageTaken(index, percentDamage);
}

event Tick( float deltaTime )
{
	local int i;

	super.Tick( deltaTime );

	for(i = 0 ; i<mSSGs.Length ; i = i)
	{
		if(mSSGs[i].gpawn == none || mSSGs[i].gpawn.bPendingDelete)
		{
			mSSGs.Remove(i, 1);
		}
		else
		{
			TakeAccelerationDamages(i);
			mSSGs[i].lastVelocity = mSSGs[i].gpawn.Velocity;
			if(mSSGs[i].lastDamageDealer != none && (mSSGs[i].gpawn.Physics == PHYS_Walking || mSSGs[i].gpawn.Physics == PHYS_Spider))
			{
				mSSGs[i].lastDamageDealer = none;
				//WorldInfo.Game.Broadcast(self, "lastDamageDealer=none (walking)");
			}
			// if speed is too high, respawn
			if(isVelocityRespawnActive && VSize(mSSGs[i].lastVelocity) >= 10000.f)
			{
				//WorldInfo.Game.Broadcast(self, mSSGs[i].gpawn @ "velocity=" $ VSize(mSSGs[i].lastVelocity));
				RespawnSSG(i);
			}
			i++;
		}
	}
}

function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	local GGPawn ragdolledPawn;

	super.OnRagdoll( ragdolledActor, isRagdoll );
	// Add ragdolled pawns to the list
	ragdolledPawn = GGPawn(ragdolledActor);
	if(ragdolledPawn == none)
		return;
	// Find the SSG in the list, or create it
	if(mSSGs.Find('gpawn', ragdolledPawn) == INDEX_NONE)
	{
		AddSSGPawn(ragdolledPawn);
	}
}

/**
 * Compute percent damages based on acceleration
 */
function TakeAccelerationDamages(int index)
{
	local float signedSpeed, deltaSpeed, minDist, dist;
	local bool speedCapReached;
	local GGPawn hitGPawn, closestPawn;
	local vector aFacing, aToB, projPos, gpawnPos;

	signedSpeed = VSize(mSSGs[index].gpawn.Velocity) - VSize(mSSGs[index].lastVelocity);
	deltaSpeed=Abs(signedSpeed);
	speedCapReached = false;
	if(mSSGs[index].lastSpeedCap > 0)
	{
		if(deltaSpeed >= mSSGs[index].lastSpeedCap)
		{
			speedCapReached = true;
		}
		else
		{
			mSSGs[index].lastSpeedCap = 0;
		}
	}
	if(deltaSpeed <= mSSGs[index].gpawn.JumpZ || speedCapReached)
	{
		return;
	}
	//myMut.WorldInfo.Game.Broadcast(myMut, "deltaSpeed=" $ deltaSpeed);
	if(signedSpeed >= 0)
	{
		mSSGs[index].lastSpeedCap = deltaSpeed;
		// Try to find a damage dealer at any cost
		if(shouldComputeDamageDealer && mSSGs[index].lastDamageDealer == none && signedSpeed > 0.f)
		{
			minDist = -1;
			foreach CollidingActors(class'GGPawn', hitGPawn, 1000.f, mSSGs[index].gpawn.mesh.GetPosition())
			{
				if(hitGPawn == mSSGs[index].gpawn)
					continue;

				projPos = hitGPawn.mesh.GetPosition();
				gpawnPos = mSSGs[index].gpawn.mesh.GetPosition();
				// The actor is in the same direction as velocity so ignore it
				aFacing=Normal(mSSGs[index].gpawn.Velocity);
				aToB=projPos - gpawnPos;
				if(aFacing dot aToB > 0.f)
					continue;

				dist = VSize(gpawnPos - projPos);
				if(minDist < 0 || dist < minDist)
				{
					minDist = dist;
					closestPawn = hitGPawn;
				}
			}
			mSSGs[index].lastDamageDealer = closestPawn;
			//DrawDebugLine(traceStart, traceEnd, 0, 0, 0, true);
			//WorldInfo.Game.Broadcast(self, "lastDamageDealer=" $ mSSGs[index].lastDamageDealer);
		}
	}
	OnDamageTaken(index, deltaSpeed/500.f);
}

/**
 * Called when a SSG takes damage
 */
function OnDamageTaken(int index, int damage)
{
	local GGPawn currGpawn;
	local vector oldVelocity;

	if(damage <= 0 || index >= mSSGs.Length)
		return;

	// Increase velocity depending on current percentage (only if accelerating)
	currGpawn = mSSGs[index].gpawn;
	if(VSize(currGpawn.Velocity) >= VSize(mSSGs[index].lastVelocity))
	{
		oldVelocity = currGpawn.Velocity;
		if(currGpawn.mIsRagdoll)
		{
			currGpawn.TakeDamage( 0.f, none, currGpawn.Location, Normal(oldVelocity)*10000.f* (mSSGs[index].percent / 100.f), class'GGDamageType');
		}
		else
		{
			currGpawn.Velocity = oldVelocity + (oldVelocity * mSSGs[index].percent / 200.f);
		}
	}

	// Increase percentage
	mSSGs[index].percent += damage;

	if(mSSGs[index].percent > 999)
	{
		mSSGs[index].percent = 999;
	}
}

/**
 * Respawn a SSG to its start position
 */
function RespawnSSG(int index)
{
	local GGPawn currGpawn;
	local GGGoat currGoat, grabberGoat;
	local PlayerController pc;

	if(index == INDEX_NONE || index >= mSSGs.Length)
		return;

	currGpawn = mSSGs[index].gpawn;
	currGoat = GGGoat(currGpawn);
	mSSGs[index].percent = 0;
	currGpawn.Velocity = vect(0, 0, 0);
	if(currGpawn.mIsRagdoll)
	{
		currGpawn.Mesh.SetRBLinearVelocity(vect(0, 0, 0));
		currGpawn.Mesh.SetRBPosition(mSSGs[index].StartLocation);
		if(GGNpc(currGpawn) != none)
		{
			GGNpc(currGpawn).StandUp();
		}
		currGoat = GGGoat(currGpawn);
		if(currGoat != none)
		{
			currGoat.StandUp();
		}
		if(currGpawn.mIsRagdoll)
		{
			currGpawn.SetRagdoll(false);
		}
	}
	if(currGpawn.DrivenVehicle != none)
	{
		currGpawn.DrivenVehicle.DriverLeave(true);
	}
	currGpawn.SetLocation(mSSGs[index].StartLocation);
	// if this pawn is grabbed, drop it
	foreach WorldInfo.AllControllers(class'PlayerController', pc)
	{
		grabberGoat = GGGoat(pc.Pawn);
		if(grabberGoat != none && grabberGoat.mGrabbedItem == currGpawn)
		{
			grabberGoat.DropGrabbedItem();
		}
	}

	if(PlayerController(currGpawn.Controller) != none && currGoat != none)
	{
		GGGameInfo(WorldInfo.Game).OnPlayerRespawn(PlayerController(currGpawn.Controller), false);
		if(currGoat != none)// if this pawn is grabbing something, drop it
		{
			currGoat.DropGrabbedItem();
		}
	}
	else
	{
		if(GGAIController(currGpawn.Controller) != none)
		{
			GGAIController(currGpawn.Controller).StopAllScheduledMovement();
		}
		OnSSGRespawn(currGpawn);
	}
	mSSGs[index].lastDamageDealer = none;
	//WorldInfo.Game.Broadcast(self, "lastDamageDealer=none (respawn)");
}

DefaultProperties
{
	bPostRenderIfNotVisible=true
	isVelocityRespawnActive=true

	mNameTagBoneName=Head

	mSpeechBubbleOffset=(X=0.0f,Y=0.0f,Z=100.0f)

	mSpeechBubbleLength=80.f;
	mSpeechBubbleHeight=30.f;
}