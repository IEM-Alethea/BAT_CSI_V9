SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/**************************************************************************
*                            Modification Log
*                                            
* Ref#  Init Date     Description           
* ----- ---- -------- ----------------------------------------------------- 
* MOD100 JWP   090115  eQuote to SyteLine interface
***************************************************************************/
ALTER PROCEDURE [dbo].[_IEM_CreateCoitemSp] (
	 @Item ItemType OUTPUT
	,@Description		DescriptionType
	,@CoNum				CoNumType
	,@BomItem			ItemType
	,@ItemUnitWeight	WeightType
	,@QtyOrderedConv	QtyUnitType
	,@OriginalPriceConv CostPrcType
	,@PMTCode			PMTCodeType
	,@partType			NVARCHAR(50)
	,@ItemTemplate		ItemType
	,@OrderDate			DateType
	,@CustNum			CustNumType
	,@CustSeq			CustSeqType
	,@PriceCode			PriceCodeType
	,@CurrencyCode		CurrCodeType
	,@CoLine			CoLineType OUTPUT
	,@Infobar			InfobarType OUTPUT
	,@Revision			RevisionType
	,@ShipDirect		ListYesNoType
	,@EngLeadDays		INT
	,@ProdLeadDays		INT
	,@PromiseDate		DateType
	,@DueDate			DateType
	,@ErpTopLineItemId	INT
	,@SubTemplate		ItemType
	,@ReqDate DateType
	,@Vendor VendNumType
	,@VendorPrice CostPrcType
	,@DropShipNumber INT
	--,@AssignSite SiteType
	--,@Uf_eCodeAttr nvarchar(100)
	--,@Uf_numSections int
	--,@Uf_numPanelInteriors int
	--,@Uf_numCdpInteriors int
	--,@kitItem ItemType = NULL
)
AS
BEGIN
	
	DECLARE 
		 @Severity INT
		,@Site SiteType
		,@ItemUM UMType
		,@TaxCode1 NVARCHAR(6)
		,@TaxCode2 NVARCHAR(6)
		,@WC WCType
		,@ID INT
		,@CurrCode CurrCodeType
		,@iShipSite SiteType
		,@ItemItem ItemType
		,@ShipSite SiteType
		,@Debug ListYesNoType
		,@ItemDesc DescriptionType
		,@ShipCode ShipCodeType
		,@PriceConv CostPrcType
		,@ItemWhse WhseType
		,@PShowMatrix ListYesNoType
		,@CoitemRowPointer RowPointerType
		,@PrintKitComponents ListYesNoType
		,@CustItem CustItemType
		,@EcCode EcCodeType
		,@OrigPriceConv CostPrcType
		,@Price CostPrcType
		,@Transport NVARCHAR(3)
		,@EffDate DateType
		,@ExpDate DateType
		,@FeatStr FeatStrType
		,@ItemPlanFlag ListYesNoType
		,@SupplQtyReq float
		,@ItemFeatTempl NVARCHAR(52)
		,@SupplQtyConvFactor float
		,@Whse WhseType
		,@ToJob JobType
		,@ToSuffix SuffixType
		,@ToRelease OperNumPoReleaseType
		,@RefType RefTypeIJOType
		,@ItemCommCode CommodityCodeType
		,@ShipTo CustSeqType
		,@OrderPriceCode PriceCodeType
		,@RefNum JobPoProjReqTrnNumType
		,@ItemOrigin NVARCHAR(2)
		,@ConfigString NVARCHAR(40)
		,@RefLineSuf SuffixType
		,@Job JobType
		,@RefRelease OperNumPoReleaseType
		,@DiscPct float
		,@Rate float
		,@TransNat TransNatType
		,@JobSuffix SuffixType
		,@UnitPrice CostPrcType
		,@TransNat2 TransNat2Type
		,@JobRelease OperNumPoReleaseType
		,@Kit ListYesNoType
		,@QtyList##1 CostPrcType
		,@ProcessInd ListYesNoType
		,@ItemReservable ListYesNoType
		,@QtyList##2 CostPrcType
		,@DelTerm DelTermType
		,@ItemSerialTracked ListYesNoType
		,@QtyList##3 CostPrcType
		,@InvFreq InvFreqType
		,@QtyList##4 CostPrcType
		,@QtyList##5 CostPrcType
		,@PriceList##1 CostPrcType
		,@PriceList##2 CostPrcType
		,@PriceList##3 CostPrcType
		,@PriceList##4 CostPrcType
		,@PriceList##5 CostPrcType
		,@iFromRefType RefTypeIJOType
		,@iFromRefNum JobPoProjReqTrnNumType
		,@PriceListType NVARCHAR(2800)
		,@ConvertPrice ListYesNoType
		,@Consolidate ListYesNoType
		,@NeedToConvertPrice ListYesNoType
		,@Summarize ListYesNoType
		,@LineDisc CostPrcType
		,@CustItemUM UMType
		--,@PromiseDate DateType
		,@FromJob JobType
		,@FromSuffix SuffixType
		,@BadDate DateType
		--,@FRE_Item ItemType
		--,@JAX_Item ItemType
		--,@VAN_Item ItemType
		,@BEL_Item ItemType
		,@ToPoNum PoNumType
		,@ToPoLine PoLineType
		,@ToPoRelease PoReleaseType
		--, @FRE_Site SiteType
		--, @JAX_Site SiteType
		--, @VAN_Site SiteType
		, @BEL_Site SiteType
		, @JrgSequence INT
		, @WorkCenter WcType
		, @OperNum OperNumType
		, @LaborHours SchedHoursType
		, @RGID ApsResgroupType
		, @LaborTicks TicksType
		,@EstimateItem ItemType


	set @DueDate = isnull(@ReqDate,GETDATE()) --djh 2017-12-20
 
	SET @Severity = 0
	SET @Debug = 1
	SET @CoLine = NULL

	SET @EngLeadDays = ISNULL(@EngLeadDays, 0)
	SET @ProdLeadDays = ISNULL(@ProdLeadDays, 0)

	IF @Debug = 1
		PRINT 'Inside _IEM_CreateCoitemSp in the ' + DB_NAME() + ' database.'

	IF @Site IS NULL
	BEGIN
		SELECT TOP 1 @Site = site
		FROM site
		WHERE app_db_name = DB_NAME()
	END

	EXEC dbo.SetSiteSp @Site, @Infobar OUTPUT

