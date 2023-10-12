#include <store>

public void OnPluginStart()
{
	RegAdminCmd("sm_refund", Command_Refund, ADMFLAG_ROOT, "Refund items for all offline players.");
}

Action Command_Refund(int client, int args)
{
	if (args < 1)	return Plugin_Handled;
	char itemname[PLATFORM_MAX_PATH];
	GetCmdArgString(itemname, sizeof(itemname));

	char buffer[128];
	FormatEx(buffer, sizeof(buffer), "SELECT * FROM store_items WHERE unique_id = '%s';", itemname);
	Store_SQLQuery(buffer, Refund_Query, 0);

	return Plugin_Continue;
}

void Refund_Query(Database db, DBResultSet results, const char[] error, any data)
{
	if (!results)
	{
		LogError("Fail to query store database");
	}

	for(int i = 1; i <= results.RowCount; i++)
	{
		
	}
	if ( results.MoreRows )
	{
		if ( results.FetchRow() )
		{
			int field_index;
			results.FieldNameToNum("price_of_purchase", field_index);
			int price = results.FetchInt(field_index);
		}
	}
}

void Refund_AddCredits()