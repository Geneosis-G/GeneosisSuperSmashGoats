class SuperSmashArena extends GGMutator;

struct BattlePlayer
{
	var GGPawn gpawn;
	var int score;
	var vector spawnLocation;
};
var array<BattlePlayer> battlePlayers;
var array<PlayerController> playingConts;

var bool postRenderSet;
var SuperSmashGoats mSSG;

var vector mSpeechBubbleOffset;
var float mSpeechBubbleLength;
var float mSpeechBubbleHeight;
var() name mNameTagBoneName;
var SoundCue mSSGTheme;

var bool isOnePressed;
var bool isTwoPressed;
var bool isThreePressed;
var bool isFourPressed;

var ArenaLimit arenaBordersUp;
var ArenaLimit arenaBordersDown;
var float arenaSize;
var float customArenaSize;
const ARENA_SIZE_SMALL = 2500;
const ARENA_SIZE_MEDIUM = 5000;
const ARENA_SIZE_LARGE = 10000;

var vector arenaCenter;
var int botsCount;
var int initLifes;
var float initTime;
var int battleMode;
const MODE_LIFE = 0;
const MODE_TIME = 1;

var bool isBattleStarted;
var int mCountdownTime;
var float mGameStartTime;
var string mStartString;
var AudioComponent mAC;

var SoundCue mBattleEndSound;
var SoundCue mDrawSound;
var SoundCue mFighterEjectedSound;
var SoundCue mCountdownSound;
var SoundCue mGoSound;
var AudioComponent mCountdownAC;
var ParticleSystem mFighterEjectedParticleTemplate;

const END_NORMAL = 0;
const END_CANCEL = 1;
const END_INIT = 2;

delegate OnBattleStarted();
delegate OnBattleEnded();
delegate OnPlayerLost(GGPawn gpawn);

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local PlayerController pc;

	goat = GGGoat( other );

	if( goat != none )
	{
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
			pc = PlayerController(goat.Controller);
			if(playingConts.Find(pc) == INDEX_NONE)
			{
				playingConts.AddItem(pc);
			}
			GGPlayerInput( PlayerController(goat.Controller).PlayerInput ).RegisterKeyStateListner( KeyState );
			if(!IsTimerActive(NameOf(InitSSG)))
			{
				SetTimer(1.f, false, NameOf(InitSSG));
			}
			if(arenaBordersUp == none)
			{
				arenaBordersUp = Spawn(class'ArenaLimit');
				arenaBordersUp.SetHidden(true);
			}
			if(arenaBordersDown == none)
			{
				arenaBordersDown = Spawn(class'ArenaLimit');
				arenaBordersDown.SetHidden(true);
			}
		}
	}

	super.ModifyPlayer( other );
}

function InitSSG()
{
	local SuperSmashGoats ssg;

	//Find Super Smash Goats mutator
	foreach AllActors(class'SuperSmashGoats', ssg)
	{
		if(ssg != none)
		{
			break;
		}
	}

	if(ssg == none)
	{
		DisplayUnavailableMessage();
		return;
	}

	mSSG = ssg;
	mSSG.OnSSGRespawn = OnSSGRespawn;
	InitSuperSmashInteraction();
}

