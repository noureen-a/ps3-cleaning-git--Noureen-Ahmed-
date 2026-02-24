* Noureen Ahmed
* February 23, 2026
* PUBH 5101W
* Problem Set 3- Cleaning Pipelines, Panel Checks, and Your First GitHub Repo

*************************************************************
* First Steps
capture log close
clear all

*************************************************************

* 1. Initialize and begin logging
* Set your working directory to the problem set folder.
global proj "/Users/noureenahmed/Desktop/Lec 3"
cd "$proj"
capture mkdir "processed_data"
capture mkdir "logs"
* Start a log file named logs/ps3.log.
log using "logs/ps3.log", text replace

*************************************************************

* 2. Part A: Clean and validate people_full.csv

* Import with stringcols(_all).
import delimited "/Users/noureenahmed/Desktop/Lec 3/Problem Set 3/pset3_data/people_full.csv", clear varnames(1) stringcols(_all)

* Standardize location and sex strings (trim/case cleanup).

* remove the spaces for location
replace location = strtrim(location)

* Unify all of the locations to lower case letters
replace location = strlower(location)

* Provide proper casing for locations
replace location = strproper(location)

* remove the spaces for sex
replace sex = strtrim(sex)

* change all of the sex to lower case letters
replace sex = strlower(sex)

* provide proper casing for sex
replace sex = strproper(sex)

* Convert the following columns from strings to numeric and handle "NA" correctly: person_id, household_id, age, height_cm, weight_kg, systolic_bp, diastolic_bp.
foreach var in person_id household_id age height_cm weight_kg systolic_bp diastolic_bp {
	replace `var' = "" if `var' == "NA"
	destring `var', replace
}


* Convert date/time fields by creating visit_date from date_str, visit_time from time_str, and people_year from visit_date.

* Date
generate visit_date = date(date_str, "MDY")

format visit_date %td

* Time
generate visit_time = clock(time_str, "hms")

format visit_time %tcHH:MM:SS

* visiting year
generate people_year = yofd(visit_date)


* Run QA checks:
misstable summarize

	* no missing person_id (use assert !missing(person_id))
	assert !missing(person_id)
	
	* unique key person_id people_year (use isid person_id people_year)
	isid person_id people_year
	
	* each non-missing person_id has 5 observations (use bysort person_id: assert _N == 5)
	bysort person_id: assert _N == 5
	
* Create categorical encodings named sex_id and location_id.

* For Sex
tab sex, missing
encode sex, generate(sex_id)

* For Location
tab location, missing
encode location, generate(location_id)

* Create these grouped variables using bysort:
* set up sort order
sort household_id person_id people_year

* hh_n: number of rows per household_id
bysort household_id: generate hh_n = _N

* note- _N is total rows in group

* hh_row: within-household row index after sorting by person_id people_year
bysort household_id (person_id people_year): generate hh_row = _n
* note- _n is row number within a group

* hh_mean_age: household-level mean of age
by household_id: egen hh_mean_age = mean(age)


* Export a cleaned file to processed_data/ps3_people_clean.csv.
export delimited using "processed_data/ps3_people_clean.csv", replace

*************************************************************

* Part 3 Part A: Clean and validate households.csv
import delimited "/Users/noureenahmed/Desktop/Lec 3/Problem Set 3/pset3_data/households.csv", clear varnames(1) stringcols(_all)

*Convert household_id year region_id income hh_size from strings to numeric (handle "NA" if present).
foreach var in household_id year region_id income hh_size {
	replace `var' = "" if `var' == "NA"
	destring `var', replace
}

*  Encode region into region_code and inspect labels.
*check table missing for regions
table region, missing 

encode region, generate(region_code)
label list region_code 


* Create these grouped variables:

* year_mean_income: mean of income by year
bysort year: egen year_mean_income = mean(income)

* region_year_mean_income: mean of income by region_code year
bysort region_code year: egen region_year_mean_income = mean(income)

* region_year_row: within-region_code index after sorting by year
bysort region_code (year): generate region_year_row =_n

* Run this regression (factor-variable notation): reg income i.region_code c.hh_size##c.year.
reg income i.region_code c.hh_size##c.year


* Export a cleaned file to processed_data/ps3_households_clean.csv.
export delimited using "processed_data/ps3_households_clean.csv", replace

*************************************************************

* Part 4. Part A: Clean and validate regions.csv as panel data
import delimited "/Users/noureenahmed/Desktop/Lec 3/Problem Set 3/pset3_data/regions.csv", clear varnames(1) stringcols(_all)


*Convert numeric variables from strings and handle "NA".
foreach var in region_id year median_income population {
	replace `var' = "" if `var' == "NA"
	destring `var', replace 
}

* Drop rows with missing panel keys.
count if missing(region_id) | missing(year)
* five missing duplicates
duplicates report region_id year
drop if missing(region_id) | missing(year)

* Verify unique region_id year.
isid region_id year


* Declare panel structure with xtset region_id year.
xtset region_id year

* Generate both:
* yoy_change_median_income = median_income - L.median_income
generate yoy_change_median_income = median_income - L.median_income
* median_income_growth_rate = (median_income - L.median_income) / L.median_income
generate median_income_growth_rate = (median_income - L.median_income) / L.median_income

* Run xtdescribe and xtsum median_income population yoy_change_median_income median_income_growth_rate.
xtdescribe
xtsum median_income population yoy_change_median_income median_income_growth_rate


*Export a cleaned file to processed_data/ps3_regions_clean.csv.

export delimited "processed_data/ps3_regions_clean.csv", replace

* Problem set completed, remainder of the assignment is to create a github and upload materials on github and d2l

display "log ended:" c(current_date) " " c(current_time)

log close  


* github link- https://github.com/noureen-a/ps3-cleaning-git--Noureen-Ahmed-.git 
