const csvFilePath = '/home/firdaws/Documents/Thesis/gtfs/stops.txt';
const jsonFilePath = '/home/firdaws/Documents/Thesis/gtfs/stops.json';
const csv = require('csvtojson');
var fs = require('fs');

const admin = require('./node_modules/firebase-admin');
const serviceAccount = require("./serviceAccount.json");
const collectionKey = "stops";

function exportCSVTofirestore() {
    createJSONFile();
}

async function createJSONFile() {
    fs.readFile(csvFilePath, 'utf8', function (err, data) {
        if (err) {
            return console.log(err);
        }
        //var result = data.replace(/[\n\r]/g,'\r\n');
        var result = data.replace(/[\n]/g, '\r');

        fs.writeFile(csvFilePath, result, 'utf8', function (err) {
            if (err) return console.log(err);
        });
    });

    console.log(csvFilePath);
    const jsonArray = await csv().fromFile(csvFilePath);
    fs.writeFile(jsonFilePath, JSON.stringify(jsonArray), function (err) {
        if (err) throw err;
        console.log('complete');
        exportData(jsonArray);
    }
    );
}

function exportData(data) {

    admin.initializeApp({ credential: admin.credential.cert(serviceAccount), databaseURL: "https://wheelchair-router.firebaseio.com" });
    const firestore = admin.firestore();
    const settings = { timestampsInSnapshots: true };
    firestore.settings(settings);
    if (data && (typeof data === "object")) {
        Object.keys(data).forEach(docKey => { 
            firestore.collection(collectionKey).doc(docKey).set(data[docKey]).then((res) => { 
                console.log("Document " + docKey + " successfully written!"); 
            }).catch((error) => { 
                console.error("Error writing document: ", error); 
            }); 
        });
    }
}

exportCSVTofirestore();