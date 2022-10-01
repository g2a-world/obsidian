/*********
	Summary Count of Customers by Country and Gender
**********/

Select g.EnglishCountryRegionName as Country
	   , sum(case when c.Gender = 'M' then 1 else 0 end) as MaleCustomers 
	   , sum(case when c.Gender = 'F' then 1 else 0 end) as FemaleCustomers
From [dbo].[DimGeography] as g join DimCustomer as c on c.GeographyKey = g.GeographyKey
Group By g.EnglishCountryRegionName
order by Country