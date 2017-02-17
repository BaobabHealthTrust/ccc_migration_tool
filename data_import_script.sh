#!/usr/bin/env bash

# CouchDB Views Definition
VIEWS='
{
   "_id": "_design/Person",
   "language": "javascript",
   "views": {
       "person": {
           "map": "function(doc) {\n  if(doc.type == \"person\") {\n  \temit(doc.person_id, null);\n  }\n}"
       },
       "person_name": {
           "map": "function(doc) {\n  if(doc.type == \"person_name\") {\n  \temit(doc.person_id, null);\n  }\n}"
       },
       "obs": {
           "map": "function(doc) {\n  if(doc.type == \"obs\") {\n  \temit(doc.person_id, null);\n  }\n}"
       },
       "drug_order": {
           "map": "function(doc) {\n  if(doc.type == \"order\") {\n  \temit(doc.person_id, null);\n  }\n}"
       },
       "identifiers": {
           "map": "function(doc) {\n  if(doc.type == \"identifier\") {\n  \temit(doc.person_id, null);\n  }\n}"
       },
       "addresses": {
           "map": "function(doc) {\n  if(doc.type == \"address\") {\n  \temit(doc.person_id, null);\n  }\n}"
       },
       "attributes": {
           "map": "function(doc) {\n  if(doc.type == \"attribute\") {\n  \temit(doc.person_id, null);\n  }\n}"
       },
       "patient_programs": {
           "map": "function(doc) {\n  if(doc.type == \"program\") {\n  \temit(doc.person_id, null);\n  }\n}"
       },
       "obs_encounters": {
           "map": "function(doc) {\n  if(doc.type == \"obs\") {\n  \temit([doc.person_id, doc.encounter_type, doc.encounter_id, doc.creator], null);\n  }\n}"
       },
       "obs_encounters_only": {
           "map": "function(doc) {\n  if(doc.type == \"obs\") {\n  \temit(doc.encounter_type, null);\n  }\n}"
       },
       "chronic_care_program": {
           "map": "function(doc) {\n  if(doc.type == \"program\") {\n  \temit([doc.person_id, doc.program], null);\n  }\n}"
       },
       "all_chronic_care_program": {
           "map": "function(doc) {\n  if(doc.type == \"program\") {\n  \temit(doc.program, null);\n  }\n}"
       },
       "obs_value": {
           "map": "function(doc) {\n  if(doc.type == \"obs\") {\n\tif(String(doc.value_boolean).trim().length > 0) {\n  \t\temit(doc.value_boolean, null);\n\t} else if(String(doc.value_coded).trim().length > 0) {\n  \t\temit(doc.value_coded, null);\n\t} else if(String(doc.value_datetime).trim().length > 0) {\n  \t\temit(doc.value_datetime, null);\n\t} else if(String(doc.value_numeric).trim().length > 0) {\n  \t\temit(doc.value_numeric, null);\n\t} else if(String(doc.value_drug).trim().length > 0) {\n  \t\temit(doc.value_drug, null);\n\t} else {\n\t\temit(doc.value_text, null);\n\t}\n  }\n}"
       }
   }
}'

# Initialise 'data/' folder
rm -rf data/

mkdir -p data/

cp couchdb.json.example couchdb.json

cp database.json.example database.json

echo

# Capture MySQL connection parameters
echo "====================== MYSQL ================================="

echo

read -p "Enter source database name: " SOURCE_DATABASE

read -p "Enter source database usename: " SOURCE_DATABASE_USERNAME

echo -n "Enter source database password for '$SOURCE_DATABASE_USERNAME': "

read -s SOURCE_DATABASE_PASSWORD

sed -i 's/"username": ""/"username": "'$SOURCE_DATABASE_USERNAME'"/g' database.json

sed -i 's/"password": ""/"password": "'$SOURCE_DATABASE_PASSWORD'"/g' database.json

sed -i 's/"database": ""/"database": "'$SOURCE_DATABASE'"/g' database.json

echo

echo

# Capture CouchDB connection parameters
echo "====================== CouchDB =============================="

echo

read -p "Enter CouchDB database name: " COUCHDB_DATABASE

read -p "Enter CouchDB database usename: " COUCHDB_DATABASE_USERNAME

