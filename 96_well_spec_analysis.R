# 96 well spectrophotometer data analysis (ferrozine)
# Copyright Jackson M. Tsuji (Neufeld Lab PhD student), 2017
# Created Nov 11th, 2016
# Description: Imports and processes data from the 96 well plate reader

#####################################################
## User variables: #################################
setwd("/Users/JTsuji/Documents/Research_General/PhD/19 other analyses/171110_xinda_NO2/") # your working directory where files are stored
parse_raw_plate_data <- TRUE # Set TRUE if you need to parse raw plate data. Will parse, then exit.
plate_data_filename <- c("01_raw/NO2_H2_both_depth_30C.txt") # Add in a vector if using multiple filenames
                        # If parse_raw_plate_data == FALSE, then this should be COMBINED plate and sample order data as output by this script when parsing
sample_order_filename <- "01_raw/NO2_sample_naming_test2.txt" # Not needed if parse_raw_plate_data == FALSE
print_plots <- TRUE # print a PDF of the standard curves and final analysis? Otherwise, will print to screen.
print_processed_data <- TRUE # print data tables?
force_zero <- TRUE # force the standard curve plots to go through (0,0)? (Recommended TRUE)
#####################################################


#####################################################
## Load required packages: ##########################
library(plyr)
library(dplyr)
library(ggplot2)
library(grid)
library(reshape2)
library(xlsx)
#####################################################


#####################################################
### Part A: Input data and clean up #################
#####################################################
# Get prefix name of input data file for naming output files
output_filenames_prefix <- substr(plate_data_filename[1], 1, nchar(plate_data_filename[1])-4)

# Funtion to pull one plate of data from an input file
get_individual_plate <- function(unparsed_plate_data, plate_ending_line, plate_num) {
  # test data
  # unparsed_plate_data <- unparsed_data
  # plate_ending_line <- plate_endings[1]
  # plate_num <- 1
  
  # Get the lines where the absorbance and well data is kept for the plate
  plate_lines <- c((plate_ending_line - 2), (plate_ending_line -1))
  
  # Pull the lines from the unparsed file
  plate_unparsed <- unparsed_plate_data[plate_lines]
  
  # Eliminate the first two tabs
  plate_unparsed <- gsub("^\t\t", "", plate_unparsed)
  
  # Make a table out of the absorbance data
  plate_parsed <- strsplit(plate_unparsed, "\t")
  names(plate_parsed) <- c("Well", "Absorbance")
  plate_parsed$Absorbance <- as.numeric(plate_parsed$Absorbance)
  plate_parsed <- data.frame("Plate_number" = plate_num, 
                             "Well" = plate_parsed[[1]], 
                             "Absorbance" = plate_parsed[[2]], 
                             stringsAsFactors = FALSE)
  
  return(plate_parsed)
}

# Function to read one input file (can contain multiple plates)
parse_input_file <- function(file_name) {
  # file_name <- plate_data_filename[1]
  
  # Read the vectorized input - got code here from the readLines help file
  con <- file(file_name, encoding = "UTF-16LE") # Assumed encoding based on the output of the plate reader software
  unparsed_data <- readLines(con)
  close(con)
  # unique(Encoding(A))
  
  # Parse the input
  # Eliminate the first line and last line (extraneous)
  unparsed_data <- unparsed_data[-c(1, length(unparsed_data))]
  
  # Determine the number of plates
  plate_endings <- grep("^~End", unparsed_data)
  number_of_plates <- length(plate_endings)
  print(paste("File ", file_name, ": found ",number_of_plates," plates' worth of plate data.", sep = ""))
  
  # Call function to get the data for each plate
  plate_data <- lapply(1:number_of_plates, function(x) {get_individual_plate(unparsed_data, plate_endings[x], x)})
  
  # Combine into a single data frame
  plate_data <- dplyr::bind_rows(plate_data)
  
  return(plate_data)
}

