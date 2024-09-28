### Query # 1 : Join - Average prescription count and length of stay based on ICU care unit and Insurance type

Select First_CareUnit, Last_CareUnit, Insurance, Round(Avg(Prescription_Count),0) as Avg_Prescription_Count
, Round(Avg(los),0) as Avg_LOS_ICU from
(Select hadm_id, icustay_id, count(Drug) as Prescription_Count from prescriptions
Group by hadm_id, icustay_id)a
Inner Join
(Select hadm_id, icustay_id, First_Careunit, Last_Careunit, los from icustays)b
on a.hadm_id = b.hadm_id and a.icustay_id = b.icustay_id 
Inner Join
(Select hadm_id, insurance from admissions)c
on b.hadm_id = c.hadm_id 
Group by Insurance, First_CareUnit, Last_CareUnit
Order by First_CareUnit, Last_CareUnit, Insurance


### Query # 2 : Nested Query & Join - % of Death out of total patients by Admission Type

Select a.Admission_Type, a.Death_Count, b.TotalPatientCount
, Round((cast(a.Death_Count as float)/b.TotalPatientCount)*100,2) as DeathRatio
from
(Select Admission_Type, Count(Subject_ID) as Death_Count from admissions
where Subject_ID in (
Select Subject_ID from
(Select Subject_ID, case when Year(deathtime)>0 and Year(deathtime) is not null then 'Yes' 
	else 'No' end as Patient_Death from admissions)a
Where Patient_Death like 'Yes') 
Group by Admission_Type)a
Inner Join
(Select Admission_Type, Count(*) as TotalPatientCount from admissions Group by Admission_Type) b
on a.Admission_Type = b.Admission_Type
Group by a.Admission_Type, a.Death_Count, b.TotalPatientCount
Order by Round((cast(a.Death_Count as float)/b.TotalPatientCount)*100,2) DESC


### Query # 3 : Date time: min & max - Average duration of each procedure event category

Select OrderCategoryName, Round(Avg(Duration_Hourly),0) as Avg_Duration_Hourly
From(
Select subject_id, hadm_id, icustay_id, OrderCategoryName, max(endtime) as EndTime, min(starttime) as StartTime
,Hour(TimeDiff(max(endtime),min(starttime))) as Duration_Hourly
from procedureevents_mv
Group by subject_id, hadm_id, icustay_id, OrderCategoryName)a
Group by OrderCategoryName
Order by Round(Avg(Duration_Hourly),0) DESC


### Query # 4 : Calculate % share of subsectionheader field within each sectionheader field 

With SectionHeader as
(
Select count(*) as Section_Count from cptevents
Where sectionheader like 'Evaluation%'
),
SubSectionHeader as
(
Select count(*) as SubSection_Count from cptevents
Where sectionheader like 'Evaluation%' and subsectionheader like 'Hospital Inpatient%' 
)
Select SubSectionHeader.Subsection_Count, SectionHeader.Section_Count
	, Round((SubSectionHeader.Subsection_Count/SectionHeader.Section_Count)*100,2) as "% share"
from SectionHeader, SubSectionHeader


### Query # 5: Table Join Example -  Average age (< 100) and length of ICU Stay by gender for each admission type