function InitSuperSmashInteraction()
{
	local SuperSmashInteraction ssi;

	ssi = new class'SuperSmashInteraction';
	ssi.InitSuperSmashInteraction(self);
	GetALocalPlayerController().Interactions.AddItem(ssi);
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

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local vector v;
	local float borderScale;

	if(mSSG == none)
		return;

	if( keyState == KS_Down )
	{
		if(newKey == 'ONE')
		{
			isOnePressed=true;
			if(!isBattleStarted)
				arenaSize = ARENA_SIZE_SMALL;
		}
		if(newKey == 'TWO')
		{
			isTwoPressed=true;
			if(!isBattleStarted)
				arenaSize = ARENA_SIZE_MEDIUM;
		}
		if(newKey == 'THREE')
		{
			isThreePressed=true;
			if(!isBattleStarted)
				arenaSize = ARENA_SIZE_LARGE;
		}
		if(newKey == 'FOUR')
		{
			isFourPressed=true;
			if(!isBattleStarted)
				arenaSize = customArenaSize;
		}
		if(newKey == 'FIVE')
		{
			SwitchBattleMode();
		}
		/*
		if(newKey == 'P')
		{
			v = arenaBordersUp.Location - arenaCenter;
			v.Z = v.Z-1;
			WorldInfo.Game.Broadcast(self, "BorderDist=" $ v.Z);
			arenaBordersUp.SetLocation(arenaCenter + v);
			arenaBordersDown.SetLocation(arenaCenter - v);
		}
		if(newKey == 'M')
		{
			v = arenaBordersUp.Location - arenaCenter;
			v.Z = v.Z+1;
			WorldInfo.Game.Broadcast(self, "BorderDist=" $ v.Z);
			arenaBordersUp.SetLocation(arenaCenter + v);
			arenaBordersDown.SetLocation(arenaCenter - v);
		}
		*/
		if(!isBattleStarted)
		{
			if(isOnePressed || isTwoPressed || isThreePressed || isFourPressed)
			{
				borderScale = arenaSize / 10000.f * 14.5f;
				v.X = borderScale;
				v.Y = borderScale;
				v.Z = 100.f;
				arenaBordersUp.SetDrawScale3D(v);
				v.Z = -100.f;
				arenaBordersDown.SetDrawScale3D(v);
				if(!IsTimerActive(NameOf(StartBattle)))
				{
					SetTimer(5.f, false, NameOf(StartBattle));
				}
			}
		}
		else
		{
			if(isOnePressed && isTwoPressed && isThreePressed)
			{
				if(!IsTimerActive(NameOf(CancelBattle)))
				{
					SetTimer(5.f, false, NameOf(CancelBattle));
				}
			}
		}
	}
	else if( keyState == KS_Up )
	{
		if(newKey == 'ONE')
		{
			isOnePressed=false;
		}
		if(newKey == 'TWO')
		{
			isTwoPressed=false;
		}
		if(newKey == 'THREE')
		{
			isThreePressed=false;
		}
		if(newKey == 'FOUR')
		{
			isFourPressed=false;
		}

		if(!isBattleStarted)
		{
			if((!isOnePressed && arenaSize == ARENA_SIZE_SMALL)
			|| (!isTwoPressed && arenaSize == ARENA_SIZE_MEDIUM)
			|| (!isThreePressed && arenaSize == ARENA_SIZE_LARGE)
			|| (!isOnePressed && !isTwoPressed && !isThreePressed && !isFourPressed))
			{
				if(IsTimerActive(NameOf(StartBattle)))
				{
					ClearTimer(NameOf(StartBattle));
				}
			}
		}
		else
		{
			if(!isOnePressed || !isTwoPressed || !isThreePressed)
			{
				if(IsTimerActive(NameOf(CancelBattle)))
				{
					ClearTimer(NameOf(CancelBattle));
				}
			}
		}
	}
}

function SwitchBattleMode()
{
	if(isBattleStarted)
	{
		WorldInfo.Game.Broadcast(self, "Can't change settings during battle");
		return;
	}

	battleMode = 1 - battleMode;
	switch(battleMode)
	{
		case MODE_LIFE:
			WorldInfo.Game.Broadcast(self, "Stock Battle");
			break;
		case MODE_TIME:
			WorldInfo.Game.Broadcast(self, "Time Battle");
			break;
		default:
			battleMode = MODE_LIFE;
	}
}

function bool IsPawnFighting(GGPawn gpawn)
{
	if(!isBattleStarted)
		return false;

	return battlePlayers.Find('gpawn', gpawn) != INDEX_NONE;
}

