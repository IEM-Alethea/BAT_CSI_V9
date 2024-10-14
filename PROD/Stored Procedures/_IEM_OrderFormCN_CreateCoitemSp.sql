SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/**********************************************************************************
*                            Modification Log
*                                            
* Ref#  Init   Date     Description           
* ----- ----   -------- -----------------------------------------------------------
* 0001  DBH    20240130 Creates inventory items in PASS that already exist in FRE
* 0002  DMS	   20240423 Add Uf_Released to the items, set to 1. OTD Project 
* 0003  DMS    20240510 Replace @ReqDate with @PromiseDate. OTD Project
**********************************************************************************/

ALTER PROCEDURE [dbo].[_IEM_OrderFormCN_CreateCoitemSp] (
	 @Item ItemType OUTPUT
	,@Description		DescriptionType
	,@Designation		nvarchar(30)
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
	,@CoLine			CoLineType
	,@Infobar			InfobarType OUTPUT
	,@Revision			RevisionType
	,@ShipDirect		ListYesNoType
	,@EngLeadDays		INT
	,@ProdLeadDays		INT
	,@PromiseDate		DateType
	,@DueDate			DateType
	,@ErpTopLineItemId	INT
	,@SubTemplate		ItemType
	,@ReqDate			DateType
	,@CustomerRequiredShipDate DateType
	,@Vendor			VendNumType
	,@VendorPrice		CostPrcType
	,@DropShipNumber	INT
	,@AssignSite		SiteType
	,@AssignWH			WhseType
	,@Uf_eCodeAttr		nvarchar(100)
	,@Uf_numSections	int
	,@Uf_numPanelInteriors int
	,@Uf_numCdpInteriors int
	,@kitItem			ItemType
	,@Uf_CustomerItem   ItemType
	,@Uf_matlCostBasis	AmountType
	,@Uf_CustomerPOLine int
	,@Uf_Released		int = 0 --0002 DMS
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
		,@JobType JobTypeType				-- 0001
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
		,@ToPoNum PoNumType
		,@ToPoLine PoLineType
		,@ToPoRelease PoReleaseType
		, @FRE_Site SiteType
		, @JAX_Site SiteType
		, @VAN_Site SiteType
		, @JrgSequence INT
		, @WorkCenter WcType
		, @OperNum OperNumType
		, @LaborHours SchedHoursType
		, @RGID ApsResgroupType
		, @LaborTicks TicksType
		,@EstimateItem ItemType
		, @ContextInfo VARBINARY(128)

	declare @curdate date=GETDATE() --no time

	SET @Severity = 0
	SET @Debug = 1

	IF @Site IS NULL
	BEGIN
		SELECT TOP 1 @Site = site
		FROM site
		WHERE app_db_name = DB_NAME()
	END

	EXEC dbo.SetSiteSp @Site, @Infobar OUTPUT

	set @Description = replace(@Description, char(13)+char(10), ' ')
	set @Description = replace(@Description, char(13), ' ')
	set @Description = replace(@Description, char(10), ' ')

	SELECT TOP 1 @FRE_Site = site FROM site	WHERE site like '%FRE%'	AND type = 'S'
	SELECT TOP 1 @JAX_Site = site FROM site WHERE site like '%JAX%'	AND type = 'S'
	SELECT TOP 1 @VAN_Site = site FROM site	WHERE site like '%VAN%'	AND type = 'S'

	SET @ItemUM = 'EA'
	SET @TaxCode1 = NULL
	SET @TaxCode2 = NULL

	SELECT @Whse = def_whse FROM invparms

	if @AssignWH is not null and @AssignSite=@site begin
		set @whse=@AssignWH
	end

	-- 0001 added for PASS orders where items not yet in inventory
	IF @partType = 'INVENTORY' AND NOT EXISTS (SELECT 1 FROM item_mst WHERE item = @SubTemplate) AND EXISTS (SELECT 1 FROM item_all WHERE item = @SubTemplate)
		BEGIN
			PRINT '0001'
			EXEC @Severity = _IEM_OrderFormCN_CreateItemSp
				  @Item = @SubTemplate
				, @Description = NULL
				, @Revision = NULL
				, @UM = NULL
				, @ProductCode = NULL
				, @Job = @Job OUTPUT
				, @Suffix = @JobSuffix OUTPUT
				, @JobType = @JobType OUTPUT
				, @Infobar = @Infobar OUTPUT
				, @Site	= @Site
				, @SiteSpecificItem = NULL
				, @TemplateItem = NULL
				, @pass_req = NULL
				, @LeadTime = NULL
		
			IF @Severity <> 0 RETURN @Severity
		END

	if @partType = 'MANUFACTURED' and @CustNum = 'RND1000' begin --djh 2023-05-08 force all r&d items to one product code (after disabling in 2021)
		set @ItemTemplate = 'R&D-SOLI'
		set @SubTemplate = 'R&D-SUB'
	end

	if @partType = 'INVENTORY' and exists (select 1 from item_mst where item=@subTemplate) begin
		select @ItemUM = u_m from item_mst where item=@subTemplate
	end

	EXEC @Severity = _IEM_OrderFormCN_CreateItemAndCurrentJobSp
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
		,@SubTemplate = @SubTemplate
		,@ProdLeadTime = @ProdLeadDays

	IF @Severity <> 0 RETURN @Severity

	declare @kitsite sitetype = isnull(@AssignSite,@Site)
	declare @site3 nvarchar(3)=right(@kitsite,3)
	declare @siteItem ItemType
	if @site3 in ('FRE','VAN','JAX') and @KitItem is not null and @PMTCode='M' begin
			declare @asql nvarchar(max), @bsql nvarchar(max)
			SELECT @asql = app_db_name + '.dbo._IEM_AddItemToBomSp'
					, @bsql = app_db_name + '.dbo._IEM_SyncBOMSp'
			FROM site
			WHERE site = @kitsite

			set @siteItem = replace(@item, 'SOLI', @site3)

			if @asql is not null begin
				SET @ContextInfo = CONTEXT_INFO()
				EXEC dbo.SetSiteSp @kitsite, ''

				EXEC @Severity =  @asql -- _IEM_AddItemToBomSp
					@Item = @siteItem,
					@AddItem = @KitItem,
					@Oper = 400,
					@Qty = 1,
					@Infobar = @Infobar

				if @severity <> 0 begin
					return @severity
				end

				EXEC @bsql -- _IEM_SyncBOMSp
					 @siteItem
					,@InfoBar OUTPUT
					,@kitsite
					,1 -- no tran created

				SET CONTEXT_INFO @ContextInfo

			end
		
	end

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
	
	IF @DropShipNumber IS NOT NULL begin --DJH 2016-5-22 only set tax code on lines if line item shipto. NULL works for using the parent tax rate
		SELECT @TaxCode1 = ISNULL(tax_code1, @TaxCode1), @TaxCode2 = ISNULL(tax_code2, @TaxCode2)
		FROM customer
		WHERE cust_num = @CustNum AND cust_seq = ISNULL(@DropShipNumber, @CustSeq)
	end

	IF @Severity <> 0 RETURN @Severity

	SELECT @ShipSite = parms.site FROM parms

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

	IF @Severity <> 0 RETURN @Severity
		   
	SELECT 
		@OrigPriceConv = @PriceConv
		,@Site = @ShipSite
		,@ItemWhse = @Whse
		,@ShipTo = @CustSeq

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
			
	IF @Severity <> 0 RETURN @Severity

	SET @CoitemRowPointer = NEWID()
	SET @PrintKitComponents = 0

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

	if not exists (select * from site where site=@AssignSite) begin
		set @AssignSite=NULL
	end
	-- in case of transfer, do this before we insert so it doesn't cause problems in the trigger
	if @assignsite is not null and @AssignWH is not null AND (@partType = 'INVENTORY' or @AssignSite=@ShipSite) begin
			declare @csql nvarchar(max), @createsev int = 0, @createinfo infobartype
			SELECT @csql = app_db_name + '.dbo._IEM_CreateItemWhseAndLocSP'
			FROM site
			WHERE site = @AssignSite

			if @csql is not null begin
				SET @ContextInfo = CONTEXT_INFO()
				EXEC dbo.SetSiteSp @AssignSite, ''

				exec @createsev = @csql -- _IEM_CreateItemWhseAndLocSP
					@Item = @Item,
					@Whse = @AssignWH,
					@Loc = 'STOCK',
					@Infobar = @createinfo output

				SET CONTEXT_INFO @ContextInfo

				if @createsev <> 0 begin
					set @severity = @createsev
					set @infobar = 'Could not create whse or loc: ' + isnull(@createinfo,'<no error>')+@csql
					return @severity
				end
			end

	end

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
		, promise_date -- AKA request date...Infor!!!!
		, Uf_CustomerRequiredShipDate
		, Uf_EngLeadTime
		, Uf_ProdLeadTime
		, non_inv_acct
		, Uf_PromiseDate -- AKA actual promise date
		, Uf_assign_site
		, Uf_assign_whse
		, Uf_ShipDirect
		,Uf_eCodeAttr
		,Uf_numSections
		,Uf_numPanelInteriors
		,Uf_numCdpInteriors
		,Uf_DrawingApprDate
		,Uf_designation
		,Uf_CustomerItem
		,Uf_matlCostBasis
		,Uf_CustomerPOLine
		,Uf_Released --0002 DMS 
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
		, ISNULL(@DueDate, '2/22/2222') --ISNULL(@ReqDate,@DueDate)
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
		--, @ReqDate -- 0002 DMS
		, @PromiseDate -- 0002 DMS
		, @CustomerRequiredShipDate
		, @EngLeadDays
		, @ProdLeadDays
		, CASE WHEN @PMTCode = 'I' THEN @GlAcct ELSE NULL END
		, @PromiseDate
		, isnull(@AssignSite,@Site)
		, @AssignWH
		, @ShipDirect
		,@Uf_eCodeAttr
		,@Uf_numSections
		,@Uf_numPanelInteriors
		,@Uf_numCdpInteriors
		--,IIF(@ReqDate < '2220-01-01', @curdate, NULL) -- DMS 0003
		,IIF(@PromiseDate < '2220-01-01', @curdate, NULL) -- DMS 0003
		,@Designation
		,@Uf_CustomerItem
		,@Uf_matlCostBasis
		,@Uf_CustomerPOLine
		,@Uf_Released
	)

	UPDATE coitem
	SET stat = 'O'
	WHERE co_num = @CoNum
		AND co_line = @CoLine
		AND stat <> 'O'

	IF @PMTCode = 'M'
	BEGIN
		DECLARE @SQL NVARCHAR(MAX)

		declare 
			@SaveSessionID uniqueidentifier,
			@RemoteSessionID uniqueidentifier,
			@Username usernametype

		SET @ToJob = LTRIM(RTRIM(@CoNum))
		SET @ToJob = dbo.ExpandKyByType('JobType',@ToJob)

		SET @ToSuffix = @CoLine

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

		
		UPDATE job
		SET stat = 'R'
		WHERE job = @ToJob
			AND suffix = @ToSuffix

		UPDATE job_sch
		SET end_date = '2/22/2222'
		WHERE job = @ToJob
			AND suffix = @ToSuffix
	END	ELSE IF @ShipDirect = 1 and isnull(@assignSite, @site) = @site begin
	 --djh 2017-07-18.  disable ship direct planned po creation for assign site
		declare @tInfobar infobartype = ''

		exec @severity = _IEM_OrderFormCN_CreateShipDirectSp
			@Item
			,@Description
			,@CoNum
			,@CoLine
			,@QtyOrderedConv
			,@ItemDesc
			,@ItemUM
			,@Whse
			,@CustNum
			,@CustSeq
			,@Vendor
			,@VendorPrice
			,@DropShipNumber
			,@DueDate
			,@tInfobar OUTPUT

		if @severity != 0 begin
			set @infobar = 'Error creating ship direct: '+isnull(@tInfobar,'')
			return @severity
		end
	END
	
	RETURN @Severity
END
GO

