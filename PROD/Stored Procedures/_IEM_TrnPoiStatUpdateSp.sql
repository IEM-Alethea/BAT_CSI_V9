SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[_IEM_TrnPoiStatUpdateSp]

AS

BEGIN

DECLARE @Site siteType;
SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()
EXEC dbo.SetSiteSp @Site, NULL

DECLARE @DBTable TABLE (
	  ID					INTEGER IDENTITY
	, app_db_name			NameType
	, site_name				SiteType
	)

DECLARE @POVchErr TABLE (
	  site_ref				SiteType
	, po_num				PoNumType
	, po_line				PoLineType
	)

DECLARE	  @Counter1					INT = 0
		, @CopyTableText			NVARCHAR(1000)

INSERT INTO @DBTable
	SELECT app_db_name, site_name
		FROM site
			WHERE site = @Site

SET @Counter1 = 0

WHILE @Counter1 < (SELECT MAX(ID) FROM @DBTable)
	BEGIN
		SET @Counter1 += 1
		SET @Site = (SELECT site_name FROM @DBTable WHERE ID = @Counter1)
		EXEC dbo.SetSiteSp @Site, NULL
			SET @CopyTableText = 'SELECT * FROM ' + @Site + '_App..trnitem
									WHERE (qty_req = 0 OR (qty_req = qty_shipped AND qty_shipped = qty_received))
										AND stat = ''O'''
			EXEC (@CopyTableText)
			SET @CopyTableText = 'UPDATE ' + @Site + '_App..trnitem SET stat = ''T''
									WHERE (qty_req = 0 OR (qty_req = qty_shipped AND qty_shipped = qty_received))
										AND stat = ''O'''
			EXEC (@CopyTableText)
			SET @CopyTableText = 'SELECT * FROM ' + @Site + '_App..trnitem
									WHERE (qty_req = 0 OR (qty_req = qty_shipped AND qty_shipped = qty_received))
										AND stat = ''T'''
			EXEC (@CopyTableText)
			SET @CopyTableText = 'UPDATE ' + @Site + '_App..trnitem SET stat = ''C''
									WHERE (qty_req = 0 OR (qty_req = qty_shipped AND qty_shipped = qty_received))
										AND stat = ''T'''
			EXEC (@CopyTableText)
			SET @CopyTableText = 'SELECT * FROM ' + @Site + '_App..trnitem tri
									WHERE (SELECT TOP 1 stat FROM ' + @Site + '_App..coitem WHERE co_num = tri.to_ref_num AND co_line = tri.to_ref_line_suf) = ''C''
										AND stat = ''T'''
			EXEC (@CopyTableText)
			SET @CopyTableText = 'UPDATE tri SET stat = ''C'' FROM ' + @Site + '_App..trnitem tri 
									WHERE (SELECT TOP 1 stat FROM ' + @Site + '_App..coitem WHERE co_num = tri.to_ref_num AND co_line = tri.to_ref_line_suf) = ''C''
										AND stat = ''T'''
			EXEC (@CopyTableText)
			SET @CopyTableText = 'SELECT * FROM ' + @Site + '_App..poitem
									WHERE (qty_ordered + qty_received + qty_voucher = 0 OR (qty_ordered = qty_received AND qty_received = qty_voucher))
										AND stat <> ''C'''
			EXEC (@CopyTableText)
			SET @CopyTableText = 'UPDATE ' + @Site + '_App..poitem SET stat = ''C''
									WHERE (qty_ordered + qty_received + qty_voucher = 0 OR (qty_ordered = qty_received AND qty_received = qty_voucher))
										AND stat <> ''C''
										AND NOT EXISTS (SELECT 1 FROM ' + @Site + '_App..lc_rcpt l WHERE l.ref_num = po_num
														AND l.ref_line_suf = po_line AND l.ref_release = po_release
														AND l.vouchered = 0)'
			EXEC (@CopyTableText)
			--SET @CopyTableText = 'SELECT * FROM ' + @Site + '_App..poitem
			--						WHERE due_date < ''2200-01-01''
			--							AND stat = ''P'''
			--EXEC (@CopyTableText)
			--SET @CopyTableText = 'UPDATE ' + @Site + '_App..poitem SET stat = ''O''
			--						WHERE due_date < ''2200-01-01''
			--							AND stat = ''P'''
			--EXEC (@CopyTableText)
	END

END




GO

