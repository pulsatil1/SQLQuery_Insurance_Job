
--�������� ���������������� ���� �� ���� �������
IF OBJECT_ID(N'tempdb..#TMP_Table', N'U') IS NOT NULL   
DROP TABLE #TMP_Table;
CREATE table #TMP_Table (����� char(9), NewPrice numeric(14,2));	--��������� ������� ��� ��������� ������

IF OBJECT_ID(N'tempdb..#TMP_InsPrice', N'U') IS NOT NULL   
DROP TABLE #TMP_InsPrice;
CREATE table #TMP_InsPrice (Tovar char(9), AvgPrice numeric(14,2));	--��������� ������� � ������ �� ���� �������
	
With TableOst as(
	SELECT 
		  �������.sp306 �����
		, �������.sp308 �����  
		, Round(Sum(sp313)/Sum(sp309),3) as ����
	FROM [BaseANR].[dbo].rg304 AS ������� With (NOLOCK)
		INNER JOIN [BaseANR].[dbo].sc111 AS ������������ With (NOLOCK) ON ������������.ID = �������.sp306
		INNER JOIN [BaseANR].[dbo].sc1106 AS ����������� With (NOLOCK) ON �����������.ID = ������������.sp1112
	WHERE 
		--�������.PERIOD = dateadd(month,datediff(month,0,GetDate()),0)	--������ ������
		�������.PERIOD = (SELECT MAX(���.PERIOD) FROM [BaseANR].[dbo].rg304 AS ��� With (NOLOCK))	--��� ���������� ������� � ������ ������������
		AND ������������.sp1445 = 0	
	GROUP BY �������.sp306
			,�������.sp308       
	HAVING (Sum(�������.sp309) > 0)) 
	
	insert into #TMP_Table
	SELECT 
		BaseTable.����� as �����,
			CASE
				WHEN ����=TableMinPrice.������� AND ����<TableMaxPrice.�������� THEN TableMaxPrice.��������
				ELSE ����
			END
			as NewPrice
	FROM TableOst as BaseTable
		INNER JOIN (SELECT 
						�����,
						MIN(����) as �������
					FROM TableOst
					GROUP BY �����
		) as TableMinPrice ON BaseTable.����� = TableMinPrice.�����
		INNER JOIN (SELECT 
						�����,
						MAX(����)/1.1 as ��������
					FROM TableOst
					GROUP BY �����
		) as TableMaxPrice ON BaseTable.����� = TableMaxPrice.�����;
			
	insert into #TMP_InsPrice 
	Select
		����� as Tovar
		,Round(AVG(NewPrice),2)	as AvgPrice
	FROM #TMP_Table
	GROUP BY �����;
--

--������ �� ���������
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
--����� �����
while @@FETCH_STATUS=0
begin
	DELETE 
	FROM [Service_ANR].[dbo].[pricetas]
	WHERE ��������� = Cast(Cast(GETDATE() as date) as date)
	and ��������� = @LgotaKod;
	
	INSERT INTO [Service_ANR].[dbo].[pricetas] 
		([���������]
       ,[���������]
       ,[����������]
       ,[�����]
       ,[��������])
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
	
	