simulated event PostRenderFor( PlayerController PC, Canvas c, vector cameraPosition, vector cameraDir )
{
	local vector locationToUse, speechScreenLocation;
	local bool isCloseEnough, isOnScreen, isVisible;
	local float cameraDistScale, cameraDist, cameraDistMax, cameraDistMin, speechScale;
	local int i;
	//WorldInfo.Game.Broadcast(self, "PostRenderFor=" $ PC $ " Length=" $ battlePlayers.Length);
	for(i = 0 ; i<battlePlayers.Length ; i++)
	{
		locationToUse = battlePlayers[i].gpawn.mesh.GetBoneLocation( mNameTagBoneName );

		if( IsZero( locationToUse ) )
		{
			locationToUse = battlePlayers[i].gpawn.Location;
		}

		if( battlePlayers[i].gpawn.mesh.DetailMode > class'WorldInfo'.static.GetWorldInfo().GetDetailMode() )
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

		if(isOnScreen && isCloseEnough && isVisible)
		{
			// The scale from distance must be at least 0.2 but the scale from time can go all the way to 0.
			speechScale = FMax( 0.2f, cameraDistScale );
			speechScreenLocation = c.Project( locationToUse + mSpeechBubbleOffset );
			RenderSpeechBubble( c, speechScreenLocation, speechScale, battlePlayers[i].score);
			//WorldInfo.Game.Broadcast(self, "RenderSpeechBubble=" $ battlePlayers[i].gpawn);
		}
		if(isOnScreen)
		{
			speechScreenLocation = c.Project( locationToUse + mSpeechBubbleOffset + vect(0, 0, 10) );
			RenderLocationArrow( c, speechScreenLocation);
		}

		c.PopDepthSortKey();
	}
}

function float GetScaleFromDistance( float cameraDist, float cameraDistMin, float cameraDistMax )
{
	return FClamp( 1.0f - ( ( FMax( cameraDist, cameraDistMin ) - cameraDistMin ) / ( cameraDistMax - cameraDistMin ) ), 0.0f, 1.0f );
}

function RenderSpeechBubble( Canvas c, vector screenLocation, float screenScale, int score)
{
	local FontRenderInfo renderInfo;
	local float textScale, XL, YL, maxTextScale;
	local string message;

	renderInfo.bClipText = true;

	maxTextScale = 1.f;
	textScale = Lerp( 0.0f, maxTextScale, screenScale );

	switch(battleMode)
	{
		case MODE_LIFE:
			message = "Lives:" @ score;
			break;
		case MODE_TIME:
			message = "Score:" @ score>0?"+" $ score:string(score);
			break;
		default:
			return;
	}

	c.DrawColor = MakeColor(255, 255, 255, 255);

	c.TextSize(message, XL, YL, textScale, textScale);
	c.SetPos(screenLocation.X, screenLocation.Y);
	c.DrawAlignedShadowText(message,, textScale, textScale, renderInfo,,, 0.5f, 1.0f);
}

function RenderLocationArrow( Canvas c, vector screenLocation)
{
	local FontRenderInfo renderInfo;
	local float textScale, XL, YL;
	local string message;

	renderInfo.bClipText = true;

	textScale = 1.f;

	message = "V";

	c.DrawColor = MakeColor(255, 255, 255, 255);

	c.TextSize(message, XL, YL, textScale, textScale);
	c.SetPos(screenLocation.X, screenLocation.Y);
	c.DrawAlignedShadowText(message,, textScale, textScale, renderInfo,,, 0.5f, 1.0f);
}


function OnSSGRespawn(GGPawn gpawn)
{
	local int index;

	//WorldInfo.Game.Broadcast(self, "OnPlayerRespawn");
	if(!isBattleStarted || gpawn == none)
		return;

	index = battlePlayers.Find('gpawn', gpawn);
	if(index == INDEX_NONE)
		return;

	SSGRespawned(index);
}

/**
 * Called when a player respawns
 */
function OnPlayerRespawn( PlayerController respawnController, bool died )
{
	local GGPawn respawnPawn;
	local int index;

	//WorldInfo.Game.Broadcast(self, "OnPlayerRespawn");

	respawnPawn = GGPawn(respawnController.Pawn);
	if(!isBattleStarted || respawnPawn == none)
		return;

	index = battlePlayers.Find('gpawn', respawnPawn);
	if(index == INDEX_NONE)
		return;

	SSGRespawned(index);
}

/**
 * Called when a SSG respawns during battle
 */
