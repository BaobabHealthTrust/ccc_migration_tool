#!/usr/bin/env node

"use strict"

// process.stdin.resume();

var client = require("node-rest-client").Client;
var config = require(path.resolve("./couchdb.json"));

var knownEncounters = [
    "COMPLICATIONS",
    "APPOINTMENT",
    "VITALS",
    "DIABETES HYPERTENSION INITIAL VISIT",
    "TREATMENT",
    "LAB RESULTS",
    "UPDATE OUTCOME",
    "ASTHMA MEASURE",
    "EPILEPSY CLINIC VISIT",
    "FAMILY MEDICAL HISTORY",
    "GENERAL HEALTH",
    "UPDATE HIV STATUS",
    "MEDICAL HISTORY",
    "SOCIAL HISTORY",
    "DISPENSING"
];

Array.prototype.diff = function (a) {
    return this.filter(function (i) {
        return a.indexOf(i) < 0;
    });
};

Date.prototype.withoutTime = function () {
    var d = new Date(this);
    d.setHours(0, 0, 0, 0);
    return d;
};

var result = [];

var programs = [];

function exitHandler(options, err) {

    // if (options.logdata) console.log(JSON.stringify(result, undefined, 4));

    if (err) console.log(err.stack);

    if (options.exit) {

        console.log(JSON.stringify(result, undefined, 4));

        process.exit();

    }

}

process.on('exit', exitHandler.bind(null, {logdata: true}));

process.on('SIGINT', exitHandler.bind(null, {exit: true}));

var fs = require("fs");

var diabetes = {};
var hypertension = {};
var epilepsy = {};
var asthma = {};

fs.writeFileSync("./result.json", "[\n");

if (fs.existsSync("./diabetes")) {

    fs.writeFileSync("./diabetes/result.json", "[\n");

}

if (fs.existsSync("./hypertension")) {

    fs.writeFileSync("./hypertension/result.json", "[\n");

}

if (fs.existsSync("./epilepsy")) {

    fs.writeFileSync("./epilepsy/result.json", "[\n");

}

if (fs.existsSync("./asthma")) {

    fs.writeFileSync("./asthma/result.json", "[\n");

}

