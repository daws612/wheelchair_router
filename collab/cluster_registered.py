import joblib
import os
import numpy as np
import pandas as pd
import psycopg2
from pandas import DataFrame
from psycopg2 import pool
from sklearn.cluster import KMeans
from sklearn.preprocessing import LabelEncoder, OneHotEncoder, StandardScaler
from sklearn_pandas import DataFrameMapper
from matplotlib import pyplot as plt

def elbow(standardized_data):
    #ELBOW METHOD
    # calculate distortion for a range of number of cluster
    elbowPlot = plt.figure(1);
    distortions = []
    for i in range(1, 10):
        km = KMeans(
            n_clusters=i, init='k-means++',
            n_init=10, max_iter=300
        )
        km.fit(standardized_data)
        distortions.append(km.inertia_)

    # plot
    plt.plot(range(1, 10), distortions, marker='o')
    plt.xlabel('Number of clusters')
    plt.ylabel('Distortion')

    #plt.show()
    dirname = os.path.dirname(__file__)
    elbowPlot.savefig(os.path.join(dirname, 'elbow.png'))
    plt.close(elbowPlot)

def visualize_clusters(standardized_data):
    dirname = os.path.dirname(__file__)

    clusterPlot = plt.figure(2, figsize=(6, 6))
    plt.scatter(standardized_data.iloc[:, 3], standardized_data.iloc[:, 0], c=cluster, s=10, cmap='viridis')

    loaded_model = joblib.load(os.path.join(dirname, 'KmeansModel.pkl'))
    centers = loaded_model.cluster_centers_
    plt.scatter(centers[:, 3], centers[:, 0], c='grey', s=200, alpha=0.1);

    plt.xlabel(standardized_data.columns[3])
    plt.ylabel(standardized_data.columns[0])
    #plt.show()
    
    clusterPlot.savefig(os.path.join(dirname, 'cluster.png'))
    plt.close(clusterPlot)

try:
    postgreSQL_pool = psycopg2.pool.SimpleConnectionPool(1, 20, user="wheelchair_routing",
                                                         password="em6Wgu<S;^J*xP?g%.",
                                                         host="127.0.0.1",
                                                         port="5432",
                                                         database="wheelchair_routing")
    if(postgreSQL_pool):
        print("Connection pool created successfully")

    # Use getconn() to Get Connection from connection pool
    ps_connection = postgreSQL_pool.getconn()

    if(ps_connection):
        print("successfully received connection from connection pool ")
        ps_cursor = ps_connection.cursor()
        ps_cursor.execute(
            "select user_id, COALESCE(gender, 'Unspecified') as gender, age, COALESCE(wheelchair_type, 'Unknown') as wheelchair_type from izmit.users")
        raw_data = DataFrame(ps_cursor.fetchall())
        if(raw_data.size < 1):
            exit()
        raw_data.columns = [x.name for x in ps_cursor.description]

    ps_cursor.close()

    # Use this method to release the connection object and send back to connection pool
    postgreSQL_pool.putconn(ps_connection)
    print("Put away a PostgreSQL connection")

    # mark zero values as missing or NaN
    #raw_data = raw_data.replace(0, np.NaN)
    # drop rows with missing values
    #raw_data.dropna(inplace=True)
    # summarize the number of rows and columns in the dataset
    print("Loaded data: ")
    print(raw_data.shape)
    if(raw_data.size < 1):
        exit()


    dirname = os.path.dirname(__file__)
    
    # We need to know how many clusters to make.
    N_CLUSTERS = 2

    # We need to know which features are categorical.
    CATEGORICAL_FEATURES = ['gender', 'wheelchair_type']

    # create a dataframe with all columns to use later for standardizing the data
    column_names_all = ['gender_Female', 'gender_Male', 'gender_Unspecified',
                        'wheelchair_type_Electric',  'wheelchair_type_Manual', 'wheelchair_type_Unknown']
    df = pd.DataFrame(columns=column_names_all)

    # OnehotEncoder will transform categorical features into binary/numerical?
    onehot = OneHotEncoder(dtype=np.int, sparse=True,
                           handle_unknown='ignore', categories='auto')
    transformed = onehot.fit_transform(raw_data[['gender', 'wheelchair_type']])
    column_names = onehot.get_feature_names(['gender', 'wheelchair_type'])

    # Create dataframe using categorical columns of the train data
    train_frame = pd.DataFrame(transformed.toarray(), columns=column_names)

    # Append this data to an empty dataframe with all the columns of all categories
    train_processed = train_frame.T.reindex(column_names_all).T.fillna(0)

    # #re-add the age column to train data
    train_processed['age'] = raw_data.age.values

    # it is common to exclude them from standardization.
    cols_to_standardize = [
        column for column in raw_data.columns
        if column not in CATEGORICAL_FEATURES and column != 'user_id'
    ]

    data_to_standardize = train_processed[cols_to_standardize]
    # Create the scaler.
    scaler = StandardScaler().fit(data_to_standardize)

    # Standardize the data
    standardized_data = train_processed.copy()
    standardized_columns = scaler.transform(data_to_standardize)
    standardized_data[cols_to_standardize] = standardized_columns
    joblib.dump(scaler, os.path.join(dirname, 'Scaler.pkl'))

    model = KMeans(
        n_clusters=N_CLUSTERS, init='k-means++',
        n_init=10, max_iter=300
    ).fit(standardized_data)

    cluster = model.predict(standardized_data)
    standardized_data['user_id'] = raw_data.user_id.values
    standardized_data['cluster_id'] = model.labels_

    print("Results:")
    print(standardized_data)

    joblib.dump(model, os.path.join(dirname, 'KmeansModel.pkl'))
    joblib.dump(standardized_data, os.path.join(dirname, 'standardized_data.pkl'))

    elbow(standardized_data)
    visualize_clusters(standardized_data)

except (Exception, psycopg2.DatabaseError) as error:
    print("Error while connecting to PostgreSQL", error)

finally:
    # closing database connection.
    # use closeall method to close all the active connection if you want to turn of the application
    if (postgreSQL_pool):
        postgreSQL_pool.closeall
    print("PostgreSQL connection pool is closed")