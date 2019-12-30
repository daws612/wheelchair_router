//const csvFilePath = '/home/firdaws/Documents/Thesis/gtfs/stops.txt';
//const jsonFilePath = '/home/firdaws/Documents/Thesis/gtfs/stops.json';
//const dirName = '/home/firdaws/Documents/Thesis/gtfs/';
const csv = require('csvtojson');
var fs = require('fs');
const path = require('path');
const txtToJson = require("txt-file-to-json");
const toJSON = require('plain-text-data-to-json');
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
            // Do whatever you want to do with the file
            const filePath = path.join(directoryPath, file);
            var filename = path.parse(file).name;//filePath.replace(/^.*[\\\/]/, '');
            console.log(filename);
            if(path.parse(file).ext === ".txt"){
                var doc = fs.readFileSync(filePath, 'utf8')
                Papa.parse(doc, { header: true, delimiter: ",",	newline: "\n",	
                 dynamicTyping: false, skipEmptyLines: 'greedy',
                    complete: function(results) {
                        const jsonFilePath = path.join(__dirname, 'gtfs/'+filename+'.json');
                        fs.writeFileSync(jsonFilePath, JSON.stringify(results) + '\n');
                       // console.log(results);
                    }
                });

                // var doc = fs.readFileSync(filePath, 'utf8')
    
                // var options = {"delimiter": ","};
                // var data = toJSON(doc, options)
    
                // const jsonFilePath = path.join(__dirname, 'gtfs/'+filename+'.json');
                // fs.writeFileSync(jsonFilePath, JSON.stringify(data) + '\n')

                //createJSONFile(filePath, filename);
                // const jsonArray = txtToJson({ filePath: filePath });

                // //const jsonArray = JSON.stringify(out);
                // const jsonFilePath = path.join(__dirname, 'gtfs/'+filename+'.json');
                // fs.writeFile(jsonFilePath, JSON.stringify(jsonArray), function (err) {
                //     if (err) throw err;
                //     console.log('completed ' + jsonFilePath);
                //     //exportData(jsonArray);
                // });
            }
        });
    });

    //createJSONFile();
}

async function createJSONFile(csvFilePath, filename) {
    fs.readFile(csvFilePath, 'utf8', function (err, data) {
        if (err) {
            return console.log(err);
        }
        //var result = data.replace(/[\n\r]/g,'\r\n');
        // var result = data.replace(/[\r\n]+/gm, '$');
        // //result = result.replace("$", "\n"); --- worked for first row only
        // result = result.split("$").join("\n");
        // //var result = data.split("\n").join('\r\n');

        // csvFilePath = path.join(__dirname, 'gtfs/'+filename+'.csv');
        // fs.writeFile(csvFilePath, result, 'utf8', function (err) {
        //     if (err) return console.log(err);
        // });

        var cells = data.split('\n').map(function (el) {
             return el.split(","); 
        });
        var headings = cells.shift();
        var out = cells.map(function (el) {
            var obj = {};
            for (var i = 0, l = el.length; i < l; i++) {
                obj[headings[i]] = isNaN(Number(el[i])) ? el[i] : +el[i];
            }
            var row = headings.concat("\r\n").concat(el);
            console.log(row);
            csv()
            .fromString(row)
            .subscribe((jsonObj)=>{
                console.log(jsonObj);
            });
            return obj;
        });

        const jsonArray = JSON.stringify(out);
        const jsonFilePath = path.join(__dirname, 'gtfs/'+filename+'.json');
        fs.writeFile(jsonFilePath, JSON.stringify(jsonArray), function (err) {
            if (err) throw err;
            console.log('completed ' + jsonFilePath);
            //exportData(jsonArray);
        });
    });

    //{eol: '\r', alwaysSplitAtEOL: true}
    // const jsonArray = await csv().fromFile(csvFilePath);
    // const jsonFilePath = path.join(__dirname, 'gtfs/'+filename+'.json');
    // fs.writeFile(jsonFilePath, JSON.stringify(jsonArray), function (err) {
    //     if (err) throw err;
    //     console.log('completed ' + jsonFilePath);
    //     //exportData(jsonArray);
    // });
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