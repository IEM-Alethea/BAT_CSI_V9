SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
exec setsitesp 'DFRE',null
declare @a nvarchar(100)
--exec _IEM_Util_Get 'polinecost', @a output, 'PF00000138','1'
--select * from poitem where po_num='PF00000138'
exec _IEM_Util_Get 'iszerocostitem', @a output, '886234C02'
select @a
*/
ALTER PROCEDURE [dbo].[_IEM_Util_Get]
    @type         nvarchar(20)='',
	@ret          nvarchar(100)='' OUTPUT,
    @val1         nvarchar(max)='',
	@val2         nvarchar(max)='',
	@val3         nvarchar(max)='',
	@val4         nvarchar(max)='',
	@val5         nvarchar(max)=''
AS
BEGIN
	
	if @type='pcode1' begin
		select @ret=product_code from item where item=@val1
	end else if @type='polinecost' begin
		select @ret=cast(qty_ordered * item_cost as nvarchar(100)) from poitem where po_num = @val1 and po_line = @val2
	end else if @type = 'iszerocostitem' begin
		set @ret = 0
		if not exists (select 1 from item where item=@val1) begin --non-inventory
			if exists (
				SELECT 1 FROM non_inventory_item i
				JOIN objectnotes o ON o.RefRowPointer = i.RowPointer
				JOIN specificnotes s ON s.SpecificNoteToken = o.SpecificNoteToken
				JOIN noteheaders n ON n.NoteHeaderToken = o.NoteHeaderToken
				WHERE n.ObjectName = 'non_inventory_item' AND n.NoteFlag = 1 AND REPLACE(LOWER(s.NoteDesc),' ','') in ('zerocost','truecost') and i.item = @val1
			) begin
				set @ret = 1
			end
		
		end else begin --inventory
			if exists (
				SELECT 1 FROM item i
				JOIN objectnotes o ON o.RefRowPointer = i.RowPointer
				JOIN specificnotes s ON s.SpecificNoteToken = o.SpecificNoteToken
				JOIN noteheaders n ON n.NoteHeaderToken = o.NoteHeaderToken
				WHERE n.ObjectName = 'item' AND n.NoteFlag = 1 AND REPLACE(LOWER(s.NoteDesc),' ','') in ('zerocost','truecost') and i.item = @val1
			) begin
				set @ret = 1
			end
		end
	end else begin
		set @ret='error'
	end

END