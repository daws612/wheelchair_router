const functions = require('firebase-functions');

const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();
const FieldValue = require('firebase-admin').firestore.FieldValue;

const config = require('./config');
const util = require('util');
const mysql = require('mysql');
const PGPool = require('pg').Pool;

const pgPool = new PGPool({
    user: config.schema.user,
    host: config.schema.host,
    database: config.schema.db,
    password: config.schema.password,
    port: 5432,
});

var pool = mysql.createPool({
    connectionLimit: 100,
    host: config.schema.host,
    user: config.schema.user,
    password: config.schema.password,
    database: config.schema.db
});


// Ping database to check for common exception errors.
pool.getConnection((err, connection) => {
    if (err) {
        if (err.code === 'PROTOCOL_CONNECTION_LOST') {
            console.error('Database connection was closed.')
        }
        if (err.code === 'ER_CON_COUNT_ERROR') {
            console.error('Database has too many connections.')
        }
        if (err.code === 'ECONNREFUSED') {
            console.error('Database connection was refused.')
        }
    }

    if (connection) connection.release()

    return
});

// Promisify for Node.js async/await.
pool.query = util.promisify(pool.query);
pgPool.query = util.promisify(pgPool.query);

exports.helloWorld = functions.https.onRequest(async (request, response) => {
    var id = "XJADPht6W9Ui2pQRGzwgKknTZWG3";
    var sqlQuery = 'SELECT * FROM izmit.users WHERE firebase_id = $1;';
    var queryResult = await pgPool.query(sqlQuery, [id]);
    response.send(queryResult);

});

async function userExists(id) {
    console.log(" Check if user with id " + id + " exists. ");
    var sqlQuery = 'SELECT * FROM izmit.users WHERE firebase_id = $1';
    var result = await pgPool.query(sqlQuery, [id]);
    console.log(" User " + id + " Exists? " + result.rowCount > 0);
    return result.rowCount > 0;
}

async function createUser(user, id) {
    const exists = await userExists(id);
    if(exists)
        return updateUser(user, id);
    console.log("Create user with id :: " + id);
    var sqlQuery = 'INSERT INTO izmit.users(gender, age, firebase_id, wheelchair_type, created_at) VALUES($1,$2,$3,$4, now())';
    await pgPool.query(sqlQuery, [user.gender, user.age, id, user.wheelchairtype]);
    logAction("create_user", id, user);
}

async function updateUser(user, id) {
    const exists = await userExists(id);
    if(!exists)
        return createUser(user, id);
    console.log("Update user with id :: " + id);
    var sqlQuery = 'UPDATE izmit.users SET gender = $1, age = $2, wheelchair_type=$3, updated_at=now(), is_deleted = false::boolean WHERE firebase_id = $4';
    await pgPool.query(sqlQuery, [user.gender, user.age, user.wheelchairtype, id]);
    logAction("update_user", id, user);
}

async function deleteUser(user, id) {
    const exists = await userExists(id);
    if(!exists)
        return;
    console.log("Delete user with id :: " + id);
    var sqlQuery = 'UPDATE izmit.users SET is_deleted = true::boolean, updated_at=now() WHERE firebase_id = $1';
    await pgPool.query(sqlQuery, [id]);
    logAction("delete_user", id, user);
}

async function logAction(action, firebase_id, user) {
    console.log("Log " + action + " for user with firebase id " + firebase_id);
    var query = "INSERT INTO izmit.logs (user_id, log_id, timestamp, description) " +
        "VALUES ((SELECT User_id FROM izmit.users WHERE firebase_id = $1), (SELECT id FROM izmit.log_types WHERE log_type = $2), now(), $3);";
    await pgPool.query(query, [firebase_id, action, JSON.stringify(user)]);
}

const firestore = admin.firestore();
const executeOnce = (change, context, task) => {
    const eventRef = firestore.collection('events').doc(context.eventId);

    return firestore.runTransaction(t =>
        t
            .get(eventRef)
            .then(docSnap => (docSnap.exists ? null : task(t)))
            .then(() => t.set(eventRef, { processed: true }))
    );
};

const documentCounter = collectionName => (change, context) =>
    executeOnce(change, context, t => {
        // on create
        if (!change.before.exists && change.after.exists) {
            createUser(change.after.data(), change.after.id);
            return t
                .get(firestore.collection('metadatas')
                    .doc(collectionName))
                .then(docSnap =>
                    t.set(docSnap.ref, {
                        count: ((docSnap.data() && docSnap.data().count) || 0) + 1
                    }));
            // on delete
        } else if (change.before.exists && !change.after.exists) {
            deleteUser(change.after.data(), change.after.id);
            return t
                .get(firestore.collection('metadatas')
                    .doc(collectionName))
                .then(docSnap =>
                    t.set(docSnap.ref, {
                        count: docSnap.data().count - 1
                    }));
        } else if (change.before.exists && change.after.exists) { //on update -- use to count all docs at once
            updateUser(change.after.data(), change.after.id);
            return firestore.collection(collectionName).get().then(function (querySnapshot) {
                return t
                    .get(firestore.collection('metadatas')
                        .doc(collectionName))
                    .then(docSnap =>
                        t.set(docSnap.ref, {
                            count: querySnapshot.docs.length
                        }));
            });
        }

        return null;
    });

/**
 * Count documents in collections.
 */

exports.usersCounter = functions.firestore
    .document('users/{id}')
    .onWrite(documentCounter('users'));


    // CREATE TABLE `wheelchair_routing`.`users` (
    //     `id` INT NOT NULL AUTO_INCREMENT,
    //     `firebase_id` VARCHAR(255) NOT NULL,
    //     `gender` VARCHAR(45) NULL,
    //     `age` INT NULL DEFAULT 0,
    //     PRIMARY KEY (`id`),
    //     UNIQUE INDEX `firebase_id_UNIQUE` (`firebase_id` ASC));

//     ALTER TABLE `wheelchair_routing`.`users` 
// ADD COLUMN `is_deleted` TINYINT(1) NOT NULL DEFAULT 0 AFTER `age`;
// ALTER TABLE `wheelchair_routing`.`users` 
// ADD COLUMN `wheelchair_type` VARCHAR(255) NULL AFTER `age`;



// CREATE TABLE `wheelchair_routing`.`logs` (
//     `id` INT NOT NULL AUTO_INCREMENT,
//     `log_id` INT NOT NULL,
//     `user_id` INT NOT NULL,
//     `timestamp` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
//     PRIMARY KEY (`id`),
//     INDEX `fk_logs_log_type_idx` (`log_id` ASC),
//     INDEX `fk_logs_users_idx` (`user_id` ASC),
//     CONSTRAINT `fk_logs_log_type`
//       FOREIGN KEY (`log_id`)
//       REFERENCES `wheelchair_routing`.`log_type` (`id`)
//       ON DELETE NO ACTION
//       ON UPDATE NO ACTION,
//     CONSTRAINT `fk_logs_users`
//       FOREIGN KEY (`user_id`)
//       REFERENCES `wheelchair_routing`.`users` (`id`)
//       ON DELETE NO ACTION
//       ON UPDATE NO ACTION);
// ALTER TABLE `wheelchair_routing`.`logs` 
// ADD COLUMN `description` LONGTEXT NULL AFTER `user_id`;