# Function to correct for plate numbers between raw files and merge into a single table
revalue_plate_numbers <- function(all_plates_list) {
  # all_plates_list <- all_files_plate_data
  
  # Determine total number of plates and renumber plates to match
  # Start with an empty vector and add plates in a loop
  total_plate_number <- 0
  for (i in 1:length(all_plates_list)) {
    # i <- 1
    
    # Get the plate number up to this point in the loop
    current_plate_number <- total_plate_number
    
    # Get the numbers of the plates from the file being examined
    plate_nums <- unique(all_plates_list[[i]]$Plate_number)
    plates_in_file <- length(plate_nums)
    
    # Determine new plate numbers to assign based on current position in the loop
    new_plate_nums <- seq(from = (current_plate_number + 1), to = (current_plate_number + plates_in_file))
    
    # Re-number the plates in that plate file
    all_plates_list[[i]]$Plate_number <- plyr::mapvalues(all_plates_list[[i]]$Plate_number, from = plate_nums, to = new_plate_nums)
    
    # Add to the total number of plates
    total_plate_number <- total_plate_number + plates_in_file
  }
  
  all_plate_data <- dplyr::bind_rows(all_plates_list)
  
  # Check number of plates found in for loop matches the number evident after merging
  final_plate_number <- length(unique(all_plate_data$Plate_number))
  if (total_plate_number != final_plate_number) {
    stop("ERROR: problem encountered in plate renumbering during file import. Exiting out.")
  } else {
    print(paste("Imported data from a total of ", final_plate_number, " plate(s).", sep = ""))
  }
  
  return(all_plate_data)
}

# Function to add sample naming data to the parsed absorbance data
add_sample_naming <- function(all_plate_data, order_filename) {
  ## Import sample order data
  plate_order <- read.table(order_filename, sep = "\t", header = TRUE, stringsAsFactors = FALSE)
  
  ## Check if the sample naming and plate abosorbance data have the same number of plates, and throw a warning if not
  if (identical(unique(plate_order$Plate_number), unique(all_plate_data$Plate_number)) == FALSE) {
    warning("WARNING: Number of plates in raw data files and sample naming sheet do not match. NA values will be placed where there are unmatched plates and may cause unexpected behaviour.")
  }
  
  ## Join sample order data with absorbance data
  all_plate_data_merged <- dplyr::full_join(all_plate_data, plate_order, by = c("Well","Plate_number"))
  
  return(all_plate_data_merged)
}

if (parse_raw_plate_data == TRUE) {
  print("Parsing plate data...")
  
  # Determine number of files provided
  number_of_files <- length(plate_data_filename)
  if (number_of_files == 1) {
    print(paste("Loading data from ", number_of_files, " file...", sep = ""))
  } else if (number_of_files > 1) {
    print(paste("Loading data from ", number_of_files, " files in sequential order...", sep = ""))
  } else {
    stop("ERROR: no input files detected")
  }
  
  # Parse each input file
  all_files_plate_data <- lapply(plate_data_filename, function(x) { parse_input_file(x) })
  
  # Combine into a single table
  all_files_plate_data <- revalue_plate_numbers(all_files_plate_data)
  
  # Add sample naming data
  plate_data_merged <- add_sample_naming(all_files_plate_data, sample_order_filename)
    
  print("Successfully read in plate data and sample naming data.")
  
  # Export combined data if desired
  if (print_processed_data == TRUE) {
    merged_data_filename <- paste(output_filenames_prefix, "_raw_data.tsv", sep = "")
    write.table(plate_data_merged, file = merged_data_filename, sep = "\t", col.names = TRUE, row.names = FALSE)
  }
  
} else {
  # Read in pre-merged plate/sample data
  plate_data <- read.table(plate_data_filename, sep = "\t", header = TRUE, stringsAsFactors = FALSE)
  
  # Check if plate number column exists for multiple plates. If it does not, exit early.
  required_colnames <- c("Plate_number", "Well", "Absorbance", "Sample_name", "Replicate", "Sample_type", "Treatment", "Blanking_group", "Dilution_factor", "Standard_conc")
  req_col_test <- unique(required_colnames %in% colnames(plate_data))
  if (length(req_col_test) == 1 && req_col_test[1] == TRUE) {
    stop("ERROR: Missing required table column (should include plate absorbance data and sample naming data; see README.md). Exiting...")
  }
}

