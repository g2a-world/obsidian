Use AdventureWorksDW2012
Go

/*********
	Count Number of customers and calculate the total sales amount, present the result by Country
**********/
;with tbl_Table1
As
(
	Select g.EnglishCountryRegionName as Country
		   , Format(sum(case when c.Gender = 'M' then 1 else 0 end), 'N0') as MaleCustomers 
		   , Format(sum(case when c.Gender = 'M' then i.SalesAmount else 0 end), 'C2') as MaleTotalSale 
		   , Format(sum(case when c.Gender = 'F' then 1 else 0 end), 'N0') as FemaleCustomers
		   , Format(sum(case when c.Gender = 'F' then i.SalesAmount else 0 end), 'C2') as FemaleTotalSale
	From [dbo].[DimGeography] as g join DimCustomer as c on c.GeographyKey = g.GeographyKey
	Join FactInternetSales as i on i.CustomerKey = c.CustomerKey
	Group By g.EnglishCountryRegionName
	
)

Select * from tbl_Table1
order by Country