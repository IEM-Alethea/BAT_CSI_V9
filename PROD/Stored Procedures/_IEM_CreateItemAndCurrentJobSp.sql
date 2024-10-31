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
ALTER PROCEDURE [dbo].[_IEM_CreateItemAndCurrentJobSp](
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
	--@FRE_Item ItemType OUTPUT,
	--@JAX_Item ItemType OUTPUT,
	--@VAN_Item ItemType OUTPUT,
	@BEL_Item ItemType OUTPUT,
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
		--,@FRE_Site SiteType
		--,@JAX_Site SiteType
		--,@VAN_Site SiteType
		,@BEL_Site SiteType
		,@Mfg NVARCHAR(7)

	SET @Severity = 0
	SET @Debug = 1

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
PRINT @ItemTemplate
	SELECT TOP 1 @BEL_Site = site
	FROM site
	WHERE site like '%BEL%'
		AND type = 'S'

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

	--SET @UM = 'EA'

	--SET @ProductCode = 'M9999'
	IF @Debug = 1
		PRINT '@partType = ' + ISNULL(@partType,'NULL')

	IF @partType = 'MANUFACTURED'
	BEGIN
		SET @Item = 'COLI' + RIGHT('0' + LTRIM(RTRIM(@CoNum)),6) + RIGHT(10000 + @CoLine,4)
		--SET @FRE_Item = 'FRE' + RIGHT('0' + LTRIM(RTRIM(@CoNum)),6) + RIGHT(10000 + @CoLine,4)
		--SET @JAX_Item = 'JAX' + RIGHT('0' + LTRIM(RTRIM(@CoNum)),6) + RIGHT(10000 + @CoLine,4)
		--SET @VAN_Item = 'VAN' + RIGHT('0' + LTRIM(RTRIM(@CoNum)),6) + RIGHT(10000 + @CoLine,4)
	END
	ELSE IF @partType = 'ORDER_SPECIFIC'
	BEGIN
		
		--SET @Item = 'TEMPLATE' + LTRIM(RTRIM(@CoNum)) + CASE WHEN @CoLine BETWEEN 1 AND 9 THEN '000' WHEN @CoLine BETWEEN 10 AND 99 THEN '00' ELSE '0' END + CAST(@CoLine AS NVARCHAR(10))		
		SET @Item = @ItemTemplate + '-' + LTRIM(RTRIM(@CoNum)) + '-' + RIGHT(10000 + @CoLine,4)
	
	END
	ELSE
	BEGIN

		SET @Item = @SubTemplate

	END

	IF @Debug = 1
		PRINT '@Item = ' + @Item

	-- Create Item
	IF NOT EXISTS(SELECT * FROM item WHERE item = @Item) AND @partType <> 'INVENTORY'
	BEGIN
		IF @Debug = 1
			PRINT 'Calling CreateItemSp'
	
		BEGIN TRANSACTION
		EXECUTE @Severity = [dbo].[_IEM_CreateItemSp] 
			 @Item = @Item
			,@Description = @Description
			,@Revision = 0 --@Revision
			,@UM = @UM
			,@ProductCode = @ProductCode
			--,@Job = @Job OUTPUT
			--,@Suffix = @Suffix OUTPUT
			--,@JobType = @JobType OUTPUT
			,@Infobar = @Infobar OUTPUT

		PRINT @INfobar

		IF @Severity <> 0
			RETURN @Severity

		COMMIT TRANSACTION

		IF @Debug = 1
		BEGIN
			PRINT 'Back from CreateItemSp'
			--PRINT 'Standard job created:  ' + ISNULL(@Job,'NULL')
			PRINT DB_NAME()
			PRINT @Infobar
		END

		PRINT 'Item lead time for ' + @Item
		PRINT @ProdLeadTime

		UPDATE item
		SET 
			cost_method = 'A'
			,cost_type = 'A'
			,p_m_t_code = CASE WHEN @partType = 'ORDER_SPECIFIC' THEN 'P' ELSE p_m_t_code END
			,lead_time = 0
			,Uf_manufacturer = @Mfg
		WHERE item = @Item

		BEGIN TRANSACTION
		EXECUTE @Severity = [dbo].[_IEM_CreateCOLICurJobSp] 
			 @Item = @Item
			,@ItemTemplate = @ItemTemplate
			,@Job = @Job OUTPUT
			,@Suffix = @Suffix OUTPUT
			,@JobType = @JobType OUTPUT
			,@Infobar = @Infobar OUTPUT

		PRINT @INfobar

		IF @Severity <> 0
			RETURN @Severity

		COMMIT TRANSACTION



/*
		IF @partType = 'MANUFACTURED'
		BEGIN


			PRINT 'Creating FRE item'

			BEGIN TRANSACTION

			IF NOT EXISTS(SELECT * FROM item_mst WHERE item = @FRE_Item)
			BEGIN

				SELECT @SQL = app_db_name + '.dbo._IEM_CreateItemSp'
				FROM site
				WHERE site = @FRE_Site

				EXECUTE @Severity = @SQL --[DFRE30_App].[dbo].[_IEM_CreateItemSp] 
					 @Item = @FRE_Item
					,@Description = @Description
					,@Revision = 0 --@Revision
					,@UM = @UM
					,@ProductCode = @ProductCode
					,@Job = @JobHolder OUTPUT
					,@Suffix = @SuffixHolder OUTPUT
					,@JobType = @JobTypeHolder OUTPUT
					,@Infobar = @Infobar OUTPUT
					,@Site = NULL --'FRE30'
					,@SiteSpecificItem = 1
					,@TemplateItem = @SubTemplate
			
			END
			PRINT 'Back from creating FRE item'

			IF @Severity <> 0
				RETURN @Severity

			COMMIT TRANSACTION

			UPDATE item
			SET cost_method = 'A', cost_type = 'A', lead_time = @ProdLeadTime, pass_req=CASE WHEN RIGHT(@Site,3) = 'FRE' THEN 1 ELSE 0 END
			WHERE item = @FRE_Item

			BEGIN TRANSACTION

			IF NOT EXISTS(SELECT * FROM item_mst WHERE item = @JAX_Item)
			BEGIN

				SELECT @SQL = app_db_name + '.dbo._IEM_CreateItemSp'
				FROM site
				WHERE site = @JAX_Site

				EXECUTE @Severity = @SQL --[DJAX30_App].[dbo].[_IEM_CreateItemSp] 
					 @Item = @JAX_Item
					,@Description = @Description
					,@Revision = 0 --@Revision
					,@UM = @UM
					,@ProductCode = @ProductCode
					,@Job = @Job OUTPUT
					,@Suffix = @Suffix OUTPUT
					,@JobType = @JobType OUTPUT
					,@Infobar = @Infobar OUTPUT
					,@Site=NULL --'JAX30'
					,@SiteSpecificItem = 1
					,@TemplateItem = @SubTemplate
			
			END

			IF @Severity <> 0
				RETURN @Severity

			COMMIT TRANSACTION

			UPDATE item
			SET cost_method = 'A', cost_type = 'A', lead_time = @ProdLeadTime, pass_req=CASE WHEN RIGHT(@Site,3) = 'JAX' THEN 1 ELSE 0 END
			WHERE item = @JAX_Item

			--IF RIGHT(@Site,3) <> 'JAX'
			--	UPDATE item_mst
			--	SET p_m_t_code = 'T'
			--	WHERE item = @JAX_Item

			BEGIN TRANSACTION

			IF NOT EXISTS(SELECT * FROM item_mst WHERE item = @VAN_Item)
			BEGIN

				SELECT @SQL = app_db_name + '.dbo._IEM_CreateItemSp'
				FROM site
				WHERE site = @VAN_Site

				EXECUTE @Severity = @SQL --[DVAN30_App].[dbo].[_IEM_CreateItemSp] 
					 @Item = @VAN_Item
					,@Description = @Description
					,@Revision = 0 --@Revision
					,@UM = @UM
					,@ProductCode = @ProductCode
					,@Job = @Job OUTPUT
					,@Suffix = @Suffix OUTPUT
					,@JobType = @JobType OUTPUT
					,@Infobar = @Infobar OUTPUT
					,@Site=NULL--'VAN30'
					,@SiteSpecificItem = 1
					,@TemplateItem = @SubTemplate


			END


			IF @Severity <> 0
				RETURN @Severity

			COMMIT TRANSACTION

			UPDATE item
			SET cost_method = 'A', cost_type = 'A', lead_time = @ProdLeadTime, pass_req=CASE WHEN RIGHT(@Site,3) = 'VAN' THEN 1 ELSE 0 END
			WHERE item = @VAN_Item

			--IF RIGHT(@Site,3) <> 'VAN'
			--	UPDATE item_mst
			--	SET p_m_t_code = 'T'
			--	WHERE item = @VAN_Item
		END

	*/

	END

	IF @partType <> 'MANUFACTURED'
		RETURN @Severity

	IF @Severity <> 0
	BEGIN
		RETURN @Severity
	END

/*
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

	IF @Debug = 1 
	BEGIN
		PRINT 'Calling CopyBomDoProcessSp'
		PRINT '     From item ' + ISNULL(@ItemTemplate,'NULL')
		PRINT '     To job ' + ISNULL(@Job,'NULL')
	END

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
		,@CopyBom = 1
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
		, @FRE_Item
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
		, CASE WHEN RIGHT(@Site,3) = 'FRE' THEN 'J' ELSE'T' END
		, 0
		, NULL
		, @TNextSequence
		, 0
	)

	SET @TNextSequence = @TNextSequence + 1

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
		, @JAX_Item
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
		, CASE WHEN RIGHT(@Site,3) = 'JAX' THEN 'J' ELSE'T' END
		, 0
		, NULL
		, @TNextSequence
		, 0
	)

	SET @TNextSequence = @TNextSequence + 1

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
		, @VAN_Item
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
		, CASE WHEN RIGHT(@Site,3) = 'VAN' THEN 'J' ELSE'T' END
		, 0
		, NULL
		, @TNextSequence
		, 0
	)

	EXEC [dbo].[_IEM_SyncBOMSp]
		 @Item
		,@InfoBar OUTPUT
		,@Site
*/

	RETURN @Severity

END






GO