Select Age_Range, Gender_Type, Admission_Type, Round(Avg(los),0) as LOS_ICUStays
From
(Select Subject_id, Case when Gender  = 'M' then 'Male' 
	when Gender = 'F' then 'Female' else '' end as "Gender_Type"
    , Case when Round(Avg(Year(dod) - Year(dob)), 0)<=25 then '0 - 25'
		when (Round(Avg(Year(dod) - Year(dob)), 0)>25 and Round(Avg(Year(dod) - Year(dob)), 0)<=50) then '26 - 50'
        when (Round(Avg(Year(dod) - Year(dob)), 0)>50 and Round(Avg(Year(dod) - Year(dob)), 0)<=75) then '51 - 75'
        when (Round(Avg(Year(dod) - Year(dob)), 0)>75 and Round(Avg(Year(dod) - Year(dob)), 0)<=100) then '76 - 100'
        else '' end as Age_Range
From patients
Group by Subject_id, Case when Gender  = 'M' then 'Male' 
	when Gender = 'F' then 'Female' else '' end
)a
Inner join
(Select Subject_id, Hadm_ID, ADMISSION_TYPE
From admissions)b
on a.Subject_id = b.Subject_id
Inner join
(Select Subject_id, Hadm_ID, los
From icustays)c
on b.Subject_id = c.Subject_id and b.Hadm_ID = c.Hadm_ID
Where Age_Range <> ''
Group by Admission_Type, Gender_Type, Age_Range
Order by Age_Range, Gender_Type DESC


### Query # 6 : Temp table
	##Since MYSQL Workbench did not allow using temporary table more than once in the same query
	## decided to create two temp tables to do the calculation

## temp table #1
Drop table Patient_Stat_1

Create temporary table Patient_Stat_1
Select case when a.Gender='M' then 'Male' when a.Gender='F' then 'Female' else "" end as Gender_Type
, b.Admission_Type, Count(*) as Section_Counts from 
(Select Subject_id, Gender
From patients)a
Inner Join
(Select Subject_id, Hadm_ID, ADMISSION_TYPE
From admissions)b
on a.Subject_id = b.Subject_id
Inner join
(Select Subject_id, Hadm_ID, sectionheader, subsectionheader
From cptevents)c
on b.Subject_id = c.Subject_id and b.Hadm_ID = c.Hadm_ID
Group by case when a.Gender='M' then 'Male' when a.Gender='F' then 'Female' else "" end
, b.Admission_Type

## temp table #1
Drop table Patient_Stat_2

Create temporary table Patient_Stat_2
Select b.Admission_Type, Count(*) as Total_Counts from 
(Select Subject_id, Gender
From patients)a
Inner Join
(Select Subject_id, Hadm_ID, ADMISSION_TYPE
From admissions)b
on a.Subject_id = b.Subject_id
Inner join
(Select Subject_id, Hadm_ID, sectionheader, subsectionheader
From cptevents)c
on b.Subject_id = c.Subject_id and b.Hadm_ID = c.Hadm_ID
Group by b.Admission_Type

# Calculate the %share of admission_type by Gender types
Select a.Admission_type, a.Gender_Type, Round((Section_Counts/Total_Counts)*100,2) as "%share_CPTSection"
 from 
(select * from Patient_Stat_1) a
inner join 
(select * from Patient_Stat_2) b
on a.Admission_Type = b.Admission_Type
Order by Admission_Type, Gender_Type


### Query # 7 : Pivot table - Calculate % share of subsectionheader field within each sectionheader field Gender and Admission type

Select Curr_Service
, sum(case when Gender_Type = 'Female' then 1 else 0 end) as "Service_Count_Female"
, sum(case when Gender_Type = 'Male' then 1 else 0 end) as "Service_Count_Male"
, Count(*) as Total_Count
, Round(Cast(sum(case when Gender_Type = 'Female' then 1 else 0 end) as float)/Count(*),2) as "Service_%Share_Female"
, Round(Cast(sum(case when Gender_Type = 'Male' then 1 else 0 end) as float)/Count(*),2) as "Service_%Share_Male"
From
(Select Subject_id, Case when Gender  = 'M' then 'Male' 
	when Gender = 'F' then 'Female' else '' end as "Gender_Type"
    From patients
)a
Inner join
(Select Subject_id, Hadm_ID, Year(Admittime) as Admit_year
From admissions)b
on a.Subject_id = b.Subject_id
Inner join
(Select Subject_id, Hadm_ID, Curr_Service
From services)c
on b.Subject_id = c.Subject_id and b.Hadm_ID = c.Hadm_ID
Group by Curr_Service
Order by  Curr_Service ASC


### Query # 8: Nested Query & Join - summary of Hospital Admission when greater than (>) 3