echo -n "Enter CouchDB database password for '$COUCHDB_DATABASE_USERNAME': "

read -s COUCHDB_DATABASE_PASSWORD

sed -i 's/"username": ""/"username": "'$COUCHDB_DATABASE_USERNAME'"/g' couchdb.json

sed -i 's/"password": ""/"password": "'$COUCHDB_DATABASE_PASSWORD'"/g' couchdb.json

sed -i 's/"database": ""/"database": "'$COUCHDB_DATABASE'"/g' couchdb.json

# TODO: Need to change these parameters to be captured dynamically as well
COUCHDB_HOST="0.0.0.0"
COUCHDB_PORT=5984

echo

echo

# Initialising CouchDB database
echo "Resetting CouchDB database..."

# First delete database if it exists
curl -s -H "Content-Type: application/json" -X DELETE "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE" > /dev/null

# Recreate the database
curl -s -X PUT "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE" > /dev/null

curl -s -H "Content-Type: application/json" -X POST "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE/_compact" > /dev/null

# Load CouchDB Views
curl -s -H "Content-Type: application/json" -X PUT -d "$VIEWS" "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE/_design/Person" > /dev/null

echo "CouchDB reset done!"

echo

# Query CCC data from database

# person table
echo "Extracting 'person' table..."

echo

mysql -u $SOURCE_DATABASE_USERNAME -p$SOURCE_DATABASE_PASSWORD $SOURCE_DATABASE -e "SELECT CONCAT('{\"person_id\":\"', COALESCE(person_id,''), '\", \"gender\":\"', COALESCE(gender,''), '\", \"birthdate\":\"', COALESCE(birthdate,''), '\", \"birthdate_estimated\":\"', COALESCE(birthdate_estimated,''), '\",\"creator\":\"', COALESCE((SELECT username FROM users WHERE user_id = person.creator LIMIT 1),''),'\", \"date_created\":\"', COALESCE(date_created,''), '\",\"date_changed\":\"', COALESCE(date_changed,''), '\",\"type\":\"person\"},') AS field FROM person WHERE COALESCE(voided, 0) = 0 AND person_id IN (SELECT DISTINCT patient_id FROM patient_program LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE name IN (\"CHRONIC CARE PROGRAM\", \"DIABETES PROGRAM\") AND COALESCE(patient_program.voided, 0) = 0)" > data/person.json;

# Delete empty lines
sed -i '/^$/d' data/person.json 

# Replace first occurrence of "field" with '{"docs":['
sed -i '0,/field/ s/field/{"docs":[/' data/person.json 

# Replace last "," with "]}"
sed -i '$ s/.$/]}/' data/person.json 

# Load the data into CouchDB
curl -s -H "Content-Type: application/json" -X POST -d @data/person.json "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE/_bulk_docs" > /dev/null

echo

# person_name table
echo "Extracting 'person_name' table..."

echo

mysql -u $SOURCE_DATABASE_USERNAME -p$SOURCE_DATABASE_PASSWORD $SOURCE_DATABASE -e "SELECT CONCAT('{\"person_name_id\":\"', COALESCE(person_name_id,''), '\",\"person_id\":\"', COALESCE(person_id,''), '\", \"given_name\":\"', COALESCE(given_name,''), '\", \"middle_name\":\"', COALESCE(middle_name,''), '\", \"family_name\":\"', COALESCE(family_name,''), '\",\"family_name2\":\"', COALESCE(family_name2,''), '\",\"creator\":\"', COALESCE((SELECT username FROM users WHERE user_id = person_name.creator LIMIT 1),''),'\",\"date_created\":\"', COALESCE(date_created,''), '\",\"type\":\"person_name\"},') AS field FROM person_name WHERE COALESCE(voided, 0) = 0 AND person_id IN (SELECT DISTINCT patient_id FROM patient_program LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE name IN (\"CHRONIC CARE PROGRAM\", \"DIABETES PROGRAM\") AND COALESCE(patient_program.voided, 0) = 0);" > data/person_name.json;

# Delete empty lines
sed -i '/^$/d' data/person_name.json 

# Replace first occurrence of "field" with '{"docs":['
sed -i '0,/field/ s/field/{"docs":[/' data/person_name.json 

