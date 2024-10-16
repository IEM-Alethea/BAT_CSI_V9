SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/**************************************************************************
*                            Modification Log
*                                            
* Ref#  Init Date     Description           
* ----- ---- -------- ----------------------------------------------------- 
*  0001 JWP   090115  eQuote to SyteLine interface
***************************************************************************/
ALTER PROCEDURE [dbo].[_IEM_ValidateQuoteSp](
	@DNum			INT,
	@Amount			decimal(20,2),
	@InfoBar 		InfoBarType OUTPUT
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
		,@customerNumber CustNumType
		,@shiptoSeq INT
		,@orderSite SiteType

	SET @Severity = 0
	SET @Debug = 1

	SET @Amount = ISNULL(@Amount,0)

	DECLARE @IDs TABLE(
		discriminator NVARCHAR(45)
		,[id] INT
		,phase NVARCHAR(40)
		,co_num NVARCHAR(30)
		,cust_num CustNumType
		,shipto_seq INT
		,order_site SiteType
	)

	DECLARE @SellPrices TABLE(
		sellPrice DECIMAL(19,8)
	)

	SET @SQL = 'SELECT discriminator, id, phase, customerOrderNumber, customerNumber, shiptoNumber, orderSite FROM infororder WHERE deleted IS NULL AND dnum = ' + CAST(@DNum AS NVARCHAR(10))

	SET @SQL = 
		'SELECT * FROM OPENQUERY(EQUOTE, ''' + @SQL + ''')'
	
	IF @Debug = 1
		PRINT @SQL

	INSERT INTO @IDs(discriminator,[id], phase, co_num, cust_num, shipto_seq, order_site)
	EXEC (@SQL)

	SELECT TOP 1 @discriminator=discriminator,@phase=phase,@conum=co_num,@customerNumber=cust_num, @shiptoSeq=shipto_seq, @orderSite=order_site from @IDs

	IF (SELECT TOP 1 app_db_name FROM site where right(site,3)=RIGHT(@orderSite,3)) IS NULL
	BEGIN
		SET @Severity = 16
		SET @Infobar = 'Invalid site.'
		RETURN @Severity
	END	

	IF @discriminator LIKE '%CN' AND @conum IS NULL
	BEGIN
		SET @Severity = 16
		SET @Infobar = 'Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' is a change notice, but has no customer order number.'
		RETURN @Severity
	END

	IF @discriminator IS NULL AND @conum IS NOT NULL
	BEGIN
		SET @Severity = 16
		SET @Infobar = 'Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' is a new order, but already has a customer order number ('+@conum+').'
		RETURN @Severity
	END

	IF @discriminator LIKE '%CN' BEGIN
		SET @phaseReady='CN_READY'
		SET @orderFormType='Change Notice'
	END ELSE BEGIN
		SET @phaseReady='ORDER_FORM_READY'
		SET @orderFormType='Order Form'
	END


	IF NOT EXISTS(SELECT * FROM @IDs)
	BEGIN
		SET @Severity = 16
		SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' does not exist.'
		RETURN @Severity
	END

	IF NOT EXISTS(SELECT * FROM @IDs WHERE phase = @phaseReady)
	BEGIN
		SET @Severity = 16
		SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' is not ready for import based on the phase.'
		RETURN @Severity
	END

	DECLARE @DBNAME NVARCHAR(20), @COUNT as int
	SELECT @DBNAME = (SELECT TOP 1 app_db_name FROM site where right(site,3)= RIGHT(@orderSite,3))
	SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.customer_mst ca WHERE ca.cust_seq = 0 and ca.cust_num='''+@customerNumber+''''
	EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
	IF (@COUNT = 0)
	BEGIN
		SET @Severity = 16
		SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' cannot be imported as customer ' + @customerNumber + ' does not exist in site ' + @orderSite + '.'
		RETURN @Severity
	END

	IF @shiptoSeq IS NOT NULL BEGIN
		SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.customer_mst ca WHERE ca.cust_seq=' + cast(@shiptoSeq as nvarchar(10)) + ' and ca.cust_num='''+ @customerNumber + ''''
		EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
		IF (@COUNT = 0)
		BEGIN
			SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.custaddr_mst ca WHERE ca.cust_seq=' + cast(@shiptoSeq as nvarchar(10)) + ' and ca.cust_num='''+ @customerNumber + ''''
			EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
			SET @Severity = 16
			IF (@COUNT = 0) BEGIN
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' cannot be imported as shipto ' + cast(@shiptoSeq as nvarchar(10)) + ' for ' +  @customerNumber + ' does not exist in site ' + @orderSite + '.'
			END ELSE BEGIN
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' references shipto ' + cast(@shiptoSeq as nvarchar(10)) + ', which exists but must first be enabled in ' + @orderSite + '.'
			END
			RETURN @Severity
		END
	END

	IF @discriminator LIKE '%CN' BEGIN
		SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.co_mst co WHERE co.co_num='''+dbo.ExpandKyByType('CoNumType',@conum)+''''
		EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@Count OUTPUT
		IF (@COUNT = 0)
		BEGIN
			SET @Severity = 16
			SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' cannot be imported as customer order ' + @conum + ' does not exist in site ' + @orderSite + '.'
			RETURN @Severity
		END
	END


/*	
	IF EXISTS(SELECT * FROM @IDs WHERE ISNULL(co_num,'') <> '')
	BEGIN
		SELECT TOP 1 @Infobar = 'Order form Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' has already been imported to customer order ' + co_num + '.'
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

	SET @SQL = 'SELECT @C=COUNT(*) from ' + @DBNAME + '.dbo.customer_mst ca WHERE ca.ship_hold = 1 and ca.cust_seq = 0 and ca.cust_num='''+@customerNumber+''''
	EXEC sp_executesql @SQL, N'@C INT OUTPUT', @C=@countHold OUTPUT

	SET @SQL = 'SELECT count(id) AS total FROM erpTopLineItem WHERE deleted is null and isShipDirect=1 and orderId = ' + CAST(@ID AS NVARCHAR(10))
	SET @SQL = 'SELECT * FROM OPENQUERY(EQUOTE, ''' + @SQL + ''')'
	INSERT INTO @counter(total)
	EXEC (@SQL)
	select @countSD = isnull(total,0) from @counter

	if @countHold > 0 and @countSD > 0 begin
		SET @Severity = 16
		SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' with '+cast(@countSD as nvarchar(9))+' ship direct(s) cannot be imported as customer ' + @customerNumber + ' is on ship hold.'
		RETURN @Severity
	end


	IF @discriminator LIKE '%CN' BEGIN
		SET @SQL = 'SELECT itemTotal AS sellPrice FROM infororder WHERE id = ' + CAST(@ID AS NVARCHAR(10))
	END ELSE BEGIN
		SET @SQL = 'SELECT SUM(sellPrice * qty) AS sellPrice FROM erpTopLineItem WHERE deleted is null and orderId = ' + CAST(@ID AS NVARCHAR(10))
	END

	SET @SQL = 
		'SELECT * FROM OPENQUERY(EQUOTE, ''' + @SQL + ''')'

	IF @Debug = 1
		PRINT @SQL

	INSERT INTO @SellPrices(sellPrice)
	EXEC (@SQL)

	IF @Debug = 1
		SELECT '@SellPrices' AS TableName, * FROM @SellPrices

	IF NOT EXISTS(SELECT * FROM @SellPrices WHERE ISNULL(sellPrice,-1) = CAST(@Amount AS NVARCHAR(22)))
	BEGIN
		SET @Severity = 16
		SET @Infobar = 'Sell price of ' + CAST(@Amount AS NVARCHAR(28)) + ' is incorrect for ' + @orderFormType + ' ref# ' + CAST(@DNum AS NVARCHAR(10)) + '.'
		RETURN @Severity
	END

	--djh 2016-10-10 check for obsolete items / dbh 2017-10-24 also check for missing items
	CREATE TABLE #coitem (
		item NVARCHAR(30),
		quantity_ordered DECIMAL(19,8),
		itemstat nchar(1),
		vendor NVARCHAR(7),
		vendor_price DECIMAL(19,8),
		is_ship_direct TINYINT,
		kitItem nvarchar(30),
		part_template nvarchar(30),
		partType nvarchar(50)
	)
		
	SET @SQL = 'SELECT * FROM OPENQUERY(EQUOTE, 
		''SELECT tli.partTemplate as Item, tli.qty AS QtyOrdered, tli.shipDirectVendor, tli.shipDirectPrice, tli.isShipDirect, tli.kitItem, tli.sourceTemplate, tli.partType FROM infororder `of` INNER JOIN erpTopLineItem tli ON of.id = tli.orderId WHERE of.dnum = ' + 
		CAST(@ID AS NVARCHAR(10)) + ' AND tli.deleted IS NULL AND of.deleted IS NULL ORDER BY tli.sequence'' )'

	IF @Debug = 1 PRINT @SQL	

	INSERT INTO #coitem(item, quantity_ordered, vendor, vendor_price, is_ship_direct, kitItem, part_template, partType)
	EXEC(@SQL)
	SET @SQL = 'UPDATE #coitem SET itemstat = i.stat FROM #coitem ci join ' + @DBNAME + '.dbo.item_mst i on i.item=ci.item'
	EXEC(@SQL)
	SET @SQL = 'UPDATE #coitem SET itemstat = NULL FROM #coitem ci LEFT join ' + @DBNAME + '.dbo.item_mst i on i.item=ci.item WHERE i.item IS NULL'
	EXEC(@SQL)

	DECLARE 
		@Item ItemType, @QtyOrdered as QtyUnitType, @ItemStat ItemStatusType, @Vendor VendNumType, 
		@shipDirect TINYINT, @kitItem nvarchar(30), @partTemplate nvarchar(30), @partType nvarchar(50)

	DECLARE crsCoLines CURSOR FORWARD_ONLY FOR
	SELECT 	Item, quantity_ordered, itemstat, vendor, is_ship_direct, kitItem, part_template, partType
	FROM #coitem
	OPEN crsCoLines

	WHILE 1=1
	BEGIN
		FETCH NEXT FROM crsCoLines INTO @Item, @QtyOrdered, @ItemStat, @Vendor, @shipDirect, @kitItem, @partTemplate, @partType
		IF @@fetch_status <> 0 break;

		if @partType='INVENTORY' BEGIN

			IF @ItemStat IS NULL
				BEGIN
					SET @Severity = 16
					SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' includes item ' + @Item + ', which does not exist.x'
					RETURN @Severity
				END

			IF @ItemStat = 'O'
				BEGIN
					SET @Severity = 16
					SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' includes item ' + @Item + ', which is marked Obsolete.'
					RETURN @Severity
				END

			IF @shipDirect=1 and NOT EXISTS(SELECT * FROM vendor WHERE vend_num = @Vendor)
				BEGIN
					SET @Severity = 16
					SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ', with ship direct on item ' + @Item + ', references Vendor '+isnull(@Vendor,'<none>')+', which does not exist in site '+@orderSite+'.'
					RETURN @Severity
				END
/*		
		END ELSE IF @partType='MANUFACTURED' BEGIN
			If @kitItem is not null and not exists (select 1 from item where item=@kitItem) BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' requires kit [' + @kitItem + '], which does not exist.'
				RETURN @Severity
			END

			If @kitItem is not null and @partTemplate <> 'MSP-SOLI' BEGIN
				SET @Severity = 16
				SET @Infobar = @orderFormType+' Ref# ' + CAST(@DNum AS NVARCHAR(10)) + ' includes kit [' + @kitItem + '] on template '+@partTemplate+', but kits are only valid for MSP-SOLI.'
				RETURN @Severity
			END
*/
		END
	END


	RETURN @Severity

END



