*Part 1: Read in the three datasets;

*Dataset 1: containing State names and Obesity Rates;
%let path = https://raw.githubusercontent.com/bdomash/SAS_project_data/master/;

filename obesity 
	url "&path.Obesity_by_state.csv"
	termstr=lf ;
	
data obesity;
	infile obesity dlm=',' firstobs=1 dsd missover;
	input state :$25. rate;
run;
*dataset 2: containing Location info for each McDonalds in the US;

filename mcdons 
	url "&path.mcdonalds.csv"
	termstr=lf;
	
data mcdonalds;
	infile mcdons dlm=',' firstobs=1 dsd missover;
	input longitude lattitude name :$199. address :$199.;
run;
	
*dataset 3: list of states with their abbreviations to later convert within the two above datasets;
filename abbrev 
	url "&path.states.csv"
	termstr=lf;
	
data abbreviations;
	infile abbrev dlm = ',' firstobs=2 dsd missover;
	input long :$27. short :$2.;
run;

*dataset 4: states and populations;
filename popu
	url "&path.population.csv"
	termstr=lf;
	
data population;
	infile popu dlm = ',' firstobs=2 dsd missover;
	input state :$27. population;
run;


*Part 2: Data-wrangling;



*First clean up mcdonalds dataset, pull out city and state information
For some observations, the state data pulls out erroneous info. 
Taking first 2 letters takes just the state abbreviation;
data mcdonalds;
	set mcdonalds;
	city = scan(address,2,",");
	state = scan(address,3,",");
	state = substrn(state,1,2);
run;

*Sort each of the datasets by full state name for merging;
proc sort data=abbreviations;by long;run;
proc sort data=obesity;by state;run;
proc sort data=population;by state;run;

*Adding abbreviated state to obesity dataset for later merge with with mcdonalds data;
*We will not need Guam or PR for these analyses;
data obesity;
	merge obesity(in=a) abbreviations(rename=(long=state) in=b);
	by state;
	if a = 1;
	if state = 'Guam' then delete;
	if state = 'Puerto Rico' then delete;
	rename short = Abbreviation;
	run;

*Add abbrevaiated state to population for later merge with mcdonalds data;
*Remove erroneous observations such as United States and Regions that were present;
data population;
	merge population(in=a) abbreviations(rename=(long=state));
	by state;
	if a = 1;
	if short='' then delete;
	rename state=long;
	rename short = state;
	run;
	

*Part 3: analysis;



*First, let's see which cities have the most McDonalds and map them;	
*Mcdonalds dataset seperates NYC into 5 buroughs, instead lets include them all as NYC;
data temp;
	set mcdonalds;
	if findw(address,'Brooklyn,NY')>0 then city = 'New York';
	if findw(address,'Queens,NY')>0 then city = 'New York';
	if findw(address,'Staten Island,NY')>0 then city = 'New York';
	if findw(address,'Manhattan,NY')>0 then city = 'New York';
	if findw(address,'Bronx,NY')>0 then city = 'New York';
	if findw(address,'New York,NY')>0 then city = 'New York';
run;

*Grouping data, counting how many mcdonalds locations for each city, state pair;
proc sql noprint;
	create table cities as 
    select city, state, count(1) as count from temp
    group by city, state;
quit;

*Sorting two datasets for merge;
proc sort data=cities;by state city;run;
proc sort data=mcdonalds; by state city;run;

*Now, for each city, state pair we are going to add a location from the mcdonalds dataset
While the coordinates will not be exact, it will give us a general location for mapping.
We only want one coordinate location for each city, state pair
And finally we need to manually add in NY's location as it was missing;  
data temp;
	merge cities(in=a) mcdonalds(in=b);
	by state city;
	if a=1;
	if first.city=1;
	drop name address;
	if city = 'New York' then do;
		lattitude = 40.758805;
		longitude = -73.984727;
		end;
	lab = cats(city,' (',count,')');
	run;


*Sorting the data to display the cities with the most Mcdonalds locations first;
proc sort data=temp;by descending count;run;


*Mapping the 10 cities with the most mcdonalds;
PROC SGMAP plotdata=temp(obs=10);
	openstreetmap;
	TITLE H=2 "Cities with the Most McDonalds";
	scatter X=longitude Y=lattitude / MARKERATTRS=(COLOR=cxff3344  symbol = CircleFilled SIZE= 10)
		datalabel = lab DATALABELATTRS=(COLOR=cxff3344 Weight=Bold SIZE=10) DATALABELPOS=Left;
RUN;

proc print data=temp(obs=10);
	var city state count;
run;

*Next, lets look at the states with the most McDonalds per capita.
Here, we group the Mcdonalds locations by states, counting how many locations per state;
proc sql noprint;
	create table states as 
    select state, count(1) as count from mcdonalds
    group by state;
