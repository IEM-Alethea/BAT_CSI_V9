SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



/************************************************************************************
*                            Modification Log
*                                            
* Ref#  Init   Date     Description           
* ----- ----   -------- -------------------------------------------------------------
*        DJH   20160522 Copy BOM to other sites
*	     DBH   20180514 Check and report obsolescence in phantom part subcomponents
*        AEP   20231023 Added UET Uf_Revenue the UET is used for PASS Revenue sites
* 0004   DBH   20240209 Upgrades @Site selection table to ignore PASS if item missing
* 0005   AEP   20240213 Per Dave H remove the hardcoded part of the 
*			   WHERE clause  'AND i.item = 'JAX1225740001' 
* 0006   DBH   20240214 Removing capability of Sync BOM in PASS
* 0008   DBH   20240221 Limiting capability of Sync BOM in PASS
*  
* use DFRE_App
* exec setsitesp 'DFRE',''
* exec _IEM_SyncBOMSp 'FRE0986660033', null, 'DFRE', 1
************************************************************************************/
ALTER PROCEDURE [dbo].[_IEM_SyncBOMSp] (
	@Item				ItemType
    ,@Infobar			InfobarType = NULL OUTPUT
	,@Site				SiteType
	,@NoTran			int = 0
)
AS
BEGIN
	DECLARE
		 @FRE_Site SiteType
		,@JAX_Site SiteType
		,@VAN_Site SiteType
		,@updateBseqSQL nvarchar(max)
		,@AppDbName	OSLocationType
		,@baditem NVARCHAR(200)
		,@usernamesave usernametype
		,@ret int = 0

	SET NOCOUNT ON;

	--when called from our own created sessions, try to restore the username after it gets wiped out by multisitebomcopy
	select @usernamesave = CreatedBy from SessionContextNames where processid=@@SPID

	--update item set Uf_BomSavedBy = @usernamesave, Uf_BomSavedDate = GETDATE() where item = @item

	if exists ( --Checks for obsolescence in job material items
		select 1 from job j
		join jobmatl jm on jm.job=j.job and jm.suffix=j.suffix
		join item i on i.item=jm.item
		where j.item=@Item and j.type='S' and i.stat = 'O'
	) begin
		select @baditem=jm.item from job j
		join jobmatl jm on jm.job=j.job and jm.suffix=j.suffix
		join item i on i.item=jm.item and i.stat = 'O'

		where j.item=@Item and j.type='S'
		set @Infobar = 'BOM contains obsolete item: ['+@baditem+']. Could not Sync BOM!'
		return -16
	end

	if exists ( --Checks for obsolescence in subcomponents of job material phantom items
		select 1 from job j
		join jobmatl jm on jm.job=j.job and jm.suffix=j.suffix
		join job jk on jk.item = jm.item
		join jobmatl jmk on jmk.job=jk.job and jmk.suffix=jk.suffix
		join item ik on ik.item=jmk.item
		where j.item=@Item and j.type='S' and jk.type='S' and ik.stat = 'O'
	) begin
		select @baditem=jm.item + ' / ' + jmk.item from job j
		join jobmatl jm on jm.job=j.job and jm.suffix=j.suffix
		join job jk on jk.item = jm.item
		join jobmatl jmk on jmk.job=jk.job and jmk.suffix=jk.suffix
		join item ik on ik.item=jmk.item AND ik.stat = 'O'
		where j.item=@Item and j.type='S' AND jk.type='S'
		set @Infobar = 'BOM contains phantom item with obsolete subcomponent: ['+@baditem+']. Could not Sync BOM!'
		return -16
	end

	declare @bjob jobtype, @bsuffix suffixtype
	select @bjob=job, @bsuffix=suffix from job j where j.item=@item and j.type='S'
	if @bjob is not null and not exists (select 1 from jobroute jr where jr.job=@bjob and jr.suffix=@bsuffix) begin
		if @NoTran=0 BEGIN TRAN
		declare @severity int, @tinfo infobar
		EXEC @Severity = _IEM_CreateJobOperationSp
			@Job = @bJob
			,@Suffix = @bSuffix
			,@WorkCenter = 'ISUMAT'
			,@LaborHours = 0
			,@OperNum = 400
			,@Infobar = @tinfo OUTPUT

		if @Severity <> 0 begin
			if @NoTran=0 rollback tran
		end
		if @NoTran=0 COMMIT TRAN
	end

	declare @sites table (
		siteref sitetype
	)
	--Insert into @sites (siteref) values ('FRE'), ('VAN'), ('JAX');

    --INSERT into @sites (siteref) (SELECT site from site where Uf_mfg = 1 OR Uf_Revenue = 1);  -- 10/18/2023 Jason Tira -- creates current operations in mfg and Rev sites
	INSERT into @sites (siteref) -- 0004 Skips PASS (or, technically, any other site) if the item doesn't exist (which, due to replication, should only ever be older items in PASS)
		SELECT	  s.site
			FROM site s
				JOIN item_all i -- 0006 --> 0008
					ON i.site_ref = s.site -- 0006 --> 0008
				WHERE (s.Uf_mfg = 1 OR (s.Uf_Revenue = 1 AND i.item LIKE 'SOLI%')) -- 0006 --> 0008
						AND i.item = @item -- 0006 --> 0008

	if exists (SELECT TOP 1 site FROM site WHERE app_db_name = DB_NAME() and site like 'D%')
		update @sites set siteref='D'+siteref
	
	declare @toSite sitetype

	declare crs cursor for
	select siteref, app_db_name from @sites s
	join site dbsite on dbsite.site=s.siteref

	open crs
	while 1=1 begin	
		fetch next from crs into @toSite, @appdbname
		if @@FETCH_STATUS != 0 break


		IF @Site <> @toSite BEGIN
			Set @updateBseqSQL = 'UPDATE jm '+
				'SET bom_seq = jml.bom_seq '+
					',uf_revision = jml.uf_revision ' +
					',uf_ShipDirectQty = jml.uf_ShipDirectQty ' +
					',uf_SurplusInSite = jml.uf_SurplusInSite ' +
					',Uf_ItemReference = jml.Uf_ItemReference ' +
				'FROM '+@AppDbName+'..item_mst si ' +
				'JOIN '+@AppDbName+'..jobmatl_mst jm ON jm.job = si.job AND jm.suffix = si.suffix and jm.site_ref = si.site_ref ' +
				'JOIN item_mst i on i.item = si.item and i.site_ref = '''+@site+''' ' +
				'JOIN jobmatl_mst jml ON jml.job = i.job AND jml.suffix = i.suffix ' +
				'AND jml.oper_num = jm.oper_num ' +
				'AND jml.sequence = jm.sequence ' +
				'AND jml.site_ref = '''+@site+''' ' +
				'WHERE si.item = '''+@Item+''' ' +
				'and not exists ( ' +
				'	select jm.bom_seq, jm.uf_ShipDirectQty, jm.uf_SurplusInSite, jm.Uf_ItemReference, jm.uf_revision ' +
				'	intersect ' +
				'	select jml.bom_seq, jml.uf_ShipDirectQty, jml.uf_SurplusInSite, jml.Uf_ItemReference, jml.uf_revision ' +
				');'

			if @notran = 0 begin
				BEGIN TRY
					BEGIN TRAN BOMCOPYCN

						EXECUTE @ret = [dbo].[MultiSiteBOMCopySp] @Site, @toSite, @Item, 0, @InfoBar OUTPUT

						If @ret <> 0 begin --pass error to try/catch
							set @InfoBar=isnull(@Infobar,N'Unknown Error calling multi-site bom copy')
							;THROW 50505, @Infobar, 1;
						end

						exec (@updateBseqSQL)
					COMMIT TRAN BOMCOPYCN
				END TRY BEGIN CATCH
					IF XACT_STATE() IN (-1,1) and @@TRANCOUNT > 0
						ROLLBACK TRANSACTION
					IF XACT_STATE() = 1 and @@TRANCOUNT > 0
						ROLLBACK TRANSACTION BOMCOPYCN
					set @Infobar = isnull(ERROR_MESSAGE(),'Unknown error trapped')+' [error num: '+isnull(cast(ERROR_NUMBER() as nvarchar(9)),'null')+']'
					set @Infobar = replace(@infobar,'<MsgTag>','')
					return -16
				END CATCH
			end else begin
				EXECUTE @ret = [dbo].[MultiSiteBOMCopySp] @Site, @toSite, @Item, 0, @InfoBar OUTPUT

				If @ret <> 0 begin
					set @InfoBar=isnull(@Infobar,N'Unknown Error calling multi-site bom copy')
					return 16
				end
				exec (@updateBseqSQL)
--				select @updateBseqSQL
			end
		end

	end
	
	if @usernamesave is not null update SessionContextNames set CreatedBy = @usernamesave  where processid=@@SPID

	return 0
END
GO

