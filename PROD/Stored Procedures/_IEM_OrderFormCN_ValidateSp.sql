SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*----------------------------------------------------------------------------------*\

	     File: _IEM_OrderFormCN_ValidateSp
  Description: 

  Change Log:
  Date        Ref #   Author       Description\Comments
  ---------  ------  -----------  -------------------------------------------------------------
  2023/08   0001	 CSI Team  	  Per testing in 2023/08 this SP does not need the 
								  UET Uf_Revenue or PASS etc. 
  2024/04   0002     DMS          Add support for validating Uf_Release and Uf_PromiseDate
\*---------------------------------------------------------------------------------*/

/*
use fre_app
exec setsitesp 'FRE',''
delete from SessionContextNames where processid=@@spid
--select dbo.usernamesp()
declare @infobar infobartype
exec _IEM_OrderFormCN_ValidateSp 84436, 16831, null, @infobar output
select @infobar
*/

ALTER PROCEDURE [dbo].[_IEM_OrderFormCN_ValidateSp](
	@ref			INT,
	@Price			decimal(20,2),
	@importTransId	int OUTPUT,
	@InfoBar 		InfoBarType OUTPUT,
	@forcerestart	int = null
) AS
BEGIN
	
	DECLARE @Severity INT
		,@SQL NVARCHAR(MAX)
		,@ID INT
		,@Debug ListYesNoType
		,@phaseReady NVARCHAR(20)
		,@orderFormType NVARCHAR(20)
		,@discriminator NVARCHAR(45)
		,@phase NVARCHAR(45)
		,@conum nvarchar(10)
		,@CNCo coNumType
		,@CustNum CustNumType
		,@shiptoSeq INT
		,@orderSite SiteType
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
		, @ShipToChange int
		, @CurrCode currcodetype
		, @FRE_Site SiteType
		, @JAX_Site SiteType
		, @VAN_Site SiteType
		, @shiptoInfoBar infobartype
		, @EndUserType EndUserTypeType
		, @Uf_CustomerItem ItemType
		, @Uf_matlCostBasis AmountType
		, @ShipHold ListYesNoType
		, @Uf_CustomerPOLine int
		, @Uf_Released ListYesNoType
		, @Uf_PromiseDate DateTime

	declare @baseUnixDate datetime = Dateadd(hh, Datediff(hh, Getutcdate(), Getdate()), {d '1970-01-01'})


	SET @Severity = 0
	set @importTransId = NULL

	IF @ref IS NULL or @Price is null BEGIN
		SET @Infobar = 'Please enter a ref and a price'
		RETURN 16
	END

	DECLARE @IDs TABLE(
		discriminator NVARCHAR(45)
		,[id] INT
		,phase NVARCHAR(40)
		,co_num NVARCHAR(30)
		,cust_num CustNumType
		,order_site SiteType
		,shipto_seq INT
		,cust_name NVARCHAR(60)
		,ship_addr_1 NVARCHAR(50)
		,ship_addr_2 NVARCHAR(50)
		,ship_addr_3 NVARCHAR(50)
		,ship_addr_4 NVARCHAR(50)
		,ship_addr_city NVARCHAR(30)
		,ship_addr_state NVARCHAR(5)
		,ship_addr_postal NVARCHAR(10)
		,ship_addr_country NVARCHAR(30)
		,shipto_care_of NVARCHAR(40)
		,curr_code NVARCHAR(3)
		,end_user_type EndUserTypeType
		,ship_hold ListYesNoType
	)

	DECLARE @SellPrices TABLE(
		sellPrice DECIMAL(20,8)
	)

	declare @lastimportid int = null
	select @lastimportid = max(importTransId) from _IEM_OrderFormCNLog where ref=@ref

	SET @SQL =	'SELECT discriminator, id, phase, customerOrderNumber, customerNumber, orderSite, shiptoNumber, shiptoName'
				+ ', shiptoAddress1, shiptoAddress2, shiptoAddress3, shiptoAddress4, shiptoCity'
				+ ', shiptoState, shiptoPostal, shiptoCountry, shiptoCareOf, currency, endUserType, shipHold '
				+ ' FROM infororder WHERE deleted IS NULL AND dnum = ' + CAST(@ref AS NVARCHAR(10))

	SET @SQL = 'SELECT * FROM OPENQUERY(EQUOTE, ''' + @SQL + ''')'
	

	INSERT INTO @IDs(discriminator,[id], phase, co_num, cust_num, order_site, shipto_seq, cust_name, ship_addr_1, ship_addr_2, ship_addr_3, ship_addr_4, ship_addr_city, ship_addr_state, ship_addr_postal, ship_addr_country, shipto_care_of, curr_code, end_user_type, ship_hold)
	EXEC (@SQL)


	SELECT TOP 1 @discriminator=discriminator,@phase=phase,@conum=co_num,@CustNum=cust_num, @shiptoSeq=shipto_seq, @orderSite=order_site, @CurrCode=curr_code, @EndUserType=end_user_type, @ShipHold = ship_hold from @IDs
	set @CNCo = dbo.ExpandKyByType('CoNumType', @conum)

	SELECT TOP 1 @FRE_Site = site FROM site	WHERE site like '%FRE%'	AND type = 'S'
	SELECT TOP 1 @JAX_Site = site FROM site	WHERE site like '%JAX%'	AND type = 'S'
	SELECT TOP 1 @VAN_Site = site FROM site	WHERE site like '%VAN%'	AND type = 'S'
	-- SELECT TOP 1 @PASS_Site = site FROM site WHERE site like '%PASS%' AND type = 'S' -- IEM Jason Tira 08-25-2023 

	IF @OrderSite = 'FRE' SET @OrderSite = @FRE_Site
	ELSE IF @OrderSite = 'JAX' SET @OrderSite = @JAX_Site
	ELSE IF @OrderSite = 'VAN' SET @OrderSite = @VAN_Site
	-- ELSE IF @OrderSite = 'PASS' SET @OrderSite = @PASS_Site -- IEM Jason Tira 08-25-2023 

	IF (SELECT TOP 1 app_db_name FROM site where site=@orderSite) IS NULL
	BEGIN
		SET @Severity = 16
		SET @Infobar = 'Invalid site: '+isnull(@orderSite,'<null>')
		RETURN @Severity
	END

	IF @discriminator = 'cn' AND @conum IS NULL
	BEGIN
		SET @Severity = 16
		SET @Infobar = 'Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' is a change notice, but has no customer order number.'
		RETURN @Severity
	END

	IF @discriminator IS NULL AND @conum IS NOT NULL and @lastimportid is null --djh 2018-04-10; if last import id set then we are resuming.  don't warn about conum
	BEGIN
		SET @Severity = 16
		SET @Infobar = 'Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' is a new order, but already has a customer order number ('+@conum+').'
		RETURN @Severity
	END

	IF @discriminator = 'cn' BEGIN
		SET @phaseReady='CN_READY'
		SET @orderFormType='Change Notice'
	END ELSE BEGIN
		SET @phaseReady='ORDER_FORM_READY'
		SET @orderFormType='Order Form'
	END

	if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and importTransId = @lastimportid and action='Import' and result='success') begin
		select @conum=co_num from _IEM_OrderFormCNLog where ref=@ref and importTransId = @lastimportid and action='Import' and result='success'
		set @InfoBar = 'Import of '+@orderFormType + ' Ref# ' + CAST(@ref AS NVARCHAR(10))+' has already completed successfully as order '+ltrim(@conum)+' (importtransid='+CAST(@lastimportid AS NVARCHAR(10))+')'
		RETURN 16
	end

	IF NOT EXISTS(SELECT * FROM @IDs)
	BEGIN
		SET @Severity = 16
		SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' does not exist.'
		RETURN @Severity
	END

	IF NOT EXISTS(SELECT * FROM @IDs WHERE phase = @phaseReady)
	BEGIN
		SET @Severity = 16
		SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' does not have phase = '+@phaseReady+', and will not be imported'
		RETURN @Severity
	END


	if isnull(@discriminator,'') <> 'cn' and isnull(@EndUserType,'')='' begin
		SET @Severity = 16
		SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' cannot be imported as end user type was not specified.'
		RETURN @Severity
	end

	DECLARE @DBNAME NVARCHAR(20), @COUNT as int
	SELECT @DBNAME = (SELECT TOP 1 app_db_name FROM site where site=@orderSite)
	SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.customer_mst ca WHERE ca.cust_seq = 0 and ca.cust_num='''+@CustNum+''''
	EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
	IF (@COUNT = 0)
	BEGIN
		SET @Severity = 16
		SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' cannot be imported as customer ' + @CustNum + ' does not exist in site ' + @orderSite + '.'
		RETURN @Severity
	END

	If @discriminator = 'cn' BEGIN --we will verify the order doesn't have a different customer number.   this must be updated manually.
		declare @curcust custnumtype
		SET @SQL = 'SELECT @curcust=cust_num from ' + @DBNAME + '.dbo.co_mst co WHERE co.co_num='''+dbo.ExpandKyByType('CoNumType',@conum)+''''
		EXEC sp_executesql @SQL, N'@curcust custNumType OUTPUT', @curcust=@curcust OUTPUT
		IF (@curcust != @CustNum)
		BEGIN
			SET @Severity = 16
			SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' cannot be imported as order ' + ltrim(@conum) + ' has customer ' + @curcust + ';  You must manually change customer to '+@CustNum
			RETURN @Severity
		END
	END

	IF @shiptoSeq IS NOT NULL BEGIN
		SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.customer_mst ca WHERE ca.cust_seq=' + cast(@shiptoSeq as nvarchar(10)) + ' and ca.cust_num='''+ @CustNum + ''''
		EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
		IF (@COUNT = 0)
		BEGIN
			SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.custaddr_mst ca WHERE ca.cust_seq=' + cast(@shiptoSeq as nvarchar(10)) + ' and ca.cust_num='''+ @CustNum + ''''
			EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
			SET @Severity = 16
			IF (@COUNT = 0) BEGIN
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' cannot be imported as shipto ' + cast(@shiptoSeq as nvarchar(10)) + ' for ' +  @CustNum + ' does not exist in site ' + @orderSite + '.'
			END ELSE BEGIN
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' references shipto ' + cast(@shiptoSeq as nvarchar(10)) + ', which exists but must first be enabled in ' + @orderSite + '.'
			END
			RETURN @Severity
		END
	END

	IF @discriminator = 'cn' BEGIN
		SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.co_mst co WHERE co.co_num='''+dbo.ExpandKyByType('CoNumType',@conum)+''''
		EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
		IF (@COUNT = 0)
		BEGIN
			SET @Severity = 16
			SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' cannot be imported as customer order ' + @conum + ' does not exist in site ' + @orderSite + '.'
			RETURN @Severity
		END
	END


/*	
	IF EXISTS(SELECT * FROM @IDs WHERE ISNULL(co_num,'') <> '')
	BEGIN
		SELECT TOP 1 @Infobar = 'Order form Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' has already been imported to customer order ' + co_num + '.'
		FROM @IDs
		WHERE ISNULL(co_num,'') <> ''

		SET @Severity = 16
		RETURN @Severity 
	END
*/
	SELECT TOP 1 @ID = [id]
	FROM @IDs


	DECLARE @counter TABLE(
		total int
	)

	declare @countHold int, @countSD int

	SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.customer_mst ca WHERE ca.ship_hold = 1 and ca.cust_seq = 0 and ca.cust_num='''+@CustNum+''''
	EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@countHold OUTPUT

	SET @SQL = 'SELECT count(id) AS total FROM erpTopLineItem WHERE deleted is null and isShipDirect=1 and orderId = ' + CAST(@ID AS NVARCHAR(10))
	SET @SQL = 'SELECT * FROM OPENQUERY(EQUOTE, ''' + @SQL + ''')'
	INSERT INTO @counter(total)
	EXEC (@SQL)
	select @countSD = isnull(total,0) from @counter

	if @countHold > 0 and @countSD > 0 begin
		SET @Severity = 16
		SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' with '+cast(@countSD as nvarchar(9))+' ship direct(s) cannot be imported as customer ' + @CustNum + ' is on ship hold.'
		RETURN @Severity
	end


	IF @discriminator = 'cn' BEGIN
		SET @SQL = 'SELECT itemTotal AS sellPrice FROM infororder WHERE id = ' + CAST(@ID AS NVARCHAR(10))
	END ELSE BEGIN
		SET @SQL = 'SELECT cast( IFNULL(SUM(sellPrice * qty),0) as DECIMAL(20,2)) AS sellPrice FROM erpTopLineItem WHERE deleted is null and orderId = ' + CAST(@ID AS NVARCHAR(10))
	END

	SET @SQL = 
		'SELECT * FROM OPENQUERY(EQUOTE, ''' + @SQL + ''')'

	IF @Debug = 1
		PRINT @SQL

	INSERT INTO @SellPrices(sellPrice)
	EXEC (@SQL)

	IF @Debug = 1
		SELECT '@SellPrices' AS TableName, * FROM @SellPrices

	declare @correctPrice decimal(10,2)=(select sellPrice from @SellPrices)

	IF NOT EXISTS(SELECT * FROM @SellPrices WHERE ISNULL(sellPrice,-1) = CAST(@Price AS NVARCHAR(22)))
	BEGIN
		SET @Severity = 16
		SET @Infobar = 'Sell price of ' + CAST(@Price AS NVARCHAR(28)) + ' is incorrect for ' + @orderFormType + ' ref# ' + CAST(@ref AS NVARCHAR(10)) + '.'
		if (dbo.UserName2Sp() like '%hulme%') set @InfoBar=@InfoBar+'('+cast(@correctPrice as nvarchar(28))+')'
		RETURN @Severity
	END

	--djh 2016-10-10 check for obsolete items

	declare @coitem TABLE (
		assignSite siteType
		, assignWH whseType
		, item itemType
		, description descriptionType
		, designation nvarchar(30)
		, quantity_ordered qtyUnitType
		, itemstat itemStatusType
		, vendor vendNumType
		, vendor_price qtyUnitType
		, is_ship_direct TINYINT
		, kitItem itemType
		, part_template itemType
		, template_stat itemStatusType
		, template_reason_code reasonCodeType
		, sub_template itemType
		, sub_template_stat itemStatusType
		, sub_template_reason_code reasonCodeType
		, partType nvarchar(50)
		, co_line coLineType
		, erpTopLineItemId INT
		, request_date_unix INT
		, request_date dateTime
		, CustomerRequiredShipDate_unix INT
		, CustomerRequiredShipDate dateTime
		, new_unit_price qtyUnitType
		, drop_ship_name NameType
		, drop_ship_care_of AddressType
		, drop_ship_address1 AddressType
		, drop_ship_address2 AddressType
		, drop_ship_address3 AddressType
		, drop_ship_address4 AddressType
		, drop_ship_country CountryType
		, drop_ship_city CityType
		, drop_ship_state StateType
		, drop_ship_zip PostalCodeType
		, drop_ship_number CustSeqType
		, Uf_CustomerItem ItemType
		, Uf_matlCostBasis AmountType
		, Uf_numSections int
		, Uf_CustomerPOLine int
		, Uf_Released ListYesNoType
		, Uf_PromiseDate DateTime
	)

	select * into #coitem from @coitem where 1=2 -- create temp table from table var (allows use of user defined types)
		
	SET @SQL = 'SELECT * FROM OPENQUERY(EQUOTE, 
		''SELECT tli.assignSite, tli.assignWH, tli.partTemplate as Item, tli.qty AS QtyOrdered, tli.shipDirectVendor, tli.shipDirectPrice, tli.isShipDirect, tli.kitItem, tli.sourceTemplate, tli.subTemplate, tli.partType, tli.CustomerItem, tli.dnum, '+
		'tli.shiptoName, tli.shiptoCareOf, tli.shiptoAddress1, tli.shiptoAddress2, tli.shiptoAddress3, tli.shiptoAddress4, tli.shiptoCountry, tli.shiptoCity, tli.shiptoState, tli.shiptoPostal, tli.shiptoNumber '+
		',tli.custPoLine '+
		',tli.released, tli.promiseDate ' + -- 0002 DMS
		'FROM infororder `of` INNER JOIN erpTopLineItem tli ON of.id = tli.orderId WHERE of.dnum = ' + 
		CAST(@ID AS NVARCHAR(10)) + ' AND tli.deleted IS NULL AND (tli.action is NULL or tli.action=''''ADD'''') AND of.deleted IS NULL ORDER BY tli.sequence'' )'

	IF @Debug = 1 PRINT @SQL	

	INSERT INTO #coitem(
			assignSite
			,assignWH
			,item
			,quantity_ordered
			,vendor
			,vendor_price
			,is_ship_direct
			,kitItem
			,part_template
			,sub_template
			,partType
			,Uf_CustomerItem
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
			,Uf_CustomerPOLine
			,Uf_Released
			,Uf_PromiseDate
	)
	EXEC(@SQL)

	-- remove toplineitems that were already processed on a previously failed import
	delete ci
	from #coitem ci
	join _IEM_OrderFormCNLog cnl on cnl.erpTopLineItemId=ci.erpTopLineItemId and cnl.ref=@ref
	where 
	(action = 'CreateCOLine' and ci.partType in ('INVENTORY','ORDER_SPECIFIC') and result='success')
	or (action = 'CreateCOLineAndJobs' and ci.partType='MANUFACTURED' and result='complete')
	--or (action = 'UpdateCOLine' and result='success')
	--djh 2022-05-18, we can't exclude these due to UpdateCOLineSD, UpdateCOLineAddr, UpdateSOLIDescription which may have to run after updatecoline
	--could implement similar to CreateCOLineAndJobs=complete for efficiency
	or (action = 'UpdateCOLineSD' and result='success') --if this ran it must be done with the rest.  it may not always run, though


	update #coitem set drop_ship_country = 'USA' where drop_ship_country = 'US'

	SET @SQL = 'UPDATE #coitem SET itemstat = i.stat FROM #coitem ci join ' + @DBNAME + '.dbo.item_mst i on i.item=ci.item'
	EXEC(@SQL)
	SET @SQL = 'UPDATE #coitem SET template_stat = i.stat, template_reason_code = i.reason_code FROM #coitem ci join ' + @DBNAME + '.dbo.item_mst i on i.item=ci.part_template'
	EXEC(@SQL)
	SET @SQL = 'UPDATE #coitem SET sub_template_stat = i.stat, sub_template_reason_code = i.reason_code FROM #coitem ci join ' + @DBNAME + '.dbo.item_mst i on i.item=ci.sub_template'
	EXEC(@SQL)

	DECLARE 
		@Item ItemType, @QtyOrdered as QtyUnitType, @ItemStat ItemStatusType, @Vendor VendNumType, 
		@shipDirect TINYINT, @kitItem nvarchar(30),
		@partTemplate nvarchar(30), @templateStat ItemStatusType, @templateReasonCode ReasonCodeType, @subTemplate nvarchar(30), @subTemplateStat ItemStatusType, @subTemplateReasonCode ReasonCodeType, 
		@partType nvarchar(50), @assignSite siteType, @assignWH whseType

	declare @foundUpdates int = 0

	DECLARE crsCoLines CURSOR FORWARD_ONLY FOR
	SELECT  assignSite, assignWH, isnull(Item,'<null>'), quantity_ordered, itemstat, vendor, is_ship_direct, kitItem, isnull(part_template,'<null>'), template_stat, template_reason_code, isnull(sub_template,'<null>'), sub_template_stat, sub_template_reason_code, partType
			,drop_ship_name ,drop_ship_care_of ,drop_ship_address1 ,drop_ship_address2 ,drop_ship_address3 ,drop_ship_address4 ,drop_ship_country ,drop_ship_city ,drop_ship_state ,drop_ship_zip ,drop_ship_number
			,Uf_CustomerPOLine
			,Uf_Released, Uf_PromiseDate -- 0002 DMS
	FROM #coitem
	OPEN crsCoLines

	WHILE 1=1
	BEGIN
		FETCH NEXT FROM crsCoLines INTO @assignSite, @assignWH, @Item, @QtyOrdered, @ItemStat, @Vendor, @shipDirect, @kitItem, @partTemplate, @templateStat, @templateReasonCode, @subTemplate, @subTemplateStat, @subTemplateReasonCode, @partType
		,@DropShipName , @DropShipCareOf , @DropShipAddress1 , @DropShipAddress2 , @DropShipAddress3 , @DropShipAddress4 , @DropShipCountry , @DropShipCity , @DropShipState , @DropShipZip , @DropShipNumber
		,@Uf_CustomerPOLine
		,@Uf_Released, @Uf_PromiseDate -- 0002 DMS
		IF @@fetch_status <> 0 break;

		if @partType='INVENTORY' BEGIN
			If @ItemStat = 'O' BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' includes item ' + @Item + ', which is marked Obsolete.'
				RETURN @Severity
			END

			If not exists (select 1 from item_all where item=@item) BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' uses item ' + @item + ', which does not exist.'
				RETURN @Severity
			END

			IF @shipDirect=1 and NOT EXISTS(SELECT * FROM vendor_all WHERE vend_num = @Vendor and site_ref=isnull(@assignSite,@orderSite)) BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ', with ship direct on item ' + @Item + ', references Vendor '+isnull(@Vendor,'<none>')+', which does not exist in site '+isnull(@assignSite,@orderSite)+'.'
				RETURN @Severity
			END

			IF @shipDirect=1 and EXISTS(
				SELECT * FROM vendor_all va
				join itemvend_all vi on vi.vend_num=va.vend_num and vi.item=@item and vi.site_ref=va.site_ref
				join u_m_conv_all uc on uc.item = vi.item and isnull(uc.vend_num,vi.vend_num)=vi.vend_num and uc.site_ref=va.site_ref and uc.from_u_m=vi.u_m
				WHERE va.vend_num = @Vendor and va.site_ref=isnull(@assignSite,@orderSite)
				and floor(@QtyOrdered / uc.conv_factor) != ceiling(@QtyOrdered / uc.conv_factor)
			) BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ', with ship direct on item ' + @Item + ', cannot be imported because the vendor '+@Vendor+' does not ship exactly the quantity ordered.'
				RETURN @Severity
			END

		END ELSE IF @partType='ORDER_SPECIFIC' BEGIN
			If not exists (select 1 from item_all where item=@item) BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' uses 3rd-party sourced item ' + @item + ', which does not exist.'
				RETURN @Severity
			END

			If not exists (select 1 from item_all where item=@item and overview = 'ORDER-SPECIFIC-TEMPLATE FOR '+@item) BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' uses 3rd-party sourced template ' + @item + ', which is not a valid template.'
				RETURN @Severity
			END

			If @TemplateStat = 'O' and isnull(@templateReasonCode,'') <> 'OT' BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' uses template code ' + @partTemplate + ', which is marked Obsolete.'
				RETURN @Severity
			END

		END ELSE IF @partType='MANUFACTURED' BEGIN
			if @partTemplate is null set @partTemplate='<<null>>'
			if @subTemplate is null set @subTemplate='<<null>>'

			If @partTemplate not like '%-SOLI' BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' uses template code ' + @partTemplate + ', which is not valid (Should be of the form *-SOLI).'
				RETURN @Severity
			END

			If @subTemplate not like '%-SUB' BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' uses sub-template code ' + @subTemplate + ', which is not valid (Should be of the form *-SUB).'
				RETURN @Severity
			END

			If @TemplateStat = 'O' BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' uses template code ' + @partTemplate + ', which is marked Obsolete.'
				RETURN @Severity
			END

			If @SubTemplateStat = 'O' BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' uses sub-template code ' + @subTemplate + ', which is marked Obsolete.'
				RETURN @Severity
			END

			If not exists (select 1 from item_all where item=@partTemplate) BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' uses template code ' + @partTemplate + ', which does not exist.'
				RETURN @Severity
			END

			If not exists (select 1 from item_all where item=@subTemplate) BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' uses sub-template code ' + @subTemplate + ', which does not exist.'
				RETURN @Severity
			END

			If @kitItem is not null and not exists (select 1 from item_all where item=@kitItem) BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' requires kit [' + @kitItem + '], which does not exist.'
				RETURN @Severity
			END

			If @kitItem is not null and @partTemplate <> 'MSP-SOLI' BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' includes kit [' + @kitItem + '] on template '+@partTemplate+', but kits are only valid for MSP-SOLI.'
				RETURN @Severity
			END
		END

		IF @DropShipNumber IS NOT NULL BEGIN
			SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.customer_mst ca WHERE ca.cust_seq=' + cast(@DropShipNumber as nvarchar(10)) + ' and ca.cust_num='''+ @CustNum + ''''
			EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
			IF (@COUNT = 0)
			BEGIN
				SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.custaddr_mst ca WHERE ca.cust_seq=' + cast(@DropShipNumber as nvarchar(10)) + ' and ca.cust_num='''+ @CustNum + ''''
				EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
				SET @Severity = 16
				IF (@COUNT = 0) BEGIN
					SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' (item ' + @Item + ') cannot be imported as shipto ' + cast(@DropShipNumber as nvarchar(10)) + ' for ' +  @CustNum + ' does not exist in site ' + @orderSite + '.'
				END ELSE BEGIN
					SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' (item ' + @Item + ') references shipto ' + cast(@DropShipNumber as nvarchar(10)) + ', which exists but must first be enabled in ' + @orderSite + '.'
				END
				RETURN @Severity
			END
		END

		if @DropShipName is not null begin -- djh 2019-10-10; do not bother calling if we are setting to the default ship-to
			set @SQL = @DBNAME + '.dbo._IEM_OrderFormCN_CreateShipToSp'

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
					,@Infobar = @shiptoInfoBar OUTPUT
					,@ShipToCareOf = @DropShipCareOf
					,@ShipToCurrency = @CurrCode
					,@ValidateOnly = 1
			
			if @Severity <> 0 begin
				set @InfoBar = isnull(@shiptoInfoBar,'error checking shipto')
				return 16
			end
		end
		set @foundUpdates = 1 --used to verify there is something to do when importing CN
	END
	close crsCoLines
	deallocate crsCoLines
	
	if @discriminator='cn' begin

		delete from #coitem
		SET @SQL = N'SELECT * FROM OPENQUERY(EQUOTE, '
			+ N'''SELECT tli.assignSite, tli.assignWH, tli.partTemplate as Item, tli.description, tli.designation, tli.qty AS QtyOrdered, tli.shipDirectVendor, tli.shipDirectPrice, tli.isShipDirect, tli.kitItem, tli.sourceTemplate, tli.subTemplate, tli.partType, tli.requestDate, tli.requiredShipDate, (tli.orderUnitPrice+tli.sellprice) as newUnitPrice, tli.co_line'
			+ N', tli.shiptoName, tli.shiptoCareOf, tli.shiptoAddress1, tli.shiptoAddress2, tli.shiptoAddress3, tli.shiptoAddress4, tli.shiptoCountry, tli.shiptoCity, tli.shiptoState, tli.shiptoPostal, tli.shiptoNumber, tli.CustomerItem, tli.matlCostBasis, tli.numSections'
			+ N', tli.custPoLine '
			+ N', tli.released, tli.promiseDate ' -- 0002 DMS
			+ N' FROM infororder `of` INNER JOIN erpTopLineItem tli ON of.id = tli.orderId WHERE of.dnum ='
			+ CAST(@ID AS NVARCHAR(10)) + N' AND tli.deleted IS NULL AND tli.action=''''UPDATE'''' AND of.deleted IS NULL ORDER BY tli.sequence'' )'

		IF @Debug = 1 PRINT @SQL	

		INSERT INTO #coitem(
			assignSite
			,assignWH
			,item
			,description
			,designation
			,quantity_ordered
			,vendor
			,vendor_price
			,is_ship_direct
			,kitItem
			,part_template
			,sub_template
			,partType
			,request_date_unix
			,CustomerRequiredShipDate_unix
			,new_unit_price
			,co_line
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
			,Uf_PromiseDate -- 0002 DMS
		)
		EXEC(@SQL)


		UPDATE #coitem
		SET 
		request_date = cast(DATEADD(SECOND, request_date_unix, @baseUnixDate)+.5 as date)
		, CustomerRequiredShipDate = cast(DATEADD(SECOND, CustomerRequiredShipDate_unix, @baseUnixDate)+.5 as date)

		DECLARE 
			 @reqDate dateType, @CustomerRequiredShipDate datetype, @newUnitPrice qtyUnitType, @coLine coLineType, @description descriptiontype, @designation nvarchar(30), @Uf_numSections int


		DECLARE crsCoLines CURSOR FORWARD_ONLY FOR
		SELECT 	assignSite, assignWH, Item, description, designation, quantity_ordered, vendor, is_ship_direct, kitItem, part_template, sub_template, partType, co_line, request_date, new_unit_price
				,drop_ship_name ,drop_ship_care_of ,drop_ship_address1 ,drop_ship_address2 ,drop_ship_address3 ,drop_ship_address4 ,drop_ship_country ,drop_ship_city ,drop_ship_state ,drop_ship_zip ,drop_ship_number, Uf_CustomerItem, Uf_matlCostBasis, Uf_numSections
				,Uf_CustomerPOLine
				,Uf_Released,Uf_PromiseDate -- 0002 DMS
		FROM #coitem
		OPEN crsCoLines

		WHILE 1=1
		BEGIN
			FETCH NEXT FROM crsCoLines INTO @assignSite, @assignWH, @Item, @description, @designation, @QtyOrdered, @Vendor, @shipDirect, @kitItem, @partTemplate, @subTemplate, @partType, @coLine, @reqDate, @newUnitPrice
				,@DropShipName , @DropShipCareOf , @DropShipAddress1 , @DropShipAddress2 , @DropShipAddress3 , @DropShipAddress4 , @DropShipCountry , @DropShipCity , @DropShipState , @DropShipZip , @DropShipNumber, @Uf_CustomerItem, @Uf_matlCostBasis, @Uf_numSections
				,@Uf_CustomerPOLine
				,@Uf_Released, @Uf_PromiseDate -- 0002 DMS
			IF @@fetch_status <> 0 break;

			if exists (select 1 from coitem_mst_all ci where ci.co_num=@CNCo and ci.co_line=@coLine and price_conv != @newUnitPrice and ci.stat<>'O')
			begin
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' will not be imported, as it contains a price update for closed line '+ltrim(@CNCo)+'-'+cast(@coline as nvarchar(4))+'.'
				return 16
			end
			
			if exists (select 1 from coitem_mst_all ci where ci.co_num=@CNCo and ci.co_line=@coLine and ci.item <> @item and ci.ref_num is not null) begin
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' will not be imported, as it contains a item number update for line '+ltrim(@CNCo)+'-'+cast(@coline as nvarchar(4))+', which has a source reference.'
				return 16
			end

			if exists (select 1 from coitem_mst_all ci where ci.co_num=@CNCo and ci.co_line=@coLine and ci.item <> @item and ci.qty_shipped+ci.qty_invoiced+ci.qty_packed+ci.qty_picked>0) begin
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' will not be imported, as it contains a item number update for line '+ltrim(@CNCo)+'-'+cast(@coline as nvarchar(4))+', which has shipping or invoicing activity.'
				return 16
			end

			if exists 
				(
				select 1 from coitem_mst_all ci 
					join poitem_mst_all pi on pi.po_num=ci.ref_num and pi.po_line=ci.ref_line_suf
					where ci.co_num=@CNCo and ci.co_line=@coLine and isnull(ci.Uf_ShipDirect,0)<>isnull(@shipDirect,0) and pi.stat <> 'P'
				) 
			begin
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' will not be imported, as it contains a ship direct update for line '+ltrim(@CNCo)+'-'+cast(@coline as nvarchar(4))+', which has a linked PO.'
				return 16
			end

			if exists
					(select 1 from coitem_mst_all ci 
						where ci.co_num=@CNCo and ci.co_line=@coLine 
						and (
							ISNULL(promise_date,'2222-02-22') <> ISNULL(@reqDate,'2222-02-22') 
							or ISNULL(Uf_CustomerRequiredShipDate,'2222-02-22') <> ISNULL(@CustomerRequiredShipDate,'2222-02-22') 
							or price_conv != @newUnitPrice
							or (Uf_DrawingApprDate is null and @reqDate<'2220-01-01' and item like 'SOLI%') 
							or description != dbo.soliDescription(@description, @designation)
							or isnull(Uf_designation,'') != @designation
							or isnull(Uf_CustomerItem,'') != isnull(@Uf_CustomerItem,'')
							or isnull(Uf_matlCostBasis,0) != isnull(@Uf_matlCostBasis,0)
							or (ci.ref_num is null and ci.qty_shipped+ci.qty_invoiced+ci.qty_packed+ci.qty_picked = 0 and ci.item <> @Item) --don't allow updates for anything with a ref or shipping
							or isnull(Uf_ShipDirect,0) != isnull(@shipDirect,0)
							or isnull(Uf_numSections,0) != isnull(@Uf_numSections,0)
							or isnull(Uf_assign_site,'') != isnull(@assignSite,'')
							or isnull(Uf_assign_whse,'') != isnull(@assignWH,'') 
							or whse <> IIF(@assignsite=site_ref,@assignWH,site_ref)
							or isnull(Uf_CustomerPOLine,'') != isnull(@Uf_CustomerPOLine,'')
							or ISNULL(Uf_PromiseDate,'2222-02-22') != ISNULL(@Uf_PromiseDate,'2222-02-22') -- 0002 DMS
							or ISNULL(Uf_Released,0) != ISNULL(@Uf_Released,0)-- 0002 DMS
						)
					) 
			begin
				set @foundUpdates = 1
			end

			if exists
					(select 1 from coitem_mst_all ci join item_mst i on i.item = ci.item
						where ci.co_num=@CNCo and ci.co_line=@coLine and i.description != dbo.soliDescription(@description, @designation))
			begin
				set @foundUpdates = 1
			end


			IF @DropShipNumber IS NOT NULL BEGIN
				SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.customer_mst ca WHERE ca.cust_seq=' + cast(@DropShipNumber as nvarchar(10)) + ' and ca.cust_num='''+ @CustNum + ''''
				EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
				IF (@COUNT = 0)
				BEGIN
					SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.custaddr_mst ca WHERE ca.cust_seq=' + cast(@DropShipNumber as nvarchar(10)) + ' and ca.cust_num='''+ @CustNum + ''''
					EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
					SET @Severity = 16
					IF (@COUNT = 0) BEGIN
						SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' (item ' + @Item + ') cannot be imported as shipto ' + cast(@DropShipNumber as nvarchar(10)) + ' for ' +  @CustNum + ' does not exist in site ' + @orderSite + '.'
					END ELSE BEGIN
						SET @Infobar = @orderFormType+' Ref# ' + CAST(@ref AS NVARCHAR(10)) + ' (item ' + @Item + ') references shipto ' + cast(@DropShipNumber as nvarchar(10)) + ', which exists but must first be enabled in ' + @orderSite + '.'
					END
					RETURN @Severity
				END
			END

			if @DropShipName is not null 
			or exists (select 1 from coitem_mst_all ci where ci.co_num=@CNCo and ci.co_line=@coLine and ci.cust_num is not null)
			begin
				if @DropShipName is not null begin -- djh 2019-10-10; do not bother calling if we are setting to the default ship-to
					set @SQL = @DBNAME + '.dbo._IEM_OrderFormCN_CreateShipToSp'

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
							,@Infobar = @shiptoInfoBar OUTPUT
							,@ShipToCareOf = @DropShipCareOf
							,@ShipToCurrency = @CurrCode
							,@CoNum = @CNCo
							,@CoLine = @CoLine
							,@ValidateOnly = 1
							,@ShipToChange = @ShipToChange OUTPUT
			
					if @Severity <> 0 begin
						set @InfoBar = isnull(@shiptoInfoBar,'error checking shipto')
						return 16
					end

					if @ShipToChange=1
						set @foundUpdates = 1
				end else begin
					set @foundUpdates = 1
				end
			end

		END
		close crsCoLines
		deallocate crsCoLines

		if not exists (	SELECT 1	
						FROM co_mst_all co 
						join custaddr_mst ca on ca.cust_num=co.cust_num and ca.cust_seq=co.cust_seq 
						join @ids i on co.co_num = dbo.ExpandKyByType('CoNumType',i.co_num)
						WHERE 
							ISNULL(ca.cust_seq,'') = ISNULL(i.shipto_seq,'')
							AND ISNULL(ca.name,'') = ISNULL(i.cust_name,'')
							AND ISNULL(ca.addr##1,'') = ISNULL(i.ship_addr_1,'') 
							AND ISNULL(ca.addr##2,'') = ISNULL(i.ship_addr_2,'') 
							AND ISNULL(ca.addr##3,'') = ISNULL(i.ship_addr_3,'') 
							AND ISNULL(ca.addr##4,'') = ISNULL(i.ship_addr_4,'') 
							AND ISNULL(ca.city,'') = ISNULL(i.ship_addr_city,'') 
							AND ISNULL(ca.state,'') = ISNULL(i.ship_addr_state,'') 
							AND ISNULL(ca.zip,'') = ISNULL(i.ship_addr_postal,'')
							AND ISNULL(ca.country,'') = ISNULL(i.ship_addr_country,'')
							AND ISNULL(ca.Uf_CareOf,'') = ISNULL(i.shipto_care_of,'')
							AND ISNULL(ca.curr_code,'') = ISNULL(i.curr_code,'')
		) 
		begin
			set @foundUpdates = 1
		end

		if @discriminator = 'cn' and exists (select 1 from co_mst_all where co_num = @CNCo and ship_hold <> @ShipHold) begin
			set @foundUpdates = 1
		end


		if @foundUpdates = 0 begin
			set @InfoBar = @orderFormType + ' Ref# ' + CAST(@ref AS NVARCHAR(10))+' had no updates or adds.  Nothing to do.'
			set @Severity = 16
		end
	end

	declare @isRunning int=0, @otherRef int =0
	;with activeImports as (
		select distinct cl1.ref, cl1.importTransId from _IEM_OrderFormCNLog cl1 
		where datediff(day, cl1.CreateDate, getdate()) < 1
		and not exists (select 1 from _IEM_OrderFormCNLog cl2 where cl2.ref=cl1.ref and cl2.importTransId=cl1.importTransId and cl2.action='Import' and cl2.result in ('success','fail'))
	)
	select @isRunning=count(1), @otherRef=max(ref) from activeImports where ref <> @ref

	if (@isRunning > 0) begin
		set @InfoBar = 'Another import of (Ref# ' + CAST(@otherRef AS NVARCHAR(10))+') is still running or has crashed.  Please contact IT.'
		set @Severity = 16
	end

	if  (select count(1) from _IEM_OrderFormCNLog where ref=@ref and importTransId = @lastimportid and action='Import') = 1 begin
		if exists (select 1 from _IEM_OrderFormCNLog where ref=@ref and importTransId = @lastimportid and (datediff(minute, CreateDate, getdate()) < 40 and isnull(@forcerestart,0)=0)) begin -- if there is any import log in the last 60 minutes for this importid
			set @InfoBar = 'Another import of '+@orderFormType + ' Ref# ' + CAST(@ref AS NVARCHAR(10))+' is still running or has crashed.  Try again or contact IT'
			set @Severity = 16
		end else begin
			declare @tseq int
			select @tseq = max(tseq)+1 from _IEM_OrderFormCNLog where ref=@ref and importTransId = @lastimportid
			insert into _IEM_OrderFormCNLog (ref, importTransId, tseq, action, result, error)
			values (@ref, @lastimportid, @tseq, 'Import', 'fail', 'Auto-marked as failed due to 40 minute timeout')
		end
	end

skipcheck:

	if @severity=0 begin
		set @InfoBar = 'Beginning import of '+@orderFormType + ' Ref# ' + CAST(@ref AS NVARCHAR(10))
		select @importTransId = max(importTransId)+1 from _IEM_OrderFormCNLog where ref=@ref
		if @importTransId is null set @importTransId = 0
	end
	RETURN @Severity

END



GO

