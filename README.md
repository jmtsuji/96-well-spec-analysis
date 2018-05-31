# 96-well-spec-analysis
Scripts for quickly processing 96 well plate data from the Neufeld lab spec.

Copyright Jackson M. Tsuji, 2017

**NOTE: this script is in development and should not be used for important analyses without consulting the script author (Jackson M. Tsuji).

# Dependencies (R packages)
* [`plyr`](https://cran.r-project.org/web/packages/plyr/index.html)
* [`dplyr`](http://dplyr.tidyverse.org)
* [`ggplot2`](http://ggplot2.tidyverse.org)
* [`reshape2`](https://cran.r-project.org/web/packages/reshape2/index.html)
* [`xlsx`](https://cran.r-project.org/web/packages/xlsx/index.html)
* Can be installed by running: `install.packages(c("plyr", "dplyr", "ggplot2", "reshape2", "xlsx"), dependencies = TRUE)`

# Usage
This script is ideally run within a console (e.g., RStudio) rather than in command line, because parameters are designed to be modified in the "User variables" section in the first few lines of the code before each run. The input is raw, exported 96 well plate absorbance data (TXT format; see below) from the Neufeld lab 96 well plate reader. Analyzed output can be visualized downstream using a method of your choice (as the visualization method depends on your study design and goals).

**NOTE how this script handles standards: currently, one set of standards per plate is required. This could potentially be changed in the future (e.g., one set of standards per plate file set).**

Below are instructions for how to appropriately use the "User variables":

```parse_plate_data``` - set as TRUE if you are adding in files directly from the 96 well plate reader (exported in "column" mode as .txt files). Recommended. Set as FALSE if you've already imported your data previously and want to analyze it again.

```plate_data_filename``` - the name of the plate data file.
- If ```parse_plate_data == TRUE```: use raw data files from spec (see above). Plate data files can contain **more than one plates' worth of data**. **Also, you can analyze multiple raw plate data files simultaneously by giving their names as a character vector** (e.g., ```plate_data_filename <- c("file1.txt", "file2.txt")```). The order matters if importing multiple files. Plates will be numbered sequentially (i.e., 1, 2, 3) based on the order within each individual file AND the file name order provided. For example: suppose file1.txt contains 3 plates and file2.txt contains 2 plates. In this case, the three plates in file1.txt will be called plate #s 1, 2, and 3, and the two plates in file2.txt will be called plate #s 4 and 5. **This matters for when you build the sample naming sheet**.
- If ```parse_plate_data == FALSE```: use the ```*_raw_data.tsv``` file output by this script (from previously parsing plate data). You can modify this file before usage here (e.g., to omit wells or add additional metadata categories), but you must preserve the critical categories listed below (```sample_order_filename```). Note that ```sample_order_filename``` is not required if ```parse_plate_data == FALSE```.

```sample_order_filename``` - the sample naming (metadata) sheet, as a tab-separated file. See provided template ```example_input/example_sample_naming.tsv```. All columns in the example file MUST be present for the script to work. Plate numbers MUST match plate numbers assigned via ```plate_data_filename``` above. However, note that **you can also add on additional columns (e.g., additional metadata categories) as you'd like.**
- ```Plate_number``` - see comment above
- ```Well``` - well on the 96 well plate. Order does not matter (so you can arrange as seems convenient to you)
- ```Sample_name``` - name of the sample/standard/blank in question. **All samples with the same name will be averaged together.***
- ```Replicate``` - samples with the same name that should NOT be averaged together. E.g., biological replicates, or time points.
- ```Sample_type``` - either Standard, Blank, or Unknown
- ```Treatment``` - does your plate contain multiple different types of measurements (e.g., for Fe2+ and total Fe)? If so, differentiate between them here. Samples with the same name but different treatments will not be combined.
- ```Blanking_group``` - IMPORTANT. Do some of your samples require different blanks than other samples? If so, then specify which samples go with which blank here. Blanking group names can be whatever you want.
- ```Dilution_factor``` - if some of your samples are diluted.
- ```Standard_conc``` - concentration of the standard (in µM)

```print_plots``` - outputs plots as PDF files -- handy.

```print_processed_data``` - outputs processed data as TSV and Excel files -- handy.

```force_zero``` - for calculation of the standard curve. Should the curve be forced to go through (0,0)?

# Script output
- ```*_raw_data.tsv``` - combined, raw absorbance and sample info data for all input plates; returned if ```parse_plate_data == TRUE```. This file can be imported directly into the script later, if desired, by setting ```parse_plate_data == FALSE```
- ```*_plate_diagrams.pdf``` - visual representations of each plate in case a visual check is helpful. Blanked absorbances are annotated on the wells, along with sample IDs. The absorbance scale maxes out at 1 currently (so anything with absorbance higher than 1 appears grey). Wells with missing absorbance data also appear grey.
- ```*_std_curves.pdf``` - standard curve plot for each plate.
- ```*_std_curves_with_samples.pdf``` - standard curve plot for each plate, with samples included. Note that the linear trend line drawn on the plot might look different than where the samples are positioned on the plot in some cases; this is because the drawn trendline and trendline used to calculate the standards are generated differently, currently (the former by ```ggplot2::geom_smooth(method = "lm")``` and the latter by ```lm()```). The ```lm()``` equation is shown on the plot.
- ```*_calculations.xlsx``` - spreadsheet file with four sheets summarizing the calculated unknowns, standards, blanks, and trend lines
- ```*_unknowns.tsv``` - TSV file summairizing just the calculated unknowns, in case helpful for direct import into R downstream (although should be the exact same data as what is the the ```*_calculations.xlsx``` file).

# Rough script workflow (if interested)
To process the data (after parsing), this script analyzes data using the following rough steps. For each plate,
1. Calculate the linear equation for the standard curve. To do this, extract standards from the overall data frame, **blank the standards to the appropriate blank (average value)**, and then average and determine standard deviations. A linear model is generated from the average blanked values.
2. Calculate unknowns. To do this, extract unknowns from the overall data frame, then **blank each unknown to its appropriate blanking group (average value)** and calculate averages and standard deviations. Convert averages and standard deviations to concentration values using the linear trendline and dilution factor.
3. Generate plots of standard curve with/without samples.

Each of these steps are performed in parallel across all plates using ```lapply()```. Analyzed output data is then combined into tables for unknowns, standards, blanks, and trend lines. Additional user-provided metadata is merged onto the unknowns table, and all tables are then exported.
