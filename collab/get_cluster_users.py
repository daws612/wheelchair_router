import pandas as pd
import numpy as np
import joblib, os
import sys, json
import psycopg2
from psycopg2 import pool
from pandas import DataFrame
from sklearn_pandas import DataFrameMapper
from sklearn.preprocessing import OneHotEncoder
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.cluster import KMeans

#Read data from stdin
def read_in():
    lines = sys.stdin.readlines()
    #Since our input would only be having one line, parse our JSON data from that
    return json.loads(lines[0])

def main():
    try:
        postgreSQL_pool = psycopg2.pool.SimpleConnectionPool(1, 20,user = "wheelchair_routing",
                                                password = "em6Wgu<S;^J*xP?g%.",
                                                host = "localhost",
                                                port = "5432",
                                                database = "wheelchair_routing")
        #if(postgreSQL_pool):
            #print("Connection pool created successfully")
        
        # Use getconn() to Get Connection from connection pool
        ps_connection  = postgreSQL_pool.getconn()

        if(ps_connection):
            ids = read_in() #"2DFDoUKhDcZ5msfoLf2fPggYL1j1"
            #print("successfully recived connection from connection pool ")
            ps_cursor = ps_connection.cursor()
            ps_cursor.execute("select user_id, gender, age, wheelchair_type from izmit.users where firebase_id = '" + ids+ "'")
            test_data = DataFrame(ps_cursor.fetchall())
            if(test_data.size < 1):
                exit()
            test_data.columns=[ x.name for x in ps_cursor.description ]
        
        ps_cursor.close()

        #Use this method to release the connection object and send back to connection pool
        postgreSQL_pool.putconn(ps_connection)
        #print("Put away a PostgreSQL connection")

        dirname = os.path.dirname(__file__)

        #test_data = test_data.replace(0, np.NaN)
        # drop rows with missing values
        #test_data.dropna(inplace=True)
        #print("Loaded data: ")
        #print(test_data.shape)
        #print(test_data.sample(1))
        if(test_data.size < 1):
            return

        # We need to know which features are categorical.
        CATEGORICAL_FEATURES = ['gender', 'wheelchair_type']

        column_names_all = ['gender_Female', 'gender_Male', 'gender_Unspecified',
                            'wheelchair_type_Electric',  'wheelchair_type_Manual', 'wheelchair_type_Unknown']

        onehot = OneHotEncoder(dtype=np.int, sparse=True, handle_unknown='ignore', categories='auto')

        #OnehotEncoder will transform categorical features into binary/numerical? 
        test_frame = onehot.fit_transform(test_data[['gender', 'wheelchair_type']])
        column_names = onehot.get_feature_names(['gender', 'wheelchair_type'])

        #Create dataframe using categorical columns of the test data
        test_frame = pd.DataFrame(test_frame.toarray(), columns=column_names)

        #Append this data to an empty dataframe with all the columns of all categories
        test_processed = test_frame.T.reindex(column_names_all).T.fillna(0)

        #re-add the age column to test data
        test_processed['age'] = test_data.age.values

        test_cols_to_standardize = [
        column for column in test_data.columns
            if column not in CATEGORICAL_FEATURES and column != 'user_id'
        ]
        test_data_to_standardize = test_processed[test_cols_to_standardize]
        
        loaded_scaler = joblib.load(os.path.join(dirname, 'Scaler.pkl'))
        # Standardize the data
        test_standardized_data = test_processed.copy()
        test_standardized_columns = loaded_scaler.transform(test_data_to_standardize)
        test_standardized_data[test_cols_to_standardize] = test_standardized_columns

        loaded_model = joblib.load(os.path.join(dirname, 'KmeansModel.pkl'))
        test_prediction = loaded_model.predict(test_standardized_data)

        test_standardized_data['user_id'] = test_data.user_id.values
        test_standardized_data['cluster_id'] = test_prediction

        standardized_data = joblib.load(os.path.join(dirname, 'standardized_data.pkl'))
        
        test_group = standardized_data.query('cluster_id == ' + str(test_prediction))
        cluster_userids = test_group["user_id"].values.tolist()
        
        print(','.join([str(x) for x in cluster_userids]))

    except (Exception, psycopg2.DatabaseError) as error :
        print ("Error while connecting to PostgreSQL", error)

    finally:
        #closing database connection.
        # use closeall method to close all the active connection if you want to turn of the application
        if (postgreSQL_pool):
            postgreSQL_pool.closeall
        #print("PostgreSQL connection pool is closed")

#start process
if __name__ == '__main__':
    main()