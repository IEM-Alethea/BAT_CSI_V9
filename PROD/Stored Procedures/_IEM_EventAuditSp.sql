SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[_IEM_EventAuditSp]
	(
		  @EventName		NVARCHAR(50)
	)

AS

BEGIN

DECLARE @Site siteType;
SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()
EXEC dbo.SetSiteSp @Site, NULL

INSERT INTO _IEM_EventAudit (EventName, TimexStamp)
	SELECT @EventName, GETDATE()

END
GO

