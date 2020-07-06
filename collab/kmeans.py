# Step 1: Import the libraries.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

import pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
import numpy as np
from matplotlib import pyplot as plt

import psycopg2
from psycopg2 import pool
from pandas import DataFrame

# Step 2: Set up the constants.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# We need to know how many clusters to make.
N_CLUSTERS = 2

# We need to know which features are categorical.
CATEGORICAL_FEATURES = ['gender', 'wheelchair_type']

column_names_all = ['gender_Female', 'gender_Male', 'wheelchair_type_Electric',  'wheelchair_type_Manual', 'age']
df = pd.DataFrame(columns = column_names_all)  


# Step 3: Load in the raw data.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

try:
    postgreSQL_pool = psycopg2.pool.SimpleConnectionPool(1, 20,user = "wheelchair_routing",
                                              password = "em6Wgu<S;^J*xP?g%.",
                                              host = "127.0.0.1",
                                              port = "5432",
                                              database = "wheelchair_routing")
    if(postgreSQL_pool):
        print("Connection pool created successfully")

    # Use getconn() to Get Connection from connection pool
    ps_connection  = postgreSQL_pool.getconn()

    if(ps_connection):
        print("successfully recived connection from connection pool ")
        ps_cursor = ps_connection.cursor()
        ps_cursor.execute("select user_id, gender, age, wheelchair_type from izmit.users where is_deleted = false and gender != 'Unspecified' and wheelchair_type is not null and wheelchair_type != 'Unspecified' and age > 0")
        raw_data = DataFrame(ps_cursor.fetchall())
        raw_data.columns=[ x.name for x in ps_cursor.description ]

        # print ("Displaying rows from izmit.users table")
        # print(mobile_records.shape)
        # print(mobile_records.sample(5))
        # for row in mobile_records:
        #     print (row)

        ps_cursor.close()

        #Use this method to release the connection object and send back to connection pool
        postgreSQL_pool.putconn(ps_connection)
        print("Put away a PostgreSQL connection")

        # This assumes the data is in the same directory as this script.
        # Here we load the data into a pandas DataFrame.
        # raw_data = pd.read_csv('~/Documents/Thesis/wheelchair_router/collab/pg/users.csv',
        # usecols=['user_id', 'gender','age','wheelchair_type'])

        # It's helpful to take a quick look at the data.
        print('Sample of loaded data:')

        # mark zero values as missing or NaN
        raw_data = raw_data.replace(0, np.NaN)
        # drop rows with missing values
        raw_data.dropna(inplace=True)
        # summarize the number of rows and columns in the dataset
        print(raw_data.shape)
        print(raw_data.sample(5))

        # Plot the data
        plt.figure(figsize=(6, 6))
        #plt.scatter(raw_data.iloc[:, 0], raw_data.iloc[:, 3]) #age vs wtype

        # Step 4: Set up the data.
        # ~~~~~~~~~~~~~~~~~~~~~~~~

        # Turn categorical variables into dummy columns (0 or 1 values).
        # Do this to avoid assuming a meaningful order of categories.
        # Use drop_first to avoid multicollinearity among features.
        unstandardized_data = pd.get_dummies(
            raw_data,
            columns=CATEGORICAL_FEATURES,
            drop_first=False
        )

        unstandardized_data = unstandardized_data.T.reindex(column_names_all).T.fillna(0)

        # Since the dummy columns already have values of 0 or 1,
        # it is common to exclude them from standardization.
        cols_to_standardize = [
          column for column in raw_data.columns
            if column not in CATEGORICAL_FEATURES and column != 'user_id'
        ]

        data_to_standardize = unstandardized_data[cols_to_standardize]
        # Create the scaler.
        scaler = StandardScaler().fit(data_to_standardize)

        # Standardize the data
        standardized_data = unstandardized_data.copy()
        standardized_columns = scaler.transform(data_to_standardize)
        standardized_data[cols_to_standardize] = standardized_columns

        # It's helpful to double check that the final data looks good.
        print('Sample of data to use:')
        print(standardized_data.sample(5))
        print('')
        print(standardized_data.shape)

        # Step 5: Fit the model.
        # ~~~~~~~~~~~~~~~~~~~~~~

        #kmeans = KMeans(n_clusters=2)
        #kmeans.fit(standardized_data)
        #y_kmeans = kmeans.predict(standardized_data)

        model = KMeans(n_clusters=N_CLUSTERS).fit(standardized_data)


        # Step 6: Get the results.
        # ~~~~~~~~~~~~~~~~~~~~~~~~

        # It's helpful to see the results on the unstandardized data.
        # The output of model.predict() is an integer representing
        # the cluster that each data point is classified with.
        unstandardized_data['cluster'] = model.predict(standardized_data)

        # It's helpful to take a quick look at the count and
        # average value values per cluster.

        #print('Cluster summary:')
        #summary = unstandardized_data.groupby(['cluster']).mean()
        #summary['count'] = unstandardized_data['cluster'].value_counts()
        #summary = summary.sort_values(by='count', ascending=False)
        #print(summary)
        print(model.cluster_centers_)

        plt.scatter(standardized_data.iloc[:,2], standardized_data.iloc[:, 4], c=unstandardized_data['cluster'], s=50, cmap='viridis')

        centers = model.cluster_centers_
        plt.scatter(centers[:, 2], centers[:,4], c='black', s=200, alpha=0.1);

        test_data = pd.read_csv('~/Documents/Thesis/wheelchair_router/collab/pg/user_test.csv',
        usecols=['gender','age','wheelchair_type'])

        # It's helpful to take a quick look at the data.
        print('Sample of loaded data:')

        # mark zero values as missing or NaN
        test_data = test_data.replace(0, np.NaN)
        # drop rows with missing values
        test_data.dropna(inplace=True)
        # summarize the number of rows and columns in the dataset
        print(test_data.shape)
        print(test_data)

        test_unstandardized_data = pd.get_dummies(
            test_data,
            columns=CATEGORICAL_FEATURES,
            drop_first=False
        )
        test_unstandardized_data = test_unstandardized_data.T.reindex(column_names_all).T.fillna(0)

        # Since the dummy columns already have values of 0 or 1,
        # it is common to exclude them from standardization.
        test_cols_to_standardize = [
          column for column in test_data.columns
            if column not in CATEGORICAL_FEATURES
        ]
        test_data_to_standardize = test_unstandardized_data[test_cols_to_standardize]

        # Create the scaler.
        #scaler = StandardScaler().fit(test_data_to_standardize)

        # Standardize the data
        test_standardized_data = test_unstandardized_data.copy()
        test_standardized_columns = scaler.transform(test_data_to_standardize)
        test_standardized_data[test_cols_to_standardize] = test_standardized_columns

        # It's helpful to double check that the final data looks good.
        print('Sample of data to use:')
        print(test_standardized_data)
        print('')
        print(test_standardized_data.shape)

        test_unstandardized_data['cluster'] = model.predict(test_standardized_data)
        plt.scatter(test_standardized_data.iloc[:,2], test_standardized_data.iloc[:, 4], s=50, c='green')

        summary = unstandardized_data.groupby(['cluster']).mean()
        summary['count'] = unstandardized_data['cluster'].value_counts()
        summary = summary.sort_values(by='count', ascending=False)
        print(summary)

        #print('Cluster summary:')
        summary = test_unstandardized_data.groupby(['cluster']).mean()
        summary['count'] = test_unstandardized_data['cluster'].value_counts()
        summary = summary.sort_values(by='count', ascending=False)
        print(summary)

        print(centers)

        plt.show()

except (Exception, psycopg2.DatabaseError) as error :
    print ("Error while connecting to PostgreSQL", error)

finally:
    #closing database connection.
    # use closeall method to close all the active connection if you want to turn of the application
    if (postgreSQL_pool):
        postgreSQL_pool.closeall
    print("PostgreSQL connection pool is closed")