(new client()).get("http://localhost:5984/" + config.database + "/_design/Person/_view/obs_encounters_only?keys=" +
    encodeURIComponent(JSON.stringify(knownEncounters)) + "&include_docs=true&reduce=false", function (data) {

    var json = JSON.parse(data);

    (new client()).get("http://localhost:5984/" + config.database + "/_design/Person/_view/all_chronic_care_program?include_docs=true&reduce=" +
        "false&key=%22CHRONIC CARE PROGRAM%22", function (res) {

        var programsData = JSON.parse(res);

        programs = programsData.rows.map(function (e) {
            return e;
        }).reduce(function (a, e, i) {

            if (e.doc.person_id)
                a[e.doc.person_id] = e.doc;

            return a;

        }, {})

        for (var i = 0; i < json.rows.length; i++) {

            if (json.rows[i] && json.rows[i].doc) {

                var row = json.rows[i].doc;

                if ((programs[row.person_id] ? (((new Date(row.obs_datetime)).withoutTime() >=
                    (new Date(programs[row.person_id].date_enrolled)).withoutTime()) || ((new Date(row.date_created)).withoutTime() >=
                    (new Date(programs[row.person_id].date_created)).withoutTime())) : false)) {

                    var value;

                    if (String(row.value_boolean).trim().length > 0) {

                        value = row.value_boolean;

                    } else if (String(row.value_coded).trim().length > 0) {

                        value = row.value_coded;

                    } else if (String(row.value_datetime).trim().length > 0) {

                        value = row.value_datetime;

                    } else if (String(row.value_drug).trim().length > 0) {

                        value = row.value_drug;

                    } else if (String(row.value_numeric).trim().length > 0) {

                        value = row.value_numeric;

                    } else {

                        value = row.value_text;

                    }

                    var entry = {
                        person_id: row.person_id,
                        encounter_type: row.encounter_type,
                        encounter_id: row.encounter_id,
                        encounter_datetime: row.obs_datetime,
                        concept: row.concept,
                        value: value,
                        program: {
                            date_enrolled: (programs[row.person_id] ? programs[row.person_id].date_enrolled : ""),
                            date_completed: (programs[row.person_id] ? programs[row.person_id].date_completed : ""),
                            patient_program_id: (programs[row.person_id] ? programs[row.person_id].patient_program_id : "")
                        }
                    }

                    if ((row.encounter_type.match(/lab\sresults/i) && row.concept.match(/blood\ssugar\stest\stype/i)) ||
                        (row.encounter_type.match(/diabetes/i))) {

                        if (!fs.existsSync("./diabetes")) {

                            fs.mkdirSync("./diabetes");

                            fs.writeFileSync("./diabetes/result.json", "[\n");

                        }

                        if (!diabetes[row.person_id])
                            diabetes[row.person_id] = [];

                        if (diabetes[row.person_id].indexOf(row.encounter_id))
                            diabetes[row.person_id].push(row.encounter_id);

                        fs.appendFileSync("./diabetes/result.json", JSON.stringify(entry) + ",\n");

                    }

                    if (row.encounter_type.match(/vitals/i) && row.concept.match(/blood\spressure/i) || row.value_drug.match(/amlodipine/i)) {

                        if (!fs.existsSync("./hypertension")) {

                            fs.mkdirSync("./hypertension");

                            fs.writeFileSync("./hypertension/result.json", "[\n");

                        }

                        if (!hypertension[row.person_id])
                            hypertension[row.person_id] = [];

                        if (hypertension[row.person_id].indexOf(row.encounter_id))
                            hypertension[row.person_id].push(row.encounter_id);

                        fs.appendFileSync("./hypertension/result.json", JSON.stringify(entry) + ",\n");

                    }

                    if (row.concept.match(/epilepsy/i) || row.value_drug.match(/phenobarbitone/i) || row.value_drug.match(/carbamazepine/i)) {

                        if (!fs.existsSync("./epilepsy")) {

                            fs.mkdirSync("./epilepsy");

                            fs.writeFileSync("./epilepsy/result.json", "[\n");

                        }

                        if (!epilepsy[row.person_id])
                            epilepsy[row.person_id] = [];

                        if (epilepsy[row.person_id].indexOf(row.encounter_id))
                            epilepsy[row.person_id].push(row.encounter_id);

                        fs.appendFileSync("./epilepsy/result.json", JSON.stringify(entry) + ",\n");

                    }

                    if (row.concept.match(/asthma/i) || row.value_drug.match(/aminophylline/i) || row.value_drug.match(/salbutamol/i)) {

                        if (!fs.existsSync("./asthma")) {

                            fs.mkdirSync("./asthma");

                            fs.writeFileSync("./asthma/result.json", "[\n");

                        }

                        if (!asthma[row.person_id])
                            asthma[row.person_id] = [];

                        if (asthma[row.person_id].indexOf(row.encounter_id))
                            asthma[row.person_id].push(row.encounter_id);

                        fs.appendFileSync("./asthma/result.json", JSON.stringify(entry) + ",\n");

                    }

                    fs.appendFileSync("./result.json", JSON.stringify(entry) + (i < json.rows.length - 1 ? ",\n" : "\n"));

                }

            }

        }

        fs.appendFileSync("./result.json", "]");

        if (fs.existsSync("./diabetes")) {

            fs.appendFileSync("./diabetes/result.json", "{}]");

        }

        if (fs.existsSync("./hypertension")) {

            fs.appendFileSync("./hypertension/result.json", "{}]");

        }

        if (fs.existsSync("./epilepsy")) {

            fs.appendFileSync("./epilepsy/result.json", "{}]");

        }

        if (fs.existsSync("./asthma")) {

            fs.appendFileSync("./asthma/result.json", "{}]");

        }

    }).on('error', function (err) {
        console.log(err.message, err.request.options);
    });

}).on('error', function (err) {
    console.log(err.message, err.request.options);
});


