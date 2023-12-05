/* This is a data cleaning project of nashville housing data
data was extracted from Alex the Analyst GitHub profile.

First step is an explorative look at the data to see what it looks like &  the overall data*/

select *

from NashvilleHousing
/* there are 56477 rows of data with some columns having nulls and each one will be tackled as per the way the data is missing
we first start by standardizing the date formats
*/


select SaleDate
from NashvilleHousing

update NashvilleHousing
set SaleDate = convert(date,saledate)

/* next we see that the property address contains null values and affects other fields that may relate to the address. we can note that the
parcelID is unique & linked to an address, so we can perhaps use it as a referrence for updating the property address
Select *
From dbo.NashvilleHousing
--Where PropertyAddress is null
--order by ParcelID

From this initial query we can see that there is some address information in terms of the owner however we can simply create a self join 
to create a mapping for which the PacelID has an address and use that to update our table
*/


Select a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress,b.PropertyAddress)
From dbo.NashvilleHousing a
JOIN dbo.NashvilleHousing b
	on a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
Where a.PropertyAddress is null
/* this gives us a view from which we can extract the data we need to update the table*/

Update a
SET PropertyAddress = ISNULL(a.PropertyAddress,b.PropertyAddress)
From dbo.NashvilleHousing a
JOIN dbo.NashvilleHousing b
	on a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
Where a.PropertyAddress is null

Alter Table [dbo].[NashvilleHousing]
ADD StreetAddress Nvarchar(255);
Update NashvilleHousing
set StreetAddress = SUBSTRING(PropertyAddress,1,CHARINDEX(',',PropertyAddress)-1)

Alter Table [dbo].[NashvilleHousing]
ADD City nvarchar(255);
Update NashvilleHousing
set City =SUBSTRING(PropertyAddress,CHARINDEX(',',PropertyAddress)+1,LEN(PropertyAddress)) 

/* 
We want to know whether the house was sold as vacant, however we see that the field has a bit data type thus we want to convert it Yes or No
We don't want to update the table as we want to run it into our ML algorithm thus we shall keep the original and create a query for it as we want it expressed 
in a yes or no format
*/ 
Select COUNT(CONVERT(nvarchar(MAX),SoldAsVacant)) AS Sold_Count
, CASE When CONVERT(nvarchar(MAX),SoldAsVacant) = '1' THEN 'Yes'
	   When CONVERT(nvarchar(MAX),SoldAsVacant) = '0' THEN 'No'
	   ELSE CONVERT(nvarchar(MAX),SoldAsVacant)
	   END as Sold_As_Vacant
From dbo.NashvilleHousing
group by SoldAsVacant

/*
When exploring this data further we saw that there were duplicate data and as such we partition the data to see if we had duplicates that we can remove
We created a CTE to use for our delete function so as to remove the duplicates

We want to run this data through out python ML algorithm thus if we have duplicate data then essentially we are giving that data extra weight
*/
-- Removing the Duplicates
WITH RowNumCTE AS(
Select *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
					) row_num
From dbo.NashvilleHousing
--order by ParcelID
)
DELETE 
From RowNumCTE
Where row_num > 1
--------------------------------------------------------------------------------------------------------------------------
/* there seems to be null values still for the OwnerName,Address acreage,land value & other quantitative data that will confuse our ML algo
thus lets explore them & see how we deal with them

The first I will do is order by the fields with null values and see if information can't be pulled from a previous transaction that might allow us to 
update the missing values
*/
-- the query below shows that the issues with the house specs are somewhat linked to the missing information relating to the year it was build
select
count(UniqueID),YearBuilt,AVG(SalePrice) AVG_SalePrice
,OwnerName, OwnerAddress, Acreage, TaxDistrict, LandValue, BuildingValue, TotalValue, Bedrooms, FullBath, HalfBath
from NashvilleHousing
--where YearBuilt is not null
group by YearBuilt
,OwnerName, OwnerAddress, Acreage, TaxDistrict, LandValue, BuildingValue, TotalValue, Bedrooms, FullBath, HalfBath
order by 1 desc,YearBuilt
--There is 30404 (over 60% of our data) as such the simple solution I took was to just filter out the null values based on the null in the YearBuilt column
-- I did not update the table as the missing information can be rectified with further research / investigation of the municipal records which would be usefull info

select 
	YEAR(SaleDate) as Year_of_Sale
	,AVG(SalePrice) as AVG_Sale_Price
	,YearBuilt
from NashvilleHousing
--where YearBuilt is not null


group by YearBuilt, SaleDate
order by SaleDate

/*
Once metric that might of interest to our ML algo is the age of the house at the date of sale as this could influence the value of the house
Having the age along with both the year built and date of sale will cause colinearity however we will deal with that on python when we look at feature selection

*/
Alter Table [dbo].[NashvilleHousing]
ADD Age_of_House int;
Update NashvilleHousing
set Age_of_House =(cast(YEAR(SaleDate) as int) - YearBuilt)