
--Get the weighted average price for all products
IF OBJECT_ID(N'tempdb..#TMP_Table', N'U') IS NOT NULL   
DROP TABLE #TMP_Table;
CREATE table #TMP_Table (Tovar char(9), NewPrice numeric(14,2));	--Temporary table to speed up work

IF OBJECT_ID(N'tempdb..#TMP_InsPrice', N'U') IS NOT NULL   
DROP TABLE #TMP_InsPrice;
CREATE table #TMP_InsPrice (Tovar char(9), AvgPrice numeric(14,2));	--Temporary table with prices for all products
	
With TableOst as(
	SELECT 
		  Остатки.sp306 Товар
		, Остатки.sp308 Серия  
		, Round(Sum(sp313)/Sum(sp309),3) as Цена
	FROM [BaseANR].[dbo].rg304 AS Остатки With (NOLOCK)
		INNER JOIN [BaseANR].[dbo].sc111 AS Номенклатура With (NOLOCK) ON Номенклатура.ID = Остатки.sp306
		INNER JOIN [BaseANR].[dbo].sc1106 AS ЛекСредства With (NOLOCK) ON ЛекСредства.ID = Номенклатура.sp1112
	WHERE 
		Остатки.PERIOD = dateadd(month,datediff(month,0,GetDate()),0)	--beginning of the month
		AND Номенклатура.sp1445 = 0	
	GROUP BY Остатки.sp306
			,Остатки.sp308       
	HAVING (Sum(Остатки.sp309) > 0)) 
	
	insert into #TMP_Table
	SELECT 
		BaseTable.Товар as Tovar,
			CASE
				WHEN Цена=TableMinPrice.МинЦена AND Цена<TableMaxPrice.МаксЦена THEN TableMaxPrice.МаксЦена
				ELSE Цена
			END
			as NewPrice
	FROM TableOst as BaseTable
		INNER JOIN (SELECT 
						Товар,
						MIN(Цена) as МинЦена
					FROM TableOst
					GROUP BY Товар
		) as TableMinPrice ON BaseTable.Товар = TableMinPrice.Товар
		INNER JOIN (SELECT 
						Товар,
						MAX(Цена)/1.1 as МаксЦена
					FROM TableOst
					GROUP BY Товар
		) as TableMaxPrice ON BaseTable.Товар = TableMaxPrice.Товар;
			
	insert into #TMP_InsPrice 
	Select
		Tovar
		,Round(AVG(NewPrice),2)	as AvgPrice
	FROM #TMP_Table
	GROUP BY Tovar;
--

--CURSOR ON INSURANCE
declare @LgotaKod numeric(5,0)
declare @PercentNum numeric(4,2)

declare ins_cursor cursor
for select 
		LgotaKod
		,PercentNum
	from
		TempDB_ANR.dbo.PriceForInsurance as PFI
	where Inactive = 0
open ins_cursor

fetch next from ins_cursor into @LgotaKod,@PercentNum
--loop bypass
while @@FETCH_STATUS=0
begin
	DELETE 
	FROM [Service_ANR].[dbo].[pricetas]
	WHERE ДатаПрайс = Cast(Cast(GETDATE() as date) as date)
	and ЛьготаКод = @LgotaKod;
	
	INSERT INTO [Service_ANR].[dbo].[pricetas] 
		([ДатаПрайс]
       ,[ЛьготаКод]
       ,[ИДТоварБаз]
       ,[Товар]
       ,[ЦенаРозн])
	SELECT 
		Cast(Cast(GETDATE() as date) as date)
		,@LgotaKod
		,BaseANR.[dbo]._StrToId(InsPrice.Tovar)
		,InsPrice.Tovar
		,Case 
			WHEN TovaruSK.[Percent] IS NOT NULL THEN InsPrice.AvgPrice*(1 + TovaruSK.[Percent]/100)
			ELSE InsPrice.AvgPrice*(1 + @PercentNum/100)
		 END
	FROM #TMP_InsPrice as InsPrice
	LEFT JOIN [TempDB_ANR].[dbo].[TovaruSK] as TovaruSK
		ON InsPrice.Tovar = TovaruSK.Tovar;

fetch next from ins_cursor into @LgotaKod,@PercentNum
end

close ins_cursor
deallocate ins_cursor
