SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*
	DECLARE @Infobar		Infobartype

	Exec _IEM_CurrateLoadSp @Infobar OUTPUT
	select @Infobar
	--delete from currate_MST where eff_date = dbo.MidnightOf(GetDate())
	select * from currate_mst
	--select * from currency_mst
	--	SELECT 
	--id, createTime, exRate, fromCurrency, isLatest, toCurrency FROM OPENQUERY(EQUOTE, 'SELECT * FROM `dev-iemq`.`exchangeRateDaily` WHERE isLatest = 1')

*/

ALTER PROCEDURE [dbo].[_IEM_CurrateLoadSp] (
    @Infobar InfobarType = NULL OUTPUT
)
AS
BEGIN
    DECLARE 
        @RptSessionID RowPointerType
        ,@Severity INT = 0

    EXEC dbo.InitSessionContextSp
        @ContextName	= '_IEM_CurrateLoadSp'
        ,@SessionID		= @RptSessionID OUTPUT
        ,@Site			= null 

	DECLARE @fcurr CurrCodeType
		,@tcurr CurrCodeType
		,@fsite SiteType
		,@tsite SiteType
		,@rate Decimal(12,7)

	DECLARE @CurTable TABLE (
		Id					int
		,createtime			int
		,ExchRate			Decimal(12,7)
		,fromCurrency		CurrCodeType
		,isLatest			tinyint
		,toCurrency			CurrCodeType)

	declare @exchSQL nvarchar(max), @exchdb nvarchar(10), @exchOQ nvarchar(max)
	if @@SERVERNAME='SYTELINE-SQL' 
		set @exchdb='dev-iemq'
	else 
		set @exchdb='iemq'

	set @exchSQL = 'SELECT * FROM `'+@exchdb+'`.`exchangeRateDaily` WHERE isLatest = 1'

	set @exchOQ = 'SELECT id, createTime, exRate, fromCurrency, isLatest, toCurrency FROM OPENQUERY(EQUOTE, '''+@exchSQL+''')'

	insert into @CurTable
	EXEC (@exchOQ)

	/*
	insert into @CurTable
	SELECT id, createTime, exRate, fromCurrency, isLatest, toCurrency FROM OPENQUERY(EQUOTE, 'SELECT * FROM `iemq`.`exchangeRateDaily` WHERE isLatest = 1')
	*/

	BEGIN TRY
		Insert into currate
			(from_curr_code
			,eff_date
			,buy_rate
			,sell_rate
			,to_curr_code)
		select
			ct.fromCurrency
			,dbo.MidnightOf(GetDate())
			,1/ct.ExchRate
			,1/ct.ExchRate	-- 1/ct.ExchRate
			,ct.toCurrency
		from @CurTable ct inner join currency fc on ct.fromCurrency = fc.curr_code
		inner join currency tc on ct.toCurrency = tc.curr_code
		left join currate cr on ct.fromCurrency = cr.from_curr_code and ct.toCurrency = cr.to_curr_code
		and cr.eff_date = dbo.MidnightOf(GetDate())
		where cr.from_curr_code is null and ct.ExchRate <> 0
		
		Insert into currate
			(from_curr_code
			,eff_date
			,buy_rate
			,sell_rate
			,to_curr_code)
		select
			ct.toCurrency
			,dbo.MidnightOf(GetDate())
			,ct.ExchRate
			,ct.ExchRate
			,ct.fromCurrency
		from @CurTable ct inner join currency fc on ct.toCurrency = fc.curr_code
		inner join currency tc on ct.fromCurrency = tc.curr_code
		left join currate cr on ct.toCurrency = cr.from_curr_code and ct.fromCurrency = cr.to_curr_code
		and cr.eff_date = dbo.MidnightOf(GetDate())
		where cr.from_curr_code is null and ct.ExchRate <> 0

		
		Declare site_cursor Cursor local FOR
		select fsite.curr_code,tsite.curr_code,from_site,to_site,buy_rate from sitenet 
		join currparms_all fsite on sitenet.from_site=fsite.site_ref
		join currparms_all tsite on sitenet.to_site=tsite.site_ref
		join currate on from_curr_code=fsite.curr_code and to_curr_code = tsite.curr_code
		WHERE eff_date = dbo.MidnightOf(GetDate())


		Open site_cursor

		While 1=1
		BEGIN
			FETCH Next from site_cursor into @fcurr,@tcurr,@fsite,@tsite,@rate

			IF @@Fetch_status <> 0 BREAK

			update sitenet set exch_rate = @rate where sitenet.from_site=@fsite and sitenet.to_site=@tsite

			EXECUTE ChangeTransferExchRateSp @fsite, @tsite, @rate, @Infobar OUTPUT

		END



		SET @Infobar = CAST(@@ROWCOUNT as nvarchar(10)) + ' record(s) added.'
	END TRY
	BEGIN CATCH
		SET @Severity = @@ERROR
		SET @Infobar = ERROR_MESSAGE()
	END CATCH

    Return @Severity
END
GO

