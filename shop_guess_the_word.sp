#include <sourcemod>
#include <shop>
#include <emitsoundany> 
#include <entity_prop_stocks>

#pragma newdecls required
#pragma tabsize 0

#define particletime 5.0

char WordsList[300];
int mincredits;
int maxcredits;
float minquestion;
float maxquestion;
float timeanswer;
int credits;
static char questionResult[100];

Handle timerQuestionEnd;

public Plugin myinfo =
{
    name = "[Shop] Guess The Word",
    author = "TTony",
    description = "Guess a given word with its letters randomized",
    version = "1.0",
    url = "https://github.com/PrdTTony"
};


public void OnPluginStart()
{   
	ConVar cvar = CreateConVar("sm_GuessTheWord_words",	"test;play",    "Words players guess");
	HookConVarChange(cvar,	CVAR_WordsList);
    cvar.GetString(WordsList, sizeof(WordsList));
	HookConVarChange(cvar = CreateConVar("sm_GuessTheWord_minimum_credits",	"5",	"The minimum number of credits earned for a correct answer.", _, true, 1.0), CVAR_MinimumCredits);
	mincredits = cvar.IntValue;
	HookConVarChange(cvar = CreateConVar("sm_GuessTheWord_maximum_credits",	"100",	"The maximum number of credits earned for a correct answer.", _, true, 1.0), CVAR_MaximumCredits);
	maxcredits = cvar.IntValue;
	HookConVarChange(cvar = CreateConVar("sm_GuessTheWord_time_guess_word",	"15",	"Time in seconds to guess the given word.", _, true, 5.0),	CVAR_TimeAnswer);
	timeanswer = cvar.FloatValue;
	HookConVarChange(cvar = CreateConVar("sm_GuessTheWord_time_minamid_questions",	"100",	"The minimum time in seconds between each of the words.", _, true, 5.0),	CVAR_MinQuestion);
	minquestion = cvar.FloatValue;
	HookConVarChange(cvar = CreateConVar("sm_GuessTheWord_time_maxamid_questions",	"250",	"The maximum time in seconds between each of the words.", _, true, 10.0),	CVAR_MaxQuestion);
	maxquestion = cvar.FloatValue;
	AutoExecConfig(true, "shop_GuessTheWord");
}

public void CVAR_WordsList(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(WordsList, sizeof(WordsList));
}
public void CVAR_MinimumCredits(ConVar convar, const char[] oldValue, const char[] newValue)
{
	mincredits = convar.IntValue;
}
public void CVAR_MaximumCredits(ConVar convar, const char[] oldValue, const char[] newValue)
{
	maxcredits = convar.IntValue;
}
public void CVAR_TimeAnswer(ConVar convar, const char[] oldValue, const char[] newValue)
{
	timeanswer = convar.FloatValue;
}
public void CVAR_MinQuestion(ConVar convar, const char[] oldValue, const char[] newValue)
{
	minquestion = convar.FloatValue;
}
public void CVAR_MaxQuestion(ConVar convar, const char[] oldValue, const char[] newValue)
{
	maxquestion = convar.FloatValue;
}

public void OnMapStart()
{
    PrecacheSoundAny("shop/party_horn_01.wav"); 
}

public void OnConfigsExecuted()
{   
	timerQuestionEnd = null;
	CreateTimer(GetRandomFloat(minquestion, maxquestion), CreateQuestion, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action CreateQuestion(Handle timer)
{   
    int separators = CountChars(WordsList, ';');
    int len = strlen(WordsList);
    if (WordsList[len - 1] == ';'){
        separators--;
    }
    char[][] exploded = new char[separators][300];

    int count = ExplodeString(WordsList, ";", exploded, separators, 300);

    int randomWord = GetRandomInt(0, count - 1);
    char word[300];
    Format(word, sizeof(word), "%s", exploded[randomWord]);
    int len1 = strlen(word);

    for (int i = len1 - 1; i > 0; --i)
    {
        int randIndex = GetRandomInt(0, i);
        char temp = word[i];
        word[i] = word[randIndex];
        word[randIndex] = temp;
    }

    Format(questionResult, sizeof(questionResult), "%s", exploded[randomWord]);
    credits = GetRandomInt(mincredits, maxcredits);
    timerQuestionEnd = CreateTimer(timeanswer, EndQuestion, _, TIMER_FLAG_NO_MAPCHANGE);

    PrintToChatAll(" \x02[Shop] \x01Who guesses the word first | \x02%s \x01| receives \x04%i \x01credits", word, credits);
    return Plugin_Stop;
}

public Action EndQuestion(Handle timer)
{   
	SendEndQuestion();
	return Plugin_Stop;
}

void SendEndQuestion(int client = 0)
{
	int i = MaxClients;
	if(client)
	{
		while(i)
		{
			if(IsClientInGame(i)) PrintToChat(i, " \x02[Shop] \x10%N \x01won \x04%i \x01credits for guessing the word", client, credits);
			--i;
		}
		delete timerQuestionEnd;
	}
	else
	{
		while(i)
		{
			if(IsClientInGame(i)) PrintToChat(i, " \x02[Shop] \x01Time expired. No correct answer :(");
			--i;
		}
	}
	OnConfigsExecuted();
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if(timerQuestionEnd && StrEqual(sArgs, questionResult))
	{
		int clients[1];
		Shop_GiveClientCredits(clients[0] = client, credits);
        CreateSpawnParticle(clients[0], "weapon_confetti_balloons", particletime); 
        EmitSoundToClientAny(clients[0], "goldmember/party_horn_01.wav"); 
		PrintHintText(clients[0], "Ai primit %i credite pentru ca ai raspuns corect", credits);								
		SendEndQuestion(clients[0]);
	}
}

stock void CreateSpawnParticle(int ent, char[] particleType, float time)
{
    int particle = CreateEntityByName("info_particle_system");
    if (IsValidEdict(particle))
    {
        float position[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", position);
        TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(particle, "effect_name", particleType);
        DispatchKeyValue(particle, "start_active", "1");
        DispatchSpawn(particle);
        ActivateEntity(particle);
        SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", ent);
        char addoutput[64]; 
        Format(addoutput, sizeof(addoutput), "OnUser1 !self:kill::%i:1", time);
        SetVariantString(addoutput);
        AcceptEntityInput(ent, "AddOutput");
        AcceptEntityInput(ent, "FireUser1");   
    }
}

public Action DeleteParticle(Handle timer, any particle) 
{ 
    if (IsValidEntity(particle)) 
    { 
        char classN[64]; 
        GetEdictClassname(particle, classN, sizeof(classN)); 
        if (StrEqual(classN, "info_particle_system", false)) 
        { 
            RemoveEdict(particle); 
        } 
    } 
    return Plugin_Continue;
} 

int CountChars(const char[] str, char c)
{
    int count;
    for (int i = 0; str[i] != '\0'; ++i)
    {
        if (str[i] == c)
            count++;
    }
    return count;
}