function SSGRespawned(int index)
{
	local int indexSSG, indexSSGKiller, indexKiller;

	indexSSG = mSSG.mSSGs.Find('gpawn', battlePlayers[index].gpawn);
	if(indexSSG != INDEX_NONE)
	{
		mSSG.mSSGs[indexSSG].percent = 0;
		switch(battleMode)
		{
			case MODE_LIFE:
				battlePlayers[index].score--;
				if(battlePlayers[index].score <= 0)
				{
					if(battlePlayers.Length <= 1)
					{
						EndBattle();
						return;
					}
					OnPlayerLost(battlePlayers[index].gpawn);
					DisplayFinishRank(battlePlayers[index].gpawn, battlePlayers.Length);
					TeleportOutOfArena(battlePlayers[index].gpawn);
					battlePlayers.Remove(index, 1);
					if(battlePlayers.Length <= 1)
					{
						EndBattle();
					}
					return;
				}
				break;
			case MODE_TIME:
				battlePlayers[index].score--;
				if(mSSG.mSSGs[indexSSG].lastDamageDealer != none)
				{
					indexSSGKiller = mSSG.mSSGs.Find('gpawn', mSSG.mSSGs[indexSSG].lastDamageDealer);
					if(indexSSGKiller != INDEX_NONE)
					{
						indexKiller = battlePlayers.Find('gpawn', mSSG.mSSGs[indexSSGKiller].gpawn);
						if(indexKiller != INDEX_NONE)
						{
							battlePlayers[indexKiller].score++;
						}
					}
				}
				break;
			default:
				return;
		}
		PlaceAtSpawn(battlePlayers[index].gpawn, battlePlayers[index].spawnLocation);
		if(GGAIController(battlePlayers[index].gpawn.Controller) != none)
		{
			GGAIController(battlePlayers[index].gpawn.Controller).StopAllScheduledMovement();
			GGAIController(battlePlayers[index].gpawn.Controller).ResumeDefaultAction();
		}
	}
}

function PlaceAtSpawn(GGPawn gpawn, vector spawnLocation, optional bool ignoreZ=false)
{
	local rotator camOffset, newRot;
	local PlayerController pc;
	local GGAIController AIC;
	local vector dest, expectedLoc;

	dest = spawnLocation;
	expectedLoc = dest;
	if(ignoreZ)
	{
		dest.Z = gpawn.Location.Z;
	}
	gpawn.Velocity = vect(0, 0, 0);
	while(gpawn.Location != expectedLoc)
	{
		expectedLoc = dest;
		gpawn.SetLocation(expectedLoc);
		dest.Z += 10;
	}
	pc = PlayerController(gpawn.Controller);
	if(pc != none)
	{
		camOffset = PlayerController(gpawn.Controller).PlayerCamera.Rotation - gpawn.Rotation;
	}
	newRot = rotator(Normal2D(arenaCenter - gpawn.Location));
	gpawn.SetRotation(newRot);
	if(pc != none)
	{
		pc.PlayerCamera.SetRotation(gpawn.Rotation + camOffset);
	}
	gpawn.SetPhysics(PHYS_Falling);
	AIC = GGAIController(gpawn.Controller);
	if(AIC != none)
	{
		AIC.mOriginalRotation = newRot;
		AIC.mOriginalPosition = expectedLoc;
	}
}

event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	ManageSound();
	if(isBattleStarted)
	{
		// If a fighting player exit the arena, he is forced to respawn
		// If a creature or player not in the battle try to enter the arena, he is forced to exit
		ManageSSGPlayers();

		if(battleMode == MODE_TIME)
		{
			if(ManageTimer() < 1.f)
			{
				EndBattle();
			}
		}
	}
}

function ManageSound()
{
	if( mAC == none || mAC.IsPendingKill() )
	{
		mAC = CreateAudioComponent( mSSGTheme, false );
	}

	if(isBattleStarted)
	{
		if(!mAC.IsPlaying())
		{
			mAC.Play();
			StopSound(true);
		}
	}
	else
	{
		if(mAC.IsPlaying())
		{
			mAC.Stop();
			StopSound(false);
		}
	}

	if( mCountdownAC == none || mCountdownAC.IsPendingKill() )
	{
		mCountdownAC = CreateAudioComponent( mCountdownSound, false );
	}
}

simulated function StopSound(bool stop)
{
	local GGPlayerControllerBase goatPC;
	local GGProfileSettings profile;

	goatPC=GGPlayerControllerBase( GetALocalPlayerController() );
	profile = goatPC.mProfileSettings;

	if(stop)
	{
		goatPC.SetAudioGroupVolume( 'Music', 0.f);
	}
	else
	{
		goatPC.SetAudioGroupVolume( 'Music', profile.GetMusicVolume());
	}
}