/*
	SELECT TOP 1 @FRE_Site = site
	FROM site
	WHERE site like '%FRE%'
		AND type = 'S'

	SELECT TOP 1 @JAX_Site = site
	FROM site
	WHERE site like '%JAX%'
		AND type = 'S'

	SELECT TOP 1 @VAN_Site = site
	FROM site
	WHERE site like '%VAN%'
		AND type = 'S'
*/

	SELECT TOP 1 @BEL_Site = site
	FROM site
	WHERE site like '%BEL%'
		AND type = 'S'

	SET @ItemUM = 'EA'
	SET @TaxCode1 = NULL
	SET @TaxCode2 = NULL

	SELECT @Whse = def_whse 
	FROM invparms

	SELECT @CoLine = ISNULL(MAX(co_line),0) + 1
	FROM coitem (READUNCOMMITTED)
	WHERE co_num = @CoNum

	IF @Debug = 1
		PRINT 'Calling _IEM_CreateItemAndCurrentJobSp'

	if @partType = 'MANUFACTURED' and @CustNum = 'RND1000' begin --djh 2017-06-30 force all r&d items to one product code
		set @ItemTemplate = 'R&D-COLI'
		set @SubTemplate = 'R&D-SUB'
	end

	-- Create item
	--IF @PMTCode = 'M'
		EXEC @Severity = _IEM_CreateItemAndCurrentJobSp
			@Item = @Item OUTPUT
			,@Description = @Description
			,@CoNum = @CoNum
			,@CoLine = @CoLine
			,@WC = @WC
			,@BomID = @ID
			,@PMTCode = @PMTCode
			,@partType = @partType
			,@ItemTemplate = @ItemTemplate
			,@Infobar = @Infobar OUTPUT
			,@BEL_Item = @BEL_Item OUTPUT
			,@SubTemplate = @SubTemplate
			,@ProdLeadTime = @ProdLeadDays
	--ELSE
	--	SET @Item = @ItemTemplate

	IF @Debug = 1
		PRINT 'Back from _IEM_CreateItemAndCurrentJobSp'

	IF @Severity <> 0
		RETURN @Severity

/*
	declare @site3 nvarchar(3)=right(@site,3)
	declare @siteItem ItemType
	if @site3 in ('BEL') and @KitItem is not null begin
		set @siteItem = @BEL_Item
		EXEC @Severity = _IEM_AddItemToBomSp
			@Item = @siteItem,
			@AddItem = @KitItem,
			@Oper = 400,
			@Qty = 1,
			@Infobar = @Infobar
*/