###############################################
### Part B: Process standards and unknowns #################
###############################################

### First, split the raw data into multiple sub-tables by date of sampling
plate_data_sep <- lapply(unique(plate_data_merged$Plate_number), function(x) {filter(plate_data_merged, Plate_number == x)})
names(plate_data_sep) <- unique(plate_data_merged$Plate_number)

# Assume one standard for whole plate with different blanking options
make_standard_curve <- function(data_table) {
  # data_table <- plate_data_sep[[1]]
  
  ## Summarize standard curve data
  std_raw <- filter(data_table, Sample_type == "Standard")
  std_grouped <- group_by(std_raw, Blanking_group, Treatment, Sample_name, Standard_conc, Plate_number)
  std_summ <- summarise(std_grouped, Ave_abs = mean(Absorbance), StdDev_abs = sd(Absorbance))
  
  # Get Blanking Group of standards
  std_Blanking_group <- as.character(unique(std_summ$Blanking_group))
  
  # Check that only one Blanking Group is present and throw a warning otherwise -- handling multiple is not yet supported.
  if (length(std_Blanking_group) > 1) {
    stop("ERROR: detected standards of multiple Blanking Groups in the dataset. The script is not yet able to handle this. Exiting out...")
  }
  
  ### Summarize blanks
  blanks_raw <- filter(data_table, Sample_type == "Blank")
  blanks_grouped <- group_by(blanks_raw, Blanking_group, Sample_name, Standard_conc, Plate_number)
  blanks_summ <- summarise(blanks_grouped, Ave_abs = mean(Absorbance), StdDev_abs = sd(Absorbance))
  
  # Find blank matching Blanking Group of standards and pull out absorbance
  std_blank_row <- match(std_Blanking_group, blanks_summ$Blanking_group)
  std_blank_abs <- as.numeric(blanks_summ[std_blank_row,"Ave_abs"])
  std_blank_abs_sd <- as.numeric(blanks_summ[std_blank_row,"StdDev_abs"])
  # Check that standard deviation (if exists) is less than 10% to make sure the blank is okay. If not, throw a warning.
  if (is.na(std_blank_abs_sd) == FALSE) {
    if (std_blank_abs_sd > (0.1 * std_blank_abs)) {
      warning(paste("WARNING: Plate_number ", unique(data_table$Plate_number), ": std. dev. of standards blank is >10% of its average. Something could be fishy with the input data.", sep = ""))
    }
  }
  
  # Check if blank absorbance is greater than absorbance of lowest standard
  if (min(std_summ$Ave_abs) < std_blank_abs) {
    # Identify number of standards below blank
    stds_below_blank <- nrow(dplyr::filter(std_summ, Ave_abs < std_blank_abs))
    std_names_below_blank <- unique(dplyr::filter(std_summ, Ave_abs < std_blank_abs)$Sample_name)
    std_names_below_blank_readable <- glue::collapse(std_names_below_blank, sep = ", ")
    
    # Throw a warning
    warning(paste("WARNING: Plate_number ", unique(data_table$Plate_number), ": blank has higher absorbance than ", stds_below_blank, 
                  " of the standards (",  std_names_below_blank_readable, "). Will throw out all standards below blank.", sep = ""))
    
    # Remove all standards with absorbance lower than blank
    std_summ <- dplyr::filter(std_summ, Ave_abs > std_blank_abs)
  }
  
  # Subtract blank from all standards
  std_summ$Ave_abs <- (std_summ$Ave_abs - std_blank_abs)
  
  # Make linear trendline
  if (force_zero == TRUE) {
    trendline <- lm(Ave_abs ~ 0 + Standard_conc, data = std_summ) # Forcing through origin: https://stackoverflow.com/a/18947967, accessed 170815
  } else {
    trendline <- lm(Ave_abs ~ Standard_conc, data = std_summ)
  }
  
  # Summarize some trendline values
  if (force_zero == TRUE) {
    trendline_coeff <- c(0, coefficients(trendline)) # to make this match what the coefficients look like when not fixed to origin
  } else {
    trendline_coeff <- coefficients(trendline)
  }
  trendline_Rsquared <- summary(trendline)$r.squared
  trendline_summ <- data.frame("Intercept" = unname(trendline_coeff[1]), "Slope" = unname(trendline_coeff[2]), "R_squared" = trendline_Rsquared, "Plate_number" = unique(std_summ$Plate_number), stringsAsFactors = FALSE)
  
  # Return list of processed data
  output_list <- list(std_summ, trendline_summ, blanks_summ)
  names(output_list) <- c("Standards_blanked", "Trendline", "Blanks_all")
  
  return(output_list)
}

