#!/usr/bin/env sh

read -p "Check for dependencies? [y|N]: " DEPENDENCIES;

if [ "$DEPENDENCIES" = "y" ]; then

    echo "Checking dependencies...";
    ./check_dependencies.sh;

fi

clear;

read -p "Import data? [y|N]: " IMPORTDATA;

if [ "$IMPORTDATA" = "y" ]; then

    echo "Importing data for analysis...";
    ./data_import_script.sh;

fi

clear;

read -p "Analyse data? [y|N]: " ANALYSEDATA;

if [ "$ANALYSEDATA" = "y" ]; then

    echo "Analysing data...";
    ./patient_programs.js;

fi

clear;

read -p "Verify data? [y|N]: " VERIFYDATA;

if [ "$VERIFYDATA" = "y" ]; then

    echo "Verifying data...";
    ./verify.js;

fi

read -p "Generate and load migration scripts? [y|N]: " MIGRATEDATA;

if [ "$MIGRATEDATA" = "y" ]; then

    echo "Generating and loading migration scripts...";
    ./generate_migration_scripts.js;

fi

clear;

echo "Done!";