/*		
		EXEC [dbo].[_IEM_SyncBOMSp]
			 @siteItem
			,@InfoBar OUTPUT
			,@Site


	end
*/

	IF @Debug = 1
		PRINT 'Calling CoitemValidateItemSp'

	EXEC @Severity = 
		CoitemValidateItemSp
				1 --new record
			,@CoNum
			,'R'
			,@OrderDate
			,@Item
			,NULL --@OldItem
			,@CustNum
			,@CustSeq
			,@QtyOrderedConv
			,@PriceCode
			,@CurrencyCode
			,@iShipSite           OUTPUT
			,@ItemItem           OUTPUT
			,@ItemUM             OUTPUT
			,@ItemDesc           OUTPUT
			,@CustItem           OUTPUT
			,@Price              OUTPUT
			,@FeatStr            OUTPUT
			,@ItemPlanFlag       OUTPUT
			,@ItemFeatTempl      OUTPUT
			,@ItemCommCode       OUTPUT
			,@ItemUnitWeight     OUTPUT
			,@ItemOrigin         OUTPUT
			,@BadDate            OUTPUT
			,@RefType            OUTPUT 
			,@RefNum             OUTPUT           
			,@RefLineSuf         OUTPUT         
			,@RefRelease         OUTPUT         
			,@TaxCode1           OUTPUT
			,NULL--@TaxCode1Desc       OUTPUT
			,@TaxCode2           OUTPUT
			,NULL--@TaxCode2Desc       OUTPUT
			,@DiscPct            OUTPUT
			,@Infobar            OUTPUT
			,@CoLine        
			,@SupplQtyReq        OUTPUT
			,@SupplQtyConvFactor OUTPUT
			,@Kit                OUTPUT
			,@PrintKitComponents OUTPUT
			,@ItemReservable     OUTPUT
			,@ItemSerialTracked  OUTPUT
			,NULL --NEW FIELD ADDED BY APAR
	
	
	if @description is not null and @description <> '' set @ItemDesc = @Description --djh 2016-7-27, allow custom descriptions for inventory items
	
	IF @Debug = 1
		PRINT 'Back from CoitemValidateItemSp'

	IF @DropShipNumber IS NOT NULL --DJH 2016-5-22 only set tax code on lines if line item shipto. NULL works for using the parent tax rate
		SELECT
			@TaxCode1 = ISNULL(tax_code1, @TaxCode1)
			,@TaxCode2 = ISNULL(tax_code2, @TaxCode2)
		FROM customer
		WHERE cust_num = @CustNum
			AND cust_seq = ISNULL(@DropShipNumber, @CustSeq)
	

	IF @Severity <> 0
		RETURN @Severity

	SELECT @ShipSite = parms.site
	FROM parms
		
	IF @Debug = 1
		PRINT 'Calling ItemUnitWeightSp'

	EXEC @Severity = ItemUnitWeightSp
						@Item
					, @ItemUnitWeight  OUTPUT
					, @Infobar         OUTPUT

	EXEC @Severity = GetEcvtSp
						@CustNum
					, @CustSeq
					, @ShipCode
					, @EcCode     OUTPUT
					, @Transport  OUTPUT
					, @SupplQtyReq OUTPUT
					, @SupplQtyConvFactor OUTPUT

	IF @Debug = 1
		PRINT 'Back from ItemUnitWeightSp'

	IF @Severity <> 0 
		RETURN @Severity
		   
	SELECT 
			@OrigPriceConv = @PriceConv
		,@Site = @ShipSite
		,@ItemWhse = @Whse
		,@ShipTo = @CustSeq
			
	IF @Debug = 1
	BEGIN
		PRINT 'Calling PriceCalSp'
		PRINT 'Whse = ' + ISNULL(@ItemWhse, 'NULL')
	END

	EXECUTE @Severity = PriceCalSp
		@PShowMatrix
		,@Item
		,@CustNum
		,@CustItem
		,@EffDate
		,@ExpDate
		,@QtyOrderedConv
		,@OrderPriceCode
		,@CurrCode
		,@ConfigString
		,@Rate
		,@UnitPrice OUTPUT
		,@QtyList##1 OUTPUT
		,@QtyList##2 OUTPUT
		,@QtyList##3 OUTPUT
		,@QtyList##4 OUTPUT
		,@QtyList##5 OUTPUT
		,@PriceList##1 OUTPUT
		,@PriceList##2 OUTPUT
		,@PriceList##3 OUTPUT
		,@PriceList##4 OUTPUT
		,@PriceList##5 OUTPUT
		,@PriceListType OUTPUT
		,@Infobar OUTPUT
		,@Site
		,@CoNum
		,@CoLine
		,@ConvertPrice
		,@NeedToConvertPrice OUTPUT
		,@ItemUM
		,@ItemWhse
		,@ShipTo
		,@LineDisc OUTPUT
		,@CustItemUM OUTPUT
			
	IF @Debug = 1
		PRINT 'Back from PriceCalSp'

	IF @Severity <> 0 
		RETURN @Severity

	SET @CoitemRowPointer = NEWID()
	SET @PrintKitComponents = 0
	
	IF @Debug = 1
		PRINT 'Creating coitem record.'

	DECLARE @GlAcct AcctType

	SELECT @GLAcct = pc.inv_adj_acct
	FROM item i
	INNER JOIN prodcode pc ON i.product_code = pc.product_code
	WHERE item = @Item

	IF @GlAcct IS NULL
		SELECT @GlAcct = pc.inv_adj_acct
		FROM non_inventory_item ni
		INNER JOIN prodcode pc ON ni.product_code = pc.product_code
		WHERE item = @Item

