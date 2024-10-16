SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[_IEM_SendEmailSp] (
    @from       AS NVARCHAR(256) = 'infor@iemfg.com',
    @to         AS NVARCHAR(MAX) = 'danh@iemfg.com',
    @subject    AS NVARCHAR(256) = '',
    @body       AS NVARCHAR(MAX) = '',
	@html       AS INT = 0,
	@cc         as NVARCHAR(MAX) = '',
	@reportName as NVARCHAR(256) = '',
	@outputType as NVARCHAR(256) = 'EXCEL',
	@textParam  as nvarchar(max) = null,
	@userid     as UserNameType = null,
	@loadStrings as INT = 0,
	@parameters as XML = null,
	@Infobar    AS Infobar = '' OUTPUT
) AS
	declare @dbName NVARCHAR(256), @ret int, @SiteID SiteType, @Company NameType, @logo nvarchar(max)
	declare @bgsessid NVARCHAR(100);
	set @dbName = DB_NAME()

	SELECT @SiteID = parms.site, @Company = company
	FROM parms_mst parms
	LEFT JOIN site 	ON parms.site = site.site
	WHERE app_db_name = DB_NAME()

	set @logo=@siteid + '/SLHeaderLogo.bmp'

	if @from is null or @from='{NULL}' set @from='infor@iemfg.com'
	if @to is null or @to='{NULL}' set @to='danh@iemfg.com'
	if @subject is null or @subject='{NULL}' set @subject=''
	if @body is null or @body='{NULL}' set @body=''
	if @html is null set @html=0
	if @cc is null or @cc='{NULL}' set @cc=''
	if @reportName is null or @reportName='{NULL}' set @reportName = ''
	if @outputType is null or @outputType='{NULL}' set @outputType='EXCEL'
	if @userid is null or @userid='{NULL}' set @userid = dbo.UserNameSp()

	if (@textParam is not null and @textParam<>'{NULL}') and @parameters is null set @parameters = cast(@textParam as XML)
	if @parameters is null set @parameters = cast('<row/>' as xml)

	set @bgsessid = @parameters.value('/row[1]/@BGSessionId','nvarchar(100)')

	set @parameters.modify('insert attribute BG_USERID {sql:variable("@userid")} into (/row)[1]');
	set @parameters.modify('insert attribute BG_SITEID {sql:variable("@SiteID")} into (/row)[1]');
	set @parameters.modify('insert attribute BG_COMPANYNAME {sql:variable("@Company")} into (/row)[1]');
	set @parameters.modify('insert attribute pSLHeaderLogo {sql:variable("@logo")} into (/row)[1]');
	if @bgsessid is not null set @parameters.modify('insert attribute BGSessionId1 {sql:variable("@bgsessid")} into (/row)[1]');
	

	if @loadStrings = 1 begin
		declare @forms nvarchar(10)
		IF OBJECT_ID('tempdb..#formstrings') IS NOT NULL DROP TABLE #formstrings
		create TABLE #formstrings ([Name] NVARCHAR(50), [ScopeType] SMALLINT, [ScopeName] NVARCHAR(50), [String] NVARCHAR(501))
		if @@SERVERNAME='SYTELINE-SQL' set @forms='dev' else set @forms='iem'
		declare @sql nvarchar(max) = 'select Name, ScopeType, ScopeName, String from '+@forms+'_forms..Strings'
		insert into #formstrings exec (@sql)

		IF OBJECT_ID('tempdb..#reportxml') IS NOT NULL DROP TABLE #reportxml
		create table #reportxml (id int primary key, x xml)
		create primary xml index idx_x on #reportxml (x)
		insert into #reportxml
		SELECT top 1 1 as id, CONVERT(XML,C.Parameter) AS x FROM  ReportServer.dbo.Catalog C WHERE  C.Content is not null AND  C.Type  = 2 AND C.Name  =  @reportName

		DECLARE stringcursor cursor READ_ONLY for
		SELECT Paravalue.value('Name[1]', 'VARCHAR(250)') as Name, strings.String, strings.ScopeName, strings.ScopeType
		FROM #reportxml
		CROSS APPLY x.nodes('//Parameters/Parameter') p ( Paravalue )
		LEFT JOIN #formstrings strings on Paravalue.value('Prompt[1]', 'VARCHAR(250)')=strings.Name+'_'
		where Paravalue.value('DefaultValues[1]', 'VARCHAR(250)')+'_'= Paravalue.value('Prompt[1]', 'VARCHAR(250)') and Paravalue.value('Type[1]', 'VARCHAR(250)') ='String'

		declare @StrName nvarchar(50), @StrValue nvarchar(501), @paramText nvarchar(max)='', @ScopeName nvarchar(50), @ScopeType smallint

		
		set @paramText=@paramText+cast(@parameters as nvarchar(max))
		set @paramText=replace(@paramText,N'/>',N'')

		declare @AddedParams table (Name nvarchar(50))

		Open stringcursor
		While 1 = 1
		BEGIN
			Fetch next from stringcursor into @StrName, @StrValue, @ScopeName, @ScopeType
			IF @@FETCH_STATUS <> 0	BREAK
			if @StrValue is null set @StrValue = @StrName -- default value for strings with "_" is their own name.  see "NONE" in InventoryCost which does not accept null/empty string
			if @ScopeType=2 and @ScopeName <> @userid CONTINUE --user scoped strings? not likely but support as best we can
			if not exists (select 1 from @AddedParams where Name = @StrName) begin
				insert into @AddedParams (Name) values (@StrName)
				set @paramText=@paramText+N' '+@StrName+N'='+N'"'+@StrValue+N'"'
				--print @paramText
			end

		END
		close stringcursor
		deallocate stringcursor

		set @paramText=@paramText+N' />'
		--print @paramText
		begin try
			set @parameters=@paramText
		end try
		begin catch
			--just fail silently because we couldn't update strings for some reason
		end catch
	end
		
	--print cast(@parameters as nvarchar(max))

	set @ret=15
	exec @ret=master.._IEM_SendEmail @from, @to, @subject, @body, @html, @cc, @dbName, @reportName, @outputType, @parameters, @Infobar OUTPUT

	return @ret