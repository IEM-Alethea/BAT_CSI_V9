SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



/**************************************************************************
*                            Modification Log
*                                            
* Ref#  Init Date     Description           
* ----- ---- -------- ----------------------------------------------------- 
* MOD146 JWP   122915  Import job labor transactions
exec _IEM_ImportLaborTransactionsLauncherSp
***************************************************************************/
ALTER PROCEDURE [dbo].[_IEM_ImportLaborTransactionsSp] (
	@Infobar InfobarType OUTPUT
)
AS
BEGIN

	DECLARE 
		@Severity INT
		,@ID INT
		,@hoursWorked DECIMAL(19,8)
		,@DateWorked DateType
		,@employeeNumber EmpNumType
		,@jobNumber JobType
		,@workCenter WCType
		,@DcsfcRowpointer RowPointerType
		,@PPostDate DateTime
		,@StopPost ListYesNoType
		,@PCanOverride ListYesNoType
		,@Site SiteType
		,@SQL NVARCHAR(MAX)
		,@Debug ListYesNoType
		,@JobtranRowPointer RowPointerType
		,@SessionID UniqueIdentifier
		,@OperNum OperNumType
		,@jobSuffix SuffixType
		,@Whse WhseType
		,@RecordID INT
		,@RecordsPosted INT
		,@Errors INT
		,@TimeStamp INT
		,@postMethod NVARCHAR(200)
		,@fisiID nvarchar(45)

	declare @cardnumber nvarchar(20)
	        ,@firstname nvarchar(30)
	        ,@lastname nvarchar(30)
	
	declare @emp table (
		firstname nvarchar(30)
		,lastname nvarchar(30)
		,cardnumber nvarchar(20)
	)


	Set @TimeStamp=DATEDIFF(second,{d '1970-01-01'},GETUTCDATE())

	SET @Debug = 0
	SET @Errors = 0
	SET @RecordsPosted = 0

	SELECT @Site = site
	FROM site
	WHERE app_db_name = DB_NAME()

	EXEC SetSiteSp @Site, @InfoBar OUTPUT

	IF @Debug = 1
		PRINT @Site

	SET @Severity = 0
	SET @PCanOverride = 1
	SET @SessionID = dbo.SessionIDSp()

	DECLARE @LaborTrans TABLE(
		id INT
		,hoursWorked DECIMAL(19,8)
		,dateWorked INT
		,employeeNumber NVARCHAR(7)
		,site NVARCHAR(8)
		,jobNumber NVARCHAR(20)
		,jobSuffix SuffixType
		,workCenter NVARCHAR(100)
		,recordID UNIQUEIDENTIFIER
		,dateRecorded INT
		,error NVARCHAR(2800)
		,datePosted INT
		,fisiID nvarchar(45)
		,postMethod NVARCHAR(200)
	)

	SET @SQL = 'SELECT * FROM OPENQUERY(EQUOTE, ''SELECT id,hoursWorked,dateWorked,employeeNumber,site,job,suffix,workCenter,recordID,dateRecorded,error,datePosted,fisiID,postMethod FROM laborTransb WHERE recordID IS NULL AND error IS NULL AND site = ''''' + @Site + ''''''')'

	IF @Debug = 1
	BEGIN
		PRINT @SQL
		PRINT 'Importing records into @LaborTrans'
	END

	INSERT INTO @LaborTrans
	EXEC(@SQL)

	DELETE lt FROM @LaborTrans lt WHERE NOT EXISTS (SELECT 1 FROM jobroute WHERE job = lt.jobNumber AND suffix = lt.jobSuffix AND wc = lt.workCenter)
	
	IF @Debug = 1
		PRINT 'Records inserted into @LaborTrans'

	DECLARE crsLaborTrans CURSOR FORWARD_ONLY FOR
	SELECT 	id,
			hoursWorked,
			dbo.MidnightOf(DATEADD(second, dateWorked, '1/1/1970')),
			employeeNumber,
			jobNumber,
			workCenter,
			jobSuffix,
			fisiID
	FROM @LaborTrans
	OPEN crsLaborTrans

	WHILE 1=1
	BEGIN
		FETCH NEXT FROM crsLaborTrans INTO 
			@ID, @hoursWorked, @dateWorked, @employeeNumber, @jobNumber, @workCenter, @jobSuffix, @fisiID

		IF @@fetch_status <> 0
			break;

		/*
		if @fisiID = 'oct.reversal'
			SET @PPostDate = '2016-10-31 01:23:45'
		else
		*/
			SET @PPostDate = GetDate()

		/*
		IF NOT EXISTS (SELECT * FROM job WHERE job = @jobNumber AND suffix = @jobSuffix AND stat = 'R')
		BEGIN
			SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT id, error from laborTransb WHERE id = ' + CAST(@ID AS NVARCHAR(8)) + ''') SET error = ''Job ' + @jobNumber + '-' + CONVERT(varchar(4), @jobSuffix) + ' with status R does not exist.'' ' 

			IF @Debug = 1
			BEGIN
				PRINT @SQL
			END

			EXEC(@SQL)
			SET @Errors = @Errors + 1
			CONTINUE
		END
		*/

		set @postMethod = NULL
		IF NOT EXISTS(SELECT * FROM job WHERE job = @jobNumber AND suffix = @JobSuffix and stat='R')
		BEGIN
			if EXISTS(SELECT * FROM job WHERE job = @jobNumber AND suffix = @JobSuffix and stat='C') begin
				begin try
					update job set stat='R' where job = @jobNumber AND suffix = @JobSuffix
				end try
				begin catch
					SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT id, error from laborTrans WHERE id = ' + CAST(@ID AS NVARCHAR(8)) + ''') SET error = ''Job ' + @jobNumber + '-' + CONVERT(varchar(4), @jobSuffix) + ' could not be reopened.'' ' 
					EXEC(@SQL)
					SET @Errors = @Errors + 1
					CONTINUE;
				end catch
				set @postMethod = 'Reopened line'
				update @LaborTrans set postMethod = @postMethod where id=@ID
			end
		END

		IF @workCenter is NULL
		BEGIN
			SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT id, error from laborTransb WHERE id = ' + CAST(@ID AS NVARCHAR(8)) + ''') SET error = ''For Job ' + @jobNumber + '-' + CONVERT(varchar(4), @jobSuffix) + ' , wc is NULL.'' ' 

			IF @Debug = 1
			BEGIN
				PRINT @SQL
			END

			EXEC(@SQL)
			SET @Errors = @Errors + 1
			CONTINUE
		END

		IF NOT EXISTS (SELECT * FROM wc WHERE wc=@workCenter)
		BEGIN
			SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT id, error from laborTransb WHERE id = ' + CAST(@ID AS NVARCHAR(8)) + ''') SET error = ''For Job ' + @jobNumber + '-' + CONVERT(varchar(4), @jobSuffix) + ' , wc "'+@workCenter+'" does not exist.'' ' 

			IF @Debug = 1
			BEGIN
				PRINT @SQL
			END

			EXEC(@SQL)
			SET @Errors = @Errors + 1
			CONTINUE
		END


		if len(@employeeNumber)=7 and left(@employeeNumber,1) = 'E' and not exists (select null from employee where emp_num = @employeeNumber) begin
			set @cardnumber = right(@employeeNumber,len(@employeeNumber)-1) + 0

			delete from @emp

			SET @SQL = 	'SELECT * FROM OPENQUERY(EQUOTE, ''SELECT firstname, lastname, cardnumber from novatimeemployee where cardnumber = ' + @cardnumber + ';'')'
			insert into @emp (
				firstname
				,lastname
				,cardnumber
			) exec (@SQL)

			select top 1 @firstname = firstname, @lastname = lastname, @cardnumber = cardnumber from @emp where cardnumber = @cardnumber

			if @firstname is not null and @lastname is not null and @cardnumber is not null begin
				begin try
					insert into 
					employee (emp_num, name, dept, emp_type, pay_freq, marital_stat, wage_acct, union_type, shift, pr_from, lname, fname, citizen, email_addr)
					  values (@employeeNumber, left(@lastname+', '+@firstname, 35), 400, 'H', 'D', 'S', '60500', 'F', 'DAY', 'N', left(@lastname, 15), left(@firstname,15), 1, left(@firstname+'.'+@lastname,60-len('@iemfg.com'))+'@iemfg.com')
				end try
				begin catch
					SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT id, error from laborTransb WHERE id = ' + CAST(@ID AS NVARCHAR(8)) + ''') SET error = ''Employee Number "' + @employeeNumber+'" could not be inserted.'' ' 
					EXEC(@SQL)
					SET @Errors = @Errors + 1
					CONTINUE
				end catch
			end
		end

		IF NOT EXISTS (select * from employee where emp_num=@employeeNumber)
		BEGIN
			SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT id, error from laborTransb WHERE id = ' + CAST(@ID AS NVARCHAR(8)) + ''') SET error = ''Employee Number "' + @employeeNumber+'" does not exist.'' ' 

			IF @Debug = 1
			BEGIN
				PRINT @SQL
			END

			EXEC(@SQL)
			SET @Errors = @Errors + 1
			CONTINUE
		END


		SET @OperNum = NULL

