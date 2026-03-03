********************************************************
* Noureen Ahmed
* PUBH 5105W
* March 02, 2026
* Problem Set 4: Real ACS Data Cleaning with Macros and Git Workflow
********************************************************

* Prep Steps
capture log close
clear all
********************************************************

* 1. Initialize and begin logging
* Set your working directory to the problem set folder.

global proj "/Users/noureenahmed/Desktop/Problem Set 4"
cd "$proj"
capture mkdir "processed_data"
capture mkdir "logs"
* Start a log file named logs/ps4.log.
log using "logs/ps4.log", text replace
display "Log started: " c(current_date) " " c(current_time)
********************************************************

* 2. Import the data without forcing all columns to strings

import delimited "//Users/noureenahmed/Desktop/Problem Set 4/psam_p50.csv", clear varnames(1)

* Verify and display that the dataset has more than 100 variables (using ds)

ds
local nvars = r(varlist)
local numvar = wordcount("`nvars'")
display "Number of variables in dataset: `numvar'"
assert `numvar' > 100

* 3. Use local macros to define numeric and categorical columns

* Create a local macro named numeric_vars with this required subset of ACS columns:
	* – AGEP WAGP WKHP SCHL PINCP POVPIP ESR COW MAR SEX RAC1P HISP ADJINC PWGTP
local numeric_vars "agep wagp wkhp schl pincp povpip esr cow mar sex rac1p hisp adjinc pwgtp"

* Create a local macro named categorical_vars with this required subset:
* – NAICSP SOCP
local categorical_vars "naicsp socp"
foreach v of local numeric_vars {

* If `vars' are a string
    capture confirm string variable `vars'
    if _rc == 0 {
* convert to numeric only when needed (handle "NA", ".", and blanks correctly).
        replace `vars' = "" if inlist(strtrim(upper(`vars')), "NA", ".", "")
        destring `vars', replace
    }

}

* if `vars' are already numeric, do nothing

* Use a loop over categorical_vars to:
	* – clean string formatting,
	* – encode each variable to a new _id variable.
	
foreach v of local categorical_vars {
	replace `v' = strtrim(`v') 
	replace `v' = strlower(`v') 
	replace `v' = strproper(`v')
}

foreach v of local categorical_vars { 
	encode `v', gen(`v'_id) 
}
	
* Display both macro contents in the log.
display "numeric_vars: `numeric_vars'"
display "categorical_vars: `categorical_vars'"


********************************************************

* 4. Run QA checks and save a cleaned full file

* Check for missing key fields and verify uniqueness of SERIALNO SPORDER using duplicates report and isid.

count if missing(serialno) | missing(sporder)
display "Missing SERIALNO or SPORDER: " r(N)

duplicates report serialno sporder
isid serialno sporder

* Save processed_data/ps4_cleaned_full.dta.
save "processed_data/ps4_cleaned_full.dta", replace

********************************************************

* 5. Build a sample-construction table

* Use postfile to create a step-by-step sample-construction table with:
	*– step name,
tempname sample_post
tempfile sample_steps

    *– remaining observations,
	*– excluded observations at that step.

postfile `sample_post' str80 step int n_remaining int n_excluded using "`sample_steps'", replace
	
display "`sample_steps'"

count
local n_prev = r(N)
post `sample_post' ("Start: cleaned observations") (`n_prev') (0)

* Required filtering sequence:
	*– keep ages 25–64,
keep if inrange(agep, 25, 64)
count
local n_now = r(N)
post `sample_post' ("Inclusion- age 25-64") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'

	*– keep WAGP > 0 and WKHP >= 35,
	
keep if wagp > 0 & wkhp >= 35
count
local n_now = r(N)
post `sample_post' ("Inclusion- WAGP > 0 and WKHP >= 35") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'

	*– keep ESR in employed categories (1 or 2),
	
