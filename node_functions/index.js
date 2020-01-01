var fs = require('fs');
const path = require('path');
const Papa = require('papaparse');
const csvParser = require('csv-parser');

const admin = require('./node_modules/firebase-admin');
const serviceAccount = require("./serviceAccount.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount), databaseURL: "https://wheelchair-router.firebaseio.com" });
const firestore = admin.firestore();
const settings = { timestampsInSnapshots: true };
firestore.settings(settings);

function exportCSVTofirestore() {

    const directoryPath = path.join(__dirname, 'gtfs');
    //passsing directoryPath and callback function
    fs.readdir(directoryPath, function (err, files) {
        //handling error
        if (err) {
            return console.log('Unable to scan directory: ' + err);
        }
        //listing all files using forEach
        files.forEach(function (file) {
            const filePath = path.join(directoryPath, file);
            var filename = path.parse(file).name;
            console.log(file);
            if (path.parse(file).ext === ".txt") {
                //createJSONFile(filePath, filename);
                batchUpload2(filePath, filename);
            }
        });
    });
}

async function createJSONFile(filePath, filename) {
    var doc = fs.readFileSync(filePath, 'utf8')
    Papa.parse(doc,
        {
            header: true,
            delimiter: ",",
            newline: "\n",
            dynamicTyping: false,
            skipEmptyLines: 'greedy',
            complete: function (results) {
                //console.log ("Processed finished" + results)
                //write parsed json to file
                const jsonFilePath = path.join(__dirname, 'gtfs/' + filename + '.json');
                fs.writeFileSync(jsonFilePath, JSON.stringify(results) + '\n');
                exportData(results.data, filename);
            }
        });
}

function exportData(data, collectionKey) {
    if (data && (typeof data === "object")) {
        //Object.keys(data).forEach(docKey => {
        firestore.collection(collectionKey).doc(docKey).set(data[docKey]).then((res) => {
            console.log("Document " + docKey + " successfully written!");
        }).catch((error) => {
            console.error("Error writing document: ", error);
        });
        //});
    }
}

exportCSVTofirestore();


const handleError = (error) => {
    // Do something with the error...
};

const commitMultiple = batchFactories => {
    let result = Promise.resolve();
    /** Waiting 1.2 seconds between writes */
    const TIMEOUT = 1200;

    batchFactories.forEach((promiseFactory, index) => {
        result = result
            .then(() => {
                return new Promise(resolve => {
                    setTimeout(() => Promise.resolve(), TIMEOUT);
                });
            })
            .then(promiseFactory)
            .then(() => console.log(`Commited ${index + 1} of ${batchFactories.length}`));
    });

    return result;
};

async function batchUpload(csvFilePath, filename) {
    let currentBatchIndex = 0;
    const batchesArray = [], batchFactoriesArray = [], batchFactories = [];
    let batchDocsCount = 0;

    batchFactoriesArray.push()
    let batch = firestore.batch();

    return Promise
        .resolve()
        .then(() => {
            const data = [];

            return fs
                .createReadStream(csvFilePath)
                .pipe(csvParser())
                .on('data', async (row) => {


                    while (currentBatchIndex < 500) {

                        const ref = firestore.collection(filename).doc(batchDocsCount.toString());

                        batch.set(ref, JSON.parse(JSON.stringify(row)));

                        batchDocsCount++; currentBatchIndex++;
                    }
                    if (currentBatchIndex >= 500) {
                        currentBatchIndex = 0;
                        batch = firestore.batch();
                        await batch.commit().then(function () {
                            console.log("commit batch " + currentBatchIndex);
                        });
                    }
                })
                .on('end', () => Promise.resolve());
        })
        //.then(() => commitMultiple(batchFactories))
        .then(() => res.json({ done: true }))
        .catch(handleError);
};

var stream = require('stream');

function batchUpload2(csvFilePath, filename) {
    var tmpArr = [];
    let batch = firestore.batch();
    var index = 0;
    fs.createReadStream(csvFilePath).pipe(csvParser()).pipe(new stream.Writable({
        write: function (json, encoding, callback) {
            index++;
            tmpArr.push(json);
            const ref = firestore.collection(filename).doc(index.toString());
            batch.set(ref, JSON.parse(JSON.stringify(json)));

            if (tmpArr.length === 500) {
                batch.commit().then(function () {
                    console.log(filename + " commit batch at index: " + index);
                    batch = firestore.batch();
                    tmpArr = [];
                    callback();
                });
            } else {
                callback();
            }
        },
        objectMode: true
    }))
        .on('finish', function () {
            if (tmpArr.length > 0) {
                batch.commit().then(function () {
                    console.log("commit batch on finish");
                    batch = firestore.batch();
                    tmpArr = [];
                });
            }
        })
}