Select a.Subject_id, Case when b.Gender = 'M' then 'Male' 
	when b.Gender = 'F' then 'Female' else '' end as "Gender_Type"
    , Case when (Year(b.dod) - Year(b.dob))>0 then (Year(b.dod) - Year(b.dob)) else '' end as 'Age'
    , Case when b.Expire_Flag=1 then 'Yes' else 'No' end as "Expire_Flag"
, a.Admission_Count, a.Admit_Year, a.Admission_Type, a.Insurance
from
(Select Subject_id, count(hadm_ID) as Admission_Count, Admit_Year, Admission_Type, Insurance
from 
(Select Subject_id, Hadm_ID, Year(admittime) as Admit_Year, Admission_Type, Insurance
From admissions)x
Group by Subject_id, Admit_Year, Admission_Type, Insurance having count(hadm_ID)>3
)a
Inner Join
(Select * from patients)b
on a.subject_id = b.subject_id
Order by Admit_Year ASC


### Query # 9 : Sub Query for subset of patients having having prescriptions along with ICU stays

Select a.subject_id, d.Gender, d.Age, b.StartDate, Diagnosis
	, Round(Avg(a.los),2) as Avg_LOS_ICU, concat(Drug_Type, ': ', Drug, ': ', Route) as Drug_Info from 
(
Select subject_id, hadm_id, icustay_id, los from icustays where ICUStay_ID in (
Select distinct ICUstay_ID from prescriptions where ICUstay_ID <> ''))a
Left join
(
SELECT subject_id, hadm_id, startdate, Drug_Type, Drug, Route FROM prescriptions)b
on a.subject_id = b.subject_id and a.hadm_id = b.hadm_id
Left join
(
SELECT subject_id, hadm_id, Diagnosis FROM admissions)c
on b.subject_id = c.subject_id and b.hadm_id = c.hadm_id
Left Join
(Select Subject_id, Gender
, Case when (Year(dod) - Year(dob))>0 then Round((Year(dod) - Year(dob)),0) else "" end as "Age"
    From patients) d
on a.subject_id = d.subject_id 
Group by a.subject_id, d.Gender, d.Age, b.StartDate, Diagnosis, concat(Drug_Type, ': ', Drug, ': ', Route)
having Round(Avg(a.los),2) >14
order by a.subject_id, b.StartDate ASC


### Query # 10 : Procedure events counts by Gender, Age Range and Insurance type

Select c.Insurance, a.Gender, Age_Range, b.OrderCategoryDescription
	, count(b.OrderCategoryName) as "OrderCategory_Counts"
    from 
(Select Subject_id, Gender
, Case when Round(Avg(Year(dod) - Year(dob)), 0)<=25 then '0 - 25'
	when (Round(Avg(Year(dod) - Year(dob)), 0)>25 and Round(Avg(Year(dod) - Year(dob)), 0)<=50) then '26 - 50'
	when (Round(Avg(Year(dod) - Year(dob)), 0)>50 and Round(Avg(Year(dod) - Year(dob)), 0)<=75) then '51 - 75'
	when (Round(Avg(Year(dod) - Year(dob)), 0)>75 and Round(Avg(Year(dod) - Year(dob)), 0)<=100) then '76 - 100'
	else '' end as Age_Range
    From patients Group by Subject_id, Gender
    ) a
inner join
(SELECT distinct subject_id, Hadm_ID, OrderCategoryName
	, OrderCategoryDescription FROM procedureevents_mv
)b
on a.subject_id = b.subject_id 
inner join
(SELECT distinct subject_id, Hadm_ID, Year(admittime) as Admit_Year, Insurance
FROM admissions
)c
on b.subject_id = c.subject_id and b.Hadm_ID = c.Hadm_ID
where Age_Range <>''
Group by a.Subject_ID, a.Gender, Age_Range, c.Insurance, b.OrderCategoryDescription
Order by Insurance, Age_Range, Gender
