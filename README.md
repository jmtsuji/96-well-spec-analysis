# 96-well-spec-analysis
Scripts for quickly processing 96 well plate data from the Neufeld lab spec.

Copyright Jackson M. Tsuji, 2017

**NOTE: this script is in development and should not be used for important analyses without consulting the script author (Jackson M. Tsuji).

# Dependencies (R packages)
* [`getopt`](https://cran.r-project.org/web/packages/getopt/index.html)
* [`glue`](https://cran.r-project.org/web/packages/glue/index.html)
* [`plyr`](https://cran.r-project.org/web/packages/plyr/index.html)
* [`dplyr`](http://dplyr.tidyverse.org)
* [`ggplot2`](http://ggplot2.tidyverse.org)
* [`reshape2`](https://cran.r-project.org/web/packages/reshape2/index.html)
* [`xlsx`](https://cran.r-project.org/web/packages/xlsx/index.html)
* Can be installed by running: `install.packages(c("getopt", "glue", "plyr", "dplyr", "ggplot2", "reshape2", "xlsx"), dependencies = TRUE)`

__NOTE:__ Package 'xlsx' relies on 'rJava', which requires that Java (x64, I think) be installed on your system.

# Usage - general
This script can be run either in the R console or via command line (if Rscript is installed and in the PATH).

## Run via console
To run in a console (e.g., [RStudio](https://www.rstudio.com/)), open in the console, set `RUN_COMMAND_LINE <- FALSE` (approx. line 9), and then set user variables from approx. lines 13-23. You can then press "Source" to run.

## Run via command line (recommended for reproducibility)
To run via command line, try `./96_well_spec_analysis.R -h` at the command line (from within the folder where you download the script) to see options. Briefly, you can run like:
```
96_well_spec_analysis.R -i spec_file.txt -m metadata_file.tsv -o analyzed_data
```

# Input files
## From the spec
The script is designed to read the RAW output file exported from the Neufeld lab 96 well spectrophotometer in .txt format. For now, make sure the export settings are 'both' and 'column' format (working on supporting multiple output settings long-term). The raw file has an odd text encoding (Little Endian), but the Rscript is coded to handle this. Note that the plate data file can contain **more than one plates' worth of data**, and the script can handle this.

## Metadata
See the example metadata file provided in `testing/input/example_sample_metadata.tsv`. You need something similar to tell the script which wells from the plate correspond to your samples, standards, blanks, and so on.

A few columns are specifically required by this script. One is optional. You can also add as many additional metadata categories as you'd like for your own reference or to help differentiate your data (the script will consider them when attempting to distinguish samples from one another).

### Required columns
* Plate_number: number sequentially from 1. Mostly important if your raw spec file contains more than one plate, but still required even if you only have one plate (for now).
* Well: the well ID in the 96 well plate (e.g., A1)
* Sample_name: the name of the blank, unknown, or standard
* Sample_type: MUST be one of 'Blank', 'Unknown', or 'Standard'
* Blanking_group: e.g., 'Water' or 'Matrix' - can be whatever term you want. See below for more details on this.
* Dilution_factor: how much the sample was diluted before input into the assay (e.g., 20 for a 20x dilution)
* Standard_conc: the concentration of each standard. Can leave this blank or as 'NA' for non-standards.

### Optional column:
* Standard_group: if you have more than one set of standards per plate, you MUST specify which samples correspond to which standard by including this column - the script knows to look for it. See note below.

### Examples of other helpful columns:
* Replicate: it can be helpful to have the same 'Sample_name' for multiple (e.g., biological) replicates but vary the 'Replicate' ID (e.g., A, B, C...)
* Treatment: this can be a helpful way to distinguish between different assayed parameters (e.g., NO2 versus NO2+NO3)
* Date: e.g., if samples represent a time series
Adding these additional columns can make downstream analysis much easier. The script will automatically know not to average samples with unique total sets of column information.

### Best practices (personal tips):
* It will be tough to make the metadata sheet the first time, but then you can re-use the first one you make as a template for future runs.
* Try to keep the sample 'Sample_name' as much as possible whenever you have samples that are related. Change the variables in other columns (e.g., Replicate, Treatment, Date) to show when samples are unique from one another. This can make downstream visualization easier
* If you find outliers or points you want to remove, you can remove them easily by removing their corresponding entry in the sample metadata sheet before starting the script.
* The '*_unknowns.tsv' file can be readily imported back into R and used for making nice plots, e.g., via `ggplot2`
* (I'm working on a wrapper to process multiple sets of plate data and metadata files at the same time to do larger-scale analyses with this script).

## A note on standards
The script by default can handle either one set of standards for the entire plate file (which can contain more than one plate) or one standard per plate. If you have a setup more complicated (e.g., two different standards for two different treatments on the same plate), you'll need to explicitly specify a `Standard_group` for each sample as an additional column in your metadata file (see above).

## A note on blanks
The way that blanking is implemented in this script can be a bit tricky to understand at first. It's quite possible to have multiple different types of blanks in the same 96 well plate (e.g., if some of your samples are in one matrix, and some are in another). If you have a setup like this, then give each type of blank a unique `Blanking_group` name (doesn't matter what it is, so long as you are consistent within the same plate file). Also give any other samples that you want to normalize to that blank the same `Blanking_group`. Then, the script will know to normalize to that blank.

# Script settings ('User variables'):
The names here correspond to the console version of the script (first variable shown), and the the short flag for the command line version (second variable shown).

## Basic:
* `plate_data_filename [-i]`: the name of the plate data file from the 96 well spec.
* `sample_metadata_filename [-m]`: the sample naming (metadata) sheet, as a tab-separated file. See provided template ```example_input/example_sample_naming.tsv```. All columns in the example file MUST be present for the script to work. Plate numbers MUST match plate numbers assigned via ```plate_data_filename``` above. However, note that **you can also add on additional columns (e.g., additional metadata categories) as you'd like.**
* `output_filenames_prefix [-o]`: prefix to append the various file names and extensions of output files to. The script will try to guess by default based on your input raw plate data file name.

## For advanced usage:
* `pre_parsed_data_file [-p]`: you can input a previously parsed data file set into the script using this flag. The file should contain your metadata joined to the absorbance data in tab-separated (TSV) format. If you set this variable, you MUST set `plate_data_filename` and `sample_metadata_filename` to NULL or NA (or not set at all, for command line)
* `force_curve_through_zero [-z]`: for calculation of the standard curve. Should the curve be forced to go through (0,0)? [Default: TRUE, i.e., force through zero]

# Script output
* `*_raw_data.tsv` - combined, raw absorbance and sample info data for all input plates. This file can be imported directly into the script later, if desired, using the `pre_parsed_data_file` option above.
* `*_plate_diagrams.pdf` - visual representations of each plate in case a visual check is helpful. Blanked absorbances are annotated on the wells, along with sample IDs. The absorbance scale maxes out at 1 currently (so anything with absorbance higher than 1 appears grey). Wells with missing absorbance data also appear grey.
* `*_std_curve_plot.pdf` - standard curve plot for each plate.
* `*_std_curve_plot_with_unknowns.pdf` - standard curve plot for each plate, with samples included. Note that the linear trend line drawn on the plot might look different than where the samples are positioned on the plot in some cases; this is because the drawn trendline and trendline used to calculate the standards are generated differently, currently (the former by ```ggplot2::geom_smooth(method = "lm")``` and the latter by ```lm()```). The ```lm()``` equation is shown on the plot.
* `*_calculations.xlsx` - spreadsheet file with four sheets summarizing the calculated unknowns, standards, blanks, and trend lines
* `*_unknowns.tsv` - TSV file summairizing just the calculated unknowns, in case helpful for direct import into R downstream (although should be the exact same data as what is the the ```*_calculations.xlsx``` file).

# Rough script workflow (if interested)
1. Parse the input raw data file. Figure out how many plates' worth of data are there.
2. Join the raw data to the metadata sheet.
3. Calculate summary statistics for the blanks and then blank all samples according to their appropriate blanking group.
4. Determine how standards are laid out and whether or not more than one set of standards is present.
5. For each set of standards, make a standard curve (using blanked absorbances).
6. For each set of standards, convert the (blanked) absorbances of the appropriate unknowns to concentration values. Make standard curve plots (some with unknowns overlaid).
7. Combine the data together from each set of standards for easy export.
8. Make a plate diagram figure for each plate.
9. Summarize the data tables into an Excel file.
10. Export remaining tables and plots.