/*
 * If a fighting player exit the arena, he is forced to respawn
 * if a creature or player not in the battle try to enter the arena, he is forced to exit
 */
function ManageSSGPlayers()
{
	local bool isInArena;
	local int i;
	local vector oldPos;

	//Clean fighter list and lock players during countdown
	for(i = 0 ; i<battlePlayers.Length ; i = i)
	{
		if(battlePlayers[i].gpawn == none || battlePlayers[i].gpawn.bPendingDelete)
		{
			battlePlayers.Remove(i, 1);
		}
		else
		{
			if(mCountdownTime > 0)
			{
				if(GGAIController(battlePlayers[i].gpawn.Controller) != none)
				{
					GGAIController(battlePlayers[i].gpawn.Controller).StopAllScheduledMovement();
				}
				PlaceAtSpawn(battlePlayers[i].gpawn, battlePlayers[i].spawnLocation, true);
			}
			i++;
		}
	}
	if(battlePlayers.Length <= 1)
	{
		EndBattle();
		return;
	}
	//Do the barrier effect
	for(i = 0 ; i<mSSG.mSSGs.Length ; i++)
	{
		isInArena = VSize2D(mSSG.mSSGs[i].gpawn.Mesh.GetPosition() - arenaCenter) <= arenaSize;
		if(IsPawnFighting(mSSG.mSSGs[i].gpawn))
		{
			if(!isInArena)
			{
				oldPos = mSSG.mSSGs[i].gpawn.Mesh.GetPosition();
				WorldInfo.MyEmitterPool.SpawnEmitter(mFighterEjectedParticleTemplate, oldPos, rotator(Normal2D(arenaCenter - oldPos)));
				mSSG.RespawnSSG(i);
				PlaySound(mFighterEjectedSound,,,, battlePlayers[0].gpawn.mesh.GetPosition());
			}
		}
		else
		{
			if(isInArena)
			{
				TeleportOutOfArena(mSSG.mSSGs[i].gpawn);
			}
		}
	}
}

function TeleportOutOfArena(GGPawn gpawn)
{
	local vector dest, center;
	local rotator rot;
	local float dist;
	local Actor hitActor;
	local vector hitLocation, hitNormal, traceEnd, traceStart;

	center=arenaCenter;
	rot=Rotator(vect(1, 0, 0));
	rot.Yaw+=RandRange(0.f, 65536.f);

	dist=arenaSize + 200;

	dest=center+Normal(Vector(rot))*dist;
	traceStart=dest;
	traceEnd=dest;
	traceStart.Z=10000.f;
	traceEnd.Z=-3000;

	hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true);
	if( hitActor == none )
	{
		hitLocation = traceEnd;
	}

	if(gpawn.mIsRagdoll)
	{
		gpawn.Mesh.SetRBLinearVelocity(vect(0, 0, 0));
		gpawn.Mesh.SetRBPosition(hitLocation + vect(0, 0, 100));
	}
	else
	{
		gpawn.Velocity = vect(0, 0, 0);
		gpawn.SetLocation(hitLocation + vect(0, 0, 100));
	}
}

function float ManageTimer()
{
	local GGUITweenLabel label;
	local GGPlayerControllerGame GGPCG;
	local float timeRemaining;
	local int i;

	//WorldInfo.Game.Broadcast(self, "ManageTimer");
	timeRemaining = GetBattleTime();
	if(timeRemaining < 0)
	{
		timeRemaining = 0;
	}

	for(i = 0 ; i<battlePlayers.Length ; i++)
	{
		GGPCG = GGPlayerControllerGame( battlePlayers[i].gpawn.Controller );
		if(GGPCG == none)
			continue;

		label = GGHUD( GGPCG.myHUD ).mHUDMovie.mGameTimer;
		if( label == none )
			continue;

		label.SetLabelText(class'GGGameInfo'.static.FormatTime(timeRemaining));
	}

	return timeRemaining;
}

