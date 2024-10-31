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
ALTER PROCEDURE [dbo].[_IEM_CreateCoSp] (
	 @CustNum CustNumType
	,@BillToSeq CustSeqType
	,@CustSeq CustSeqType
	,@CustPo CustPoType
	,@OrderDate DateType
	,@PromiseDate DateType
	,@EstShipDate DateType
	,@CustName NameType
	,@SubTotal CostPrcType
	,@Freight CostPrcType
	,@SalesTax CostPrcType
	,@ExtPrice CostPrcType
	,@CurrCode CurrCodeType
	,@ReqDate DateType
	,@TotalWeight WeightType
	,@Whse WhseType
	,@OrderSite SiteType
	,@CoNum CoNumType OUTPUT
	,@Infobar InfobarType OUTPUT
	,@ProjectManager UsernameType
	,@JobName NVARCHAR(60)
	,@EngineeringSubmittal NVARCHAR(10)
	,@ContactName NameType
	,@ContactPhone PhoneType
	,@ContactEmail EmailType
	,@Slsman SlsmanType
	,@Slsman2 SlsmanType
    ,@OrderShipCode ShipCodeType
	,@EndUserType EndUserTypeType
) AS
BEGIN

	DECLARE 
		 @Severity INT
		,@Prefix NVARCHAR(6)
		,@TaxMode1         TaxModeType
		,@TaxMode2         TaxModeType
		,@ExchRate         ExchRateType     
		,@TaxCode1Type     LongListType
		,@TaxCode1         TaxCodeType    
		,@TaxCode2Type     LongListType
		,@TaxCode2         TaxCodeType    
		,@FrtTaxCode1Type  LongListType
		,@FrtTaxCode1      TaxCodeType    
		,@FrtTaxCode2Type  LongListType
		,@FrtTaxCode2      TaxCodeType    
		,@MiscTaxCode1Type LongListType
		,@MiscTaxCode1     TaxCodeType    
		,@MiscTaxCode2Type LongListType
		,@MiscTaxCode2     TaxCodeType    
		,@iCustSeq			CustSeqType
		,@oNewCoNum			CoNumType
		,@ShipmentExists	ListYesNoType
		,@ShipToAddress		AddressType
		,@CoRowPointer		RowPointerType
		,@BillToAddress		AddressType
		,@ShipCode			ShipCodeType
		,@Contact			NameType
		,@Phone				PhoneType
		,@ShipPartial		ListYesNoType
		,@BillToContact		NameType
		,@ShipEarly			ListYesNoType
		,@CusUseExchRate	ListYesNoType
		,@BillToPhone		PhoneType
		,@CustSlsman			SlsmanType
		,@Consolidate		ListYesNoType
		,@ShipToContact		NameType
		,@Summarize			ListYesNoType
		,@ShipToPhone		PhoneType
		,@InvFreq			InvFreqType
		,@CorpCust			CustNumType
		,@EInvoice			ListYesNoType
		,@CorpCustName		NameType
		,@TermsCode			TermsCodeType
		,@CorpCustContact	NameType
		,@PriceCode			PriceCodeType
		,@CorpCustPhone		PhoneType
		,@CustomerEndUserType		EndUserTypeType
		,@CorpAddress		AddressType
		,@ApsPullUp			ListYesNoType
		,@UseExchRate		ListYesNoType
		,@TransNat			TransNatType
		,@TransNat2			TransNat2Type
		,@ShipCodeDesc		DescriptionType
		,@DelTerm			DeltermType
		,@TermsCodeDesc		DescriptionType
		,@ProcessInd		ProcessIndType
		,@Site				SiteType
		,@CusLcrReqd		ListYesNoType
		,@OnCreditHold		ListYesNoType
		,@ShipmentApprovalRequired	ListYesNoType
		,@Debug ListYesNoType
		,@ShipHold			Flag

	DECLARE @UserName Nvarchar(30)
	set @username = dbo.UserNameSp()


	SET @Severity = 0
	SET @Debug = 1

	IF @Debug = 1
		PRINT '@CustNum value coming into procedure:  ' + @CustNum

	IF @Site IS NULL
	BEGIN
		SELECT TOP 1 @Site = site
		FROM site
		WHERE app_db_name = DB_NAME()
	END

	IF @Debug = 1
	BEGIN
		PRINT 'Calling SetSiteSp'
		PRINT @Site
	END

	BEGIN TRANSACTION
	EXEC @Severity = dbo.SetSiteSp @Site, @Infobar OUTPUT

	IF @Severity <> 0
		RETURN @Severity
		
	COMMIT TRANSACTION

	IF @Debug = 1
	BEGIN
		PRINT 'CONTEXT_INFO()=''' + CAST(CONTEXT_INFO() AS NVARCHAR(8)) + ''''
	END

	SET @iCustSeq = @CustSeq 

	-- If order already exists, return success
	IF EXISTS(SELECT * FROM co WHERE co_num = @CoNum)
		RETURN @Severity

	-- Get order prefix from parameters
	SELECT @Prefix = co_prefix
	FROM coparms (NOLOCK)
	
	-- Gather tax information
	SELECT @TaxMode1 = tax_mode 
	FROM tax_system (NOLOCK)
	WHERE tax_system = 1
	
	SELECT @TaxMode2 = tax_mode 
	FROM tax_system (NOLOCK)
	WHERE tax_system = 1

	IF @TaxMode1 = 'A'
	BEGIN
		SET @TaxCode1Type = 'R'
		SET @FrtTaxCode1Type = 'E'
		SET @MiscTaxCode1Type = 'E'
	END
	ELSE IF @TaxMode1 = 'I'
	BEGIN
		SET @TaxCode1Type = 'E'
		SET @FrtTaxCode1Type = 'R'
		SET @MiscTaxCode1Type = 'R'
	END

	IF @TaxMode2 = 'A'
	BEGIN
		SET @TaxCode2Type = 'R'
		SET @FrtTaxCode2Type = 'E'
		SET @MiscTaxCode2Type = 'E'
	END
	ELSE IF @TaxMode2 = 'I'
	BEGIN
		SET @TaxCode2Type = 'E'
		SET @FrtTaxCode2Type = 'R'
		SET @MiscTaxCode2Type = 'R'
	END  

	SET @CustSeq = @iCustSeq   -- CoCustomerValid2Sp will reset the custseq to default custseq 0

	-- Standard SyteLine validation call
	EXEC @Severity = CoCustomerValid2Sp
		  @oNewCoNum
		, NULL   --@RowPointer
		, NULL   --@OldCustNum
		, @OrderDate
		, @ExchRate            OUTPUT
		, @CustNum             OUTPUT
		, @CustSeq             OUTPUT
		, @ShipmentExists      OUTPUT
		, @BillToAddress       OUTPUT
		, @ShipToAddress       OUTPUT
		, @Contact             OUTPUT
		, @Phone               OUTPUT
		, @BillToContact       OUTPUT
		, @BillToPhone         OUTPUT
		, @ShipToContact       OUTPUT
		, @ShipToPhone         OUTPUT
		, @CorpCust            OUTPUT
		, @CorpCustName        OUTPUT
		, @CorpCustContact     OUTPUT
		, @CorpCustPhone       OUTPUT
		, @CorpAddress         OUTPUT
		, @CurrCode            OUTPUT
		, @UseExchRate         OUTPUT
		, @Whse                OUTPUT
		, @ShipCode            OUTPUT
		, @ShipCodeDesc        OUTPUT
		, @ShipPartial         OUTPUT
		, @ShipEarly           OUTPUT
		, @Consolidate         OUTPUT
		, @Summarize           OUTPUT
		, @InvFreq             OUTPUT
		, @Einvoice            OUTPUT
		, @TermsCode           OUTPUT
		, @TermsCodeDesc       OUTPUT
		, @CustSlsman              OUTPUT
		, @PriceCode           OUTPUT
		, NULL--@PriceCodeDesc       OUTPUT
		, @CustomerEndUserType         OUTPUT
		, NULL--@EndUserTypeDesc     OUTPUT
		, @ApsPullUp           OUTPUT
		, @TaxCode1Type     
		, @TaxCode1            OUTPUT
		, NULL--@TaxDesc1            OUTPUT
		, @TaxCode2Type    
		, @TaxCode2            OUTPUT
		, NULL--@TaxDesc2            OUTPUT
		, @FrtTaxCode1Type  
		, @FrtTaxCode1         OUTPUT
		, NULL--@FrtTaxDesc1         OUTPUT
		, @FrtTaxCode2Type  
		, @FrtTaxCode2         OUTPUT
		, NULL--@FrtTaxDesc2         OUTPUT
		, @MiscTaxCode1Type 
		, @MiscTaxCode1        OUTPUT
		, NULL--@MiscTaxDesc1        OUTPUT
		, @MiscTaxCode2Type 
		, @MiscTaxCode2        OUTPUT
		, NULL--@MiscTaxDesc2        OUTPUT
		, @TransNat            OUTPUT
		, @TransNat2           OUTPUT
		, @Delterm             OUTPUT
		, @ProcessInd          OUTPUT
		, @CusLcrReqd          OUTPUT
		, @CusUseExchRate      OUTPUT
		, @OnCreditHold        OUTPUT
		, @Infobar             OUTPUT
		, @ShipmentApprovalRequired OUTPUT
		, @ShipHold				OUTPUT
	
	IF @Severity <> 0
		RETURN @Severity	

	IF @FrtTaxCode1 IS NULL SET @FrtTaxCode1 = (SELECT TOP 1 frt_tax_code FROM tax_system WHERE tax_system = 1) -- DBH 2017-12-08
	IF @MiscTaxCode1 IS NULL SET @MiscTaxCode1 = (SELECT TOP 1 misc_tax_code FROM tax_system WHERE tax_system = 1) -- DBH 2017-12-08

   IF @iCustSeq <> 0
   BEGIN
      -- Standard SyteLine validation call
      EXEC @Severity = CoCustSeqValidSp
                       @CustNum
                     , @iCustSeq
                     , @ShipToAddress       OUTPUT
                     , @Whse                OUTPUT
                     , @ShipCode            OUTPUT
                     , @ShipPartial         OUTPUT
                     , @ShipEarly           OUTPUT
                     , @CustSlsman          OUTPUT
                     , @TaxCode1            OUTPUT
                     , @TaxCode2            OUTPUT
                     , @ShipToContact       OUTPUT
                     , @ShipToPhone         OUTPUT
                     , @Infobar             OUTPUT
					 , @ShipHold			OUTPUT
	END

	SET @CoRowPointer = NEWID()

	BEGIN TRANSACTION
   
   -- Get next available CO number
	EXEC @Severity = NextCoSp
		 NULL
		,@Prefix 
		,10
		,@oNewCoNum OUTPUT
		,@Infobar   OUTPUT

      IF @Severity <> 0
         RETURN @Severity

	IF NOT EXISTS(SELECT * FROM slsman WHERE slsman = @Slsman)
		SET @Slsman = NULL



	BEGIN TRANSACTION
	EXEC @Severity = dbo.SetSiteSp @Site, @Infobar OUTPUT
	COMMIT TRANSACTION

	IF @Debug = 1
	BEGIN
		PRINT 'Creating co record'
		PRINT 'CustNum=''' + @CustNum + ''''
		PRINT 'CustSeq=' + CAST(@iCustSeq AS NVARCHAR(10))
		PRINT 'Site=' + @SIte
		PRINT 'CONTEXT_INFO()=''' + CAST(CONTEXT_INFO() AS NVARCHAR(8)) + ''''
		PRINT DB_NAME()
	END
	-- Create Customer Order

/*
	DECLARE @commission1 decimal
	DECLARE @eligible ListYesNoType
	set @Slsman = ISNULL(@Slsman, @CustSlsman)

	exec _IEM_ValidateCommissionSP @Slsman, @CustNum, @eligible output
	if @eligible = 1 set @commission1 = 1.0 else set @commission1 = 0.0
*/

	BEGIN TRY
		INSERT INTO co(
			  RowPointer
			, co_num
			, type
			, cust_num
			, cust_seq
			, order_date
			, whse
			, stat
			, contact
			, phone
			, use_exch_rate
			, ship_code
			, ship_partial
			, ship_early
			, consolidate
			, summarize
			, inv_freq
			, einvoice
			, terms_code
			, slsman
			, pricecode
			, end_user_type
			, aps_pull_up
			, tax_code1
			, tax_code2
			, frt_tax_code1
			, frt_tax_code2
			, msc_tax_code1
			, msc_tax_code2
			, trans_nat
			, trans_nat_2
			, delterm
			, process_ind
			, orig_site
			, exch_rate
			, cust_po
			, taken_by
			, freight
			, sales_tax
			, price
			--, Uf_EngineeringSubmittal
			--, Uf_ContactEmail
			--, Uf_ProjectManager
			--, Uf_JobName
			--, Uf_CommMult1
			--, Uf_Slsman2
			--, demanding_site
		)
		VALUES(
			  @CoRowPointer
			, @oNewCoNum
			, 'R' 
			, @CustNum
			, @iCustSeq
			, @OrderDate
			, @Whse
			, 'O' 
			, @ContactName
			, @ContactPhone
			, @CusUseExchRate
			, ISNULL(@OrderShipCode, @ShipCode)
			, @ShipPartial
			, @ShipEarly
			, @Consolidate
			, @Summarize
			, @InvFreq
			, @EInvoice
			, @TermsCode
			, ISNULL(@Slsman, @CustSlsman)
			, @PriceCode
			, ISNULL(@EndUserType, @CustomerEndUserType)
			, @ApsPullUp
			, @TaxCode1
			, @TaxCode2
			, @FrtTaxCode1
			, @FrtTaxCode2
			, @MiscTaxCode1
			, @MiscTaxCode2
			, @TransNat
			, @TransNat2
			, @DelTerm
			, @ProcessInd
			, @Site
			, @ExchRate
			, @CustPo
			, 'EQUOTE'
			, ISNULL(@Freight,0)
			, @SalesTax
			, 0
			--, @EngineeringSubmittal
			--, @ContactEmail
			--, @ProjectManager
			--, @JobName
			--, @commission1
			--, @Slsman2
			--, @OrderSite
		)
	END TRY
	BEGIN CATCH
		SET @Infobar = ERROR_MESSAGE()

		IF @Debug = 1
		BEGIN
			PRINT @Infobar
			PRINT 'Error inserting co'
		END

		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION

		RETURN 16
	END CATCH

	COMMIT TRANSACTION	

	EXEC InitSessionContextWithUserSp -- context wiped out by insert co? djh 2016-6-19
     @ContextName = '_IEM_CustomerOrderCreateSp'
   , @SessionID   = NULL
   , @Site        = @Site
   , @UserName    = @UserName
	
	UPDATE co
	SET stat = 'O'
	WHERE co_num = @oNewCoNum
		AND stat <> 'O'

	UPDATE co
	set CreatedBy = @UserName
	WHERE co_num = @oNewCoNum
	
	SET @CoNum = @oNewCoNum

END


GO

