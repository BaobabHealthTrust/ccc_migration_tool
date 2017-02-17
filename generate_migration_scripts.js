#!/usr/bin/env node

var fs = require("fs");
var path = require("path");
var async = require("async");
var path = require("path");
var config = require(path.resolve("./database.json"));
var knex = require('knex')({
    client: 'mysql',
    connection: {
        host: config.host,
        user: config.username,
        password: config.password,
        database: config.database
    },
    pool: {
        min: 0,
        max: 500
    }
});

function queryRaw(sql, callback) {

    knex.raw(sql)
        .then(function (result) {

            callback(result);

        })
        .catch(function (err) {

            console.log("$: " + err.message);

            callback(err);

        });

}

function fetchData(filename) {

    var result = [];

    filename = path.resolve(filename);

    if (fs.existsSync(filename)) {

        var data = require(filename);

        result = data.map(function (e) {

            return (Object.keys(e).length > 0 ? {
                person_id: e.person_id,
                encounter_id: e.encounter_id,
                patient_program_id: e.program.patient_program_id,
                date_enrolled: e.program.date_enrolled,
                date_completed: e.program.date_completed
            } : null)

        }).reduce(function (a, e, i) {

            if (!e)
                return a;

            if (!a[e.person_id])
                a[e.person_id] = {
                    encounters: [],
                    patient_programs: {}
                };

            if (a[e.person_id].encounters.indexOf(e.encounter_id) < 0)
                a[e.person_id].encounters.push(e.encounter_id);

            if (!a[e.person_id].patient_programs[e.patient_program_id])
                a[e.person_id].patient_programs[e.patient_program_id] = {
                    date_enrolled: e.date_enrolled,
                    date_completed: e.date_completed
                };

            return a;

        }, {})

    }

    return result;

}

function initializePrograms(callback) {

    var programsList = [
        "EPILEPSY PROGRAM",
        "ASTHMA PROGRAM",
        "HYPERTENSION PROGRAM",
        "DIABETES PROGRAM",
        "CROSS-CUTTING PROGRAM"
    ];

    async.each(programsList, function (program, callback) {

        var sql = "SELECT * FROM program WHERE name = '" + program + "' AND retired = 0";

        queryRaw(sql, function (programs) {

            if (programs && programs[0] && programs[0].length <= 0) {

                var sql = "SELECT * FROM concept_name LEFT OUTER JOIN concept ON concept.concept_id = " +
                    "concept_name.concept_id WHERE name = '" + program + "' AND voided = 0 LIMIT 1";

                queryRaw(sql, function (concepts) {

                    if (concepts && concepts[0] && concepts[0].length > 0) {

                        var concept_id = concepts[0][0].concept_id;

                        var sql = "INSERT INTO program (concept_id, creator, date_created, retired, name, uuid) VALUES (" +
                            concept_id + ", 1, NOW(), 0, '" + program + "', (SELECT UUID()))";

                        queryRaw(sql, function (prog) {

                            callback();

                        })

                    } else {

                        var sql = "INSERT INTO concept (retired, datatype_id, class_id, creator, date_created, uuid) " +
                            "VALUES (0, 4, 11, 1, NOW(), (SELECT UUID()))";

                        queryRaw(sql, function (record) {

                            var concept_id = record[0].insertId;

                            var sql = "INSERT INTO concept_name (concept_id, name, locale, creator, date_created, " +
                                "voided, uuid, concept_name_type) VALUES (" + concept_id + ", '" + program + "', 'en', " +
                                "1, NOW(), 0, (SELECT UUID()), 'FULLY_SPECIFIED')";

                            queryRaw(sql, function (name) {

                                var sql = "INSERT INTO program (concept_id, creator, date_created, retired, name, uuid) VALUES (" +
                                    concept_id + ", 1, NOW(), 0, '" + program + "', (SELECT UUID()))";

                                queryRaw(sql, function (prog) {

                                    callback();

                                })

                            })

                        })

                    }

                })

            } else {

                callback();

            }

        });

    }, function (err) {

        if (err)
            console.log(err);

        var sql = "SELECT COUNT(*) AS field FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = \"" + config.database +
            "\" AND TABLE_NAME = \"encounter\" AND COLUMN_NAME = \"patient_program_id\"";

        queryRaw(sql, function (data) {

            if (data && data[0] && data[0].length > 0 && data[0][0].field == 0) {

                var sql = "ALTER TABLE `" + config.database + "`.`encounter` ADD COLUMN `patient_program_id` INT(11) " +
                    "NULL AFTER `date_changed`";


                queryRaw(sql, function (result) {

                    if (result && result[0]) {

                        callback()

                    }

                })

            } else {

                callback();

            }

        })

    });

}

