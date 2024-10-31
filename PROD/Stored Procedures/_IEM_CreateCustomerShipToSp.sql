SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/**************************************************************************
*                            Modification Log
*                                            
* Ref#  Init Date     Description           
* ----- ---- -------- ----------------------------------------------------- 
*        DBH   100617  Removed references to Uf_CareOf and State Sales Tax
* MOD100 JWP   090115  eQuote to SyteLine interface
***************************************************************************/
ALTER PROCEDURE [dbo].[_IEM_CreateCustomerShipToSp](
	 @CustNum CustNumType
	,@Name NameType
	,@Addr1 AddressType
	,@Addr2 AddressType
	,@Addr3 AddressType
	,@Addr4 AddressType
	,@Country CountryType
	,@City CityType
	,@State StateType
	,@PostalCode PostalCodeType
	,@OrderSite SiteType
	,@CustSeq NVARCHAR(10) OUTPUT
	,@Infobar InfobarType OUTPUT
	,@ShipToContactName NameType
	,@ShipToContactPhone PhoneType
	,@ShipToContactFax PhoneType
	,@ShipToContactEmail EmailType
	,@ShipToCareOf AddressType
	,@ShipToCurrency CurrCodeType
)
AS
BEGIN

	DECLARE
		 @Severity INT
		,@County CountyType
		,@ResellerSlsman SlsmanType
		,@PrimarySiteFlag ListYesNoType
		,@BillToFlag ListYesNoType
		,@AddressChanged ListYesNoType
		,@Site SiteType
		,@Debug ListYesNoType
		,@TaxCode NVARCHAR(6)
		,@TaxCode2 NVARCHAR(6)

	SET @Severity = 0
	SET @BillToFlag = 0
	SET @Debug = 1

	IF @Debug = 1
		PRINT 'In _IEM_CreateCustomerShipToSp'

	IF @Site IS NULL
	BEGIN
		SELECT TOP 1 @Site = site
		FROM site
		WHERE app_db_name = DB_NAME()
	END

	EXEC dbo.SetSiteSp @Site, @Infobar OUTPUT
	
	IF EXISTS(
		SELECT * 
		FROM custaddr 
		WHERE 
			cust_num = @CustNum 
			AND ISNULL(name,'') = ISNULL(@Name,'')
			AND ISNULL(addr##1,'') = ISNULL(@Addr1,'') 
			AND ISNULL(addr##2,'') = ISNULL(@Addr2,'') 
			AND ISNULL(addr##3,'') = ISNULL(@Addr3,'') 
			AND ISNULL(addr##4,'') = ISNULL(@Addr4,'') 
			AND ISNULL(city,'') = ISNULL(@City,'') 
			AND ISNULL(state,'') = ISNULL(@State,'') 
			AND ISNULL(zip,'') = ISNULL(@PostalCode,'')
			--AND ISNULL(Uf_CareOf,'') = ISNULL(@ShipToCareOf,'')
			AND ISNULL(curr_code,'') = ISNULL(@ShipToCurrency,'')
		)
	BEGIN
		IF @Debug = 1
			PRINT 'Customer ship-to record found.'

		SELECT @CustSeq = cust_seq
		FROM custaddr
		WHERE 
			cust_num = @CustNum 
			AND ISNULL(name,'') = ISNULL(@Name,'')
			AND ISNULL(addr##1,'') = ISNULL(@Addr1,'') 
			AND ISNULL(addr##2,'') = ISNULL(@Addr2,'') 
			AND ISNULL(addr##3,'') = ISNULL(@Addr3,'') 
			AND ISNULL(addr##4,'') = ISNULL(@Addr4,'') 
			AND ISNULL(city,'') = ISNULL(@City,'') 
			AND ISNULL(state,'') = ISNULL(@State,'') 
			AND ISNULL(zip,'') = ISNULL(@PostalCode,'')
			--AND ISNULL(Uf_CareOf,'') = ISNULL(@ShipToCareOf,'')

		--UPDATE customer
		--SET contact##2 = @ShiptoContactName
		--	, phone##2 = @ShiptoContactPhone 
		--WHERE cust_num = @CustNum
		--	AND cust_seq = @CustSeq

		--UPDATE custaddr
		--SET ship_to_email = @ShiptoContactEmail
		--WHERE cust_num = @CustNum
		--	AND cust_seq = @CustSeq
		IF @CustSeq IS NOT NULL
		BEGIN
			IF NOT EXISTS(SELECT * FROM customer WHERE cust_num = @CustNum AND cust_seq = @CustSeq)
			BEGIN
				SET @Severity = 16
				SET @Infobar = 'Customer: ' + @CustNum + ', Ship-To: ' + @CustSeq + char(13) + 'Address matched orderform address, but must be enabled in site ' + @Site + ' before quote can be imported.'
				RETURN @Severity
			END
		END

		RETURN @Severity
	END

	IF @Debug = 1
	BEGIN
		PRINT 'No existing ship-to found.'
		PRINT 'Checking for valid bill-to.'
	END

	IF NOT EXISTS(SELECT * FROM customer_mst_all WHERE cust_num = @CustNum AND cust_seq = 0)
	BEGIN
		IF @Debug = 1
		BEGIN
			PRINT 'No valid bill-to record found for customer:  ' + @CustNum
		END

		SET @Severity = 16
		SET @Infobar = 'No bill-to exists for customer ' + @CustNum + '.'
		RETURN @Severity
	END

	IF @Debug = 1
		PRINT 'Valid bill-to found.'

	--SELECT @Country = cu.country
	--FROM custaddr_mst cu 
	--WHERE site_ref = @Site AND cust_num = @CustNum AND cust_seq = 0

	

	SET @PrimarySiteFlag = 1

	IF @Debug = 1
		PRINT 'Creating ship-to record '

	BEGIN TRANSACTION

	EXECUTE @Severity = [dbo].[_IEM_CustomerPortalCreateCustomerShipToSp] 
		 @CustNum
		,@CustSeq OUTPUT
		,@Name
		,@Addr1
		,@Addr2
		,@Addr3
		,@Addr4
		,@City
		,@County
		,@State
		,@PostalCode
		,@Country
		,@ResellerSlsman
		,NULL--@ShipToContactName
		,NULL --@ShipToContactPhone
		,NULL --@ShipToContactFax
		,NULL --@ShipToContactEmail
		,@PrimarySiteFlag
		,@BillToFlag
		,@AddressChanged
		,@OrderSite
		,@Infobar OUTPUT

/*
	EXEC _IEM_StateTaxableSP
		@State = @State
		,@CustNum = @CustNum
		,@TaxCode = @TaxCode OUTPUT
		,@TaxCode2 = @TaxCode2 OUTPUT
*/

		
/*
	UPDATE custaddr
	SET Uf_CareOf = @ShipToCareOf, curr_code = @ShipToCurrency
	WHERE cust_num = @CustNum
		AND cust_seq = @CustSeq
*/

/*
	UPDATE customer 
	SET tax_code1 = @TaxCode
		, tax_code2 = @TaxCode2 
	WHERE cust_num = @CustNum
		AND cust_seq = @CustSeq
*/


	--SELECT * FROM customer WHERE cust_num = @CustNum AND cust_seq = @CustSeq
	IF @Debug = 1
		PRINT 'Shipto created:  ' + CAST(@CustSeq AS NVARCHAR(4))
	IF @Severity = 0
		COMMIT TRANSACTION

	RETURN @Severity

END








GO