# Function to adjust absorbances of unknowns based on blanks
# (need to refactor nested loop for clarity)
blank_unknowns <- function(summarized_unknowns, summarized_blanks) {
  # # Test variables
  # unk_raw <- dplyr::filter(plate_data_sep[[1]], Sample_type == "Unknown")
  # unk_grouped <- group_by(unk_raw, Blanking_group, Treatment, Sample_name, Dilution_factor, Plate_number, Replicate)
  # summarized_unknowns <- summarise(unk_grouped, Ave_abs = mean(Absorbance), StdDev_abs = sd(Absorbance))
  # summarized_blanks <- make_standard_curve(plate_data_sep[[1]])$Blanks_all
  
  # Get all Blanking Groups
  unk_Blanking_groups <- as.character(unique(summarized_unknowns$Blanking_group))
  
  # For each Blanking Group, get the corresponding blank value and use to blank the unknown
  summarized_unknowns$Blank_abs_ave <- numeric(length = nrow(summarized_unknowns))
  summarized_unknowns$Blank_abs_sd <- numeric(length = nrow(summarized_unknowns))
  summarized_unknowns$Ave_abs_blanked <- numeric(length = nrow(summarized_unknowns))
  for (i in 1:length(unk_Blanking_groups)) {
    # i <- 1
    
    # Get name of Blanking Group
    unk_b_grp <- unk_Blanking_groups[i]
    
    # Find match in blanks summary table
    # Throw a warning if the blanking group does not exist.
    if (is.na(match(unk_b_grp, summarized_blanks$Blanking_group)) == TRUE) {
      warning(paste("WARNING: No blank available for group ", unk_b_grp, ", for Plate_number ", unique(summarized_unknowns$Plate_number), 
                    ". Will not generate concentration values for any of the measurements from this blanking group.", sep = ""))
    }
    matching_row <- match(unk_b_grp, summarized_blanks$Blanking_group)
      
    # Pull out average and standard deviation
    blank_abs <- as.numeric(summarized_blanks[matching_row,"Ave_abs"])
    blank_abs_sd <- as.numeric(summarized_blanks[matching_row,"StdDev_abs"])
    
    # Throw a warning if standard deviation exists and is >10% of average
    if (is.na(blank_abs_sd) == FALSE) {
      if (blank_abs_sd > (0.1 * blank_abs)) {
        warning(paste("WARNING: Plate_number ", unique(summarized_unknowns$Plate_number), ": Blanking unknowns: standard deviation of blank for group ", unk_b_grp," is >10% of the average value of the blank. Something could be fishy with the input data.", sep = ""))
      }
    }
    
    # Find unknowns matching the standard
    unknowns_row_num <- which(summarized_unknowns$Blanking_group %in% unk_b_grp) # https://stackoverflow.com/a/30282302, accessed 170925
    
    for (j in unknowns_row_num) {
      # j <- unknowns_row_num[1]
      summarized_unknowns$Ave_abs_blanked[j] <- summarized_unknowns$Ave_abs[j] - blank_abs
      summarized_unknowns$Blank_abs_ave[j] <- blank_abs
      summarized_unknowns$Blank_abs_sd[j] <- blank_abs_sd
    }
    
  }
  
  return(summarized_unknowns)
}