quit;

*Sorting by state to merge;
proc sort data=population;by state;run;
proc sort data=states;by state; run;

*Here, we merge our state-grouped McDonalds data with each state's population
Now we have Mcdonalds per state and population per state in each row
We also create a per-capita variable, using 100000 since it creates nice single-digit values;
data states;
	merge states(in=a) population(in=b);
	by state;
	if a=1 and b=1;
	per_100000 = count/population*100000;
	run;

*Sorting the dataset by states with most McDonalds per capita;
proc sort data=states; by descending per_100000;run;


*Plotting a barchart of the states with the most McDonalds per-capita;
title "States with the most McDonalds per 100,000 people";
		proc sgplot data = states(obs=10);
			xaxis label = 'State';
			yaxis label = 'McDonalds per 100,000';
			vbar state / datalabel response=per_100000 CATEGORYORDER=RESPDESC
			datalabelattrs=(size=12pt) 
			fillattrs=(color='blue');
		run;
*Lets print the results as well to better visualize which states have the most McDonalds;
proc print data=states labels;
	var long per_100000;
	label long = 'State' per_100000 = 'McDonalds/100,000';
	run;



*Next lets plot the states with the highest obesity rates;
proc sort data=obesity;by descending rate;run;
title "States with the Highest Obesity Rate";
proc sgplot data = obesity(obs=10);
			xaxis label = 'State';
			yaxis label = 'Obesity Rate';
			vbar Abbreviation / datalabel response=rate CATEGORYORDER=RESPDESC
			datalabelattrs=(size=12pt) 
			fillattrs=(color='red');
		run;
*Lets also print these results;
proc print data=obesity label;
	var state rate;
	label state = 'State' rate = 'Obesity Rate (%)';
	run;	

*Finally lets look at the relationship between the two;
*First we must merge the obesity state-wide data with the McDonalds state-wide per capita data;
proc sort data=obesity;by state;run;
proc sort data=states;by long;run;
data merged;
	merge obesity(rename=(state=long)) states(in=b);
	by long;
	drop abbreviation;
	run;


*Now we create a scatter plot between the two variables. We include a regression line;
title 'Obesity Rate vs McDonalds per 100000 people';
proc sgplot data=merged;
	xaxis label = 'McDonalds per 100000 people';
	yaxis label = 'Obesity Rate';
    reg x=per_100000 y=rate / lineattrs=(color=red thickness=2) datalabel=state;
    run;

*This visualization would be a lot better if we could color code by region;
*Lets add some more data;
filename region 
	url "https://raw.githubusercontent.com/cphalpert/census-regions/master/us%20census%20bureau%20regions%20and%20divisions.csv"
	termstr=lf ;
	
data region;
	infile region dlm=',' firstobs=2 dsd missover;
	input state :$25. short :$2. region :$10. division :$25.;
run;

proc sort data=region;by state;run;
proc sort data=merged;by long; run;
data merged;
	merge merged(in=a) region(in=b rename=(state=long));
	by long;
	drop short;
run;

*Plot again with region;
title 'Obesity Rate vs McDonalds per 100000 people';
proc sgplot data=merged;
	styleattrs datacontrastcolors=(red green orange blue);
	xaxis label = 'McDonalds per 100000 people';
	yaxis label = 'Obesity Rate';
	scatter x=per_100000 y=rate / group=region markerattrs=(symbol=CircleFilled) markeroutlineattrs=(color=black thickness=1);
    reg x=per_100000 y=rate / lineattrs=(color=red thickness=2) datalabel=state;
    run;

*Finally we do some simple regression analysis to check the relationship between the two variables;
proc reg data=merged;
	label rate ='Obesity Rate';
	label per_100000 ='McDonalds per 1000000';
	model rate=per_100000;
run;

proc corr data=merged NOMISS plots=matrix;
	var rate per_100000;
run;
	
*The analysis shows that there is a significant relationship between the two variables;
*However, there appear to be (at least) two outlier variables
Lets remove those and see if this affects the analysis;
data no_outliers;
	set merged;
	if state = 'DC' then delete;
	if state = 'HI' then delete;
	*if state = 'CO' then delete;
	*if state = 'MT' then delete;
	*if state = 'NV' then delete;
run;

*Once again we can see a significant relationship between the two
We can conclude that there is a significant relationship between McDonalds in a state and a state's obesity rate;
proc reg data=no_outliers;
	label rate ='Obesity Rate';
	label per_100000 ='McDonalds per 1000000';
	model rate=per_100000;
run;

proc corr data=no_outliers NOMISS plots=matrix;
	var rate per_100000;
run;


