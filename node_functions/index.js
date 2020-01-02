var fs = require('fs');
const path = require('path');
const csvParser = require('csv-parser');
var stream = require('stream');
var configJS = require('./config.js');

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
                batchUpload(filePath, filename);
            }
        });
    });
}

exportCSVTofirestore();


const handleError = (error) => {
    // Do something with the error...
};

function batchUpload(csvFilePath, filename) {
    var tmpArr = [];
    let batch = firestore.batch();
    var index = 0;
    fs.createReadStream(csvFilePath).pipe(csvParser()).pipe(new stream.Writable({
        write: function (json, encoding, callback) {
            index++;
            tmpArr.push(json);
            var latName, lonName;
            if(filename === "stops") {
                latName = json.stop_lat;
                lonName = json.stop_lon;
            } else if(filename === "shapes") {
                latName = json.shape_pt_lat;
                lonName = json.shape_pt_lon;
            }
            //Create geopoint of latlngs in the files
            var location = new admin.firestore.GeoPoint(+latName, +lonName);
            json.location = location;
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