/*		SELECT @OperNum = oper_num
		FROM jobroute 
		WHERE job = @jobNumber
			AND suffix = @jobSuffix
			AND wc = @workCenter
*/
--		IF @OperNum IS NULL
--		BEGIN
-- djh 2016-04-18, always call to update costs
			IF @Debug = 1
				PRINT 'Calling _IEM_CreateJobOperationSp'

			--SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT id, error from laborTransb WHERE id = ' + CAST(@ID AS NVARCHAR(8)) + ''') SET error = ''No job routings exist for specified work center.''' 
			BEGIN TRANSACTION
			EXEC @Severity = _IEM_CreateJobOperationSp
				@Job = @jobNumber
				,@Suffix = @jobSuffix
				,@WorkCenter = @workCenter
				,@LaborHours = 0
				,@OperNum = @OperNum OUTPUT
				,@Infobar = @Infobar OUTPUT

			COMMIT TRANSACTION
			IF @Debug = 1
			BEGIN
				PRINT 'Back from _IEM_CreateJobOperationSp'
			END

--		END

		if (select complete from jobroute where job=@jobNumber and suffix=@jobSuffix and oper_num=@OperNum) <> 0 begin
			begin try
				update jobroute set complete=0 where job=@jobNumber and suffix=@jobSuffix and oper_num=@OperNum
			end try begin catch
				SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT id, error from laborTransb WHERE id = ' + CAST(@ID AS NVARCHAR(8)) + ''') SET error = ''Could not re-open operation'' ' 

				EXEC(@SQL)
				SET @Errors = @Errors + 1
				CONTINUE
			end catch
		end

		SELECT @Whse = whse
		FROM job
		WHERE job = @jobNumber
			AND suffix = @jobSuffix

		-- Create record in dcsfc_mst
		BEGIN TRANSACTION
		INSERT INTO jobtran(job, suffix, trans_type, trans_date, qty_complete, qty_scrapped, oper_num, a_hrs, emp_num, a_$, pay_rate, qty_moved, whse, loc, close_job, issue_parent, complete_op, pr_rate, job_rate, shift, posted, low_level, backflush, trans_class, wc, awaiting_eop, fixovhd, varovhd, co_product_mix)
		VALUES(@jobNumber, @jobSuffix, 'R',@PPostDate, 0, 0, @OperNum, @hoursWorked, @employeeNumber, 0, 'R', 0, @Whse, 'STOCK', 0, 0, 0, 0, 0, 'DAY', 0, 0, 0, 'J', @workCenter, 0, 0, 0, 0)
