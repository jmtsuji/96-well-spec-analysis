#!/usr/bin/env bash
set -euo pipefail
# 96_well_spec_analysis_test.sh
# Copyright Jackson M. Tsuji, 2018
# Neufeld lab, University of Waterloo, Canada
# Created May 31, 2018
# Description: Runs automated test of 96_well_spec_analysis.R
# **Early development version. You must run the R script with "FOR TESTING" variables before running this script.

# Hard-coded variables
SCRIPT_VERSION="v0.3" # to match git tag
TARGET_FILES=(example_raw_plate_data_1_plate_diagrams.pdf example_raw_plate_data_1_raw_data.tsv example_raw_plate_data_1_std_curves_with_samples.pdf example_raw_plate_data_1_unknowns.tsv)

# If no input is provided, exit out and provide help
if [ $# == 0 ]
	then
	printf "$(basename $0): Runs automated test of 96_well_spec_analysis.R - simple check of md5 hashes for key output files.\n"
	printf "Version: ${SCRIPT_VERSION}\n"
	printf "Contact Jackson M. Tsuji (jackson.tsuji@uwaterloo.ca) for bug reports or feature requests.\n\n"
	printf "Usage: $(basename $0) known_output_md5_dir test_output_dir\n\n"
	printf "Usage details:\n"
	printf "1. known_output_md5_dir: Path to the directory containing the md5sum's of the 'proper' script outputs. This directory is provided in the git repo at 'testing/output_known_md5'.\n"
	printf "2. test_output_dir: Path to the directory containing the output files (that you want to test) from running the R script.\n\n"
	printf "NOTE: base name of the output files MUST be 'example_raw_plate_data_1'. This script will check:\n"

	for file in ${TARGET_FILES[@]}; do
		printf "* ${file}\n"
	done
	printf "\n"

	exit 1
fi

# Set variables from user input:
MD5_DIR=$1
TEST_DIR=$2

function test_inputs {
	# Description: tests that provided folders and files exist in the proper configuration
	# GLOBAL params: ${MD5_DIR}; ${TEST_DIR}; ${TARGET_FILES}
	# Return: none
	
	if [ ! -d ${MD5_DIR} ]; then
		echo "ERROR: Cannot find md5sum directory at '${MD5_DIR}'. Exiting..."
		exit 1
	fi
	
	if [ ! -d ${TEST_DIR} ]; then
		echo "ERROR: Cannot find test output directory at '${TEST_DIR}'. Exiting..."
		exit 1
	fi
	
	for file in ${TARGET_FILES[@]}; do
		if [ ! -f ${MD5_DIR}/${file}.md5 ]; then
			echo "ERROR: Cannot find md5 file '${file}.md5' in '${MD5_DIR}'. Exiting..."
			exit 1
		fi
	done
	
	for file in ${TARGET_FILES[@]}; do
		if [ ! -f ${TEST_DIR}/${file} ]; then
			echo "ERROR: Cannot find md5 file '${file}' in '${TEST_DIR}'. Exiting..."
			exit 1
		fi
	done
		
}

function check_md5 {
	# Description: generates md5sum for all test files and compares to test files
	# GLOBAL params: ${TEST_DIR}; ${TARGET_FILES}
	# Return: .md5 file for each entry in ${TARGET_FILES}; variable ${OVERALL_TEST_STATUS} (0 if passed, 1 if at least one file failed)

	# Initialize the ${OVERALL_TEST_STATUS} variable
	OVERALL_TEST_STATUS=0

	for file in ${TARGET_FILES[@]}; do
		# Generate MD5
		md5sum ${TEST_DIR}/${file} > ${TEST_DIR}/${file}.md5
		
		# Check if the MD5 files match. Will be 0 if matching and 1 if not matching
		# TODO - find a cleaner way to write this code
		local compare_status=$(cmp ${TEST_DIR}/${file}.md5 ${MD5_DIR}/${file}.md5 >/dev/null; echo $?)
		
		# Report to user
		if [ ${compare_status} = 0 ]; then
			echo "${file}: MD5 check PASSED."
			
			# Clean up
			rm ${TEST_DIR}/${file}.md5
			
		elif [ ${compare_status} = 1 ]; then
			echo "${file}: MD5 check FAILED. Leaving behind ${TEST_DIR}/${file}.md5 for reference."
			
			# Change ${OVERALL_TEST_STATUS} to 1 if at least one test fails
			OVERALL_TEST_STATUS=1
			
			# For now, do not clean up the md5 if failed.
			
		fi
		
	done

}


function main {
	echo "Running $(basename $0), version ${SCRIPT_VERSION}, on $(date)."
	echo ""
	
	test_inputs
	
	# Get date and time of start
	start_time=$(date)
	
	# Check MD5s
	check_md5

	end_time=$(date)
	
	echo ""
	
	if [ ${OVERALL_TEST_STATUS} = 0 ]; then
		printf "Test finished.\nOverall: PASSED\n\n"
	elif [ ${OVERALL_TEST_STATUS} = 1 ]; then
		printf "Test finished.\nOverall: FAILED (see above)\n\n"
	fi
	
	# TODO - remove the comment below once this is addressed.
	echo "Started at ${start_time} and finished at ${end_time}."
	echo ""

	echo "$(basename $0): finished."
	echo ""

}

main