keep if inlist(esr, 1, 2)
count
local n_now = r(N)
post `sample_post' ("Inclusion- keep ESR in 1 or 2") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'

	*– drop missing values in key model covariates and encoded categorical IDs.
drop if missing(agep, wagp, wkhp, schl, pincp, povpip, esr, cow, mar, sex, rac1p, hisp, adjinc, pwgtp)
drop if missing(naicsp_id, socp_id)
count
local n_now = r(N)
post `sample_post' ("Exclusion criteria is missing values in covariates and categorical IDs") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'

* Create ln_wage = ln(WAGP).
gen ln_wage = ln(wagp)
label var ln_wage "Log hourly wage"


* Export processed_data/ps4_sample_construction.csv.

postclose `sample_post'
preserve
use "`sample_steps'", clear
export delimited using "processed_data/ps4_sample_construction.csv", replace
restore

********************************************************

* 6. Use macros for model specification and loops


* Create locals for:
	*– outcome
local outcome "ln_wage"

	*– covariates_demo
local covariates_demo "c.agep i.sex i.rac1p i.hisp i.mar"

	*– covariates_humancap
local covariates_humancap "c.schl"

	*– covariates_labor
local covariates_labor "c.wkhp i.esr i.cow"

	*– covariates_occ
local covariates_occ "i.socp_id i.naicsp_id"

	*– combined model_covariates
local model_covariates "`covariates_demo' `covariates_humancap' `covariates_labor' `covariates_occ'"

* Display your outcome and model_covariates macros.
display "Outcome macro: `outcome'"
display "Model covariates macro: `model_covariates'"

* Use a foreach loop over a qa_vars macro to report means and standard deviations.
foreach v of local qa_vars {
		quietly summarize `v'
		display as txt "`v': N =" %6.0f r(N) " mean=" %9.3f r(mean) " sd=" %9.3f r(sd)
}


* Use a forvalues loop to report counts for WKHP >= cutoff over several cutoffs.
forvalues cutoff = 35(5)50 {
	quietly count if wkhp >= `cutoff'
	display as txt "Observations with hours >= `cutoff': " %6.0f r(N)
}

* Run and store three regression specifications that build from simple to full covariate blocks.

* Regression 1
reg `outcome' `covariates_demo', vce(robust)
estimates store regmod1
display "Stored: regmod1 (demographics only)"

* Regression 2
reg `outcome' `covariates_demo' `covariates_humancap', vce(robust)
estimates store regmod2
display "Stored: regmod2 (demographics + human capital)"

* Regression 3
reg `outcome' `model_covariates', vce(robust)
estimates store regmod3
display "Stored: regmod3 (full model)"

* Display estimates comparison table
estimates table regmod1 regmod2 regmod3, b(%9.3f) se stats(N r2)


********************************************************

* 7. Required macro-based keep list

* Create a local macro named keepvars containing all variables required in your final analysis dataset.

local keepvars "serialno sporder `numeric_vars' `categorical_vars' naicsp_id socp_id ln_wage"

* Use keep `keepvars' (do not hardcode a standalone keep list).
* Verify each kept variable exists using a loop and confirm variable.
display " Verify all keepvars exist "
foreach v of local keepvars {
    capture confirm variable `v'
    if _rc != 0 {
        display as error "There is an ERROR: keepvars variable is missing: `v'"
        exit 198
    }
}


* Your keepvars must include the encoded _id variables created from categorical_vars.
keep `keepvars'

* Save processed_data/ps4_analysis_data.dta.
save "processed_data/ps4_analysis_data.dta", replace

********************************************************
* 8. Git workflow (required; continuation of PS3 repo)
* Use the same GitHub repository from Problem Set 3.
* Add a new folder named lecture_5_pset4/ in that repository.
* Add your completed script and log:
	*lecture_5_pset/ps4.do
	*lecture_5_pset/logs/ps4.log
* Make one commit on main with a descriptive message.
* Record your latest commit hash for your own records (git rev-parse –short HEAD).


