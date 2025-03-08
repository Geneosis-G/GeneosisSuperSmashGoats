class SuperSmashInteraction extends Interaction;

var SuperSmashArena myMut;

function InitSuperSmashInteraction(SuperSmashArena newMut)
{
	myMut=newMut;
}

function bool ShouldExit()
{
	if(myMut.mSSG == none)
		return true;

	if(myMut.isBattleStarted)
	{
		myMut.WorldInfo.Game.Broadcast(myMut, "Can't change settings during battle");
		return true;
	}

	return false;
}

exec function SSGStock(int newStock)
{
	if(ShouldExit())
		return;

	if(newStock < 1)
		newStock = 1;

	myMut.initLifes = newStock;
	myMut.WorldInfo.Game.Broadcast(myMut, "Stock = " $ newStock);
}

exec function SSGTime(int newTimeMin)
{
	if(ShouldExit())
		return;

	if(newTimeMin < 1)
		newTimeMin = 1;

	myMut.initTime = newTimeMin * 60;
	myMut.WorldInfo.Game.Broadcast(myMut, "Time = " $ newTimeMin $ " min");
}

exec function SSGArenaSize(int newArenaSize)
{
	if(ShouldExit())
		return;

	if(newArenaSize < 1000)
		newArenaSize = 1000;

	myMut.customArenaSize = newArenaSize;
	myMut.WorldInfo.Game.Broadcast(myMut, "Arena Size = " $ newArenaSize);
}

exec function SSGBots(int newBotsCount)
{
	if(ShouldExit())
		return;

	if(newBotsCount < 0)
		newBotsCount = 0;

	myMut.botsCount = newBotsCount;
	myMut.WorldInfo.Game.Broadcast(myMut, "Bots Count = " $ newBotsCount);
}