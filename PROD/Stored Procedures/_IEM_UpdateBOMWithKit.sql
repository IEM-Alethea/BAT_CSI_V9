SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*
exec setsitesp 'DFRE',''
exec _IEM_UpdateBOMWithKit 'KIT=$CHMDL3400LS'
*/
ALTER PROCEDURE [dbo].[_IEM_UpdateBOMWithKit] 
	@kit itemType
AS
BEGIN
	declare itemCrs cursor for
		select i.item, jm.createdby
		from item i
		join job j on j.job=i.job and j.suffix=i.suffix
		join jobmatl jm on jm.job=j.job and jm.suffix=j.suffix
		where  
		jm.item = @kit
		and exists (select 1 from job where type='J' and stat='R' and job.item=i.item)

	
	OPEN itemCrs;

    declare @item itemtype, @createdBy usernametype
	declare @tinfo infobartype = null, @severity int=0
	WHILE 1=1
    BEGIN
        FETCH NEXT FROM itemCrs INTO @item, @createdby
        IF @@FETCH_STATUS <> 0 BREAK;

		select @tinfo = null, @severity = 0
		exec @severity=_IEM_DoUpdateJobsSp @item=@item, @infobar=@tinfo output, @username=@createdby
	END
	close itemCrs
	deallocate itemCrs
END



GO


