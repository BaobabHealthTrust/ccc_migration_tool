#!/usr/bin/env node

var fs = require("fs");
var path = require("path");
var client = require("node-rest-client").Client;
var config = require(path.resolve("./couchdb.json"));

Array.prototype.diff = function (a) {
    return this.filter(function (i) {
        return a.indexOf(i) < 0;
    });
};

function fetchGroupElements(filename) {

    var result = [];

    filename = path.resolve(filename);

    if (fs.existsSync(filename)) {

        var group = require(filename);

        result = group.map(function (e) {

            return e.person_id;

        }).reduce(function (a, e, i) {

            if (e && a.indexOf(e) < 0)
                a.push(e);

            return a;

        }, [])

    }

    return result;

}

function fetchInitialElements(callback) {

    var result = [];

    (new client()).get("http://localhost:5984/" + config.database + "/_design/Person/_view/all_chronic_care_program?key=%22CHRONIC+CARE+" +
        "PROGRAM%22&include_docs=true&reduce=false", function (data) {

        var json = JSON.parse(data);

        result = json.rows.map(function (e) {

            return e.doc.person_id;

        }).reduce(function (a, e, i) {

            if (e && a.indexOf(e) < 0)
                a.push(e);

            return a;

        }, []);

        callback(result);

    })

}

var aA = fetchGroupElements("./asthma/result.json");

var dA = fetchGroupElements("./diabetes/result.json");

var eA = fetchGroupElements("./epilepsy/result.json");

var hA = fetchGroupElements("./hypertension/result.json");

var uniqIds = aA.concat(dA).concat(eA).concat(hA).reduce(function (a, e, i) {

    if (a.indexOf(e) < 0)
        a.push(e);

    return a;

}, []);

fetchInitialElements(function(allElements) {

    var missing = allElements.diff(uniqIds);

    fs.writeFileSync("./missing.json", JSON.stringify(missing, undefined, 4));

    console.log("\n\tAsthma: \t%s\n\tDiabetes: \t%s\n\tEpilepsy: \t%s\n\tHypertension: \t%s\n\tUnique: \t%s\n\tAll: \t\t%s\n\tMissing: \t%s\n",
        aA.length, dA.length, eA.length, hA.length, uniqIds.length, allElements.length, missing.length);

});