--		VALUES(@jobNumber, @jobSuffix, 'R',@dateWorked, 0, 0, @OperNum, @hoursWorked, @employeeNumber, 0, 'R', 0, @Whse, 'STOCK', 0, 0, 0, 0, 0, 'DAY', 0, 0, 0, 'J', @workCenter, 0, 0, 0, 0)
		COMMIT TRANSACTION

		SELECT TOP 1 @RecordID = trans_num, @JobtranRowPointer = RowPointer
		FROM jobtran
		WHERE job = @jobNumber
			AND suffix = @jobSuffix
			AND a_hrs = @hoursWorked
			AND posted = 0
		ORDER BY CreateDate desc

		IF @Debug = 1
		BEGIN
			PRINT 'Jobtran record created'
			PRINT @RecordID
			PRINT @JobtranRowPointer
		END


		IF @Debug = 1
			PRINT 'Posting transaction'

		BEGIN TRANSACTION

		EXEC @Severity = PostJobTransactions1Sp
			@SessionID = @SessionID
			,@SJobtranRowPointer = @JobtranRowPointer
			,@PPostNeg = 1
			,@CurWhse = @Whse
			,@Infobar = @Infobar OUTPUT
			,@PromptButtons = NULL

		IF @Debug = 1
		BEGIN
			PRINT 'Back from posting'
			PRINT @Infobar
		END

		IF @Severity <> 0
		BEGIN
			SET @Errors = @Errors + 1
			ROLLBACK TRANSACTION
			delete FROM jobtran	WHERE job = @jobNumber AND suffix = @jobSuffix and RowPointer = @JobtranRowPointer and posted=0
		END
		ELSE
		BEGIN
			COMMIT TRANSACTION
			SET @RecordsPosted = @RecordsPosted + 1
		END
		
		-- djh 2017-01-20.  add check to close jobs where qty_complete >= qty_released.  
		-- to catch jobs that are opened through unknown method.  
		-- the close below may be failing sometimes, but it will close on next labor posted if so

		if @postMethod is not null or exists (select 1 from job where job=@jobNumber and suffix=@JobSuffix and (qty_complete >= qty_released or item='UNPOSTABLEJOBCOSTS')) begin --happens when job had to be reopened or unpostable job costs had to be reopened
			begin try
				begin tran
					delete FROM jobtran WHERE job = @jobNumber AND suffix = @jobSuffix and posted=0 -- cannot close job if unposted transactions.  since we just opened it, it shouldn't exist, but just in case
				commit tran
			end try begin catch
				rollback tran
			end catch
			
			/*begin try
				update job set stat='C' where job=@jobNumber and suffix=@JobSuffix
				/*
				if @fisiID = 'oct.reversal' begin
					update j set trans_date = @PPostDate
					from journal j 
					join (select top 1 * from matltran m where m.ref_num=@jobNumber and m.ref_line_suf=@jobSuffix order by trans_date desc) m
					on m.trans_num=j.matl_trans_num
				end --*/
			end try begin catch
				SET @Errors = @Errors + 1
			end catch*/
		end

		SET @Severity = 0

		SET @SQL = 'UPDATE OPENQUERY(EQUOTE, ''SELECT id, recordID, error, datePosted, postMethod from laborTransb WHERE id = ' + CAST(@ID AS NVARCHAR(8)) + ''') SET recordID = ' + ISNULL(CAST(@RecordID AS NVARCHAR(8)),'NULL') + ', datePosted=' + CAST(@TimeStamp AS NVARCHAR(16)) + ', error = '''+ ISNULL(@Infobar,'') + ''', postMethod = ' + CASE WHEN @postMethod IS NULL THEN 'NULL' ELSE '''' + @postMethod + '''' END 

		IF @Debug = 1
		BEGIN
			PRINT 'TRANCOUNT:'
			PRINT @@TRANCOUNT
			PRINT '----------------'
			PRINT @SQL
		END

		EXEC(@SQL)

	END
	CLOSE crsLaborTrans
	DEALLOCATE crsLaborTrans

	SET @Infobar = 'Number of records posted:  ' + CAST(@RecordsPosted AS NVARCHAR(8)) + '.  Number of errors:  ' + CAST(@Errors AS NVARCHAR(8))

	RETURN 0

END


GO