function createScripts(array, program) {

    var script = [];

    var patients = Object.keys(array);

    for (var j = 0; j < patients.length; j++) {

        var patient_id = patients[j];

        var programs = Object.keys(array[patient_id].patient_programs);

        for (var i = 0; i < programs.length; i++) {

            var program_id = programs[i];

            var sql = "UPDATE patient_program SET voided = 0, voided_by = (SELECT user_id FROM users WHERE retired = 0 " +
                "LIMIT 1), date_voided = NOW(), void_reason = \"Voided during migration due to irrelevance in new design.\"" +
                " WHERE patient_program_id = \"" + program_id + "\"";

            script.push(sql);

        }

        var dateEnrolled = (programs.length > 0 && array[patient_id].patient_programs[programs[0]] ?
            array[patient_id].patient_programs[programs[0]].date_enrolled : (new Date()));

        var dateCompleted = (programs.length > 0 && array[patient_id].patient_programs[programs[0]] ?
            array[patient_id].patient_programs[programs[0]].date_completed : "");

        var sql = "INSERT INTO patient_program (patient_id, program_id, date_enrolled, date_completed, creator, date_created, " +
            "uuid) VALUES (\"" + patient_id + "\", (SELECT program_id FROM program WHERE name = \"" + program + "\" LIMIT 1), " +
            "\"" + dateEnrolled + "\", \"" + dateCompleted + "\", (SELECT user_id FROM users WHERE retired = 0 " +
            "LIMIT 1), NOW(), (SELECT UUID()))";

        script.push(sql);

        var sql = "SELECT @patient_program_id := LAST_INSERT_ID()";

        script.push(sql);

        for (var i = 0; i < array[patient_id].encounters.length; i++) {

            var encounter_id = array[patient_id].encounters[i];

            var sql = "UPDATE encounter SET patient_program_id = @patient_program_id WHERE encounter_id = \"" + encounter_id +
                "\"";

            script.push(sql);

        }

    }

    return script.join(";\n\n");

}

function runCmd(cmd, callBack) {
    var exec = require('child_process').exec;

    exec(cmd, function (error, stdout, stderr) {

        callBack(error, stdout, stderr);

    });
}

var commands = [];

initializePrograms(function () {

    var asthma = fetchData("./asthma/result.json");

    fs.writeFileSync("./asthma/dump.json", JSON.stringify(asthma, undefined, 4));

    var asthmaScripts = createScripts(asthma, "ASTHMA PROGRAM");

    fs.writeFileSync("./asthma/dump.sql", asthmaScripts);

    commands.push({
        message: "Loading './asthma/dump.sql'...",
        cmd: "mysql -h " + config.host + " -u " + config.username + " -p" + config.password +
        " " + config.database + " < ./asthma/dump.sql"
    });

    var epilepsy = fetchData("./epilepsy/result.json");

    fs.writeFileSync("./epilepsy/dump.json", JSON.stringify(epilepsy, undefined, 4));

    var epilepsyScripts = createScripts(epilepsy, "EPILEPSY PROGRAM");

    fs.writeFileSync("./epilepsy/dump.sql", epilepsyScripts);

    commands.push({
        message: "Loading './epilepsy/dump.sql'...",
        cmd: "mysql -h " + config.host + " -u " + config.username + " -p" + config.password +
        " " + config.database + " < ./epilepsy/dump.sql"
    });

    var hypertension = fetchData("./hypertension/result.json");

    fs.writeFileSync("./hypertension/dump.json", JSON.stringify(hypertension, undefined, 4));

    var hypertensionScripts = createScripts(hypertension, "HYPERTENSION PROGRAM");

    fs.writeFileSync("./hypertension/dump.sql", hypertensionScripts);

    commands.push({
        message: "Loading './hypertension/dump.sql'...",
        cmd: "mysql -h " + config.host + " -u " + config.username + " -p" + config.password +
        " " + config.database + " < ./hypertension/dump.sql"
    });

    var diabetes = fetchData("./diabetes/result.json");

    fs.writeFileSync("./diabetes/dump.json", JSON.stringify(diabetes, undefined, 4));

    var diabetesScripts = createScripts(diabetes, "DIABETES PROGRAM");

    fs.writeFileSync("./diabetes/dump.sql", diabetesScripts);

    commands.push({
        message: "Loading './diabetes/dump.sql'...",
        cmd: "mysql -h " + config.host + " -u " + config.username + " -p" + config.password +
        " " + config.database + " < ./diabetes/dump.sql"
    });

    async.each(commands, function (cmd, callback) {

        console.log(cmd.message);

        runCmd(cmd.cmd, function (error, stdout, stderr) {

            if (error) {

                console.log(error);

            } else if (stderr) {

                console.log(stderr);

            } else if (stdout) {

                console.log(stdout);

            }

            callback();

        });

    }, function (err) {

        if(err)
            console.log(err.message);

    });

});