function float GetBattleTime()
{
	return mCountdownTime>0?initTime:initTime - (WorldInfo.RealTimeSeconds - mGameStartTime);
}

function StartBattle()
{
	local BattlePlayer newBP;
	local int i, indexSSG, botsToAdd;
	local GGPlayerControllerGame GGPCG;
	local GGUITweenLabel label;
	local GGPawn newBot, newPlayer;

	ComputeArenaCenter(playingConts[0].Pawn.Mesh.GetPosition());

	mSSG.isVelocityRespawnActive=false;
	mSSG.shouldComputeDamageDealer=(battleMode == MODE_TIME);
	mCountdownTime = 4;
	mGameStartTime = WorldInfo.RealTimeSeconds;

	for(i = 0 ; i<playingConts.Length ; i = i)
	{
		newPlayer=GGSVehicle(playingConts[i].Pawn)!=none?GGPawn(GGSVehicle(playingConts[i].Pawn).Driver):GGPawn(playingConts[i].Pawn);
		indexSSG = mSSG.mSSGs.Find('gpawn', newPlayer);
		if(indexSSG == INDEX_NONE)
		{
			playingConts.Remove(i, 1);
			continue;
		}
		newBP.gpawn = newPlayer;
		if(battleMode == MODE_LIFE)
			newBP.score = initLifes;
		newBP.spawnLocation = GetNextSpawnLocation();
		battlePlayers.AddItem(newBP);
		mSSG.RespawnSSG(indexSSG);
		PlaceAtSpawn(newBP.gpawn, newBP.spawnLocation);
		GGPCG = GGPlayerControllerGame( newBP.gpawn.Controller );
		label = GGHUD( GGPCG.myHUD ).mHUDMovie.mGameTimer;
		if( label == none && battleMode == MODE_TIME)
		{
			label = GGHUD( GGPCG.myHUD ).mHUDMovie.AddGameTimerWidget();
			label.mInitialText = class'GGGameInfo'.static.FormatTime( GetBattleTime() );
		}
		GGPCG.GotoState( 'RaceCountdown' );
		i++;
	}

	//Add bots if needed
	botsToAdd=botsCount;
	foreach CollidingActors(class'GGPawn', newBot, arenaSize, arenaCenter)
	{
		if(botsToAdd == 0 || battlePlayers.Length == 8)
			break;

		if(battlePlayers.Find('gpawn', newBot) != INDEX_NONE
		|| newBot.DrivenVehicle != none)//Don't involve driving NPCs into battle
			continue;

		indexSSG = mSSG.mSSGs.Find('gpawn', newBot);
		if(indexSSG == INDEX_NONE)
		{
			indexSSG = mSSG.AddSSGPawn(newBot);
		}

		newBP.gpawn = newBot;
		if(battleMode == MODE_LIFE)
			newBP.score = initLifes;
		newBP.spawnLocation = GetNextSpawnLocation();
		battlePlayers.AddItem(newBP);
		mSSG.RespawnSSG(indexSSG);
		PlaceAtSpawn(newBP.gpawn, newBP.spawnLocation);
		botsToAdd--;
	}

	//Display Arena borders
	arenaBordersUp.SetLocation(arenaCenter);
	arenaBordersDown.SetLocation(arenaCenter);
	arenaBordersUp.SetHidden(false);
	arenaBordersDown.SetHidden(false);

	isBattleStarted = true;
	SetTimer( 1.0f, true, NameOf( CountDownTimer ) );
	if(battlePlayers.Length < 2)
	{
		EndBattle(END_INIT);
		return;
	}

	OnBattleStarted();
}

function ComputeArenaCenter(vector centerBase)
{
	local Actor hitActor;
	local vector hitLocation, hitNormal, traceEnd, traceStart;

	traceStart=centerBase;
	traceEnd=centerBase;
	traceStart.Z=10000.f;
	traceEnd.Z=-3000;

	hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true);
	if( hitActor == none )
	{
		hitLocation = traceEnd;
	}

	arenaCenter = hitLocation;
}

