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
* 0002  DBH  20240522  unix field no longer used
***************************************************************************/
ALTER PROCEDURE [dbo].[_IEM_CustomerOrderCreateSp](
	 @Ref	INT
	,@Price CostPrcType
	,@CoNum CoNumType OUTPUT
	,@CoLine CoLineType OUTPUT
	,@QuoteNum INT OUTPUT
	,@QuoteRev INT OUTPUT
	,@InfoBar 		InfoBarType OUTPUT
	,@PerformWritebacks ListYesNoType = 1
) 
AS
BEGIN

	-- Declare variables
	DECLARE @Severity int
		, @Prefix GenericKeyType
		, @CustNum CustNumType
		, @BillToSeq INT
		, @ShipToSeq INT
		, @TaxMode1         TaxModeType
		, @TaxMode2         TaxModeType
		, @ExchRate         ExchRateType     
		, @TaxCode1Type     LongListType
		, @TaxCode1         TaxCodeType    
		, @TaxCode2Type     LongListType
		, @TaxCode2         TaxCodeType    
		, @FrtTaxCode1Type  LongListType
		, @FrtTaxCode1      TaxCodeType    
		, @FrtTaxCode2Type  LongListType
		, @FrtTaxCode2      TaxCodeType    
		, @MiscTaxCode1Type LongListType
		, @MiscTaxCode1     TaxCodeType    
		, @MiscTaxCode2Type LongListType
		, @MiscTaxCode2     TaxCodeType     
		, @iCustSeq INT
		, @OrderDate		DateType
		, @iCustNum CustNumType
		, @CustSeq INT
		, @ParmsWhse WhseType
		, @ShipmentExists ListYesNoType
		, @ShipToAddress LongAddress
		, @Contact ContactType
		, @BillToAddress LongAddress
		, @Whse WhseType
		, @Phone PhoneType
		, @BillToContact ContactType
		, @ShipCode ShipCodeType
		, @CustUseExchRate ListYesNoType
		, @BillToPhone PhoneType
		, @ShipPartial ListYesNoType
		, @CusUseExchRate ListYesNoType
		, @ShipToContact ContactType
		, @ShipEarly ListYesNoType
		, @ShipToPhone PhoneType
		, @Slsman SlsmanType
		, @Slsman2 SlsmanType
		, @Consolidate ListYesNoType
		, @CorpCust CustNumType
		, @Summarize ListYesNoType
		, @CorpCustName NameType
		, @InvFreq InvFreqType
		, @EInvoice ListYesNoType
		, @CorpCustContact ContactType
		, @TermsCode TermsCodeType
		, @PriceCode PriceCodeType
		, @CorpCustPhone PhoneType
		, @EndUserType EndUserTypeType
		, @CorpAddress LongAddress
		, @ApsPullUp ListYesNoType
		, @CurrCode CurrCodeType
		, @TransNat TransNatType
		, @UseExchRate LIstYesNoType
		, @TransNat2 TransNatType
		, @ShipCodeDesc DescriptionType
		, @DelTerm DelTermType
		, @TermsCodeDesc DescriptionType
		, @ProcessInd ListYesNoType
		, @CusLcrReqd ListYesNoType
		, @Site SiteType
		, @OnCreditHold ListYesNoType
		, @CustPo CustPoType
		, @PromiseDate DateType
		, @EstShipDate DateType
		, @CustName NameType
		, @SubTotal CostPrcType
		, @Freight CostPrcType
		, @SalesTax CostPrcType
		, @ExtPrice CostPrcType
		, @ReqDate DateType
		, @TotalWeight WeightType
		, @OnHold ListYesNoType
		, @OnHoldReason NVARCHAR(20)
		, @OnHoldUser UsernameType
		, @OnHoldDate DateType
		, @oNewCoLine INT
		, @Description DescriptionType
		, @iItem ItemType
		, @Item ItemType
		, @ItemUnitWeight WeightType
		, @QtyOrderedConv QtyUnitType
		, @ItemUnitCubes QtyUnitType
		, @ShipSite SiteType
		, @iUM UmType
		, @QtyOrdered QtyUnitType
		, @ItemItem ItemType
		, @UnitPrice CostPrcType
		, @ItemUM UMType
		, @ItemDesc DescriptionType
		, @EcCode EcCodeType
		, @CustItem CustItemType
		--, @Price CostPrcType
		, @Transport TransportType
		, @FeatStr FeatStrType
		, @SupplyQtyReq QtyUnitType
		, @PriceConv CostPrcType
		, @CoRowPointer RowPointerType
		, @CoitemRowPointer RowPointerType
		, @ItemPlanFlag LIstYesNoType
		, @iItemDesc DescriptionType
		, @ItemFeatTempl FeatTemplateType
		, @SupplQtyReq QtyUnitType
		, @DiscPct LineDiscType
		, @ItemCommCode CommodityCodeType
		, @SupplyQtyConvFactor UMConvFactorType
		, @ItemOrigin EcCodeType
		, @RefType RefTypeIJOType
		, @RefNum CoNumJobType
		, @DueDate DateType
		, @SupplQtyConvFactor UMConvFactorType
		, @RefLineSuf CoLineSuffixType
		, @RefRelease CoReleaseOperNumType
		, @Kit ListYesNoType
		, @PrintKitComponents ListYesNoType
		, @ItemReservable ListYesNoType
		, @iFromRefType RefTypeIJOType
		, @ItemSerialTracked ListYesNoType
		, @iFromRefNum CoNumJobType
		, @OrigPriceConv CostPrcType
		, @iWhse WhseType
		, @iShipSite SiteType
		, @LineDesc DECIMAL(4,1)
		, @LineDisc CostPrcType
		, @DiscountPercent AmountType
		, @OrderDiscPcnt LineDiscType
		, @LineDiscPcnt LineDiscType
		, @OrderDiscCode nvarchar(30)
		, @LineDiscCode nvarchar(30)
		, @DiscountCodes nvarchar(65)
		, @PShowMatrix Flag
		, @PItem ItemType
		, @PCustNum CustNumType
		, @PCustItem ItemType
		, @PEffDate DateType
		, @PExpDate DateType
		, @PQtyOrdered QtyUnitType
		, @POrderPriceCode PriceCodeType
		, @PCurrCode CurrCodeType
		, @PConfigString FeatStrType
		, @PRate ExchRateType
		, @PUnitPrice CostPrcType
		, @PQtyList##1 QtyUnitType
		, @PQtyList##2 QtyUnitType
		, @PQtyList##3 QtyUnitType
		, @PQtyList##4 QtyUnitType
		, @PQtyList##5 QtyUnitType
		, @PPriceList##1 CostPrcType
		, @PPriceList##2 CostPrcType
		, @PPriceList##3 CostPrcType
		, @PPriceList##4 CostPrcType
		, @PPriceList##5 CostPrcType
		, @PPriceListType InfobarType
		, @PCoNum CoNumType
		, @PCoLine CoLineType
		, @ConvertPrice ListYesNoType
		, @NeedToConvertPrice ListYesNoType
		, @ItemWhse WhseType
		, @ShipTo CustSeqType
		, @CustItemUM UMType
		, @ShipmentApprovalRequired ListYesNoType
		, @RefString NVARCHAR(50)
		, @SQL NVARCHAR(MAX)
		, @BomItem ItemType
		, @WC WCType
		, @BomSequence INT
		, @PMTCode NVARCHAR(15)
		, @partType NVARCHAR(50)
		, @ID INT
		, @Debug INT
		, @OriginalPriceConv CostPrcType
		, @Job JobType
		, @JobSuffix SuffixType
		, @JobRelease SMALLINT
		, @OrderSite SiteType
		, @ItemTemplate ItemType
		, @ToJob JobType
		, @ToSuffix SuffixType
		, @CustomerSite SiteType
		, @EngLeadDays INT
		, @ProdLeadDays INT
		, @JobName NVARCHAR(60)
		, @EngineeringSubmittal NVARCHAR(10)
		, @ShiptoCareOf AddressLineType
		, @ErpTopLineItemId INT
		, @SubTemplate ItemType
		, @ProjectManager NameType
		, @RequestDate DateType
		, @Vendor VendNumType
		, @VendorPrice CostPrcType
		---, @FRE_Site SiteType
		---, @JAX_Site SiteType
		---, @VAN_Site SiteType
		, @BEL_Site SiteType
		, @DropShipName NameType
		, @DropShipAddress1 AddressLineType
		, @DropShipAddress2 AddressLineType
		, @DropShipAddress3 AddressLineType
		, @DropShipAddress4 AddressLineType
		, @DropShipCountry CountryType
		, @DropShipCity CityType
		, @DropShipState StateType
		, @DropShipZip PostalCodeType
		, @DropShipNumber INT
		, @CoPromiseDate DateType
		, @discriminator NVARCHAR(45)
		, @phaseDone NVARCHAR(20)
		--, @SQL NVARCHAR(500)
		,@linesInserted int
		,@AssignSite SiteType
		,@Uf_eCodeAttr nvarchar(100)
		,@Uf_numSections int
		,@Uf_numPanelInteriors int
		,@Uf_numCdpInteriors int
		,@kitItem nvarchar(30)

	SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()
	EXEC dbo.SetSiteSp @Site, NULL

	SET @Debug = 1

	SET @Severity = 0
	
	SET @CoNum = NULL --DJH 2016-3-30.  Adds only allowed via CN.  Should be set to NULL again during select, but to avoid confusion if passed

	set @linesInserted=0

	-- Validate quote
	EXEC @Severity = _IEM_ValidateQuoteSp
		 @DNum = @Ref
		,@Amount = @Price
		,@Infobar = @Infobar OUTPUT
	
	IF @Debug = 1
		PRINT @Infobar
	
	IF @Severity <> 0
		RETURN @Severity

	SET @RefString = CAST(@Ref AS NVARCHAR(10))
	
	-- Create table for order header
	DECLARE @co TABLE(
		discriminator NVARCHAR(45),
		customerOrderNumber NVARCHAR(10),
		cust_num NVARCHAR(7),
		po_num NVARCHAR(25),
		quote NVARCHAR(50),
		quote_rev NVARCHAR(10),
		order_date DATETIME,
		promised_date DATETIME,
		est_ship_date DATETIME,
		cust_name NVARCHAR(60),
		sub_total DECIMAL(20,8),
		shipping_cost DECIMAL(20,8),
		tax DECIMAL(20,8),
		total_price DECIMAL(20,8),
		curr_code NVARCHAR(3),
		ship_addr_1 NVARCHAR(50),
		ship_addr_2 NVARCHAR(50),
		ship_addr_3 NVARCHAR(50),
		ship_addr_4 NVARCHAR(50),
		ship_addr_country NVARCHAR(30),
		ship_addr_city NVARCHAR(30),
		ship_addr_state NVARCHAR(5),
		ship_addr_postal NVARCHAR(10),
		cust_req_date DATETIME,
		ship_to NVARCHAR(10),
		total_weight DECIMAL(19,8),
		customer_dept NVARCHAR(30),
		bill_addr_1 NVARCHAR(50),
		bill_addr_2 NVARCHAR(50),
		bill_addr_3 NVARCHAR(50),
		bill_addr_4 NVARCHAR(50),
		bill_to_number INT,
		whse NVARCHAR(4),
		item_id INT,
		order_site NVARCHAR(8),
		is_ship_direct TINYINT,
		contact_name NVARCHAR(30),
		contact_phone NVARCHAR(25),
		contact_email NVARCHAR(60),
		project_manager NVARCHAR(30),
		job_name NVARCHAR(60),
		engineering_submittal NVARCHAR(10),
		shipto_care_of NVARCHAR(40),
		slsman NVARCHAR(8),
		slsman2 NVARCHAR(8),
		ship_code shipCodeType,
		end_user_type EndUserTypeType
	)

	SET @SQL = 	
		'SELECT * FROM OPENQUERY(EQUOTE, ''SELECT of.discriminator, of.customerOrderNumber, of.customerNumber AS CustNum, of.customerPo AS CustPO, of.quotesDnum AS QuoteNum, of.quotesRev AS QuoteRev, 0 AS sub_total, 0 AS shipping_cost, 0 AS tax, q.Price AS total_price, of.currency AS curr_code, of.shipToNumber AS ShipTo, 0 AS total_weight, 0 AS bill_to_number, NULL AS whse, of.shiptoAddress1, of.shiptoAddress2, of.shiptoAddress3, of.shiptoAddress4, of.shiptoCountry, of.shiptoCity, of.shiptoState, of.shiptoPostal, of.id, of.orderSite, of.shiptoName, of.contactName, of.contactPhone, of.contactEmail, of.projectManager, of.jobName, of.engineeringSubmittals, of.shiptoCareOf, of.salesId, of.salesId2, of.shipVia, of.endUserType FROM infororder `of` LEFT JOIN quotes q ON of.quotesDnum = q.dnum AND of.quotesRev = q.rev where of.deleted IS NULL AND of.dnum = ' + @RefString + ''')'

	IF @Debug = 1
		PRINT @SQL	
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

	PRINT 'Inserting'
	-- Insert CO header information
	INSERT INTO @co(
		discriminator,
		customerOrderNumber,
		cust_num,
		po_num,
		quote,
		quote_rev,
		sub_total,
		shipping_cost,
		tax,
		total_price,
		curr_code,
		ship_to,
		total_weight,
		bill_to_number,
		whse,
		ship_addr_1,
		ship_addr_2,
		ship_addr_3,
		ship_addr_4,
		ship_addr_country,
		ship_addr_city,
		ship_addr_state,
		ship_addr_postal,
		item_id,
		order_site,
		cust_name,
		contact_name,
		contact_phone,
		contact_email,
		project_manager,
		job_name,
		engineering_submittal,
		shipto_care_of,
		slsman,
		slsman2,
		ship_code,
		end_user_type
	)
	EXEC(@SQL)

	IF @Debug = 1
	BEGIN
		PRINT 'inserted'

		select * from @co
	END

	select @discriminator=discriminator, @QuoteNum=quote, @QuoteRev=quote_rev from @co

	IF @discriminator LIKE '%CN' BEGIN
		SET @phaseDone = 'CN_PROCESSED'
	END ELSE BEGIN
		SET @phaseDone = 'ORDER_CREATED'
	END

	-- Get current site
	SELECT @Site = site
	FROM parms

	IF @Debug = 1
		PRINT 'Site = ' +  @Site
		
	-- Get default site
	SELECT @OrderSite = order_site
	FROM @co

	IF @Debug = 1
		PRINT 'Order Site = ' +  @OrderSite	

	DECLARE @DBName NVARCHAR(500)
	SET @DBName = DB_NAME()

/*
	IF @OrderSite = 'FRE'
		SET @OrderSite = @FRE_Site
	ELSE IF @OrderSite = 'JAX'
		SET @OrderSite = @JAX_Site
	ELSE IF @OrderSite = 'VAN'
		SET @OrderSite = @VAN_Site
*/
	IF @OrderSite = 'BEL'
		SET @OrderSite = @BEL_Site
	ELSE
	BEGIN
		SET @OrderSite = @Site
	END

	/*
	IF LEFT(@DBName,2) = 'C1'
		SET @OrderSite = 'C1' + @OrderSite
	ELSE IF LEFT(@DBName,2) = 'C2'
		SET @OrderSite = 'C2' + @OrderSite
	ELSE
		SET @OrderSite = @OrderSite + '30'
	*/

	-- Get default warehouse
	SELECT @Whse = def_whse 
	FROM invparms_mst
	where RIGHT(site_ref,3) = RIGHT(@OrderSite,3)
	
	IF @Debug = 1
		PRINT 'Whse = ' +  ISNULL(@Whse, '')
	
	-- Handle NULL request date
	UPDATE @co
	SET cust_req_date = '2/22/2222'--dbo.MidnightOf(GetDate())
	--WHERE cust_req_date IS NULL
	--	OR cust_req_date < dbo.MidnightOf(GetDate())

	-- Handle null promised date
	UPDATE @co
	SET promised_date = '2/22/2222'

	DECLARE 
		 @Addr1 NVARCHAR(50)
		,@Addr2 NVARCHAR(50)
		,@Addr3 NVARCHAR(50)
		,@Addr4 NVARCHAR(50)
		,@Country NVARCHAR(30)
		,@City NVARCHAR(30)
		,@State NVARCHAR(5)
		,@PostalCode NVARCHAR(10)
		,@ShipDirect ListYesNoType
		,@ContactName NameType
		,@ContactPhone PhoneType
		,@ContactEmail EmailType
		,@CNDiscriminator nvarchar(45)


	SELECT TOP 1 
		@CNDiscriminator = discriminator
		,@CoNum = dbo.ExpandKyByType('CoNumType',co.customerOrderNumber)
		,@CustNum = co.cust_num
		,@Addr1 = co.ship_addr_1
		,@Addr2 = co.ship_addr_2
		,@Addr3 = co.ship_addr_3
		,@Addr4 = co.ship_addr_4
		,@Country = co.ship_addr_country
		,@City = co.ship_addr_city
		,@State = co.ship_addr_state
		,@PostalCode = co.ship_addr_postal
		,@ShipDirect = co.is_ship_direct
		,@CustName = co.cust_name
		,@ContactName = co.contact_name
		,@ContactPhone = co.contact_phone
		,@ContactEmail = co.contact_email
		,@EngineeringSubmittal = co.engineering_submittal
		,@ShiptoCareOf = co.shipto_care_of
		,@CurrCode = co.curr_code
		,@CustSeq = CASE WHEN ISNUMERIC(co.ship_to) = 1 THEN CAST(co.ship_to AS INT) ELSE NULL END
		,@Slsman = co.slsman
		,@EndUserType = co.end_user_type
	FROM @Co co


	IF @Debug = 1
		PRINT 'Calling _IEM_CreateCustomerShipToSp in site:  ' + @OrderSite

	SELECT @SQL = site.app_db_name + '.dbo._IEM_CreateCustomerShipToSp'
	FROM site 
	WHERE site.site = @OrderSite
	
	PRINT 'HERE'


	IF @CustSeq IS NULL
		EXEC @Severity =  @SQL
				 @CustNum = @CustNum
				,@Name = @CustName
				,@Addr1 = @Addr1
				,@Addr2 = @Addr2
				,@Addr3 = @Addr3
				,@Addr4 = @Addr4
				,@Country = @Country
				,@City = @City
				,@State = @State
				,@PostalCode = @PostalCode
				,@OrderSite = @OrderSite
				,@CustSeq = @CustSeq OUTPUT
				,@Infobar = @Infobar OUTPUT
				,@ShipToContactName = @ContactName
				,@ShipToContactPhone = @ContactPhone
				,@ShipToContactFax = NULL
				,@ShipToContactEmail = @ContactEmail
				,@ShipToCareOf = @ShipToCareOf
				,@ShipToCurrency = @CurrCode

		-- Writeback, infororder
		IF @PerformWritebacks = 1
		BEGIN
			SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT dnum, shiptoNumber from infororder WHERE dnum = ' + @RefString + ''') SET shiptoNumber = ''' + CAST(@CustSeq AS NVARCHAR(6)) + ''' WHERE ISNULL(shiptoNumber,'''') <> ''' + CAST(@CustSeq AS NVARCHAR(6)) + ''''
			
			IF @Debug = 1
				PRINT @SQL

			EXEC (@SQL)
		END

	UPDATE @CO
	SET ship_to = @CustSeq

	IF @Severity <> 0
	BEGIN
		RETURN @Severity
	END
	
	
	--SELECT * FROM @CO

	DECLARE @ItemID INT

	SELECT TOP 1 @ItemID = item_id
	FROM @co 

	DECLARE @coitem TABLE(
		description NVARCHAR(40),
		designation NVARCHAR(30),
		item NVARCHAR(30),
		unit_weight DECIMAL(11,3),
		quantity_ordered DECIMAL(19,8),
		price DECIMAL(20,8),
		p_m_t_code NVARCHAR(20),
		partType   NVARCHAR(50),
		item_template NVARCHAR(30),
		engr_lead_days INT,
		prod_lead_days INT,
		promise_date DateType,
		promise_date_unix INT,
		due_date DateType,
		due_date_unix INT,
		request_date_unix INT,
		request_date DateType,
		shipto_care_of NVARCHAR(40),
		erpTopLineItemId INT,
		sub_template NVARCHAR(30),
		part_tempate NVARCHAR(30),
		vendor NVARCHAR(7),
		vendor_price DECIMAL(19,8),
		is_ship_direct TINYINT,
		drop_ship_name NVARCHAR(60)
		, drop_ship_address1 NVARCHAR(50)
		, drop_ship_address2 NVARCHAR(50)
		, drop_ship_address3 NVARCHAR(50)
		, drop_ship_address4 NVARCHAR(50)
		, drop_ship_country NVARCHAR(30)
		, drop_ship_city NVARCHAR(30)
		, drop_ship_state NVARCHAR(5)
		, drop_ship_zip NVARCHAR(10)
		, drop_ship_number INT
		, item_lead_time INT
		, assign_site SiteType
		, Uf_eCodeAttr nvarchar(100)
		, Uf_numSections int
		, Uf_numPanelInteriors int
		, Uf_numCdpInteriors int
		, kitItem NVARCHAR(30)
		)
		
	SET @SQL = 	
	'SELECT * FROM OPENQUERY(EQUOTE, 
		''SELECT left(tli.description,40) AS Description, left(tli.designation,30) as designation, 0 AS UnitWeight, tli.qty AS QtyOrdered, tli.sellPrice AS Price, CASE WHEN tli.partType IN(''''ORDER_SPECIFIC'''',''''INVENTORY'''') THEN ''''I'''' ELSE ''''M'''' END AS pmtCode, tli.partType, ''''TBD'''' AS Item, tli.SourceTemplate, tli.engrLeadDays, tli.prodLeadDays, tli.dueDate, tli.promiseDate, tli.requestDate, tli.shiptoCareOf, tli.id, CASE WHEN tli.partType IN(''''ORDER_SPECIFIC'''',''''INVENTORY'''') THEN tli.partTemplate ELSE tli.subTemplate END AS subTemplate, tli.shipDirectVendor, tli.shipDirectPrice, tli.isShipDirect, tli.shiptoName, tli.shiptoAddress1, tli.shiptoAddress2, tli.shiptoAddress3, tli.shiptoAddress4, tli.shiptoCountry, tli.shiptoCity, tli.shiptoState, tli.shiptoPostal, tli.shiptoNumber, tli.assignSite, tli.eCodeAttr, tli.numSections, tli.numPanelInteriors, tli.numCdpInteriors, tli.kitItem FROM infororder `of` INNER JOIN erpTopLineItem tli ON of.id = tli.orderId WHERE of.dnum = ' + @RefString + '' + ' AND tli.deleted IS NULL AND of.deleted IS NULL AND (tli.action = ''''ADD'''' or tli.action is NULL) ORDER BY tli.sequence'' )'   --' AND tli.partTemplate <> ''''$TESTING'''''')'

	IF @Debug = 1
		PRINT @SQL	

	-- Insert CO line information from XML	
	INSERT INTO @coitem(description, designation, unit_weight, quantity_ordered, price, p_m_t_code, partType, item, item_template, engr_lead_days, prod_lead_days, due_date_unix, promise_date/*_unix*/, request_date_unix, shipto_care_of, erpTopLineItemId, sub_template, vendor, vendor_price, is_ship_direct, drop_ship_name, drop_ship_address1, drop_ship_address2, drop_ship_address3, drop_ship_address4, drop_ship_country, drop_ship_city, drop_ship_state, drop_ship_zip, drop_ship_number, assign_site, Uf_eCodeAttr, Uf_numSections, Uf_numPanelInteriors, Uf_numCdpInteriors, kitItem)
	EXEC(@SQL)																																												-- 0002 DBH unix field no longer used

	--select * from @coitem
	--RETURN

	update @coitem set description=
		left(ISNULL(description,''), 40 - iif(len(designation)>0, len(designation)+3, 0)) + 
		iif(len(designation)>0, ' "' + designation + '"' , '');

	UPDATE @coitem
	SET /*promise_date = DATEADD(SECOND, promise_date_unix, {d '1970-01-01'})	  -- 0002 DBH unix field no longer used
		, */due_date = DATEADD(SECOND, due_date_unix, {d '1970-01-01'})
		, request_date = DATEADD(SECOND, request_date_unix, {d '1970-01-01'})
	

	UPDATE @coitem
	SET due_date = CASE WHEN p_m_t_code = 'I' THEN request_date ELSE '2/22/2222' END
	WHERE ISNULL(due_date_unix,0) = 0

	--select * from @coitem

	UPDATE @coitem
	SET item_template = 'LVSB-SOLI'
	WHERE ISNULL(item_template,'') = ''

	-- update order line weight
	UPDATE @coitem
	SET unit_weight = it.unit_weight
	FROM @coitem ci
	INNER JOIN item it (NOLOCK) on ci.item = it.item
	
	UPDATE @co
	SET order_date = GetDate()

	-- Populate CO header variables
	SELECT @iCustNum = cust_num, @BillToSeq = bill_to_number, @iCustSeq = CAST(ship_to AS INT), 
		@CustPo = po_num, @OrderDate = order_date, @PromiseDate = promised_date,
		@EstShipDate = est_ship_date, @CustName = cust_name, @SubTotal = sub_total,
		@Freight = shipping_cost, @SalesTax = tax, @ExtPrice = total_price,
		@CurrCode = curr_code, @ReqDate = cust_req_date,
		@TotalWeight = total_weight,
		@Whse = whse, @ShipDirect = is_ship_direct, @ProjectManager = project_manager, @JobName = job_name,
		@ContactName = contact_name, @ContactPhone = contact_phone, @ContactEmail = contact_email, @Slsman = slsman, @Slsman2 = slsman2, @ShipCode = ship_code
	FROM @co

	IF @Debug = 1
		PRINT '@iCustNum prior to creating CO:  ' + @iCustNum

	SET @iCustSeq = CAST(@CustSeq AS INT)

	-- Create order header in order site

	SELECT @SQL = site.app_db_name + '.dbo._IEM_CreateCoSp'
	FROM site 
	WHERE site.site = @OrderSite

	EXEC @Severity = @SQL
		 @CustNum = @iCustNum
		,@BillToSeq = @BillToSeq
		,@CustSeq = @iCustSeq
		,@CustPo = @CustPO
		,@OrderDate = @OrderDate
		,@PromiseDate = @PromiseDate
		,@EstShipDate = @EstShipDate
		,@CustName = @CustName
		,@SubTotal = @SubTotal
		,@Freight = @Freight
		,@SalesTax = @SalesTax
		,@ExtPrice = @ExtPrice
		,@CurrCode = @CurrCode
		,@ReqDate = @ReqDate
		,@TotalWeight = @TotalWeight
		,@Whse = @Whse
		,@OrderSite = @OrderSite
		,@CoNum = @CoNum OUTPUT
		,@Infobar = @Infobar OUTPUT
		,@ProjectManager = @ProjectManager
		,@JobName = @JobName
		,@EngineeringSubmittal = @EngineeringSubmittal
		,@ContactName = @ContactName
		,@ContactPhone = @ContactPhone
		,@ContactEmail = @ContactEmail
		,@Slsman = @Slsman
		,@Slsman2 = @Slsman2
		,@OrderShipCode = @ShipCode
		,@EndUserType = @EndUserType

	DECLARE @FirstLine ListYesNoType

	SET @FirstLine = 1

	SET @CoPromiseDate = @PromiseDate

	--Create CO Lines
	DECLARE crsCoLines CURSOR FORWARD_ONLY FOR
	SELECT 	description,
			unit_weight,
			quantity_ordered,
			price,
			p_m_t_code,
			partType,
			item_template,
			engr_lead_days,
			prod_lead_days,
			promise_date,
			erpTopLineItemId,
			due_date,
			sub_template,
			request_date,
			vendor,
			vendor_price,
			is_ship_direct,
			drop_ship_name
			, drop_ship_address1
			, drop_ship_address2
			, drop_ship_address3
			, drop_ship_address4
			, drop_ship_country
			, drop_ship_city
			, drop_ship_state
			, drop_ship_zip
			, drop_ship_number
			--, assign_site
			--, Uf_eCodeAttr
			--, Uf_numSections
			--, Uf_numPanelInteriors
			--, Uf_numCdpInteriors
			--, kitItem
	FROM @coitem
	OPEN crsCoLines

	WHILE @Severity = 0
	BEGIN
		FETCH NEXT FROM crsCoLines INTO 
			@Description, @ItemUnitWeight, @QtyOrderedConv, @OriginalPriceConv, @PMTCode, @partType,
			@ItemTemplate, @EngLeadDays, @ProdLeadDays, @PromiseDate, @ErpTopLineItemId, 
			@DueDate, @SubTemplate, @RequestDate, @Vendor, @VendorPrice, @ShipDirect, @DropShipName,
			@DropShipAddress1, @DropShipAddress2, @DropShipAddress3, @DropShipAddress4, @DropShipCountry,
			@DropShipCity, @DropShipState, @DropShipZip, @DropShipNumber/*, @AssignSite,
			@Uf_eCodeAttr, @Uf_numSections, @Uf_numPanelInteriors, @Uf_numCdpInteriors, @kitItem*/


		IF @@fetch_status <> 0
			break;

		--SET @PromiseDate = NULL

		IF @EngineeringSubmittal = 'RECORD'
		BEGIN
			DECLARE @tStartDate DateType, @tLeadTime int
			SET @tStartDate = GetDate()
			SET @tLeadTime = @EngLeadDays+@ProdLeadDays
			EXEC @Severity = _IEM_GetCalDate @tStartDate, @tLeadTime, @PromiseDate OUTPUT
		END
		ELSE IF @EngineeringSubmittal = 'APPROVAL'
		BEGIN
			SET @PromiseDate = NULL
		END

		IF @DropShipName IS NOT NULL OR @DropShipAddress1 IS NOT NULL
		BEGIN

			SELECT @SQL = site.app_db_name + '.dbo._IEM_CreateCustomerShipToSp'
			FROM site 
			WHERE site.site = @OrderSite
	
			IF @DropShipNumber IS NULL
				EXEC @Severity =  @SQL
						 @CustNum = @CustNum
						,@Name = @DropShipName
						,@Addr1 = @DropShipAddress1
						,@Addr2 = @DropShipAddress2
						,@Addr3 = @DropShipAddress3
						,@Addr4 = @DropShipAddress4
						,@Country = @DropShipCountry
						,@City = @DropShipCity
						,@State = @DropShipState
						,@PostalCode = @DropShipZip
						,@OrderSite = @OrderSite
						,@CustSeq = @DropShipNumber OUTPUT
						,@Infobar = @Infobar OUTPUT
						,@ShipToContactName = @ContactName
						,@ShipToContactPhone = @ContactPhone
						,@ShipToContactFax = NULL
						,@ShipToContactEmail = @ContactEmail
						,@ShipToCareOf = @ShipToCareOf
						,@ShipToCurrency = @CurrCode	
						
			IF @Severity <> 0
				RETURN @Severity		

			IF @PerformWritebacks = 1
			BEGIN
				SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT Id, shipToNumber from erpTopLineItem WHERE Id = ' + CAST(@ErpTopLineItemId AS NVARCHAR(20)) + ''') SET shiptoNumber = ''' + CAST(@DropShipNumber AS NVARCHAR(6)) + ''' WHERE ISNULL(shiptoNumber,'''') <> ''' + CAST(@DropShipNumber AS NVARCHAR(6)) + ''''
				EXEC (@SQL)
			END


		END


		SELECT @SQL = site.app_db_name + '.dbo._IEM_CreateCoitemSp'
		FROM site 
		WHERE site.site = @OrderSite

		EXEC @Severity=@SQL
			 @Item OUTPUT
			,@Description
			,@CoNum
			,@BomItem
			,@ItemUnitWeight
			,@QtyOrderedConv
			,@OriginalPriceConv
			,@PMTCode
			,@partType
			,@ItemTemplate
			,@OrderDate
			,@CustNum
			,@CustSeq
			,@PriceCode
			,@CurrCode
			,@CoLine OUTPUT
			,@Infobar OUTPUT
			,NULL
			,@ShipDirect
			,@EngLeadDays
			,@ProdLeadDays
			,@PromiseDate
			,@DueDate
			,@ErpTopLineItemId
			,@SubTemplate
			,@RequestDate
			,@Vendor
			,@VendorPrice
			,@DropShipNumber
			--,@AssignSite
			--,@Uf_eCodeAttr
			--,@Uf_numSections
			--,@Uf_numPanelInteriors
			--,@Uf_numCdpInteriors
			--,@kitItem

		SET @DropShipNumber = NULL

		If @Severity <> 0 Return @Severity

		IF @PerformWritebacks = 1
		BEGIN
			SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT Id, partTemplate from erpTopLineItem WHERE Id = ' + CAST(@ErpTopLineItemId AS NVARCHAR(20)) + ''') SET partTemplate = ''' + REPLACE(@Item,'''','''''') + ''' WHERE ISNULL(partTemplate,'''') <> ''' + REPLACE(@Item,'''','''''') + ''''
			EXEC (@SQL)
		END
		SET @linesInserted = 1

	END
	CLOSE crsCoLines
	DEALLOCATE crsCoLines

	-- Writeback, infororder
	IF @PerformWritebacks = 1
	BEGIN
		SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT dnum, customerOrderNumber, phase from infororder WHERE dnum = ' + @RefString + ''') SET customerOrderNumber = ''' + LTRIM(@CoNum) + ''', phase = '''+@phaseDone+''''
		EXEC (@SQL)
	END

	IF @Severity = 0
	IF @discriminator LIKE '#CN' BEGIN
		SET @Infobar = 'CN ' + @RefString + ' processed (ADD lines imported to Order ' + LTRIM(@CoNum) + ').'
	END ELSE BEGIN
		SET @Infobar = 'Order ' + LTRIM(@CoNum) + ' created from import.'
	END
	IF @linesInserted = 1 BEGIN
		update co set stat = 'O' where co_num = @CoNum and stat <> 'O'
	END

	RETURN @Severity

END










GO

