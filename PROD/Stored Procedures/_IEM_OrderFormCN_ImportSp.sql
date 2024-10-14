SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



/*----------------------------------------------------------------------------------*\

	     File: _IEM_OrderFormCN_ImportSp
  Description: 

  Change Log:
  Date        Ref #   Author      Description\Comments
  ---------  ------  -----------  -------------------------------------------------------------
  2024/01     0001   Alethea 	  This SP does not need the UET Uf_Revenue for PASS items etc. 
  2024/04     0002   DMS		  Update to coitem.uf_promisedate instead of coitem.promise_date.
                                  Added a new coitem.uf_released. This value is set from the worknet import.
  2024/05	  0003   DMS		  Update to use the @PromiseDate to update the Uf_DrawingApprDate
  2024/05/10  0004   DMS          Update to set the Due Date to Promise Date instead of Request Date
\*---------------------------------------------------------------------------------*/


/*
use DFRE_App
DECLARE @Site siteType;
SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()
EXEC dbo.SetSiteSp @Site, NULL;
delete from SessionContextNames where processid=@@spid
delete from _iem_orderformcnlog where ref=831

declare @InfoBar 		InfoBarType
	,@PerformWritebacks ListYesNoType = 1
	,@Ref int = 831
	,@price CostPrcType=10.0
	,@importTransId int = null
	,@severity int = 0


exec @severity=_IEM_OrderFormCN_ValidateSp
	@ref,
	@price,
	@importTransId OUTPUT,
	@InfoBar OUTPUT

select @importtransid, @infobar

if @severity = 0 begin
	exec _IEM_OrderFormCN_ImportSp
		@ref
		,@price
		,@importTransId
		,@InfoBar 		 OUTPUT
		,@PerformWritebacks

	select @infobar
	select * from _iem_orderformcnlog where ref=@ref order by recorddate
end else begin
	select @severity as severity, @infobar as error
end
*/ALTER PROCEDURE [dbo].[_IEM_OrderFormCN_ImportSp](
	 @Ref	INT
	,@Price CostPrcType
	,@importTransId int OUTPUT
	,@InfoBar 		InfoBarType OUTPUT
	,@PerformWritebacks ListYesNoType = 1


	) 
AS
BEGIN
	
	SET LOCK_TIMEOUT 300000

	if @@TRANCOUNT>0 BEGIN
		ROLLBACK --djh try to exit infor trans?
	END

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
		, @ShipHold ListYesNoType
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
		, @PromiseDate DateType -- Note: Coitem.Uf_PromiseDate 0002 DMS
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
		, @Designation nvarchar(30)
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
		, @qs NVARCHAR(MAX)
		, @qu NVARCHAR(MAX)
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
		, @DefSite SiteType
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
		, @CustomerRequiredShipDate DateType
		, @Vendor VendNumType
		, @VendorPrice CostPrcType
		, @DropShipName NameType
		, @DropShipCareOf AddressLineType
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
		,@AssignWH WhseType
		,@Uf_eCodeAttr nvarchar(100)
		,@Uf_numSections int
		,@Uf_numPanelInteriors int
		,@Uf_numCdpInteriors int
		,@kitItem nvarchar(30)
		,@Uf_CustomerItem   ItemType = NULL
		,@Uf_matlCostBasis AmountType = NULL
		,@Uf_CustomerPOLine int = null
		,@tmpimportTransId int = NULL
		,@conum CoNumType = NULL
		,@CoLine CoLineType = NULL
		,@QuoteNum INT 
		,@QuoteRev INT
		,@ts int = 0
		,@ShipToChange int

		declare @tsite sitetype, @titem itemtype, @SaveSessionID uniqueidentifier, @RemoteSessionID uniqueidentifier, @Username usernametype
		declare @sitePrefix sitetype, @sAppdb OSLocationType
		declare @tc int

		declare @um umType
		,@mfg ManufacturerIdType
		,@ProductCode productCodeType

		declare @Uf_Released int -- 0002 DMS



	--djh 2021-01-12, note this does not account for DST, but we will round to the nearest date, which is good enough
	declare @baseUnixDate datetime = Dateadd(hh, Datediff(hh, Getutcdate(), Getdate()), {d '1970-01-01'})

	SET @Debug = 0

	SET @Severity = 0
	
	set @linesInserted=0

--	PRINT 1/0

	-- Validate quote
	EXEC @Severity = _IEM_OrderFormCN_ValidateSp
		 @ref = @Ref
		,@Price = @Price
		,@importTransId = @tmpimportTransId OUTPUT
		,@Infobar = @Infobar OUTPUT
	
	IF @Severity <> 0 GOTO EXITSP
	if @tmpimportTransId <> @importTransId begin -- should never happen.  id chosen by validate should match the calling form. if not, someone else may be running at the same time
		set @InfoBar = 'Import transaction id mismatch.  Please try again'
		set @Severity = -16
		GOTO EXITSP
	end else begin
		set @importTransId = @tmpimportTransId
	end


	SET XACT_ABORT ON

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
		end_user_type EndUserTypeType,
		ship_hold ListYesNoType
	)

	SET @SQL = 	
		'SELECT * FROM OPENQUERY(EQUOTE, ''
			SELECT of.discriminator, of.customerOrderNumber, of.customerNumber AS CustNum, of.customerPo AS CustPO, of.quotesDnum AS QuoteNum, of.quotesRev AS QuoteRev, 
			0 AS sub_total, 0 AS shipping_cost, 0 AS tax, q.Price AS total_price, of.currency AS curr_code, of.shipToNumber AS ShipTo, 0 AS total_weight, 
			0 AS bill_to_number, NULL AS whse, of.shiptoAddress1, of.shiptoAddress2, of.shiptoAddress3, of.shiptoAddress4, of.shiptoCountry, of.shiptoCity, 
			of.shiptoState, of.shiptoPostal, of.id, of.orderSite, of.shiptoName, of.contactName, of.contactPhone, of.contactEmail, of.projectManager, of.jobName, 
			of.engineeringSubmittals, of.shiptoCareOf, of.salesId, of.salesId2, of.shipVia, of.endUserType, of.shipHold 
			FROM infororder `of`
			LEFT JOIN quotes q ON of.quotesDnum = q.dnum AND of.quotesRev = q.rev 
			where of.deleted IS NULL AND of.dnum = ' + @RefString + ''' )'

	IF @Debug = 1
		PRINT @SQL	


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
		end_user_type,
		ship_hold
	)
	EXEC(@SQL)
--PRINT 1/0
	select @discriminator=discriminator, @QuoteNum=quote, @QuoteRev=quote_rev from @co

	IF @discriminator = 'cn' BEGIN
		SET @phaseDone='CN_PROCESSED'
	END ELSE BEGIN
		SET @phaseDone='ORDER_CREATED'
	END

	SELECT @Site = site	FROM parms
	SELECT @DefSite = order_site FROM @co

	DECLARE @DBName NVARCHAR(500)

	select @OrderSite = site, @DBName = app_db_name from site s where s.Uf_SiteIdentity=@DefSite

	if @ordersite is null begin
		set @InfoBar = 'Unable to identify valid Infor site for site='+@DefSite+'.'
		set @Severity = -16
		GOTO EXITSP
	end

	if @OrderSite <> @site begin -- djh 2018-04-16; execute in order site to avoid changing sessions too many times
		SET @SQL = @DBNAME+ '.dbo._IEM_OrderFormCN_ImportSp'

		exec _IEM_RemoteSessionSp
			@RemoteSite = @OrderSite,
			@LocalSite = @Site,
			@clear = 0

		exec @Severity = @sql
			 @Ref
			,@Price
			,@importTransId OUTPUT
			,@InfoBar OUTPUT
			,@PerformWritebacks
		
		exec _IEM_RemoteSessionSp
			@restore = 2 --from table

		GOTO EXITSP
	end
