SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*----------------------------------------------------------------------------------*\

	     File: _IEM_OrderFormCN_CreateItemAndCurrentJobSp
  Description: 

  Change Log:
  Date        Ref #   Author       Description\Comments
  ---------  ------  -----------  -------------------------------------------------------------
  2024/01     0001   Alethea 	  This SP does not need the UET Uf_Revenue for PASS items etc. 

\*---------------------------------------------------------------------------------*/

ALTER PROCEDURE [dbo].[_IEM_OrderFormCN_CreateItemAndCurrentJobSp](
	@Item			ItemType OUTPUT,
	@Description	DescriptionType,
	@CoNum			CoNumType,
	@CoLine			CoLineType,
	@WC				WCType,
	@BomID			INT,
	@PMTCode		PMTCodeType,
	@partType		NVARCHAR(50),
	@ItemTemplate	ItemType,
	@InfoBar 		InfoBarType OUTPUT,
	@SubTemplate		ItemType,
	@ProdLeadTime		INT
) AS
BEGIN
	DECLARE @Severity int
		,@Revision RevisionType
		,@UM UMType
		,@ProductCode ProductCodeType
		,@Job JobType
		,@Suffix SuffixType
		,@JobType JobTypeType
		,@SQL NVARCHAR(MAX)
		,@Debug ListYesNoType
		,@FromJob JobType
		,@FromSuffix SuffixType
		,@ToJob JobType
		,@ToSuffix SuffixType
		,@StartOper OperNumType
		,@EndOper OperNumType
		,@NextOrderLine INT
		,@Site SiteType
		,@JobHolder JobType
		,@SuffixHolder SuffixType
		,@JobTypeHolder JobTypeType
		,@Mfg ManufacturerIdType

	SET @Severity = 0
	SET @Debug = 1

	IF @Site IS NULL
	BEGIN
		SELECT TOP 1 @Site = site
		FROM site
		WHERE app_db_name = DB_NAME()
	END

	EXEC dbo.SetSiteSp @Site, @Infobar OUTPUT

	SELECT TOP 1 @NextOrderLine = co_line
	FROM coitem_mst (NOLOCK)
	WHERE co_num = @CoNum
	ORDER BY co_line DESC

	--SET @NextOrderLine = ISNULL(@NextOrderLine,0) + 1

	IF @partType = 'MANUFACTURED' AND NOT EXISTS(SELECT * FROM item where item = @ItemTemplate)
	BEGIN
		SET @Severity = 16
		SET @Infobar = 'Template Item ' + @ItemTemplate + ' does not exist.  Cannot create quoted item.'
		RETURN @Severity
	END

	SELECT @UM = u_m, @ProductCode = product_code, @Mfg = Uf_manufacturer
	FROM item 
	WHERE item = @ItemTemplate

	IF @partType = 'MANUFACTURED' BEGIN
		SET @Item = 'SOLI' + RIGHT('0' + LTRIM(RTRIM(@CoNum)),6) + RIGHT(10000 + @CoLine,4)
	END	ELSE IF @partType = 'ORDER_SPECIFIC' BEGIN
		SET @Item = @ItemTemplate + '-' + LTRIM(RTRIM(@CoNum)) + '-' + RIGHT(10000 + @CoLine,4)
	END ELSE BEGIN
		SET @Item = @SubTemplate
	END

	-- Create Item
	IF NOT EXISTS(SELECT * FROM item WHERE item = @Item) AND @partType <> 'INVENTORY' BEGIN
		EXECUTE @Severity = [dbo].[_IEM_OrderFormCN_CreateItemSp] 
			 @Item = @Item
			,@Description = @Description
			,@Revision = NULL --@Revision
			,@UM = @UM
			,@ProductCode = @ProductCode
			,@Job = @Job OUTPUT
			,@Suffix = @Suffix OUTPUT
			,@JobType = @JobType OUTPUT
			,@Infobar = @Infobar OUTPUT
			,@Site = NULL
			,@SiteSpecificItem = 0
			,@TemplateItem = @ItemTemplate
			,@pass_req = 1
			,@LeadTime=0

		IF @Severity <> 0
			RETURN @Severity

		if not exists (select 1 from item_all where item = @Item and site_ref=@Site) begin
			set @InfoBar = 'Could not find item '+@Item+' in order site '+@Site+' ; aborting.'
			set @Severity=16
			return
		end
	END

	IF @partType <> 'MANUFACTURED'
		RETURN @Severity

	IF @Severity <> 0
	BEGIN
		RETURN @Severity
	END

	SELECT @FromJob = job, @FromSuffix = suffix
	FROM item
	WHERE item = @ItemTemplate
	
	SELECT @ToJob = job, @ToSuffix = suffix
	FROM item 
	WHERE item = @Item

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
		,@FromItem = @ItemTemplate
		,@StartOper = @StartOper
		,@EndOper = @EndOper
		,@LMBVar = 'B'
		,@Revision = NULL
		,@ScrapFactor = 0
		,@CopyBom = 0
		,@ToJobCategory = 'C'
		,@ToItem = @Item
		,@ToJob = @ToJob
		,@ToSuffix = @ToSuffix
		,@EffectDate = NULL
		,@OptionType = 'D'
		,@AfterOper = NULL
		,@CopyToPSReleaseBom = NULL
		,@Infobar = @Infobar OUTPUT
		,@CopyUetValues = 1

	SELECT @FromJob = job, @FromSuffix = suffix
	FROM item
	WHERE item = @SubTemplate
	
	SELECT TOP 1 @StartOper = oper_num
	FROM jobroute (NOLOCK)
	WHERE job = @FromJob AND suffix = @FromSuffix
	ORDER BY oper_num

	SELECT TOP 1 @EndOper = oper_num
	FROM jobroute (NOLOCK)
	WHERE job = @FromJob AND suffix = @FromSuffix
	ORDER BY oper_num DESC

	SELECT @ToJob = job, @ToSuffix = suffix
	FROM item 
	WHERE item = @Item

	DECLARE 
		 @JobmatlRowPointer RowPointerType
		,@JobmatlCost CostPrcType
		,@JobmatlSequence JobmatlSequenceType
		,@TNextSequence JobmatlSequenceType

	SET @JobmatlSequence = 0
	SET @TNextSequence = 0

	SELECT TOP 1
		@JobmatlRowPointer = jobmatl.RowPointer
		, @JobmatlCost       = jobmatl.cost
		, @JobmatlSequence   = jobmatl.sequence
	FROM jobmatl
	WHERE jobmatl.job      = @ToJob
		AND jobmatl.suffix   = @ToSuffix
		AND jobmatl.oper_num = 10
	ORDER BY jobmatl.sequence DESC

	IF @JobmatlRowPointer IS NULL
		SET @TNextSequence = 1
	ELSE
		SET @TNextSequence = @JobmatlSequence + 1

	declare @tsite sitetype, @titem itemtype
	declare @sitePrefix sitetype, @sAppdb OSLocationType

	declare scrs cursor for 
	select site, Uf_SiteIdentity, app_db_name from site where Uf_mfg=1								--> 0001 Alethea Not needed as we don't have PASS items Uf_Revenue = 1	

	open scrs
	while 1=1 begin
		fetch scrs into @tsite, @sitePrefix, @sAppdb
		if @@FETCH_STATUS != 0 break
		set @titem=replace(@item, 'SOLI', @sitePrefix)


		INSERT INTO jobmatl
		(
			job
			, suffix
			, oper_num
			, sequence
			, bom_seq
			, matl_type
			, item
			, u_m
			, matl_qty
			, matl_qty_conv
			, units
			, cost
			, matl_cost
			, lbr_cost
			, fovhd_cost
			, vovhd_cost
			, out_cost
			, cost_conv
			, ref_type
			, backflush
			, bflush_loc
			, alt_group
			, alt_group_rank
		)
		VALUES
		(
			@ToJob
			, @ToSuffix
			, 10
			, @TNextSequence
			, @TNextSequence
			, 'M'
			, @titem
			, @UM
			, 1
			, 1
			, 'U'
			, 0 --@ItemUnitCost
			, 0 --@ItemMatlCost
			, 0
			, 0
			, 0
			, 0
			, 0 --@JobmatlCost
			, CASE WHEN @Site = @tsite THEN 'J' ELSE'T' END
			, 0
			, NULL
			, @TNextSequence
			, 0
		)

		SET @TNextSequence = @TNextSequence + 1
	end -- site loop
	close scrs
	deallocate scrs


	EXEC [dbo].[_IEM_SyncBOMSp]
		 @Item
		,@InfoBar OUTPUT
		,@Site
		,1 -- do not create transactions.  we should already be in a tran

	RETURN @Severity

END






GO