# Replace last "," with "]}"
sed -i '$ s/.$/]}/' data/person_name.json 

# Load the data into CouchDB
curl -H "Content-Type: application/json" -X POST -d @data/person_name.json "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE/_bulk_docs" > /dev/null

echo

# obs table
echo "Extracting 'obs' table..."

echo

mysql -u $SOURCE_DATABASE_USERNAME -p$SOURCE_DATABASE_PASSWORD $SOURCE_DATABASE -e "SELECT CONCAT('{\"obs_id\":\"', COALESCE(obs_id,''), '\",\"person_id\":\"', COALESCE(person_id,''), '\", \"concept\":\"', (SELECT name FROM concept_name WHERE concept_name.concept_id = obs.concept_id LIMIT 1), '\",\"encounter_id\":\"', COALESCE(encounter_id,''), '\",\"encounter_type\":\"', COALESCE((SELECT name FROM encounter_type LEFT OUTER JOIN encounter ON encounter.encounter_type = encounter_type.encounter_type_id WHERE encounter.encounter_id = obs.encounter_id LIMIT 1),''), '\",\"obs_datetime\":\"', COALESCE(obs_datetime,''), '\",\"location\":\"', COALESCE((SELECT name FROM location WHERE location.location_id = obs.location_id LIMIT 1),''), '\", \"value_boolean\":\"', COALESCE(value_boolean,''), '\",\"value_coded\":\"', COALESCE((CASE WHEN COALESCE(value_coded_name_id,0) != 0 THEN (SELECT name FROM concept_name WHERE concept_name.concept_name_id = obs.value_coded_name_id LIMIT 1) ELSE (SELECT name FROM concept_name WHERE concept_name.concept_id = obs.value_coded LIMIT 1) END), ''), '\", \"value_drug\":\"', COALESCE((SELECT name FROM drug WHERE drug_id = obs.value_drug LIMIT 1),''), '\", \"value_datetime\":\"', COALESCE(value_datetime, ''), '\", \"value_numeric\":\"', COALESCE(value_numeric,''), '\",\"value_text\":\"', COALESCE(value_text,''), '\",\"creator\":\"', COALESCE((SELECT username FROM users WHERE user_id = obs.creator LIMIT 1),''),'\",\"date_created\":\"', COALESCE(date_created,''), '\",\"type\":\"obs\"},') AS field FROM obs WHERE COALESCE(obs.voided, 0) = 0 AND person_id IN (SELECT DISTINCT patient_id FROM patient_program LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE name IN ('CHRONIC CARE PROGRAM', 'DIABETES PROGRAM') AND COALESCE(patient_program.voided, 0) = 0);" > data/obs.json;

# Delete empty lines
sed -i '/^$/d' data/obs.json 

# Replace first occurrence of "field" with '{"docs":['
sed -i '0,/field/ s/field/{"docs":[/' data/obs.json 

# Replace last "," with "]}"
sed -i '$ s/.$/]}/' data/obs.json 

# Load the data into CouchDB
curl -H "Content-Type: application/json" -X POST -d @data/obs.json "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE/_bulk_docs" > /dev/null

echo

# orders related tables
echo "Extracting 'drug orders' table..."

echo