# Function to convert sample absorbances to concentrations for each Plate_number, re-blanking standards as needed
convert_to_concentration <- function(data_table, std_list) {
  # data_table <- plate_data_sep[[1]]
  # std_list <- plate_data_stds[[1]]
  
  ### Summarize unknowns data
  unk_raw <- filter(data_table, Sample_type == "Unknown")
  unk_grouped <- group_by(unk_raw, Blanking_group, Treatment, Sample_name, Dilution_factor, Plate_number, Replicate)
  unk_summ <- summarise(unk_grouped, Ave_abs = mean(Absorbance), StdDev_abs = sd(Absorbance))
  
  # Subtract appropriate blanks
  unk_summ <- blank_unknowns(unk_summ, std_list$Blanks_all)
  
  # Convert to concentration using standard curve (linear model) AND dilution factor
  unk_summ$Ave_concentration_uM <- (unk_summ$Ave_abs_blanked - std_list$Trendline$Intercept) / std_list$Trendline$Slope * unk_summ$Dilution_factor
  
  # Get standard devations (also accounting for dilution factor)
  unk_summ$StdDev_Concentration_uM <- (unk_summ$StdDev_abs / std_list$Trendline$Slope) * unk_summ$Dilution_factor
  # For calculating std dev like this, see http://www.psychstat.missouristate.edu/introbook/sbk15.htm, accessed ~Jan. 2017
  
  
  # Figure out where to put the trend line equation text on the plot
  min_x <- min(std_list$Standards_blanked$Standard_conc)
  max_x <- max(std_list$Standards_blanked$Standard_conc)
  min_y <- min(std_list$Standards_blanked$Ave_abs)
  max_y <- max(std_list$Standards_blanked$Ave_abs)
  x_coord <- (max_x - min_x) * 0.05 # arbitrary position 5% to the right of the y axis
  y_coord <- (max_y - min_y) * 0.8 # arbitrary position 80% above the x axis
  
  ## Make standards plot without samples
  std_plot <- ggplot(std_list$Standards_blanked, aes(x = Standard_conc, y = Ave_abs)) +
    geom_smooth(method = "lm", se = T, colour = "purple") +
    geom_errorbar(aes(x = Standard_conc, ymin = Ave_abs-StdDev_abs, ymax = Ave_abs+StdDev_abs), width = 0, size = 0.8, alpha = 0.8) +
    geom_point(alpha = 0.9, size = 3) +
    annotate("text", x = x_coord, y = y_coord, label = paste("y = ", round(std_list$Trendline$Slope, digits = 5), "x + ", round(std_list$Trendline$Intercept, digits = 5), "\n R^2 = ", round(std_list$Trendline$R_squared, digits = 5), sep = ""), size = 3) +
    theme_bw() +
    # Add theme elements to make the plot look nice
    theme(panel.grid = element_blank(), title = element_text(size = 10), axis.title = element_text(size = 12), 
          strip.text = element_text(size = 10), strip.background = element_rect(fill = "#e6e6e6"),
          panel.border = element_rect(colour = "black", size = 1), panel.spacing.y = unit(3, "mm"), panel.spacing.x = unit(0, "mm"),
          axis.text.x = element_text(size = 10, colour = "black"), axis.text.y = element_text(size = 10, colour = "black"),
          axis.ticks = element_line(size = 0.5), axis.line = element_line(colour = "black", size = 0.5),
          legend.text = element_text(size = 7), legend.title = element_blank(),
          legend.key = element_rect(colour = "grey", size = 0.3), legend.key.size = unit(3, "mm"),
          legend.spacing = unit(1, "mm"), legend.box.just = "left", plot.margin = unit(c(2,2,2,2), "mm")) +
    #         See http://stackoverflow.com/questions/1330989/rotating-and-spacing-axis-labels-in-ggplot2 (approx. Jan 27, 2016) for vertical x-axis labels
    # scale_x_continuous(limits = c(0, NA)) +
    # scale_y_continuous(limits = c(0, NA)) +
    scale_x_log10() +
    scale_y_log10() +
    annotation_logticks() +
    xlab("Concentration (uM)") +
    ylab("Absorbance") +
    ggtitle(paste("Plate_number: ", unique(data_table$Plate_number), sep = ""))
  
  # # Print plot to the screen
  # print(std_plot)
  
  # Add on samples to the standard plot
  unk_plot <- std_plot +
    geom_errorbar(data = unk_summ, aes(x = (Ave_concentration_uM / Dilution_factor), ymin = Ave_abs_blanked-StdDev_abs, ymax = Ave_abs_blanked+StdDev_abs), width = 0, size = 0.8, alpha = 0.8, colour = "darkcyan") +
    geom_point(data = unk_summ, aes((Ave_concentration_uM / Dilution_factor), Ave_abs_blanked), shape = 21, alpha = 0.8, size = 3, fill = "darkcyan")
    
  # # Print plot to the screen
  # print(unk_plot)
  
  output_list <- list(unk_summ, std_plot, unk_plot)
  names(output_list) <- c("unk_summ", "std_plot", "std_plot_with_unknowns")
  return(output_list)

}