--must start logging here in case of recursive import call above
	set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, result)
	values (@site, @ref, @ts, @importTransId, 'Import', 'begin');


	-- Get default warehouse
	SELECT @Whse = def_whse FROM invparms_mst where site_ref = @OrderSite
	
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


	SET @SQL = @DBNAME+ '.dbo._IEM_OrderFormCN_CreateShipToSp'
	
	IF @CustSeq IS NULL OR @discriminator='cn' BEGIN --djh always call createshipto for possible updates on cns

		set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, actionText, co_num, result)
		values (@site, @ref, @ts, @importTransId, 'CreateCOShipTo', 'CustNum='+@CustNum+'; Addr1='+@Addr1+';', @CoNum, 'begin');

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
				,@ShipToCareOf = @ShipToCareOf
				,@ShipToCurrency = @CurrCode
				,@CoNum = @conum

		IF @Severity <> 0 BEGIN
			set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, error, Infobar, co_num, result)
			values (@site, @ref, @ts, @importTransId, 'CreateCOShipTo',@InfoBar, @InfoBar, @CoNum, 'fail');
			GOTO RECORDFAIL
		END

		if @discriminator = 'cn' begin
			begin try
				set @sql = 
				'update com set com.cust_seq = @custseq, com.tax_code1 = cu.tax_code1, com.tax_code2 = cu.tax_code2'
				+ ' from ' + @DBNAME + '.dbo.co_mst com join '
				+ @DBNAME + '.dbo.customer_mst cu on cu.cust_seq = @custseq and cu.cust_num = com.cust_num' 
				+ ' where co_num=@conum and com.cust_seq <> @custseq'
				exec sp_executesql @sql, N'@conum conumtype, @custseq custseqtype', @conum, @CustSeq
			end try begin catch
				set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, error, errorNumber, result)
				values (@site, @ref, @ts, @importTransId, 'CreateCOShipTo', 'Error updating cust seq: '+ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
				SET @Severity = -16
				GOTO RECORDFAIL
			end catch
		end


		set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, actionText, co_num, result)
		values (@site, @ref, @ts, @importTransId, 'CreateCOShipTo', 'CustNum='+@CustNum+'; CustSeq='+cast(@CustSeq as nvarchar(4))+'; '+@InfoBar, @CoNum, 'success');

		-- Writeback, infororder
		IF @PerformWritebacks = 1
		BEGIN
			SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT dnum, shiptoNumber from infororder WHERE dnum = ' + @RefString + ''') SET shiptoNumber = ''' + CAST(@CustSeq AS NVARCHAR(6)) + ''' WHERE ISNULL(shiptoNumber,'''') <> ''' + CAST(@CustSeq AS NVARCHAR(6)) + ''''
		
			EXEC (@SQL)
		END
	END
	UPDATE @CO SET ship_to = @CustSeq


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
		CustomerRequiredShipDate_unix INT,
		CustomerRequiredShipDate DateType,
		erpTopLineItemId INT,
		sub_template NVARCHAR(30),
		part_tempate NVARCHAR(30),
		vendor NVARCHAR(7),
		vendor_price DECIMAL(19,8),
		is_ship_direct TINYINT,
		drop_ship_name NVARCHAR(60)
		, drop_ship_care_of NVARCHAR(40)
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
		, assignSite SiteType
		, assignWH whsetype
		, Uf_eCodeAttr nvarchar(100)
		, Uf_numSections int
		, Uf_numPanelInteriors int
		, Uf_numCdpInteriors int
		, kitItem NVARCHAR(30)
		, co_line coLineType
		, new_unit_price DECIMAL(19,8)
		, Uf_CustomerItem ItemType
		, Uf_matlCostBasis AmountType
		, Uf_CustomerPOLine int
		, Uf_Released int -- 0002 DMS
		)
		
	SET @SQL = 	
	'SELECT * FROM OPENQUERY(EQUOTE, 
		''SELECT left(tli.description,40) AS Description, designation, 0 AS UnitWeight, tli.qty AS QtyOrdered, tli.sellPrice AS Price, CASE WHEN tli.partType IN(''''ORDER_SPECIFIC'''',''''INVENTORY'''') THEN ''''I'''' ELSE ''''M'''' END AS pmtCode, tli.partType, ''''TBD'''' AS Item, tli.SourceTemplate, tli.engrLeadDays, tli.prodLeadDays, tli.dueDate, tli.promiseDate, tli.requestDate, tli.requiredShipDate, tli.dnum, CASE WHEN tli.partType IN(''''ORDER_SPECIFIC'''',''''INVENTORY'''') THEN tli.partTemplate ELSE tli.subTemplate END AS subTemplate, tli.shipDirectVendor, tli.shipDirectPrice, tli.isShipDirect, tli.shiptoName, tli.shiptoCareOf, tli.shiptoAddress1, tli.shiptoAddress2, tli.shiptoAddress3, tli.shiptoAddress4, tli.shiptoCountry, tli.shiptoCity, tli.shiptoState, tli.shiptoPostal, tli.shiptoNumber, tli.assignSite, tli.assignWH, tli.eCodeAttr, tli.numSections, tli.numPanelInteriors, tli.numCdpInteriors, tli.kitItem, tli.customerItem, tli.matlCostBasis,tli.custPoLine, tli.released FROM infororder `of` INNER JOIN erpTopLineItem tli ON of.id = tli.orderId WHERE of.dnum = ' + 
		@RefString + ' AND tli.deleted IS NULL AND of.deleted IS NULL AND (tli.action = ''''ADD'''' or tli.action is NULL) ORDER BY tli.sequence'' )'   --' AND tli.partTemplate <> ''''$TESTING'''''')' -- 0002 DMS Added tle.released 

	INSERT INTO @coitem(
	description
	, designation
	, unit_weight
	, quantity_ordered
	, price
	, p_m_t_code
	, partType
	, item
	, item_template
	, engr_lead_days
	, prod_lead_days
	, due_date_unix
	--, promise_date_unix -- 0002 DMS
	, promise_date -- 0002 DMS
	, request_date_unix
	, CustomerRequiredShipDate_unix
	, erpTopLineItemId
	, sub_template
	, vendor
	, vendor_price
	, is_ship_direct
	, drop_ship_name
	, drop_ship_care_of
	, drop_ship_address1
	, drop_ship_address2
	, drop_ship_address3
	, drop_ship_address4
	, drop_ship_country
	, drop_ship_city
	, drop_ship_state
	, drop_ship_zip
	, drop_ship_number
	, assignSite
	, assignWH
	, Uf_eCodeAttr
	, Uf_numSections
	, Uf_numPanelInteriors
	, Uf_numCdpInteriors
	, kitItem
	, Uf_CustomerItem
	, Uf_matlCostBasis
	, Uf_CustomerPOLine
	, Uf_Released
	)
	EXEC(@SQL)



	update @coitem set drop_ship_country = 'USA' where drop_ship_country = 'US'

	update @coitem set description=dbo.soliDescription(description, designation)

	--cast to date to make sure DST doesn't create a 1 hr difference and move the DAY
	UPDATE @coitem
	--SET promise_date = cast(DATEADD(SECOND, promise_date_unix, @baseUnixDate)+.5 as date) -- 0002 DMS
	SET due_date = cast(DATEADD(SECOND, due_date_unix, @baseUnixDate)+.5 as date)
		, request_date = cast(DATEADD(SECOND, request_date_unix, @baseUnixDate)+.5 as date)
		, CustomerRequiredShipDate = cast(DATEADD(SECOND, CustomerRequiredShipDate_unix, @baseUnixDate)+.5 as date) 


	UPDATE @coitem
	-- SET due_date = CASE WHEN p_m_t_code = 'I' THEN request_date ELSE '2/22/2222' END -- 0004 DMS
	SET due_date = CASE WHEN p_m_t_code = 'I' THEN promise_date ELSE '2/22/2222' END -- 0004 DMS
	WHERE ISNULL(due_date_unix,0) = 0

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
		@ContactName = contact_name, @ContactPhone = contact_phone, @ContactEmail = contact_email, @Slsman = slsman, @Slsman2 = slsman2, @ShipCode = ship_code,
		@ShipHold = ship_hold
	FROM @co

	SET @iCustSeq = CAST(@CustSeq AS INT)

	-- Create order header in order site

	if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and action='CreateCO' and result='success') begin
		select @CoNum = co_num from _IEM_OrderFormCNLog where ref=@ref and action='CreateCO' and result='success'
		set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, result)
		values (@site, @ref, @ts, @importTransId, 'CreateCO', 'skip');
	end else begin
	
		SET @SQL = @DBNAME+ '.dbo._IEM_OrderFormCN_CreateCoSp'

		BEGIN TRY
			set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, result)
			values (@site, @ref, @ts, @importTransId, 'CreateCO', 'begin');

			BEGIN TRAN CREATECOFOROFCN
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
					,@ShipHold = @ShipHold
			COMMIT TRAN CREATECOFOROFCN
			set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, result, co_num)
			values (@site, @ref, @ts, @importTransId, 'CreateCO', 'success', @CoNum);
		END TRY BEGIN CATCH
			IF XACT_STATE() IN (-1,1) and @@TRANCOUNT > 0
				ROLLBACK TRANSACTION
			IF XACT_STATE() = 1 and @@TRANCOUNT > 0
				ROLLBACK TRANSACTION CREATECOFOROFCN
		
			set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, error, errorNumber, result)
			values (@site, @ref, @ts, @importTransId, 'CreateCO', ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
			SET @Severity = -16
			GOTO RECORDFAIL
		END CATCH
	end

	if @discriminator = 'cn' and exists (select 1 from co_mst_all where co_num = @conum and ship_hold <> @ShipHold) begin
		set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, actionText, co_num, result)
		values (@site, @ref, @ts, @importTransId, 'UpdateShipHold', 'ShipHold='+cast(@ShipHold as nvarchar(1)), @CoNum, 'begin');

		begin try
			set @sql = 
			'update com set com.ship_hold = @ShipHold '
			+ ' from ' + @DBNAME + '.dbo.co_mst com '
			+ ' where co_num=@conum'
			exec sp_executesql @sql, N'@conum conumtype, @ShipHold ListYesNoType', @conum, @ShipHold
		end try begin catch
			set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, error, errorNumber, result)
			values (@site, @ref, @ts, @importTransId, 'UpdateShipHold', 'Error updating cust seq: '+ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
			SET @Severity = -16
			GOTO RECORDFAIL
		end catch
	end

	DECLARE @FirstLine ListYesNoType

	SET @FirstLine = 1

	SET @CoPromiseDate = @PromiseDate

	--Create CO Lines
	DECLARE crsCoLines CURSOR FORWARD_ONLY FOR
	SELECT 	description,
			designation,
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
			CustomerRequiredShipDate,
			vendor,
			vendor_price,
			is_ship_direct,
			drop_ship_name
			, drop_ship_care_of
			, drop_ship_address1
			, drop_ship_address2
			, drop_ship_address3
			, drop_ship_address4
			, drop_ship_country
			, drop_ship_city
			, drop_ship_state
			, drop_ship_zip
			, drop_ship_number
			, assignSite
			, assignWH
			,Uf_eCodeAttr
			,Uf_numSections
			,Uf_numPanelInteriors
			,Uf_numCdpInteriors
			,kitItem
			,Uf_CustomerItem
			,Uf_matlCostBasis
			,Uf_CustomerPOLine
			,Uf_Released --0002 DMS
	FROM @coitem
	OPEN crsCoLines

	WHILE @Severity = 0
	BEGIN
		FETCH NEXT FROM crsCoLines INTO 
			@Description, @Designation, @ItemUnitWeight, @QtyOrderedConv, @OriginalPriceConv, @PMTCode, @partType,
			@ItemTemplate, @EngLeadDays, @ProdLeadDays, @PromiseDate, @ErpTopLineItemId, 
			@DueDate, @SubTemplate, @RequestDate, @CustomerRequiredShipDate, @Vendor, @VendorPrice, @ShipDirect, @DropShipName, @DropShipCareOf, 
			@DropShipAddress1, @DropShipAddress2, @DropShipAddress3, @DropShipAddress4, @DropShipCountry,
			@DropShipCity, @DropShipState, @DropShipZip, @DropShipNumber, @AssignSite, @AssignWH,
			@Uf_eCodeAttr, @Uf_numSections, @Uf_numPanelInteriors, @Uf_numCdpInteriors, @kitItem, @Uf_CustomerItem, @Uf_matlCostBasis
			,@Uf_CustomerPOLine
			,@Uf_Released --0002 DMS

		IF @@fetch_status <> 0 break;

		-- 0002 DMS Removed the hardcoded lead times
		--if @partType = 'MANUFACTURED' and (@EngLeadDays is null or @ProdLeadDays is null) begin
		--	declare @lt table (
		--		p ProductCodeType,
		--		eng_lt int,
		--		prod_lt int
		--	);

		--	insert into @lt (p,eng_lt,prod_lt) values
		--	('M1000',4,10),
		--	('M1100',4,10),
		--	('M1200',4,10),
		--	('M1300',30,30),
		--	('M1400',15,30),
		--	('M1500',35,60),
		--	('M1600',40,80),
		--	('M1700',40,80),
		--	('M1800',20,80),
		--	('M1900',20,25),
		--	('M2000',30,30),
		--	('M2300',30,75),
		--	('M2400',10,20),
		--	('M2410',10,20),
		--	('M2420',10,20),
		--	('M2430',10,10),
		--	('M2500',10,20),
		--	('M2600',1,1),
		--	('M2700',1,10),
		--	('M9999',1,30);

		--	if isnull(@EngLeadDays,0) in (0,999) set @EngLeadDays = (select top 1 eng_lt from item i join @lt l on l.p=i.product_code where i.item=@ItemTemplate)
		--	if isnull(@ProdLeadDays,0) in (0,999) set @ProdLeadDays = (select top 1 prod_lt from item i join @lt l on l.p=i.product_code where i.item=@ItemTemplate)
		--end


		SET @EngLeadDays = ISNULL(@EngLeadDays, 0) --should never happen for manufactured? djh 2018-03-09
		SET @ProdLeadDays = ISNULL(@ProdLeadDays, 0)

		DECLARE @tStartDate DateType, @tLeadTime int
		SET @tStartDate = GetDate()
		SET @tLeadTime = @EngLeadDays+@ProdLeadDays

		IF @EngineeringSubmittal = 'APPROVAL' BEGIN
			SET @tLeadTime = @tLeadTime + 20 --djh 2018-03-09 for approval add 20 for approval time
		END
		--EXEC @Severity = _IEM_GetCalDate @tStartDate, @tLeadTime, @PromiseDate OUTPUT -- 0002 DMS No Longer used to calculate promise date
		SELECT @UM = u_m, @ProductCode = product_code, @Mfg = Uf_manufacturer
		FROM item 
		WHERE item = @ItemTemplate

		if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and action='ReserveCOLine' and erpTopLineItemId=@ErpTopLineItemId and result='success') begin
			set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, result)
			values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'ReserveCOLine', 'skip');

			select @coline = co_line from _IEM_OrderFormCNLog_mst where ref=@ref and action='ReserveCOLine' and erpTopLineItemId=@ErpTopLineItemId and result='success'
		end else begin
			SELECT @CoLine = ISNULL(MAX(co_line),0) + 1 FROM coitem (READUNCOMMITTED) WHERE co_num = @CoNum

			set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, actionText, result, co_num, co_line)
			values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'ReserveCOLine', 'Item: '+@ItemTemplate, 'success', @CoNum, @CoLine);
		end

		if @PMTCode='M' begin -- site items moved here for smaller transactions
			declare scrs cursor for 
			select site, Uf_SiteIdentity, app_db_name from site where Uf_mfg=1			--> 0001 Alethea Not needed as we don't have PASS items Uf_Revenue = 1	

			open scrs
			while 1=1 begin
				fetch scrs into @tsite, @sitePrefix, @sAppdb
				if @@FETCH_STATUS != 0 break

				if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and action='CreateSiteItem'+@sitePrefix and erpTopLineItemId=@ErpTopLineItemId and result='success') begin
					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, result)
					values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'CreateSiteItem'+@sitePrefix, 'skip');
				end else begin
					set @titem=@sitePrefix + RIGHT('0' + LTRIM(RTRIM(@CoNum)),6) + RIGHT(10000 + @CoLine,4)

					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, actionText, result, co_num, co_line)
					values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'CreateSiteItem'+@sitePrefix, 'Item: '+@titem, 'begin', @CoNum, @CoLine);

					BEGIN TRY
						set @tc = @@trancount
						BEGIN TRAN CREATESITEITEM
							declare @pass_req int
							set @pass_req = CASE WHEN @Site = @tsite THEN 1 ELSE 0 END
							EXECUTE @Severity = dbo._IEM_OrderFormCN_CreateItemSp
								@Item = @titem
								,@Description = @Description
								,@Revision = NULL --@Revision
								,@UM = @UM
								,@ProductCode = @ProductCode
								,@Job = null
								,@Suffix = null
								,@JobType = null
								,@Infobar = @Infobar OUTPUT
								,@Site = @Site
								,@SiteSpecificItem = 1
								,@TemplateItem = @SubTemplate
								,@pass_req = @pass_req
								,@LeadTime = @ProdLeadDays

							IF @Severity <> 0
								begin
								set @InfoBar = '_IEM_OrderFormCN_CreateItemSp failed: ' + ISNULL(@Infobar, '')
								;THROW 50505, @Infobar, 1;
							end

							if not exists (select 1 from item_all where item = @titem and site_ref=@tsite) begin
								set @InfoBar = 'Could not find item '+@titem+' in site '+@tsite+' ; aborting.'
								;THROW 50505, @Infobar, 1;
							end
							if not exists (select 1 from item_all where item = @titem and site_ref=@Site) begin
								set @InfoBar = 'Could not find item '+@titem+' in order site '+@Site+' ; aborting.'
								;THROW 50505, @Infobar, 1;
							end

							EXEC [dbo].[_IEM_SyncBOMSp]
								 @titem
								,@InfoBar OUTPUT
								,@Site
								,1 -- do not create transactions.  we should already be in a tran

						if @@TRANCOUNT > @tc COMMIT TRAN CREATESITEITEM
					END TRY BEGIN CATCH
						IF @@TRANCOUNT > @tc ROLLBACK TRANSACTION CREATESITEITEM
						set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, error, errorNumber, result)
						values (@site, @ref, @ts, @importTransId, 'CreateSiteItem'+@sitePrefix, ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
						set @Severity = -16
						close scrs
						deallocate scrs
						GOTO RECORDFAIL
					END CATCH

					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, actionText, result, co_num, co_line)
					values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'CreateSiteItem'+@sitePrefix, 'Item: '+@titem, 'success', @CoNum, @CoLine);
				end
			end
			close scrs
			deallocate scrs
		end

		if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and action='CreateCOLine' and erpTopLineItemId=@ErpTopLineItemId and result='success') begin
			set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, result)
			values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'CreateCOLine', 'skip');
			--if resuming we need to grab the @coline and @item
			declare @tt nvarchar(1000)
			select @coline = co_line, @tt=actionText from _IEM_OrderFormCNLog_mst where ref=@ref and action='CreateCOLine' and erpTopLineItemId=@ErpTopLineItemId and result='success'
			set @item = replace(@tt,'Item: ','')
		end else begin


			IF @DropShipName IS NOT NULL OR @DropShipAddress1 IS NOT NULL
			BEGIN

				SET @SQL = @DBNAME+ '.dbo._IEM_OrderFormCN_CreateShipToSp'
	
				-- djh 2021-03-18; even if they passed the dropshipnumber, we can process address creation.  it may not match what's in Infor anymore
				-- came about because of a worknet bug that allowed changing address after selecting an existing dropshipnumber
--				IF @DropShipNumber IS NULL BEGIN

					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, actionText, co_num, result)
					values (@site, @ref, @ts, @importTransId, 'CreateLineShipTo', 'CustNum='+@CustNum+'; Addr1='+@DropShipAddress1+'; seq='+cast(@erptoplineitemid as nvarchar(10)), @CoNum,  'begin');

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
							,@ShipToCareOf = @DropShipCareOf
							,@ShipToCurrency = @CurrCode
							,@CoNum = @conum
							,@CoLine = -1 -- line not created yet

					IF @Severity <> 0 BEGIN
						set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, Infobar, co_num, result)
						values (@site, @ref, @ts, @importTransId, 'CreateLineShipTo',@InfoBar, @CoNum, 'fail');
						GOTO RECORDFAIL
					END

					IF @PerformWritebacks = 1
					BEGIN
						SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT Id, shipToNumber from erpTopLineItem WHERE Id = ' + CAST(@ErpTopLineItemId AS NVARCHAR(20)) + ''') SET shiptoNumber = ''' + CAST(@DropShipNumber AS NVARCHAR(6)) + ''' WHERE ISNULL(shiptoNumber,'''') <> ''' + CAST(@DropShipNumber AS NVARCHAR(6)) + ''''
						EXEC (@SQL)
					END

					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, actionText, co_num, result)
					values (@site, @ref, @ts, @importTransId, 'CreateLineShipTo', 'CustNum='+@CustNum+'; CustSeq='+cast(@DropShipNumber as nvarchar(4)), @CoNum, 'success');
--				END
						
			END
--PRINT 1/0
			SET @SQL = @DBNAME+ '.dbo._IEM_OrderFormCN_CreateCoitemSp'

			set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action,actionText, result, co_num)
			values (@site, @ref, @ts, @importTransId, 'CreateCOLine', @ItemTemplate, 'begin', @CoNum);

			BEGIN TRY
				BEGIN TRAN CREATECOITEMFOROFCN
					EXEC @Severity=@SQL
						 @Item OUTPUT
						,@Description
						,@Designation
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
						,@CoLine
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
						,@CustomerRequiredShipDate
						,@Vendor
						,@VendorPrice
						,@DropShipNumber
						,@AssignSite
						,@AssignWH
						,@Uf_eCodeAttr
						,@Uf_numSections
						,@Uf_numPanelInteriors
						,@Uf_numCdpInteriors
						,@kitItem
						,@Uf_CustomerItem
						,@Uf_matlCostBasis
						,@Uf_CustomerPOLine
						,@Uf_Released --0002 DMS
				
					If @Severity <> 0 begin --pass error to try/catch
						set @InfoBar=isnull(@Infobar,N'Unknown Error creating coitem')
						;THROW 50505, @Infobar, 1;
					end
					COMMIT TRAN CREATECOITEMFOROFCN

			END TRY BEGIN CATCH
				IF XACT_STATE() IN (-1,1) and @@TRANCOUNT > 0
					ROLLBACK TRANSACTION
				IF XACT_STATE() = 1 and @@TRANCOUNT > 0
					ROLLBACK TRANSACTION CREATECOITEMFOROFCN
				
		
				set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, error, errorNumber, result)
				values (@site, @ref, @ts, @importTransId, 'CreateCOLine', ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
				set @Severity = -16
				GOTO RECORDFAIL
			END CATCH
			SET @DropShipNumber = NULL

			IF @PerformWritebacks = 1
			BEGIN
				SET @qs = 'SELECT Id, partTemplate, co_line from erpTopLineItem WHERE Id = ' + CAST(@ErpTopLineItemId AS NVARCHAR(20))
				set @qu = 'SET partTemplate = ''' + REPLACE(@Item,'''','''''') + ''', co_line = '+cast(@coLine as nvarchar(10))+' WHERE ISNULL(partTemplate,'''') <> ''' + @Item + ''' or isnull(co_line, 0) <> '+cast(@coLine as nvarchar(10))
				SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''' + replace(@qs,'''','''''') + ''') '+@qu
				EXEC (@SQL)
			END
			SET @linesInserted = 1
			set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, actionText, result, co_num, co_line)
			values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'CreateCOLine', 'Item: '+@Item, 'success', @CoNum, @CoLine);
		END -- if not skipped
		if @PMTCode='M' begin -- site jobs moved here for smaller transactions
			if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and action='CreateCOLineSiteJobs' and erpTopLineItemId=@ErpTopLineItemId and result='complete') begin
				set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, result)
				values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'CreateCOLineSiteJobs', 'skip');
			end else begin
				declare scrs cursor for 
				select site, Uf_SiteIdentity, app_db_name from site where Uf_mfg=1				--> 0001 Alethea Not needed as we don't have PASS items Uf_Revenue = 1	

				open scrs
				while 1=1 begin
					fetch scrs into @tsite, @sitePrefix, @sAppdb
					if @@FETCH_STATUS != 0 break
					if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and action='CreateSiteJob'+@sitePrefix and erpTopLineItemId=@ErpTopLineItemId and result='success') begin
						set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, result)
						values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'CreateSiteJob'+@sitePrefix, 'skip');
					end else begin
						set @titem=replace(@item, 'SOLI', @sitePrefix)
						set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, actionText, result, co_num, co_line)
						values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'CreateSiteJob'+@sitePrefix, 'Item: '+@titem, 'begin', @CoNum, @CoLine);

						BEGIN TRY
							set @tc = @@trancount
							BEGIN TRAN CREATESITEJOB
								SET @Job = dbo.ExpandKyByType('JobType',LTRIM(RTRIM(@CoNum)) + @sitePrefix)
								set @SQL = @sAppdb + '.dbo._IEM_OrderFormCN_CreateSiteSpecificJobSp'
		
								exec _IEM_RemoteSessionSp @RemoteSite=@tsite, @LocalSite=@Site, @SaveSessionID = @SaveSessionID OUTPUT, @RemoteSessionID = @RemoteSessionID OUTPUT, @Username = @Username OUTPUT

								EXEC @SEVERITY = @SQL
									@OrderSite = @Site
									,@Job = @Job
									,@Suffix = @CoLine
									,@Item = @titem
									,@ItemTemplate = @SubTemplate
									,@JobQty = @QtyOrderedConv
									,@Infobar = @Infobar OUTPUT
								If @Severity <> 0 begin --pass error to try/catch
									set @InfoBar=isnull(@Infobar,N'Unknown Error creating subjob for site'+@tsite)
									;THROW 50505, @Infobar, 1;
								end

								if @AssignSite=@tsite and @AssignWH is not null and not exists (select 1 from iemCommon..job_all j where j.job=@job and j.suffix=@coline and j.whse = @AssignWH ) begin
									declare @wstr nvarchar(MAX)
									select @wstr = N'UPDATE j
										set whse = @AssignWH
										from ' + app_db_name + N'.dbo.job_mst j
										where j.job=@Job and j.suffix=@Suffix'
									FROM site WHERE site = @tsite
									
									EXEC sp_executesql @wstr, N'@Job NVARCHAR(20), @Suffix SMALLINT, @AssignWH nvarchar(4)', @Job = @job, @Suffix = @coline, @AssignWH=@AssignWH;

									if @tsite=@AssignSite begin -- we have to set the whse=assign whse on the subjob, in the assign site
										declare @csql nvarchar(max), @createsev int = 0, @createinfo infobartype
										SELECT @csql = app_db_name + '.dbo._IEM_CreateItemWhseAndLocSP'
										FROM site
										WHERE site = @tsite

										if @csql is not null begin
											declare @ContextInfo VARBINARY(128)
											SET @ContextInfo = CONTEXT_INFO()
											EXEC dbo.SetSiteSp @tsite, ''

											exec @severity = @csql -- _IEM_CreateItemWhseAndLocSP
												@Item = @tItem,
												@Whse = @AssignWH,
												@Loc = 'STOCK',
												@Infobar = @createinfo output

											SET CONTEXT_INFO @ContextInfo

											if @severity <> 0 begin
												set @infobar = 'Could not create whse or loc[1]: ' + isnull(@createinfo,'<no error>')+' '
													+@csql+'; '
													+isnull(@AssignWH, '<no whse>')+'; '
													+isnull(@titem, '<no item>')+'; '
												;THROW 50505, @Infobar, 1;
											end
										end
									end
								end

								if @kitItem is not null and @tsite=@AssignSite begin -- the assign site job needs syncing as it had a phantom kit
									DECLARE @r_dba NVARCHAR(20)
									SELECT @r_dba = app_db_name FROM site WHERE site = @AssignSite
									DECLARE @r_sql NVARCHAR(MAX) 
									SET @r_sql = @r_dba + '.._IEM_UpdateJobsSp'							
									exec @r_sql @item=@titem, @infobar=@infobar output, @updateimmediate=1
								end

								exec _IEM_RemoteSessionSp @RemoteSite=@tsite, @LocalSite=@Site, @SaveSessionID = @SaveSessionID, @RemoteSessionID = @RemoteSessionID, @Username = @Username, @restore = 1			

							if @@TRANCOUNT > @tc COMMIT TRAN CREATESITEJOB
						END TRY BEGIN CATCH
							IF @@TRANCOUNT > @tc ROLLBACK TRANSACTION CREATESITEJOB
							set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, error, errorNumber, result)
							values (@site, @ref, @ts, @importTransId, 'CreateSiteJob'+@sitePrefix, ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
							set @Severity = -16
							GOTO RECORDFAIL
						END CATCH

						BEGIN TRY
							declare @kitsite sitetype = isnull(@AssignSite,@Site)

							if @kitsite=@tsite and @KitItem is not null and @PMTCode='M' and @RequestDate < '2220-01-01' begin
							exec iemCommon.dbo.iemLog @job
								declare @reqdatef nvarchar(20)
								set @reqdatef=convert(nvarchar(10),@RequestDate, 21)

								declare @dstr nvarchar(MAX)
								select @dstr = N'UPDATE js
									set start_date = ''' + @ReqDatef + N'''
									from ' + app_db_name + N'.dbo.jrt_sch_mst js join ' + app_db_name + N'.dbo.jobroute_mst jr on js.job=jr.job and js.suffix=jr.suffix and js.oper_num=jr.oper_num
									where jr.wc = ''ISUMAT'' and jr.job=@Job and jr.suffix=@Suffix'
								FROM site WHERE site = @AssignSite

								EXEC sp_executesql @dstr, N'@Job NVARCHAR(20), @Suffix SMALLINT', @Job = @job, @Suffix = @coline;
							end
						END TRY BEGIN CATCH
							declare @log nvarchar(max) = 'Item: '+@titem+' failed to release kit job with error = '+ERROR_MESSAGE()
							exec iemCommon.dbo.iemLog @log
						END CATCH

						set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, actionText, result, co_num, co_line)
						values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'CreateSiteJob'+@sitePrefix, 'Item: '+@titem, 'success', @CoNum, @CoLine);
					end
				end -- site loop
				close scrs
				deallocate scrs
			end -- processing site jobs
			set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, actionText, result, co_num, co_line)
			values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'CreateCOLineAndJobs', 'Item: '+@Item, 'complete', @CoNum, @CoLine);
		end -- manufactured items
	END --co lines
	CLOSE crsCoLines
	DEALLOCATE crsCoLines

	if @discriminator='cn' begin --CN updates (other than new lines)

		delete from @coitem
		SET @SQL = 
			N'SELECT * FROM OPENQUERY(EQUOTE, '
			+ N'''SELECT tli.assignSite, tli.assignWH, tli.partTemplate as Item, tli.description, tli.designation, tli.qty AS QtyOrdered, tli.shipDirectVendor, tli.shipDirectPrice, tli.isShipDirect, tli.kitItem'
			+ N', tli.subTemplate, tli.partType, tli.requestDate, tli.requiredShipDate, (tli.orderUnitPrice+tli.sellprice) as newUnitPrice, tli.co_line, tli.dnum'
			+ N', tli.shiptoName, tli.shiptoCareOf, tli.shiptoAddress1, tli.shiptoAddress2, tli.shiptoAddress3, tli.shiptoAddress4, tli.shiptoCountry, tli.shiptoCity, tli.shiptoState, tli.shiptoPostal, tli.shiptoNumber, tli.customerItem, tli.matlCostBasis, tli.numSections'
			+ N', tli.custPoLine'
			+ N', tli.released,tli.promiseDate' --0002 DMS
			+ N' FROM infororder `of` INNER JOIN erpTopLineItem tli ON of.id = tli.orderId'
			+ N' WHERE of.dnum = ' + @RefString
			+ N' AND tli.deleted IS NULL AND tli.action=''''UPDATE'''' AND of.deleted IS NULL'
			+ N' ORDER BY tli.sequence'' )'

		IF @Debug = 1 PRINT @SQL	

		INSERT INTO @coitem(
			assignSite
			,assignWH
			,Item
			,description
			,designation
			,quantity_ordered
			,vendor
			,vendor_price
			,is_ship_direct
			,kitItem
			,sub_template
			,partType
			,request_date_unix
			,CustomerRequiredShipDate_unix
			,new_unit_price
			,co_line
			,erpTopLineItemId
			,drop_ship_name
			,drop_ship_care_of
			,drop_ship_address1
			,drop_ship_address2
			,drop_ship_address3
			,drop_ship_address4
			,drop_ship_country
			,drop_ship_city
			,drop_ship_state
			,drop_ship_zip
			,drop_ship_number
			,Uf_CustomerItem
			,Uf_matlCostBasis
			,Uf_numSections
			,Uf_CustomerPOLine
			,Uf_Released -- 0002 DMS
			,Promise_Date -- 0002 DMS
		)
		EXEC(@SQL)

		UPDATE @coitem
		SET 
		request_date = cast(DATEADD(SECOND, request_date_unix, @baseUnixDate)+.5 as date)
		, CustomerRequiredShipDate = cast(DATEADD(SECOND, CustomerRequiredShipDate_unix, @baseUnixDate)+.5 as date)
		,description=dbo.soliDescription(description, designation) -- 0002 DMS


		declare @curdate date=GETDATE() --no time


		DECLARE @newUnitPrice DECIMAL(19,8)


		DECLARE crsCoLines CURSOR FORWARD_ONLY FOR
		SELECT 	
			assignSite
			,assignWH
			,Item
			,description
			,designation
			,quantity_ordered
			,vendor
			,is_ship_direct
			,kitItem
			,sub_template
			,partType
			,co_line
			,request_date
			,CustomerRequiredShipDate
			,new_unit_price
			,erpTopLineItemId
			,drop_ship_name
			,drop_ship_care_of
			,drop_ship_address1
			,drop_ship_address2
			,drop_ship_address3
			,drop_ship_address4
			,drop_ship_country
			,drop_ship_city
			,drop_ship_state
			,drop_ship_zip
			,drop_ship_number
			,Uf_CustomerItem
			,Uf_matlCostBasis
			,vendor_price
			,due_date
			,Uf_numSections
			,Uf_CustomerPOLine
			,Uf_Released -- 0002 DMS
			,Promise_Date -- 0002 DMS
		FROM @coitem
		OPEN crsCoLines


		WHILE 1=1
		BEGIN
			FETCH NEXT FROM crsCoLines INTO
				 @assignSite
				,@assignWH
				,@Item
				,@Description
				,@Designation
				,@QtyOrdered
				,@Vendor
				,@shipDirect
				,@kitItem
				,@subTemplate
				,@partType
				,@coLine
				,@reqDate
				,@CustomerRequiredShipDate
				,@newUnitPrice
				,@ErpTopLineItemId
				,@DropShipName
				,@DropShipCareOf
				,@DropShipAddress1
				,@DropShipAddress2
				,@DropShipAddress3
				,@DropShipAddress4
				,@DropShipCountry
				,@DropShipCity
				,@DropShipState
				,@DropShipZip
				,@DropShipNumber
				,@Uf_CustomerItem
				,@Uf_matlCostBasis
				,@vendorprice
				,@dueDate
				,@Uf_numSections
				,@Uf_CustomerPOLine
				,@Uf_Released --0002 DMS
				,@PromiseDate --0002 DMS
			IF @@fetch_status <> 0 break;

			if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and action='UpdateCOLine' and erpTopLineItemId=@ErpTopLineItemId and result='success') begin
				set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, result)
				values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'UpdateCOLine', 'skip');
			end else begin
				
				if exists 
						(select 1 from coitem_mst_all ci 
							where ci.co_num=@conum and ci.co_line=@coLine 
							and (
								--ISNULL(promise_date,'2222-02-22') != ISNULL(@reqDate,'2222-02-22') -- 0002 DMS
								ISNULL(uf_promisedate,'2222-02-22') != ISNULL(@reqDate,'2222-02-22') -- 0002 DMS
								or ISNULL(Uf_CustomerRequiredShipDate,'2222-02-22') <> ISNULL(@CustomerRequiredShipDate,'2222-02-22') 
								or price_conv != @newUnitPrice
								or (Uf_DrawingApprDate is null and @PromiseDate<'2220-01-01' and item like 'SOLI%')  -- 0003 DMS
								or description != @description
								or isnull(Uf_designation,'') != @designation
								or isnull(Uf_CustomerItem,'') != isnull(@Uf_CustomerItem,'')
								or isnull(Uf_matlCostBasis,0) != isnull(@Uf_matlCostBasis,0)
								or (ci.ref_num is null and ci.qty_shipped+ci.qty_invoiced+ci.qty_packed+ci.qty_picked = 0 and ci.item <> @Item) --don't allow updates for anything with a ref or shipping
								or isnull(Uf_numSections,0) != isnull(@Uf_numSections,0)
								or isnull(Uf_assign_site,'') != isnull(@assignSite,'')
								or isnull(Uf_assign_whse,'') != isnull(@assignWH,'')
								or whse <> IIF(@assignsite=site_ref,@assignWH,site_ref)
								or isnull(Uf_CustomerPOLine,'') != isnull(@Uf_CustomerPOLine,'')
								or isnull(Uf_Released,0) != isnull(@Uf_Released,0)
								or isnull(Uf_PromiseDate,'2222-02-22') != isnull(@PromiseDate,'2222-02-22')
							) 
						)
				begin
					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action,actionText, result, co_num)
					values (@site, @ref, @ts, @importTransId, 'UpdateCOLine', @Item, 'begin', @CoNum);

					BEGIN TRY
						BEGIN TRAN UPDATECOITEMDATE 
							set @sql='
							update ci set uf_Released = @Uf_Released, uf_promisedate=@PromiseDate, promise_date=@PromiseDate, Uf_CustomerRequiredShipDate=@CustomerRequiredShipDate, price=@newUnitPrice, price_conv=@newUnitPrice, description=@description, Uf_designation=@designation, Uf_CustomerItem=@Uf_CustomerItem, Uf_matlCostBasis=@Uf_matlCostBasis, item=@Item, Uf_numSections=@Uf_numSections, Uf_assign_site=@assignSite, Uf_assign_whse=@assignWH, whse=IIF(@assignsite=site_ref and @assignWH is not null,@assignWH,site_ref), Uf_CustomerPOLine=@Uf_CustomerPOLine'
							+', Uf_DrawingApprDate=IIF(Uf_DrawingApprDate is null and @PromiseDate<''2220-01-01'' and item like ''SOLI%'', @curdate, Uf_DrawingApprDate) from ' --
							+ @DBNAME + '.dbo.coitem_mst ci 
							where ci.co_num=@conum and ci.co_line=@CoLine' -- 0002 DMS Changed set promise_date=@reqDate to set uf_promisedate=@reqDate. Add uf_released = @Uf_Released. Also Changed uf_promisedate=@reqDate, promise_date=@reqDate to uf_promisedate=@PromiseDate, promise_date=@PromiseDate 

							exec sp_executesql @sql, 
							N'@conum conumtype, @coLine coLineType, @reqDate DateType, @CustomerRequiredShipDate DateType, @newUnitPrice DECIMAL(19,8), @curdate dateType, @description descriptionType, @designation nvarchar(30), @Uf_CustomerItem itemtype, @Uf_matlCostBasis AmountType, @item itemtype, @Uf_numSections int, @assignSite siteType, @assignWH whseType, @Uf_CustomerPOLine int, @Uf_Released int, @PromiseDate DateTime', --0002 DMS Added @Uf_Released int
							@conum, @CoLine, @ReqDate, @CustomerRequiredShipDate, @newUnitPrice, @curdate, @Description, @Designation, @Uf_CustomerItem, @Uf_matlCostBasis, @Item, @Uf_numSections, @AssignSite, @AssignWH, @Uf_CustomerPOLine, @Uf_Released, @PromiseDate
						COMMIT TRAN UPDATECOITEMDATE

					END TRY BEGIN CATCH
						IF XACT_STATE() IN (-1,1) and @@TRANCOUNT > 0
							ROLLBACK TRANSACTION
						IF XACT_STATE() = 1 and @@TRANCOUNT > 0
							ROLLBACK TRANSACTION UPDATECOITEMDATE
				
		
						set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, error, errorNumber, result)
						values (@site, @ref, @ts, @importTransId, 'UpdateCOLine', ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
						set @Severity = -16
						GOTO RECORDFAIL
					END CATCH
					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, actionText, result, co_num, co_line)
					values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'UpdateCOLine', 'Item: '+@Item, 'success', @CoNum, @CoLine);

				end
			end

			if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and action='UpdateSOLIDescription' and erpTopLineItemId=@ErpTopLineItemId and result='success') begin
				set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, result)
				values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'UpdateSOLIDescription', 'skip');
			end else begin
				
				if exists 
						(select 1 from coitem_mst_all ci
						 join item i on i.item=ci.item
							where ci.co_num=@conum and ci.co_line=@coLine 
							and i.description != @description
							and i.item like 'SOLI%'
						)
				begin
					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action,actionText, result, co_num)
					values (@site, @ref, @ts, @importTransId, 'UpdateSOLIDescription', @Item, 'begin', @CoNum);

					BEGIN TRY
						BEGIN TRAN UPDATECOITEMDATE
							exec _IEM_OrderFormCN_UpdateSOLIDescription @Item, @Description
						COMMIT TRAN UPDATECOITEMDATE

					END TRY BEGIN CATCH
						IF XACT_STATE() IN (-1,1) and @@TRANCOUNT > 0
							ROLLBACK TRANSACTION
						IF XACT_STATE() = 1 and @@TRANCOUNT > 0
							ROLLBACK TRANSACTION UPDATECOITEMDATE
				
		
						set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, error, errorNumber, result)
						values (@site, @ref, @ts, @importTransId, 'UpdateSOLIDescription', ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
						set @Severity = -16
						GOTO RECORDFAIL
					END CATCH
					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, actionText, result, co_num, co_line)
					values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'UpdateSOLIDescription', 'Item: '+@Item, 'success', @CoNum, @CoLine);

				end
			end

			if (@DropShipName IS NOT NULL and @DropShipAddress1 is not null)  --djh check shiptonum? <-- djh 2021-09-13 not sure what the plan was...
			or exists (select 1 from coitem_mst_all ci where ci.co_num=@conum and ci.co_line=@coLine and ci.cust_num is not null)
			begin
				if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and action='UpdateCOLineAddr' and erpTopLineItemId=@ErpTopLineItemId and result='success') begin
					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, result, co_num, co_line)
					values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'UpdateCOLineAddr', 'skip', @conum, @CoLine);
				end else begin
					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action,actionText, result, co_num, co_line)
					values (@site, @ref, @ts, @importTransId, 'UpdateCOLineAddr', @ItemTemplate, 'begin', @CoNum, @CoLine);

					if @DropShipName is not null begin -- djh 2019-10-10; do not bother calling if we are setting to the default ship-to
						SET @SQL = @DBNAME+ '.dbo._IEM_OrderFormCN_CreateShipToSp'

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
								,@ShipToCareOf = @DropShipCareOf
								,@ShipToCurrency = @CurrCode
								,@CoNum = @conum
								,@CoLine = @CoLine

						IF @Severity <> 0 BEGIN
							set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, error, Infobar, co_num, co_line, result)
							values (@site, @ref, @ts, @importTransId, 'UpdateCOLineAddr',@InfoBar, @InfoBar, @CoNum, @CoLine, 'fail');
							GOTO RECORDFAIL
						END
					end else begin
						set @DropShipNumber = null
					end

					begin try
						set @sql = 'update ci set ci.cust_num=IIF(@DropShipNumber is null,NULL,@CustNum), ci.cust_seq = ISNULL(@DropShipNumber,0), ci.tax_code1 = cu.tax_code1, ci.tax_code2 = cu.tax_code2 '
						+ ' from ' + @DBNAME+ '.dbo.coitem_mst ci join ' 
						+ @DBNAME + '.dbo.co_mst co on co.co_num = ci.co_num join ' 
						+ @DBNAME + '.dbo.customer_mst cu on cu.cust_seq = ISNULL(@DropShipNumber,co.cust_seq) and cu.cust_num = @CustNum' 
						+ ' where ci.co_num=@conum and co_line=@coLine and (ci.cust_seq <> isnull(@DropShipNumber,0) or ci.cust_num <> @CustNum or ci.cust_num is null)'
						exec sp_executesql @sql, N'@conum conumtype, @custNum CustnumType, @DropShipNumber custseqtype, @coLine coLineType', @conum, @CustNum, @DropShipNumber, @CoLine
					end try begin catch
						set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, error, errorNumber, result)
						values (@site, @ref, @ts, @importTransId, 'UpdateCOLineAddr', 'Error updating cust seq: '+ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
						SET @Severity = -16
						GOTO RECORDFAIL
					end catch

					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, actionText, co_num, co_line, result)
					values (@site, @ref, @ts, @importTransId, 'UpdateCOLineAddr', 'CustNum='+@CustNum+'; DropShipNumber='+cast(@DropShipNumber as nvarchar(4))+'; '+@InfoBar, @CoNum, @CoLine, 'success');

					IF @PerformWritebacks = 1
					BEGIN
						SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT Id, shipToNumber from erpTopLineItem WHERE Id = ' + CAST(@ErpTopLineItemId AS NVARCHAR(20)) + ''') SET shiptoNumber = ''' + CAST(@DropShipNumber AS NVARCHAR(6)) + ''' WHERE ISNULL(shiptoNumber,'''') <> ''' + CAST(@DropShipNumber AS NVARCHAR(6)) + ''''
						EXEC (@SQL)
					END
				end

			END

			if exists (select 1 from coitem_mst_all ci where ci.co_num=@conum and ci.co_line=@coLine and isnull(Uf_ShipDirect,0) <> isnull(@ShipDirect,0))
			begin
				if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and action='UpdateCOLineSD' and erpTopLineItemId=@ErpTopLineItemId and result='success') begin
					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, erpTopLineItemId, action, result, co_num, co_line)
					values (@site, @ref, @ts, @importTransId, @ErpTopLineItemId, 'UpdateCOLineSD', 'skip', @conum, @CoLine);
				end else begin
					set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action,actionText, result, co_num, co_line)
					values (@site, @ref, @ts, @importTransId, 'UpdateCOLineSD', @ItemTemplate, 'begin', @CoNum, @CoLine);

					if @AssignSite=@OrderSite begin
						declare @existingPO PONumType, @existingPOLine POLineType
						set @existingPO=null
						if isnull(@ShipDirect,0) = 0 begin
							select @existingPO = pi.po_num, @existingPOLine = pi.po_line from
							coitem_all ci
							join poitem_all pi on pi.po_num=ci.ref_num and pi.po_line=ci.ref_line_suf
							where ci.co_num=@conum and ci.co_line=@CoLine
						end else begin
							SELECT @Whse = def_whse FROM invparms --fixme if supporting other ship-to warehouses
							SET @SQL = @DBNAME+ '.dbo._IEM_OrderFormCN_CreateShipDirectSp'

							BEGIN TRY
								BEGIN TRAN CREATESHIPDIRECT
									EXEC @Severity =  @SQL
										 @Item = @Item
										,@Description = @Description
										,@CoNum = @conum
										,@CoLine = @CoLine
										,@QtyOrderedConv = @QtyOrdered
										,@ItemDesc = @Description
										,@ItemUM = 'EA'
										,@Whse = @Whse
										,@CustNum = @CustNum
										,@CustSeq = @CustSeq
										,@Vendor = @Vendor
										,@VendorPrice = @VendorPrice
										,@DropShipNumber = @DropShipNumber
										,@DueDate = @DueDate
										,@Infobar = @Infobar OUTPUT						

									If @Severity <> 0 begin --pass error to try/catch
										set @InfoBar=isnull(@Infobar,N'Unknown Error creating ship direct')
										;THROW 50505, @Infobar, 1;
									end

								COMMIT TRAN CREATESHIPDIRECT

							END TRY BEGIN CATCH
								IF XACT_STATE() IN (-1,1) and @@TRANCOUNT > 0
									ROLLBACK TRANSACTION
								IF XACT_STATE() = 1 and @@TRANCOUNT > 0
									ROLLBACK TRANSACTION CREATESHIPDIRECT

								set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, error, errorNumber, result)
								values (@site, @ref, @ts, @importTransId, 'UpdateCOLineSD', 'Error updating ship direct: '+ERROR_MESSAGE(), ERROR_NUMBER(), 'fail');
								SET @Severity = -16
								GOTO RECORDFAIL
							end catch
						end

						begin try
							set @sql = 'update ci set uf_ShipDirect = isnull(cast(@ShipDirect as nvarchar(1)),NULL) '+
							+ IIF(@ShipDirect=1, '', ' , ref_type = ''I'', ref_num = NULL, ref_line_suf = NULL, ref_release = 0')
							+ ' from ' + @DBNAME+ '.dbo.coitem_mst ci ' 
							+ ' where ci.co_num=@conum and co_line=@coLine '
							exec sp_executesql @sql, N'@conum conumtype, @coLine coLineType, @ShipDirect ListYesNoType', @conum, @CoLine, @ShipDirect
						end try begin catch
							set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, error, errorNumber, result)
							values (@site, @ref, @ts, @importTransId, 'UpdateCOLineSD', 'Error updating SD: '+ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
							SET @Severity = -16
							GOTO RECORDFAIL
						end catch

						if @existingPO is not null begin
							begin try
								set @sql = 'update pi set qty_ordered = 0, qty_ordered_conv = 0, stat=''C'' '+
								+ ' from ' + @DBNAME+ '.dbo.poitem_mst pi ' 
								+ ' where pi.po_num = @poNum and pi.po_line = @poLine and pi.stat=''P'''
								exec sp_executesql @sql, N'@poNum ponumtype, @poLine poLineType', @existingPO, @existingPOLine
							end try begin catch
								set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, error, errorNumber, result)
								values (@site, @ref, @ts, @importTransId, 'UpdateCOLineSD', 'Error cancelling PO: '+ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
								SET @Severity = -16
								GOTO RECORDFAIL
							end catch
						end
					end else begin --assignsite<>ordersite
						begin try
							set @sql = 'update ci set uf_ShipDirect = isnull(cast(@ShipDirect as nvarchar(1)),NULL) '+
							+ IIF(@ShipDirect=1, '', ' , ref_type = ''T''')
							+ ' from ' + @DBNAME+ '.dbo.coitem_mst ci ' 
							+ ' where ci.co_num=@conum and co_line=@coLine '
							exec sp_executesql @sql, N'@conum conumtype, @coLine coLineType, @ShipDirect ListYesNoType', @conum, @CoLine, @ShipDirect
						end try begin catch
							set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, error, errorNumber, result)
							values (@site, @ref, @ts, @importTransId, 'UpdateCOLineSD', 'Error updating SD: '+ERROR_MESSAGE(),ERROR_NUMBER(), 'fail');
							SET @Severity = -16
							GOTO RECORDFAIL
						end catch
					end
				end					

				set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId,action, actionText, co_num, co_line, result)
				values (@site, @ref, @ts, @importTransId, 'UpdateCOLineSD', 'SD=' + cast(isnull(@ShipDirect,0) as nvarchar(1)) + '; DropShipNumber='+cast(@DropShipNumber as nvarchar(4))+'; '+@InfoBar, @CoNum, @CoLine, 'success');
			end
		END
		close crsCoLines
		deallocate crsCoLines

	end



	-- Writeback, infororder
	IF @PerformWritebacks = 1
	BEGIN
		SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT dnum, customerOrderNumber, phase from infororder WHERE dnum = ' + @RefString + ''') SET customerOrderNumber = ''' + LTRIM(@CoNum) + ''', phase = '''+@phaseDone+''''
		EXEC (@SQL)
	END

	IF @Severity = 0
	IF @discriminator='cn' BEGIN
		SET @Infobar = 'CN ' + @RefString + ' processed (ADD lines imported, and dates/prices updated for Order ' + LTRIM(@CoNum) + ').'
	END ELSE BEGIN
		SET @Infobar = 'Order ' + LTRIM(@CoNum) + ' created from import.'
	END
	IF @linesInserted = 1 BEGIN
		update co set stat = 'O' where co_num = @CoNum and stat <> 'O'
	END

	set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, result, co_num, infobar)
	values (@site, @ref, @ts, @importTransId, 'Import', 'success', @conum, @InfoBar);

	GOTO EXITSP
RECORDFAIL:
	set @ts += 1; insert into _IEM_OrderFormCNLog_mst (site_ref, ref, tseq, importTransId, action, result, Infobar)
	values (@site, @ref, @ts, @importTransId, 'Import', 'fail', 'Failed to import order - see log');
EXITSP:

	RETURN @Severity
END
GO