mysql -u $SOURCE_DATABASE_USERNAME -p$SOURCE_DATABASE_PASSWORD $SOURCE_DATABASE -e "SELECT CONCAT('{\"person_id\":\"', COALESCE(patient_id,''), '\", \"order_id\":\"', COALESCE(orders.order_id,''), '\",\"order_concept\":\"', COALESCE((SELECT name FROM concept_name WHERE concept_id = orders.concept_id LIMIT 1),''), '\",\"orderer\":\"', COALESCE((SELECT username FROM users WHERE user_id = orders.orderer LIMIT 1),''), '\",\"encounter_id\":\"', COALESCE(encounter_id,''), '\",\"encounter_type\":\"', COALESCE((SELECT name FROM encounter_type LEFT OUTER JOIN encounter ON encounter.encounter_type = encounter_type.encounter_type_id WHERE encounter.encounter_id = orders.encounter_id LIMIT 1),''), '\",\"instructions\":\"', COALESCE(instructions,''),'\",\"start_date\":\"', COALESCE(start_date,''),'\",\"auto_expire_date\":\"',COALESCE(auto_expire_date,''),'\",\"creator\":\"', COALESCE((SELECT username FROM users WHERE user_id = orders.creator LIMIT 1),''), '\",\"date_created\":\"',COALESCE(orders.date_created,''), '\",\"dose\":\"', COALESCE(dose,''), '\",\"equivalent_daily_dose\":\"', COALESCE(equivalent_daily_dose,''), '\",\"drug_order_units\":\"', COALESCE(drug_order.units,''), '\",\"frequency\":\"', COALESCE(frequency,''), '\",\"prn\":\"', COALESCE(prn,0), '\",\"quantity\":\"', COALESCE(quantity,''), '\",\"drug_name\":\"', COALESCE(drug.name, ''), '\",\"type\":\"order\"},') AS field FROM orders LEFT OUTER JOIN drug_order ON drug_order.order_id = orders.order_id LEFT OUTER JOIN drug ON drug.drug_id = drug_order.drug_inventory_id WHERE COALESCE(orders.voided, 0) = 0 AND orders.patient_id IN (SELECT DISTINCT patient_id FROM patient_program LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE name IN ('CHRONIC CARE PROGRAM', 'DIABETES PROGRAM') AND COALESCE(patient_program.voided, 0) = 0);" > data/drug_orders.json;

# Delete empty lines
sed -i '/^$/d' data/drug_orders.json 

# Replace first occurrence of "field" with '{"docs":['
sed -i '0,/field/ s/field/{"docs":[/' data/drug_orders.json 

# Replace last "," with "]}"
sed -i '$ s/.$/]}/' data/drug_orders.json 

# Load the data into CouchDB
curl -H "Content-Type: application/json" -X POST -d @data/drug_orders.json "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE/_bulk_docs" > /dev/null

echo

# patient identifier table
echo "Extracting 'patient_identifier' table..."

echo

mysql -u $SOURCE_DATABASE_USERNAME -p$SOURCE_DATABASE_PASSWORD $SOURCE_DATABASE -e "SELECT CONCAT('{\"person_id\":\"', COALESCE(patient_id,''), '\",\"identifier\":\"', COALESCE(identifier,''), '\",\"identifier_type\":\"', COALESCE((SELECT name FROM patient_identifier_type WHERE patient_identifier_type_id = patient_identifier.identifier_type LIMIT 1),''), '\", \"creator\":\"', COALESCE((SELECT username FROM users WHERE user_id = patient_identifier.creator LIMIT 1), ''), '\",\"date_created\":\"', COALESCE(date_created,''), '\",\"type\":\"identifier\"},') AS field FROM patient_identifier WHERE COALESCE(patient_identifier.voided, 0) = 0 AND patient_id IN (SELECT DISTINCT patient_id FROM patient_program LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE name IN ('CHRONIC CARE PROGRAM', 'DIABETES PROGRAM') AND COALESCE(patient_program.voided, 0) = 0);" > data/patient_identifier.json;

# Delete empty lines
sed -i '/^$/d' data/patient_identifier.json 

# Replace first occurrence of "field" with '{"docs":['
sed -i '0,/field/ s/field/{"docs":[/' data/patient_identifier.json 

# Replace last "," with "]}"
sed -i '$ s/.$/]}/' data/patient_identifier.json 

# Load the data into CouchDB
curl -H "Content-Type: application/json" -X POST -d @data/patient_identifier.json "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE/_bulk_docs" > /dev/null

echo

# person_address table
echo "Extracting 'person_address' table..."

echo

mysql -u $SOURCE_DATABASE_USERNAME -p$SOURCE_DATABASE_PASSWORD $SOURCE_DATABASE -e "SELECT CONCAT('{\"person_id\":\"', COALESCE(person_id,''), '\",\"address1\":\"', COALESCE(address1,''), '\",\"address2\":\"', COALESCE(address2,''), '\",\"city_village\":\"',COALESCE(state_province,''),'\",\"creator\":\"', COALESCE((SELECT username FROM users WHERE user_id = person_address.creator),''), '\", \"date_created\":\"', COALESCE(date_created,''), '\",\"county_district\":\"', COALESCE(county_district,''), '\", \"neighborhood_cell\":\"', COALESCE(neighborhood_cell,''), '\",\"type\":\"address\"},') AS field FROM person_address WHERE COALESCE(voided, 0) = 0 AND person_id IN (SELECT DISTINCT patient_id FROM patient_program LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE name IN ('CHRONIC CARE PROGRAM', 'DIABETES PROGRAM'));" > data/person_address.json;

