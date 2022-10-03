/*********
	Summary Count of Customers by Country and Gender

	Is this going to be added on develop branch?

	Yes, indeed. It worked as expected.

**********/
With tbl_Table1 As (
	Select g.EnglishCountryRegionName as Country
		   , sum(case when c.Gender = 'M' then 1 else 0 end) as MaleCustomers 
		   , sum(case when c.Gender = 'F' then 1 else 0 end) as FemaleCustomers
		   , count(c.CustomerKey) as TotalCustomer
	From [dbo].[DimGeography] as g join DimCustomer as c on c.GeographyKey = g.GeographyKey
	Group By g.EnglishCountryRegionName
	
)

Select *, (cast(MaleCustomers as decimal(6, 2)) * 100)/TotalCustomer as Pct_Male
		, (Cast(FemaleCustomers as decimal(6, 2)) * 100)/TotalCustomer as Pct_Female
From tbl_Table1
order by Country