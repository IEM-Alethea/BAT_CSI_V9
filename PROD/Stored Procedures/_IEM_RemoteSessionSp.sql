SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




ALTER PROCEDURE [dbo].[_IEM_RemoteSessionSp] (
	@RemoteSite sitetype = NULL,
	@LocalSite sitetype = NULL,
	@SaveSessionID uniqueidentifier = NULL OUTPUT,	
	@RemoteSessionID uniqueidentifier = NULL OUTPUT,
	@Username Usernametype = NULL OUTPUT,
	@restore int = 0, --1 restore from vars. 2 restore from table
	@clear int = 0 --first time in a session you should clear
) AS
BEGIN
	declare 
		@infobar infobartype,
		@Severity int,
		@sql nvarchar(max)

	if (OBJECT_ID('tempdb..##sessionTable') IS NOT NULL and @restore = 2) begin
		select @RemoteSite=RemoteSite, @LocalSite=LocalSite, @SaveSessionID=SaveSessionID, @RemoteSessionID=RemoteSessionID, @Username=Username
		from ##sessionTable where spid=@@SPID
	end

	if @RemoteSite is null return
	if @LocalSite is null return
	if @LocalSite = @RemoteSite return
	if NOT EXISTS (SELECT 1 from site where site.site = @RemoteSite)
		BEGIN
			SET @Infobar = ISNULL(@RemoteSite, '<null>') + ' does not exist in site table.'
			return 16 -- dbh 20230914
		END

	if @restore=0 begin
		
		SET @SaveSessionID = dbo.SessionIDSp()
		SET @RemoteSessionID = NEWID()
		SET @UserName = dbo.UserNameSp()
				
		select @SQL = site.app_db_name + '..InitRemoteServerSp'
			from site where site.site = @RemoteSite

		EXEC @Severity = @Sql
			@RemoteSessionID
			, @UserName
			, 0 -- @SkipReplicating
			, 0 -- @SkipBase
			, @Infobar OUTPUT
			, @Site = @RemoteSite

		select @SQL = 'update '+site.app_db_name + '..sessioncontextnames with(rowlock) set createdby=@username where sessionid=@sessionid and createdby != @username'
			from site where site.site = @RemoteSite

		EXEC sp_executesql @sql, N'@sessionid uniqueidentifier, @username usernametype', @RemoteSessionID, @UserName
	
		IF OBJECT_ID('tempdb..##sessionTable') IS NULL BEGIN
			CREATE TABLE ##sessionTable (
				RemoteSite nvarchar(8), --sitetype,
				LocalSite nvarchar(8), --sitetype,
				SaveSessionID uniqueidentifier,	
				RemoteSessionID uniqueidentifier,
				Username nvarchar(30), -- Usernametype,
				spid smallint
			)		
		END
		
		if @clear=1 delete from ##sessionTable where spid = @@SPID and localsite=@LocalSite
		insert into ##sessionTable (RemoteSite,	LocalSite,	SaveSessionID, RemoteSessionID, Username, spid)
		values (@RemoteSite, @LocalSite, @SaveSessionID, @RemoteSessionID, @Username, @@spid)

		exec setsitesp @RemoteSite, ''
	end else begin
		if @LocalSite is null return

		select @SQL = site.app_db_name + '..ResetRemoteServerSp'
			from site where site.site = @RemoteSite

		EXEC @Severity = @Sql
		  @RemoteSessionID
		, @Infobar
		, @LocalSite

		EXEC @Severity = dbo.ResetSessionIDSp @SaveSessionID

		select @SQL = 'update '+site.app_db_name + '..sessioncontextnames with(rowlock) set createdby=@username where sessionid=@sessionid and createdby != @username'
			from site where site.site = @LocalSite

		EXEC sp_executesql @sql, N'@sessionid uniqueidentifier, @username usernametype', @SaveSessionID, @UserName

		exec setsitesp @LocalSite, ''
	end
END
GO

