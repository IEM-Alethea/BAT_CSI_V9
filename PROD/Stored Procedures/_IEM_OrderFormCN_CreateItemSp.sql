SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





/**************************************************************************
special version of create item to avoid CreateItemSp's transaction
***************************************************************************/
ALTER PROCEDURE [dbo].[_IEM_OrderFormCN_CreateItemSp] (
   @Item			ItemType
  ,@Description 	DescriptionType
  ,@Revision 		RevisionType
  ,@UM 				UMType
  ,@ProductCode 	ProductCodeType
  ,@Job 			JobType			OUTPUT
  ,@Suffix 			SuffixType		OUTPUT
  ,@JobType 		JobTypeType		OUTPUT
  ,@Infobar    		InfobarType   	OUTPUT
  ,@Site			SiteType
  ,@SiteSpecificItem ListYesNoType = 0
  ,@TemplateItem ItemType = NULL
  ,@pass_req int	= 1
  ,@LeadTime int = 180
) AS
BEGIN

	DECLARE @Severity INT
		, @Debug ListYesNoType
		, @ContextInfo VARBINARY(128)
		, @FromJob JobType
		, @FromSuffix SuffixType
		, @StartOper OperNumType
		, @EndOper OperNumType
		, @Mfg ManufacturerIdType
		, @pmt PMTCodeType

	SET @ContextInfo = CONTEXT_INFO()

	SET @Severity = 0
	SET @Debug = 0

	IF @Site IS NULL
	BEGIN
		SELECT TOP 1 @Site = site
		FROM site
		WHERE app_db_name = DB_NAME()
	END

	EXEC dbo.SetSiteSp @Site, @Infobar OUTPUT

	IF NOT EXISTS(SELECT * FROM item WHERE item = @Item)
	BEGIN
/*
		EXEC @Severity = dbo.CreateItemSp 
			 @Item
			,@Description
			,@Revision
			,@UM
			,@ProductCode
			,@Job OUTPUT
			,@Suffix OUTPUT
			,@JobType OUTPUT
			,@Infobar OUTPUT

*/
--      begin copy code from createitemsp w/o trans \/

		declare 
		@LotPrefix	LotPrefixType
		, @LotTracked 		ListYesNoType
		, @SerialTracked	ListYesNoType
		, @PreassignLots	ListYesNoType
		, @PreassignSerials	ListYesNoType

		select  
		@LotPrefix = lot_prefix
		, @LotTracked 		= lot_tracking
		, @SerialTracked 	= serial_tracked
		, @PreassignLots 	= preassign_lots
		, @PreassignSerials = preassign_serials
		FROM invparms

		select @mfg = null, @pmt = null
		IF @TemplateItem IS NOT NULL 
			select @mfg=Uf_manufacturer, @pmt=p_m_t_code from item where item=@TemplateItem
		if @mfg is null set @mfg='IEM'
		if @pmt is null set @pmt='P'

		IF RIGHT(@Site, 4) = 'PASS' AND EXISTS (SELECT 1 FROM item_all WHERE item = @Item AND RIGHT(site_ref, 3) = 'FRE')
			BEGIN
				INSERT INTO item (item, description, revision, u_m, product_code, lot_prefix, lot_tracked, serial_tracked, preassign_lots, preassign_serials, cost_type, cost_method, p_m_t_code, Uf_manufacturer, pass_req, lead_time)
					SELECT item, description, revision, u_m, product_code, lot_prefix, lot_tracked, serial_tracked, preassign_lots, preassign_serials, cost_type, cost_method, p_m_t_code, Uf_manufacturer, pass_req, lead_time
						FROM item_all
							WHERE item = @Item AND RIGHT(site_ref, 3) = 'FRE'
			END
		ELSE
			BEGIN
				INSERT INTO item (item, description, revision, u_m, product_code, lot_prefix, lot_tracked, serial_tracked, preassign_lots, preassign_serials, cost_type, cost_method, p_m_t_code, Uf_manufacturer, pass_req, lead_time)
					VALUES (@Item, @Description, @Revision, @UM, @ProductCode, @LotPrefix, @LotTracked, @SerialTracked, @PreassignLots, @PreassignSerials, 'A', 'A', @pmt, @Mfg, @pass_req, @LeadTime)
			END

	   --Create the Current Route/BOM Header Job
		EXEC @Severity = dbo.PreSaveCurrOperSp 
								@Item    = @Item
							, @OperNum = NULL
							, @Wc      = 'Dummy'
							, @Job     = @Job	  OUTPUT
							, @Suffix  = @Suffix OUTPUT
							, @JobType = @JobType  OUTPUT
							, @Infobar = @Infobar  OUTPUT
-- 		end copy code from createitemsp w/o trans /\

		IF @SiteSpecificItem = 1
		BEGIN

			IF @Debug = 1
				PRINT 'Importing routings from template item.'

				SELECT @FromJob = job, @FromSuffix = suffix
				FROM item
				WHERE item = @TemplateItem

				SELECT TOP 1 @StartOper = oper_num
				FROM jobroute (NOLOCK)
				WHERE job = @FromJob AND suffix = @FromSuffix
				ORDER BY oper_num

				SELECT TOP 1 @EndOper = oper_num
				FROM jobroute (NOLOCK)
				WHERE job = @FromJob AND suffix = @FromSuffix
				ORDER BY oper_num DESC

			EXEC @Severity = CopyBomDoProcessSp
				@FromJobCategory = 'C'
				,@FromJob = @FromJob
				,@FromSuffix = @FromSuffix
				,@FromItem = @TemplateItem
				,@StartOper = @StartOper
				,@EndOper = @EndOper
				,@LMBVar = 'B'
				,@Revision = NULL
				,@ScrapFactor = 0
				,@CopyBom = 1
				,@ToJobCategory = 'C'
				,@ToItem = @Item
				,@ToJob = @Job
				,@ToSuffix = @Suffix
				,@EffectDate = NULL
				,@OptionType = 'D'
				,@AfterOper = NULL
				,@CopyToPSReleaseBom = NULL
				,@Infobar = @Infobar OUTPUT
				,@CopyUetValues = 1

		END
	END

	SET CONTEXT_INFO @ContextInfo

	RETURN @Severity

END




GO

