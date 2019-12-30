var fs = require('fs');
const path = require('path');
const Papa = require('papaparse')

const admin = require('./node_modules/firebase-admin');
const serviceAccount = require("./serviceAccount.json");
const collectionKey = "stops";

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
            console.log(filename);
            if (path.parse(file).ext === ".txt") {
                createJSONFile(filePath, filename);
            }
        });
    });
}

async function createJSONFile(filePath, filename) {
    var doc = fs.readFileSync(filePath, 'utf8')
    Papa.parse(doc, 
            {header: true, 
            delimiter: ",", 
            newline: "\n",
            dynamicTyping: false, 
            skipEmptyLines: 'greedy',
            complete: function (results) {
                //write parsed json to file
                const jsonFilePath = path.join(__dirname, 'gtfs/' + filename + '.json');
                fs.writeFileSync(jsonFilePath, JSON.stringify(results) + '\n');
                exportData(results.data);
            }
    });
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