# Optionally perform a visual check of the data
visual_check <- function(data_table) {
  # data_table <- plate_data_sep[[2]]
  
  # Split wells into row and column
  data_table$Well_row <- as.character(substr(data_table$Well, start = 1, stop = 1))
  data_table$Well_col <- as.numeric(substr(data_table$Well, start = 2, stop = 3))
  
  # Put rows in order
  data_table$Well_row <- factor(data_table$Well_row, levels = rev(c("A", "B", "C", "D", "E", "F", "G", "H")), ordered = TRUE)
  
  # Make annotation text
  data_table$Annotation <- paste(data_table$Sample_name, " ", data_table$Replicate, "\n", data_table$Absorbance, sep = "")
  # Clean out ones with no sample
  for (i in 1:length(data_table$Annotation)) {
    if (data_table$Sample_name[i] == "") {
      data_table$Annotation[i] <- ""
    }
  }
  
  plate_diagram <- ggplot(data_table, aes(factor(Well_col), Well_row)) +
    geom_point(aes(fill = Absorbance), shape = 21, size = 10) +
    geom_text(aes(label = Annotation), size = 2) +
    scale_fill_gradientn(colours = c("#ffffff", "#ff3399", "#660066"), limits = c(0,1)) + # Used limits to set absolute colour scale, as recommended at https://stackoverflow.com/a/21538521 (accessed Oct 2nd, 2017)
    xlab("") +
    ylab("") +
    ggtitle(unique(data_table$Date))
  
  return(plate_diagram)
}

# Generate standards for each Date
plate_data_stds <- lapply(names(plate_data_sep), function(x) {make_standard_curve(plate_data_sep[[x]])})
names(plate_data_stds) <- names(plate_data_sep)

# Get concentrations and plot for each Date
unknowns_data <- lapply(names(plate_data_sep), function(x) {convert_to_concentration(plate_data_sep[[x]], plate_data_stds[[x]])})
names(unknowns_data) <- names(plate_data_sep)

# Optionally generate and print plate diagrams
plate_diagrams <- lapply(names(plate_data_sep), function(x) {visual_check(plate_data_sep[[x]])})
plate_digrams_name <- paste(substr(plate_data_filename, 1, nchar(plate_data_filename)-4), "_plate_diagrams.pdf", sep = "")
if (print_plots == TRUE) {
  pdf(file = plate_digrams_name, width = 10, height = 6)
  print(plate_diagrams) # See https://stackoverflow.com/a/29834646, accessed 170815
  dev.off()
}

###############################################
### Part C: Summarize output #################
###############################################

# Summarize the unknowns (samples) data and re-order for clarity
plate_data_unknowns <- dplyr::bind_rows(lapply(names(unknowns_data), function(x) {unknowns_data[[x]][["unk_summ"]]}))
# plate_data_unknowns$Date <- as.Date(plate_data_unknowns$Date, format = "%d-%b-%y")
plate_data_unknowns <- plate_data_unknowns[,c(5,3,6,2,4,1,7,8,11,12,13)]

# # Also make user-friendly unknowns data
# plate_data_unknowns_readable <- reshape2::dcast(plate_data_unknowns, Sample_name + Replicate + Treatment ~ Date, value.var = "Ave_concentration_uM")
# plate_data_unknowns_readable_sd <- reshape2::dcast(plate_data_unknowns, Sample_name + Replicate + Treatment ~ Date, value.var = "StdDev_Concentration_uM")