# Delete empty lines
sed -i '/^$/d' data/person_address.json 

# Replace first occurrence of "field" with '{"docs":['
sed -i '0,/field/ s/field/{"docs":[/' data/person_address.json 

# Replace last "," with "]}"
sed -i '$ s/.$/]}/' data/person_address.json 

# Load the data into CouchDB
curl -H "Content-Type: application/json" -X POST -d @data/person_address.json "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE/_bulk_docs" > /dev/null

echo

# person_attribute table
echo "Extracting 'person_attribute' table..."

echo

mysql -u $SOURCE_DATABASE_USERNAME -p$SOURCE_DATABASE_PASSWORD $SOURCE_DATABASE -e "SELECT CONCAT('{\"person_id\":\"', COALESCE(person_id,''), '\",\"value\":\"', COALESCE(value,''), '\",\"attribute_type\":\"', COALESCE((SELECT name FROM person_attribute_type WHERE person_attribute_type.person_attribute_type_id = person_attribute.person_attribute_type_id LIMIT 1),''), '\",\"creator\":\"', COALESCE((SELECT username FROM users WHERE user_id = person_attribute.creator),''), '\",\"date_created\":\"', COALESCE(date_created,''), '\",\"type\":\"attribute\"},') AS field FROM person_attribute WHERE COALESCE(person_attribute.voided, 0) = 0 AND person_id IN (SELECT DISTINCT patient_id FROM patient_program LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE name IN ('CHRONIC CARE PROGRAM', 'DIABETES PROGRAM'));" > data/person_attribute.json;

# Delete empty lines
sed -i '/^$/d' data/person_attribute.json 

# Replace first occurrence of "field" with '{"docs":['
sed -i '0,/field/ s/field/{"docs":[/' data/person_attribute.json 

# Replace last "," with "]}"
sed -i '$ s/.$/]}/' data/person_attribute.json 

# Load the data into CouchDB
curl -H "Content-Type: application/json" -X POST -d @data/person_attribute.json "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE/_bulk_docs" > /dev/null

echo

# patient_program table
echo "Extracting 'patient_program' table..."

echo

mysql -u $SOURCE_DATABASE_USERNAME -p$SOURCE_DATABASE_PASSWORD $SOURCE_DATABASE -e "SELECT CONCAT('{\"patient_program_id\":\"', COALESCE(patient_program_id,''), '\",\"person_id\":\"', COALESCE(patient_id,''), '\",\"program\":\"', COALESCE((SELECT name FROM program WHERE program.program_id = patient_program.program_id LIMIT 1),''), '\",\"date_enrolled\":\"', COALESCE(date_enrolled,''), '\",\"date_completed\":\"', COALESCE(date_completed,''), '\",\"creator\":\"', COALESCE((SELECT username FROM users WHERE user_id = creator LIMIT 1),''), '\", \"date_created\":\"', COALESCE(date_created,''), '\",\"type\":\"program\"},') AS field FROM patient_program WHERE COALESCE(voided, 0) = 0 AND patient_id IN (SELECT DISTINCT patient_id FROM patient_program LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE name IN ('CHRONIC CARE PROGRAM', 'DIABETES PROGRAM'));" > data/patient_program.json;

# Delete empty lines
sed -i '/^$/d' data/patient_program.json

# Replace first occurrence of "field" with '{"docs":['
sed -i '0,/field/ s/field/{"docs":[/' data/patient_program.json

# Replace last "," with "]}"
sed -i '$ s/.$/]}/' data/patient_program.json

# Load the data into CouchDB
curl -H "Content-Type: application/json" -X POST -d @data/patient_program.json "http://$COUCHDB_DATABASE_USERNAME:$COUCHDB_DATABASE_PASSWORD@$COUCHDB_HOST:$COUCHDB_PORT/$COUCHDB_DATABASE/_bulk_docs" > /dev/null

echo

echo "Done!"

echo
