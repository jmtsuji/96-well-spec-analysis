# 96-well-spec-analysis
Scripts for quickly processing 96 well plate data from the Neufeld lab spec.

Copyright Jackson M. Tsuji, 2017

**NOTE: this script is in development and should not be used for important analyses without consulting the script author (Jackson M. Tsuji).

# Usage
```unparsed_plate_data``` - set as TRUE if you are adding in files directly from the 96 well plate reader (exported in "column" mode as .txt files). Recommended. Set as FALSE if you've already imported your data previously and want to analyze it again.

```plate_data_filename``` - the name of the plate data file (see type of file above). Plate data files can contain **more than one plates' worth of data**. **Also, you can analyze multiple raw plate data files simultaneously by giving their names as a character vector** (e.g., ```plate_data_filename <- c("file1.txt", "file2.txt")```). The order matters if importing multiple files. Plates will be numbered sequentially (i.e., 1, 2, 3) based on the order within each individual file AND the file name order provided. For example: suppose file1.txt contains 3 plates and file2.txt contains 2 plates. In this case, the three plates in file1.txt will be called plate #s 1, 2, and 3, and the two plates in file2.txt will be called plate #s 4 and 5. **This matters for when you build the sample naming sheet**.

```plate_order_filename``` - the sample naming (metadata) sheet, as a tab-separated file. See provided template ```example_sample_naming.tsv```. All columns in the example file MUST be present for the script to work. Plate numbers MUST match plate numbers assigned via ```plate_data_filename``` above.
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