function CountDownTimer(optional bool reset=false)
{
	local int i;

	mCountdownTime -= 1;
	if(mCountdownTime < 0)
	{
		PostJuiceCountdown( "" );
		return;
	}

	if(reset)
	{
		if(IsTimerActive(NameOf( CountDownTimer )))
		{
			ClearTimer(NameOf( CountDownTimer ));
		}
		if(mCountdownAC.IsPlaying())
		{
			mCountdownAC.Stop();
		}
		for(i = 0 ; i<battlePlayers.Length ; i++)
		{
			if(GGPlayerControllerGame( battlePlayers[i].gpawn.Controller ) != none)
			{
				GGPlayerControllerGame( battlePlayers[i].gpawn.Controller ).GotoState( 'PlayerWalking' );
			}

			if(GGAIController(battlePlayers[i].gpawn.Controller) != none)
			{
				GGAIController(battlePlayers[i].gpawn.Controller).ResumeDefaultAction();
			}
		}
		PostJuiceCountdown( "" );
		mCountdownTime = 0;
		return;
	}

	SetTimer(1.f, false, NameOf( CountDownTimer ));
	if( mCountdownTime > 0 )
	{
		PostJuiceCountdown( string( mCountdownTime ) );
		if(!mCountdownAC.IsPlaying())
		{
			mCountdownAC.Play();
		}
	}
	else
	{
		PostJuiceCountdown( mStartString );
		if(mCountdownAC.IsPlaying())
		{
			mCountdownAC.Stop();
		}
		PlaySound(mGoSound);
		mGameStartTime = WorldInfo.RealTimeSeconds;

		for(i = 0 ; i<battlePlayers.Length ; i++)
		{
			if(GGPlayerControllerGame( battlePlayers[i].gpawn.Controller ) != none)
			{
				GGPlayerControllerGame( battlePlayers[i].gpawn.Controller ).GotoState( 'PlayerWalking' );
			}

			if(GGAIController(battlePlayers[i].gpawn.Controller) != none)
			{
				GGAIController(battlePlayers[i].gpawn.Controller).ResumeDefaultAction();
			}
		}
	}
}

function PostJuiceCountdown( string juiceToPost )
{
	local GGPlayerControllerGame GGPCG;
	local GGHUD localHUD;
	local int i;

	for(i = 0 ; i<battlePlayers.Length ; i++)
	{
		GGPCG = GGPlayerControllerGame( battlePlayers[i].gpawn.Controller );
		if(GGPCG != none)
		{
			localHUD = GGHUD( GGPCG.myHUD );

			if( localHUD != none && localHUD.mHUDMovie != none )
			{
				if( localHUD.mHUDMovie.mCountdownLabel == none )
				{
					localHUD.mHUDMovie.AddCountdownLabel();
				}
				localHUD.mHUDMovie.SetCountdownText( juiceToPost );
			}
		}
	}
}

function vector GetNextSpawnLocation()
{
	local vector dest;
	local Actor hitActor;
	local vector hitLocation, hitNormal, traceEnd, traceStart;

	dest=arenaCenter;
	switch(battlePlayers.Length)
	{
		case 0:
			dest = arenaCenter + vect(300, 0, 0);
			break;
		case 1:
			dest = arenaCenter + vect(-300, 0, 0);
			break;
		case 2:
			dest = arenaCenter + vect(0, 300, 0);
			break;
		case 3:
			dest = arenaCenter + vect(0, -300, 0);
			break;
		case 4:
			dest = arenaCenter + vect(212, 212, 0);
			break;
		case 5:
			dest = arenaCenter + vect(-212, -212, 0);
			break;
		case 6:
			dest = arenaCenter + vect(212, -212, 0);
			break;
		case 7:
			dest = arenaCenter + vect(-212, 212, 0);
			break;
	}

	traceStart=dest;
	traceEnd=dest;
	traceStart.Z=10000.f;
	traceEnd.Z=-3000;

	hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true);
	if( hitActor == none )
	{
		hitLocation = traceEnd;
	}

	return hitLocation + vect(0, 0, 100);
}

function int CompareScore(BattlePlayer p1, BattlePlayer p2)
{
	return p1.score - p2.score;
}