# Summarize standards and re-order for clarity
plate_data_standards <- dplyr::bind_rows(lapply(names(unknowns_data), function(x) {plate_data_stds[[x]][["Standards_blanked"]]}))
plate_data_standards <- plate_data_standards[,c(5,3,4,2,1,6,7)]

# Summarize blanks and re-order for clarity
plate_data_blanks <- dplyr::bind_rows(lapply(names(unknowns_data), function(x) {plate_data_stds[[x]][["Blanks_all"]]}))
plate_data_blanks <- plate_data_blanks[,c(4,1,2,5,6)]

# Summarize trendline and re-order for clarity
plate_data_trendlines <- dplyr::bind_rows(lapply(names(unknowns_data), function(x) {plate_data_stds[[x]][["Trendline"]]}))
plate_data_trendlines <- plate_data_trendlines[,c(4,2,1,3)]

# Write summary table if desired
if (print_processed_data == TRUE) {
  # Modify input file name as the output name for the table
  table_filenames_prefix <- substr(plate_data_filename, 1, nchar(plate_data_filename)-4)
  
  table_sheetnames <- c("Unknowns", "Standards", "Blanks", "Trendlines")
  tables_to_write <- list(plate_data_unknowns, plate_data_standards, plate_data_blanks, plate_data_trendlines)
  
  # Save as Excel workbook with multiple sheets
  xlsx_table_filename <- paste(table_filenames_prefix, "_calculations.xlsx", sep = "")
  for (i in 1:length(tables_to_write)) {
    if (i == 1) {
      write.xlsx2(as.data.frame(tables_to_write[[i]]), xlsx_table_filename, sheetName = table_sheetnames[[i]], col.names=TRUE, row.names=FALSE, append=FALSE)
    } else {
      write.xlsx2(as.data.frame(tables_to_write[[i]]), xlsx_table_filename, sheetName = table_sheetnames[[i]], col.names=TRUE, row.names=FALSE, append=TRUE)
    }
  }
  
  # Also export unknowns as TSV in case helpful to the user
  table_filename_unknowns <- paste(table_filenames_prefix, "_unknowns.tsv", sep = "")
  write.table(plate_data_unknowns, file = table_filename_unknowns, sep = "\t", col.names = TRUE, row.names = FALSE)
  
  # # Write user-friendly data to Excel spreadsheet (multi-sheet)
  # xlsx_table_filename <- paste(table_filenames_prefix, "_unknowns_readable.xlsx", sep = "")
  # options(xlsx.date.format = "yyyy-MM-dd") # Doesn't seem to affect anything currently
  # write.xlsx2(plate_data_unknowns_readable, xlsx_table_filename, sheetName="conc_uM_readable", col.names=TRUE, row.names=FALSE, append=FALSE)
  # write.xlsx2(plate_data_unknowns_readable_sd, xlsx_table_filename, sheetName="StdDev_uM_readable", col.names=TRUE, row.names=FALSE, append=TRUE)

}

# Make multi-panel standard curve plots, if desired
std_plots_list <- lapply(names(unknowns_data), function(x) {unknowns_data[[x]][["std_plot"]]})
std_plot_name <- paste(substr(plate_data_filename, 1, nchar(plate_data_filename)-4), "_std_curves.pdf", sep = "")
if (print_plots == TRUE) {
  pdf(file = std_plot_name)
  print(std_plots_list) # See https://stackoverflow.com/a/29834646, accessed 170815
  dev.off()
} else {
  print(std_plots_list) # prints to screen if a PDF printout is not wanted
}

# Do again for the standard curves with samples overlaid
unk_plots_list <- lapply(names(unknowns_data), function(x) {unknowns_data[[x]][["std_plot_with_unknowns"]]})
unk_plot_name <- paste(substr(plate_data_filename, 1, nchar(plate_data_filename)-4), "_std_curves_with_samples.pdf", sep = "")
if (print_plots == TRUE) {
  pdf(file = unk_plot_name)
  print(unk_plots_list)
  dev.off()
} else {
  print(std_plots_list) # prints to screen if a PDF printout is not wanted
}
