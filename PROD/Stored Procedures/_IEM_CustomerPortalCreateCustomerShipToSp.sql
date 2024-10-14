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
ALTER PROCEDURE [dbo].[_IEM_CustomerPortalCreateCustomerShipToSp] (
  @CustNum                CustNumType,
  @CustSeq                NVARCHAR(10) OUTPUT,
  @Name                   NameType,
  @Addr1                  AddressType,
  @Addr2                  AddressType,
  @Addr3                  AddressType,
  @Addr4                  AddressType,
  @City                   CityType,
  @County                 CountyType,
  @State                  StateType,
  @PostalCode             PostalCodeType,
  @Country                CountryType,
  @ResellerSlsman         SlsmanType ,
  @ShipToContactName      NameType,
  @ShipToContactPhone     PhoneType,
  @ShipToContactFax       PhoneType,
  @ShipToContactEmail     EmailType,
  @PrimarySiteFlag        ListYesNoType,  -- Set to 1 if the stored procedure is called for the Primary Site
  @BillToFlag             ListYesNoType,  -- Set to 1 if the stored procedure is called to update customer bill to record (that is cust_seq = 0)
  @AddressChanged         ListYesNoType,  -- Set to 1 when the ship to address country, state or zip was changed
  @OrderSite			SiteType,
  @Infobar                InfobarType OUTPUT
) AS
BEGIN
 
	-- Declare Variables
	Declare
		 @Severity INT
		,@Site  SiteType
		,@Debug ListYesNoType

	SET @Severity = 0
	SET @Debug = 1

	IF @Site IS NULL
	BEGIN
		SELECT TOP 1 @Site = site
		FROM site
		WHERE app_db_name = DB_NAME()
	END

	IF @Site = @OrderSite
		SET @PrimarySiteFlag = 1
	ELSE
		SET @PrimarySiteFlag= 0

	EXEC dbo.SetSiteSp @Site, @Infobar OUTPUT

	SET @CustSeq = NULL

	IF @Debug = 1
		PRINT 'Calling CustomerPortalCreateCustomerShipToSp'

	EXEC @Severity = dbo.CustomerPortalCreateCustomerShipToSp
		@CustNum,
		@CustSeq OUTPUT,
		@Name,
		@Addr1,
		@Addr2,
		@Addr3,
		@Addr4,
		@City,
		@County,
		@State,
		@PostalCode,
		@Country,
		@ResellerSlsman,
		@ShipToContactName,
		@ShipToContactPhone,
		@ShipToContactFax,
		@ShipToContactEmail,
		@PrimarySiteFlag,
		@BillToFlag,
		@AddressChanged,
		@Infobar OUTPUT

	IF @Debug = 1
	BEGIN
		PRINT 'Back from CustomerPortalCreateCustomerShipToSp.'
		PRINT '@Infobar contents after call...'
		PRINT @Infobar
	END

	RETURN @Severity

END




GO