function EndBattle(optional int endType=END_NORMAL)
{
	local int i, rank;
	local GGUITweenLabel label;
	local GGPlayerControllerGame GGPCG;

	PlaySound(endType!=END_NORMAL?mDrawSound:mBattleEndSound);

	switch(battleMode)
	{
		case MODE_LIFE:
			for(i = 0 ; i<battlePlayers.Length ; i++)
			{
				DisplayFinishRank(battlePlayers[i].gpawn, 1, endType);
			}
			break;
		case MODE_TIME:
			battlePlayers.Sort(CompareScore);
			rank=1;
			for(i = 0 ; i<battlePlayers.Length ; i++)
			{
				if(endType == END_NORMAL)
					PostJuice(battlePlayers[i].gpawn, "TIME!");
				if(i > 0)
				{
					if(battlePlayers[i].score < battlePlayers[i-1].score)
					{
						rank++;
					}
				}
				DisplayFinishRank(battlePlayers[i].gpawn, rank, endType);
				GGPCG = GGPlayerControllerGame( battlePlayers[i].gpawn.Controller );
				if(GGPCG != none)
				{
					label = GGHUD( GGPCG.myHUD ).mHUDMovie.mGameTimer;
					if( label != none )
					{
						label.SetLabelText( "" );
					}
				}
			}
			break;
		default:
			return;
	}
	CountDownTimer(true);
	battlePlayers.Length = 0;

	//Hide Arena borders
	arenaBordersUp.SetHidden(true);
	arenaBordersDown.SetHidden(true);

	mSSG.isVelocityRespawnActive=true;
	mSSG.shouldComputeDamageDealer=false;
	isBattleStarted = false;

	OnBattleEnded();
}

function CancelBattle()
{
	EndBattle(END_CANCEL);
}

function DisplayFinishRank(GGPawn gpawn, int rank, optional int endType=END_NORMAL)
{
	if(endType == END_CANCEL)
	{
		PostJuice(gpawn, "NO CONTEST");
		return;
	}
	if(endType == END_INIT)
	{
		PostJuice(gpawn, "NOT ENOUGH FIGHTERS");
		return;
	}
	switch(rank)
	{
		case 1:
			PostJuice(gpawn, "1st");
			break;
		case 2:
			PostJuice(gpawn, "2nd");
			break;
		case 3:
			PostJuice(gpawn, "3rd");
			break;
		default:
			PostJuice(gpawn, rank $ "th");
			break;
	}
}

function PostJuice( GGPawn gpawn, string text)
{
	local GGPlayerControllerGame GGPCG;
	local GGHUD localHUD;

	GGPCG = GGPlayerControllerGame( gpawn.Controller );

	localHUD = GGHUD( GGPCG.myHUD );

	if( localHUD != none && localHUD.mHUDMovie != none )
	{
		localHUD.mHUDMovie.AddJuice( text );
	}
}

function DisplayUnavailableMessage()
{
	WorldInfo.Game.Broadcast(self, "Super Smash Arena only works if combined with Super Smash Goats.");
	SetTimer(3.f, false, NameOf(DisplayUnavailableMessage));
}

DefaultProperties
{
	initLifes=3
	initTime=180.f
	botsCount=1
	customArenaSize=ARENA_SIZE_SMALL

	mStartString="GO!"
	mCountdownTime=4

	bPostRenderIfNotVisible=true

	mNameTagBoneName=Head

	mSpeechBubbleOffset=(X=0.0f,Y=0.0f,Z=120.0f)

	mSpeechBubbleLength=80.f;
	mSpeechBubbleHeight=30.f;

	mSSGTheme=SoundCue'SuperSmashGoatsSounds.SSGThemeCue'
	mBattleEndSound=SoundCue'Goat_Sound_UI.Effect_flag_turned_in_score_Cue'
	mDrawSound=SoundCue'Goat_Sound_UI.Cue.ComboBreak_Cue'
	mFighterEjectedSound=SoundCue'MMO_SFX_SOUND.Cue.NPC_Ninja_Submit_Goat_Launch_Cue'
	mCountdownSound=SoundCue'Zombie_HUD_Sounds.Zombie_HUD_QuestTimer_RunningOut_Cue'
	mGoSound=SoundCue'Goat_Sound_UI.Cue.CheckPoint_Que'
	mFighterEjectedParticleTemplate=ParticleSystem'MMO_Effects.Effects.Effects_Xcalibur_01'
}