BEGIN TRY
    BEGIN TRANSACTION

    --******CODE *******--

    --******CODE *******--
    
	COMMIT TRAN 
			
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN 
     declare @mes varchar(max)  = ERROR_MESSAGE(),
     	@codSev int = ERROR_SEVERITY()
     	
	SELECT ERROR_MESSAGE(), ERROR_SEVERITY();

	RAISERROR(@mes,@codSev,1)
END CATCH
GO