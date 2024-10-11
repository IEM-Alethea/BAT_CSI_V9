SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*----------------------------------------------------------------------------------*\

	     File: _IEM_ClearSessionsSP
  Description: Deleted User Connection Information from Site and Master

  EXEC _IEM_ClearSessionsSP 'PASS', 'CC5A986C-8842-4926-8912-B10D7075A9AB'

  Change Log:
  Date        Ref #   Author      Description\Comments
  ---------  ------  -----------  -------------------------------------------------------------
  2024/02     0000   Alethea      Initial

\*---------------------------------------------------------------------------------*/

ALTER PROCEDURE [dbo].[_IEM_ClearSessionsSP](
	  @Site				nvarchar(8)
    , @ConnectionID		nvarchar(128)
)
AS

BEGIN

    DECLARE @DB As Nvarchar(10);
	SELECT @DB = DB FROM _IEM_SiteConnectionInformation WHERE ConnectionID = @ConnectionID

	DECLARE @sql nvarchar(max) = NULL
	--SET @sql = 'DELETE FROM ' + @Site +  '_App.dbo.ConnectionInformation WHERE ConnectionID = ''' + @ConnectionID + ''' '
	SET @sql = 'DELETE FROM ' + @DB +  '.dbo.ConnectionInformation WHERE ConnectionID = ''' + @ConnectionID + ''' '
	EXEC(@sql)
	

RETURN 0
END

GO

