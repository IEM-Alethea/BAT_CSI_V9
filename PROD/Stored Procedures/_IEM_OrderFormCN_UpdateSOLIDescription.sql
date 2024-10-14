SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



/*--------------------------------------------------------------------------------------------*\
  					 IEM Custom Code
  
  File: _IEM_OrderFormCN_UpdateSOLIDescription
  Description: 

  exec _IEM_OrderFormCN_UpdateSOLIDescription 'SOLI0986660233','new soli desc'

  Change Log:
  Date        Ref #   Author       Description\Comments
  ---------  ------  -----------  -------------------------------------------------------------
  2023/10    0001	  Jason       Added for PASS (Pass thur Revenue only site) Uf_Revenue = 1 
    
\*--------------------------------------------------------------------------------------------*/

ALTER PROCEDURE [dbo].[_IEM_OrderFormCN_UpdateSOLIDescription] (
	@Item ItemType,
	@NewDescription DescriptionType
) AS

set nocount on

declare @site sitetype, @dbsite sitetype, @infobar InfoBarType

SELECT TOP 1 @Site = site
FROM site
WHERE app_db_name = DB_NAME()

EXEC dbo.SetSiteSp @Site, @Infobar OUTPUT

declare @items table (
	item itemtype
)

IF OBJECT_ID('tempdb..#itemstoupdate') IS NOT NULL DROP TABLE #itemstoupdate
select * into #itemstoupdate from @items where 1=2

insert into #itemstoupdate (item)
values (@Item)

insert into #itemstoupdate
select replace(item,'SOLI',IIF(@@SERVERNAME='syteline-sql',right(site,3),site) ) from #itemstoupdate i --> 
-- join site s on Uf_mfg=1
join site s on Uf_mfg=1 OR (ISNULL(Uf_Revenue, 0) = 1)   -- 0001 Jason Tira

declare @sql nvarchar(max)
DECLARE @DBNAME NVARCHAR(20), @sitem itemType

update item set description = @NewDescription where item in (select item from #itemstoupdate) and isnull(description,'') <> @NewDescription

declare scrs cursor for 
select app_db_name,site from site 
where Uf_mfg=1 OR (ISNULL(Uf_Revenue, 0) = 1)   -- 0001 Jason Tira

open scrs
while 1=1 begin
	fetch next from scrs into @dbname, @dbsite
	if @@FETCH_STATUS != 0 break

	EXEC dbo.SetSiteSp @dbsite, @Infobar OUTPUT

	set @sql='update j set description = @description from '
	+ @DBNAME + '.dbo.job_mst j  where item in (select item from #itemstoupdate) and type in (''J'',''E'')'

	exec sp_executesql @sql, N'@description descriptionType', @NewDescription

end
close scrs
deallocate scrs


EXEC dbo.SetSiteSp @Site, @Infobar OUTPUT
GO