/*
	if not exists (select * from site where site=@AssignSite)
		set @AssignSite=NULL
*/

	BEGIN TRANSACTION
	INSERT INTO coitem(
		 co_num 
		, co_line
		, co_release
		, rowpointer
		, item
		, description
		, qty_ordered_conv
		, u_m
		, cust_item
		, disc
		, price_conv
		, ref_type
		, ref_num
		, ref_line_suf
		, ref_release
		, due_date
		, tax_code1
		, tax_code2
		, pricecode
		, ship_site
		, feat_str
		, comm_code
		, unit_weight
		, origin
		, suppl_qty_conv_factor 
		, print_kit_components
		, stat
		, whse
		, trans_nat
		, trans_nat_2
		, process_ind
		, delterm
		, co_orig_site
		, inv_freq
		, co_cust_num
		, cust_num
		, cust_seq
		, fs_inc_num
		, consolidate
		, summarize
		, transport
		, ec_code
		, export_value
		, promise_date
		--, Uf_EngLeadTime
		--, Uf_ProdLeadTime
		, non_inv_acct
		--, Uf_PromiseDate
		--, Uf_assign_site
		--, Uf_ShipDirect
		--,Uf_eCodeAttr
		--,Uf_numSections
		--,Uf_numPanelInteriors
		--,Uf_numCdpInteriors
		)
	VALUES(
			@CoNum
		, @CoLine
		, 0
		, @CoitemRowPointer
		, @Item
		, @ItemDesc
		, @QtyOrderedConv
		, @ItemUM
		, @CustItem
		, 0--@DiscountPercent
		, @OriginalPriceConv --@UnitPrice
		, @RefType
		, @RefNum
		, @RefLineSuf
		, @RefRelease
--		, ISNULL(@DueDate, '2/22/2222') --ISNULL(@ReqDate,@DueDate)
		, @DueDate
		, @TaxCode1
		, @TaxCode2
		, @PriceCode
		, @ShipSite
		, @FeatStr
		, @ItemCommCode
		, @ItemUnitWeight
		, @ItemOrigin
		, @SupplQtyConvFactor
		, @PrintKitComponents
		, 'O'
		, @Whse
		, @TransNat
		, @TransNat2
		, @ProcessInd
		, @DelTerm
		, @Site
		, @InvFreq
		, @CustNum
		, CASE WHEN @DropShipNumber IS NULL THEN NULL ELSE @CustNum END
		, @DropShipNumber
		, CASE @iFromRefType WHEN 'N' THEN @iFromRefNum WHEN 'E' THEN @iFromRefNum ELSE NULL END
		, 0--@Consolidate
		, 0--@Summarize
		, @Transport
		, @EcCode
		, 0
		, @ReqDate
		--, @EngLeadDays
		--, @ProdLeadDays
		, CASE WHEN @PMTCode = 'I' THEN @GlAcct ELSE NULL END
		--, @PromiseDate
		--, isnull(@AssignSite,@Site)
		--, @ShipDirect
		--,@Uf_eCodeAttr
		--,@Uf_numSections
		--,@Uf_numPanelInteriors
		--,@Uf_numCdpInteriors
	)
	COMMIT TRANSACTION

	IF @Debug = 1
		PRINT 'Coitem record created.'

	UPDATE coitem
	SET stat = 'O'
	WHERE co_num = @CoNum
		AND co_line = @CoLine
		AND stat <> 'O'

	--UPDATE coitem
	--SET Uf_PromiseDate = @PromiseDate
	--WHERE co_num = @CoNum
	--	AND co_line = @CoLine
				 
	IF @PMTCode = 'M' AND @ITEM LIKE 'COLI%'
	BEGIN
		SET @ToJob = @CoNum
		--SET @ToJob = dbo.ExpandKyByType('JobType',@ToJob)

		SET @ToSuffix = @CoLine


-- Get next MBEL job, set @ToJob, @ToSuffix

DECLARE	  @PKey     LongList

		IF @Debug = 1
			PRINT 'Creating XREF to ' + @ToJob
	
		BEGIN TRANSACTION
		EXECUTE @Severity = [dbo].[CoitemXrefSp] 
			 @CoNum = @CoNum
			,@CoLine = @CoLine
			,@CoRelease = 0
			,@RefType = 'J'
			,@RefNum = @ToJob--NULL
			,@RefLineSuf = @ToSuffix --NULL
			,@RefRelease = 0
			,@Item = @Item
			,@ItemDescription = @ItemDesc
			,@UM = 'EA'
			,@CoStat = 'O'
			,@QtyOrdered = @QtyOrderedConv
			,@DueDate = @DueDate
			,@Whse = @Whse
			,@FromWhse = @Whse
			,@FromSite = @Site
			,@ToSite = @Site
			,@PoChangeOrd = NULL
			,@MpwxrefDelete = 0
			,@CreateProj = 0
			,@CreateProjtask = 0
			,@CurRefNum = @ToJob OUTPUT
			,@CurRefLineSuf = @ToSuffix OUTPUT
			,@CurRefRelease = @ToRelease OUTPUT
			,@TrnLoc = NULL
			,@FOBSite = NULL
			,@ItemLocQuestionAsked = NULL --OUTPUT
			,@PromptMsg = NULL --OUTPUT
			,@PromptButtons = NULL --OUTPUT
			,@Infobar = @Infobar OUTPUT
			,@ExportType = 'N'
		COMMIT TRANSACTION

		IF @Debug = 1
		BEGIN
			PRINT 'Xref created'
			PRINT 'Releasing job'
		END
		
