import pandas as pd
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.cluster import KMeans
import numpy as np
from sklearn_pandas import DataFrameMapper
import pickle
from sklearn.preprocessing import OneHotEncoder
from matplotlib import pyplot as plt
import joblib
import sys, json

#Read data from stdin
def read_in():
    lines = sys.stdin.readlines()
    #Since our input would only be having one line, parse our JSON data from that
    return json.loads(lines[0])

def main():
    #get our data as an array from read_in()
    #lines = read_in()
    
    # We need to know how many clusters to make.
    N_CLUSTERS = 2

    # We need to know which features are categorical.
    CATEGORICAL_FEATURES = ['gender', 'wheelchair_type']

    column_names_all = ['gender_Female', 'gender_Male', 'wheelchair_type_Electric',  'wheelchair_type_Manual']

    onehot = OneHotEncoder(dtype=np.int, sparse=True, handle_unknown='ignore', categories='auto')

    test_data = pd.read_csv('~/Documents/Thesis/wheelchair_router/collab/pg/user_test.csv',
    usecols=['user_id', 'gender','age','wheelchair_type'])
    # mark zero values as missing or NaN
    test_data = test_data.replace(0, np.NaN)
    # drop rows with missing values
    test_data.dropna(inplace=True)
    # summarize the number of rows and columns in the dataset
    #print(test_data.shape)
    #print(test_data)

    ### Later, in another file
    # mapper_fit = pickle.load(open('fitted_mapper.pkl', 'rb'))
    # test_processed = mapper.transform(test_data)
    test_frame = onehot.fit_transform(test_data[['gender', 'wheelchair_type']])
    column_names = onehot.get_feature_names(['gender', 'wheelchair_type'])
    test_frame = pd.DataFrame(
        test_frame.toarray(),
        columns=column_names)
    test_processed = test_frame.T.reindex(column_names_all).T.fillna(0)
    test_processed['age'] = test_data.age.values

    test_cols_to_standardize = [
    column for column in test_data.columns
        if column not in CATEGORICAL_FEATURES and column != 'user_id'
    ]
    test_data_to_standardize = test_processed[test_cols_to_standardize]

    # Create the scaler.
    #scaler = StandardScaler().fit(test_data_to_standardize)

    loaded_scaler = joblib.load("Scaler.pkl")
    # Standardize the data
    test_standardized_data = test_processed.copy()
    test_standardized_columns = loaded_scaler.transform(test_data_to_standardize)
    test_standardized_data[test_cols_to_standardize] = test_standardized_columns

    # It's helpful to double check that the final data looks good.
    # print('Sample of data to use:')
    # print(test_standardized_data)
    # print('')
    # print(test_standardized_data.shape)

    # print(test_processed)
    loaded_model = joblib.load("KmeansModel.pkl")
    test_prediction = loaded_model.predict(test_standardized_data)
    #print(loaded_model.cluster_centers_)

    test_standardized_data['user_id'] = test_data.user_id.values
    test_standardized_data['cluster_id'] = test_prediction

    #print(test_standardized_data)

    standardized_data = joblib.load("standardized_data.pkl")
    test_group = standardized_data.query('cluster_id == ' + str(test_prediction))
    cluster_userids = test_group["user_id"].values.tolist()
    #print(', '.join(str(cluster_userids)))
    print(','.join([str(x) for x in cluster_userids]))
    #for entry in test_group["user_id"].values:
        #print(entry)

    #get rating data of all users in our cluster
    ratings_data = pd.read_csv('~/Documents/Thesis/wheelchair_router/collab/pg/route_ratings.csv')
    #Average of routes for each user
    Mean = ratings_data.groupby(by=["user_id", "route_id"],as_index=False)['rating'].mean()
    df_inner = pd.merge(test_group, Mean, on='user_id', how='inner')
    #print(df_inner)
    #average of routes regardless of user
    Route_Mean = df_inner.groupby(by=["route_id"],as_index=False)['rating'].mean()
    #print(Route_Mean)

#start process
if __name__ == '__main__':
    main()