/*		UPDATE job
		SET stat = 'R'
		WHERE job = @ToJob
			AND suffix = @ToSuffix*/

		UPDATE job_sch
		SET end_date = @DueDate, start_date=GETDATE()
		WHERE job = @ToJob
			AND suffix = @ToSuffix

/*		-- Create estimate job
		DECLARE @EstJob JobType
			,@StartOper OperNumType
			,@EndOper OperNumType

		--SET @EstJob = 'E' + @ToJob

		EXEC NextKeySp
			@TableName = 'job'
			,@ColumnName = 'job'
			,@Prefix = 'E'
			,@KeyLength = 10
			,@Type = NULL
			,@Where = NULL
			,@TableName2 = NULL
			,@Where2 = NULL
			,@KeyStr = @EstJob OUTPUT
			,@Infobar = @Infobar OUTPUT 

		PRINT 'Next available estimate job:  ' + @EstJob + ' - ' + CAST(@ToSuffix AS NVARCHAR(4))
	
		SELECT TOP 1 @StartOper = oper_num
		FROM jobroute_mst jr
		WHERE job = @ToJob
			AND suffix = @ToSuffix
		ORDER BY oper_num
	
		SELECT TOP 1 @EndOper = oper_num
		FROM jobroute_mst jr
		WHERE job = @ToJob
			AND suffix = @ToSuffix
		ORDER BY oper_num DESC

		BEGIN TRANSACTION

		IF @Debug = 1
			PRINT 'Calling CreateJobSp to create estimate job:  ' + @EstJob

		EXEC @Severity = CreateJobSp
			@JobType = 'E'
			,@Job = @EstJob
			,@Suffix = @ToSuffix
			,@Item = @Item
			,@Description = @ItemDesc
			,@Revision = @Revision
			,@QtyReleased = @QtyOrderedConv
			,@Status = 'W'
			,@JobDate = '2/22/2222'--@DueDate
			,@StartDate = '2/22/2222'--@DueDate
			,@Infobar = @Infobar OUTPUT
	
		COMMIT TRANSACTION

		IF @Debug = 1
			PRINT 'Back from CreateJobSp to create estimate job'

		IF @Severity <> 0
			RETURN @Severity

		update job_mst
		set est_job = @EstJob
		, est_suf = @ToSuffix
		WHERE job = @ToJob
			AND suffix = @ToSuffix

		UPDATE job_sch
		SET end_date = '2/22/2222'
		WHERE job = @ToJob
			AND suffix = @ToSuffix

		SELECT @FromJob = job, @FromSuffix = suffix
		FROM item
		WHERE item = @ItemTemplate
	
		SELECT TOP 1 @StartOper = oper_num
		FROM jobroute (NOLOCK)
		WHERE job = @FromJob
		ORDER BY oper_num

		SELECT TOP 1 @EndOper = oper_num
		FROM jobroute (NOLOCK)
		WHERE job = @FromJob
		ORDER BY oper_num DESC

		IF @Debug = 1 
		BEGIN
			PRINT 'Calling CopyBomDoProcessSp'
			PRINT '     From item ' + ISNULL(@ItemTemplate,'NULL')
			PRINT '     To job ' + ISNULL(@EstJob,'NULL')
		END

		EXEC @Severity = CopyBomDoProcessSp
			@FromJobCategory = 'C'
			,@FromJob = @FromJob
			,@FromSuffix = @FromSuffix
			,@FromItem = @ItemTemplate
			,@StartOper = @StartOper
			,@EndOper = @StartOper--@EndOper
			,@LMBVar = 'B'
			,@Revision = NULL
			,@ScrapFactor = 0
			,@CopyBom = 1
			,@ToJobCategory = 'E'
			,@ToItem = @Item
			,@ToJob = @EstJob
			,@ToSuffix = @ToSuffix
			,@EffectDate = NULL
			,@OptionType = 'D'
			,@AfterOper = NULL
			,@CopyToPSReleaseBom = NULL
			,@Infobar = @Infobar OUTPUT
			,@CopyUetValues = 1

		IF @Debug = 1
			PRINT 'Back from CopyBomDoProcessSp'

		DELETE
		FROM jobmatl
		WHERE job = @EstJob
			AND suffix = @ToSuffix
			AND LEFT(item,3) IN('FRE','JAX','VAN')

		-- TODO:  Add job materials from eQuote to estimate job
		DECLARE @erpLineItemMat TABLE(
			item NVARCHAR(30)
			,qty DECIMAL(19,8)
		)

		DECLARE @erpLineItemLabor TABLE(
			workCenter		WCType
			,laborHours		QtyUnitType
		)

		DECLARE @SQL NVARCHAR(MAX)
			,@JobmatlRowPointer RowPointerType
			,@UM UmType
			,@JobmatlSequence INT
			,@TNextSequence INT
			,@JobmatlCost CostPrcType
			,@Qty QtyUnitType

		SET @JobmatlSequence = 0
		SET @TNextSequence = 0

		SELECT TOP 1
			@JobmatlRowPointer = jobmatl.RowPointer
			, @JobmatlCost       = jobmatl.cost
			, @JobmatlSequence   = jobmatl.sequence
		FROM jobmatl
		WHERE jobmatl.job      = @EstJob
			AND jobmatl.suffix   = @ToSuffix
			AND jobmatl.oper_num = 10
		ORDER BY jobmatl.sequence DESC
		
		SET @SQL = 	
			'SELECT * FROM OPENQUERY(EQUOTE, ''SELECT partNumber, qtyDollars FROM erpLineItemMat where erpTopLineItemId = ' + CAST(@erpTopLineItemId AS NVARCHAR(20)) + ''')'

		IF @Debug = 1
		BEGIN
			PRINT 'Preparing to import estimate BOM'
			PRINT ISNULL(@SQL,'@SQL IS NULL')
		END

		INSERT INTO @erpLineItemMat(item, qty)
		EXEC (@SQL)

		-- select * from @erpLineItemMat

		IF @JobmatlRowPointer IS NULL
			SET @TNextSequence = 1
		ELSE
			SET @TNextSequence = @JobmatlSequence + 1

		DECLARE crsErpLimeItemMat CURSOR FORWARD_ONLY FOR
		SELECT item, qty
		FROM @erpLineItemMat

		OPEN crsErpLimeItemMat
		WHILE @Severity = 0
		BEGIN
			FETCH NEXT FROM crsErpLimeItemMat INTO @EstimateItem, @Qty

			IF @@FETCH_STATUS <> 0
				BREAK;

			SELECT @UM = u_m
			FROM item
			WHERE item = @EstimateItem

			SET @UM = ISNULL(@UM,'EA')

			INSERT INTO jobmatl
			(
				job
				, suffix
				, oper_num
				, sequence
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
				@EstJob
				, @ToSuffix
				, 10
				, @TNextSequence
				, 'M'
				, @EstimateItem
				, @UM
				, @Qty --1
				, @Qty --1
				, 'U'
				, 1 --@ItemUnitCost
				, 1 --@ItemMatlCost
				, 0
				, 0
				, 0
				, 0
				, 0 --@JobmatlCost
				, CASE WHEN RIGHT(@Site,3) = 'BEL' THEN 'J' ELSE 'T' END
				, 0
				, NULL
				, @TNextSequence
				, 0
			)

			SET @TNextSequence = @TNextSequence + 1
		END

		CLOSE crsErpLimeItemMat
		DEALLOCATE crsErpLimeItemMat

		SET @SQL = 	
			'SELECT * FROM OPENQUERY(EQUOTE, ''SELECT workcenter, hours FROM erpLineItemLabor where erpTopLineItemId = ' + CAST(@erpTopLineItemId AS NVARCHAR(20)) + ''')'

		INSERT INTO @erpLineItemLabor(workCenter, laborHours)
		EXEC(@SQL)

		DECLARE crsErpLineItemLabor CURSOR FORWARD_ONLY FOR
		SELECT workCenter, laborHours
		FROM @erpLineItemLabor

		OPEN crsErpLineItemLabor
		WHILE @Severity = 0
		BEGIN

			FETCH NEXT FROM crsErpLineItemLabor INTO
				@WorkCenter, @LaborHours

			IF @@FETCH_STATUS <> 0
				BREAK;

			SET @OperNum = NULL
			SET @workCenter = ISNULL(@WorkCenter,'ISUMAT')

			-- TODO:  Add labor to estimate job
			SELECT @OperNum = oper_num
			FROM jobroute
			WHERE job = @EstJob
				AND suffix = @ToSuffix
				AND wc = @WorkCenter
			
			IF @OperNum IS NULL
			BEGIN
				-- Add operation
				SELECT TOP 1 @OperNum = oper_num
				FROM jobroute
				WHERE job = @EstJob
					AND suffix = @ToSuffix
				ORDER BY oper_num DESC

				SET @OperNum = ISNULL(@OperNum,0) + 1
				PRINT 'Work Center'
				PRINT @WorkCenter

				insert into Jobroute (
					RowPointer, job, suffix, oper_num
					, wc, run_basis_lbr, run_basis_mch
					, bflush_type, cntrl_point, setup_rate, efficiency
					, fovhd_rate_mch, vovhd_rate_mch, run_rate_lbr
					, varovhd_rate, fixovhd_rate
					, effect_date, obs_date
					, NoteExistsFlag
					, Yield
					, MO_Shared
					)
					values (Newid(), @EstJob, @ToSuffix, @OperNum
					, @WorkCenter, 'H','H'
					, 'N', 1, 0, 100
					, 0, 0, 0
					, 0, 0
					, NULL, NULL
					, 0
					, 100
					, 0
					)

				SET @LaborTicks = @LaborHours * 100

				IF NOT EXISTS(SELECT * FROM jrt_sch WHERE job = @EstJob AND suffix = @ToSuffix AND oper_num = @OperNum)
				BEGIN
					
					insert into jrt_sch(
						job, suffix, oper_num							-- 1
					   , setup_ticks, setup_hrs, run_ticks_lbr			-- 2
					   , run_lbr_hrs, run_ticks_mch, run_mch_hrs		-- 3
					   , pcs_per_lbr_hr, pcs_per_mch_hr, sched_ticks	-- 4
					   , sched_hrs, sched_off, offset_hrs				-- 5
					   , move_ticks, move_hrs, queue_ticks				-- 6
					   , queue_hrs, start_date, end_date				-- 7
					   , start_tick, end_tick, finish_hrs				-- 8
					   , matrixtype, tabid, whenrule					-- 9
					   , sched_drv, plannerstep, setuprgid				-- 10
					   , setuprule, schedsteprule, crsbrkrule			-- 11
					   , allow_reallocation, splitsize, batch_definition_id	-- 12
					   , splitrule, splitgroup, RowPointer				-- 13
						)
					values(
					@EstJob, @ToSuffix, @OperNum						-- 1
					, 0, 0, @LaborTicks									-- 2
					, @LaborHours, 0, 0									-- 3
					, 0, 0, 0											-- 4
					, 0, NULL, 0										-- 5
					, 0, 0, 0											-- 6
					, 0, '2/22/2222', '2/22/2222'							-- 7
					, NULL, NULL, 0										-- 8
					, 'P', NULL, 0										-- 9
					, 'L', 0, NULL										-- 10
					, 5, 1, 0											-- 11
					, 0, 0, NULL										-- 12
					, 0, NULL, newid()
					)
				END
				ELSE
					UPDATE jrt_sch
					SET run_ticks_lbr = @LaborTicks, run_lbr_hrs = @LaborHours
					WHERE job = @EstJob AND suffix = @ToSuffix AND oper_num = @OperNum

				-- create JrtResourceGroup
				SET @RGID = NULL
				
				SELECT TOP 1 @RGID = rgid
				FROM wcresourcegroup_mst
				WHERE wc = @WorkCenter

				SET @JrgSequence = NULL

				SELECT TOP 1 @JrgSequence = sequence
				FROM jrtresourcegroup
				WHERE job = @EstJob
					AND suffix = @ToSuffix
				ORDER BY sequence DESC

				SET @JrgSequence = ISNULL(@JrgSequence,1) --+ 1

				IF NOT EXISTS(SELECT * FROM jrtresourcegroup WHERE job = @EstJob AND Suffix = @ToSuffix AND oper_num = @OperNum)
				BEGIN
					PRINT 'jrtresourcegroup sequence'
					PRINT @JrgSequence

					INSERT INTO jrtresourcegroup (
						RowPointer
					, job
					, suffix
					, oper_num
					, rgid
					, qty_resources
					, NoteExistsFlag
					, resactn
					, sequence
					)
					SELECT TOP 1
						NewID()
					, @EstJob
					, @ToSuffix
					, @OperNum
					, jrg.rgid
					, jrg.qty_resources
					, 0
					, 'S'
					, @JrgSequence
					from wcresourcegroup jrg
					WHERE wc = @WorkCenter
				END

			END
			ELSE
			BEGIN 

				UPDATE jrt_sch
				SET run_lbr_hrs = run_lbr_hrs + @laborHours
				WHERE job = @EstJob
					ANd suffix = @ToSuffix
					AND oper_num = @OperNum

			END


		END

		CLOSE crsErpLineItemLabor
		DEALLOCATE crsErpLineItemLabor


		IF @Debug = 1
			PRINT 'Job status set to Released'
*/
/*
		SET @Job = LTRIM(RTRIM(@CoNum)) + 'FRE'
		SET @Job = dbo.ExpandKyByType('JobType',@Job)

		SELECT @SQL = app_db_name + '.dbo._IEM_EquoteCreateSiteSpecificJobSp'
		FROM site
		WHERE site = @FRE_Site

		--EXEC @Severity = FRE30_App.dbo._IEM_EquoteCreateSiteSpecificJobSp
		EXEC @SEVERITY = @SQL
			 @OrderSite = @Site
			,@Job = @Job
			,@Suffix = @CoLine
			,@Item = @FRE_Item
			,@ItemTemplate = @SubTemplate--@ItemTemplate
			,@JobQty = @QtyOrderedConv
			,@Infobar = @Infobar OUTPUT


		SET @Job = LTRIM(RTRIM(@CoNum)) + 'JAX'
		SET @Job = dbo.ExpandKyByType('JobType',@Job)

		SELECT @SQL = app_db_name + '.dbo._IEM_EquoteCreateSiteSpecificJobSp'
		FROM site
		WHERE site = @JAX_Site

		--EXEC @Severity = JAX30_App.dbo._IEM_EquoteCreateSiteSpecificJobSp
		EXEC @Severity = @SQL
			 @OrderSite = @Site
			,@Job = @Job
			,@Suffix = @CoLine
			,@Item = @JAX_Item
			,@ItemTemplate = @SubTemplate--@ItemTemplate
			,@JobQty = @QtyOrderedConv
			,@Infobar = @Infobar OUTPUT


		SET @Job = LTRIM(RTRIM(@CoNum)) + 'VAN'
		SET @Job = dbo.ExpandKyByType('JobType',@Job)

		SELECT @SQL = app_db_name + '.dbo._IEM_EquoteCreateSiteSpecificJobSp'
		FROM site
		WHERE site = @VAN_Site

		--EXEC @Severity = VAN30_App.dbo._IEM_EquoteCreateSiteSpecificJobSp
		EXEC @Severity = @SQL
			 @OrderSite = @Site
			,@Job = @Job
			,@Suffix = @CoLine
			,@Item = @VAN_Item
			,@ItemTemplate = @SubTemplate--@ItemTemplate
			,@JobQty = @QtyOrderedConv
			,@Infobar = @Infobar OUTPUT
*/


	END
	ELSE
	IF @ShipDirect = 1 --and isnull(@assignSite, @site) = @site --djh 2017-07-18.  disable ship direct planned po creation for assign site
	BEGIN
		PRINT 'Ship direct entered'
		
		PRINT '1'

		IF NOT EXISTS(SELECT * FROM vendor WHERE vend_num = @Vendor)
		BEGIN
			PRINT @Vendor
			PRINT 'Vendor not found.'
			SET @Infobar = 'Invalid vendor ' + ISNULL(@Vendor,'NULL') + ' specified for ship direct item ' + @item + '.'
			SET @Severity = 16
			RETURN @Severity
		END

		PRINT '2'

		set @ToPoNum = NULL

		SELECT TOP 1 @ToPoNum = pi.po_num--, @ToPoLine = pi.po_line
		FROM poitem pi
		INNER JOIN po ON po.po_num = pi.po_num
		WHERE po.vend_num = @Vendor
			AND pi.ref_type = 'O'
			AND pi.ref_num = @CoNum
			--AND pi.ref_line_suf = @CoLine
			AND po.drop_ship_no = @CustNum
			AND po.drop_seq = ISNULL(@DropShipNumber,@CustSeq)
			AND po.stat = 'P' --only add if PO not already placed
			AND po.vend_num <> 'V009999' -- djh 2017-02-07.  do not group unknown vendor POs together


		PRINT 'Updating coitem ref_type to P'
		UPDATE coitem
		SET ref_type = 'P'
		WHERE co_num = @CoNum
			AND co_line = @CoLine
			--AND ref_type <> 'P'

		PRINT 'Creating PO xref'

		DECLARE @poDate DateType
		set @poDate=@DueDate

		BEGIN TRANSACTION
		EXECUTE @Severity = [dbo].[CoitemXrefSp] 
				@CoNum = @CoNum
			,@CoLine = @CoLine
			,@CoRelease = 0
			,@RefType = 'P'
			,@RefNum = @ToPoNum
			,@RefLineSuf = @ToPoLine
			,@RefRelease = 0
			,@Item = @Item
			,@ItemDescription = @ItemDesc
			,@UM = 'EA'
			,@CoStat = 'O'
			,@QtyOrdered = @QtyOrderedConv
			,@DueDate = @poDate
			,@Whse = @Whse
			,@FromWhse = @Whse
			,@FromSite = @Site
			,@ToSite = @Site
			,@PoChangeOrd = NULL
			,@MpwxrefDelete = 0
			,@CreateProj = 0
			,@CreateProjtask = 0
			,@CurRefNum = @ToPoNum OUTPUT
			,@CurRefLineSuf = @ToPoLine OUTPUT
			,@CurRefRelease = @ToPoRelease OUTPUT
			,@TrnLoc = NULL
			,@FOBSite = NULL
			,@ItemLocQuestionAsked = NULL --OUTPUT
			,@PromptMsg = NULL --OUTPUT
			,@PromptButtons = NULL --OUTPUT
			,@Infobar = @Infobar OUTPUT
			,@ExportType = 'N'
		COMMIT TRANSACTION

		PRINT @Infobar
		PRINT 'PO Created:  ' + @ToPoNum

		UPDATE po
		SET vend_num = @Vendor
			,drop_ship_no = @CustNum
			,drop_seq = ISNULL(@DropShipNumber,@CustSeq)
			,ship_addr = 'C'
		WHERE po_num = @ToPoNum

		UPDATE poitem
		SET item_cost = @VendorPrice, item_cost_conv = @VendorPrice, unit_mat_cost = @VendorPrice, unit_mat_cost_conv = @VendorPrice
		WHERE po_num = @ToPoNum
			AND po_line = @ToPoLine

	END
	

	RETURN @Severity
END






GO

