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
from matplotlib import pyplot as plt
import seaborn as sns

#Read data from stdin
def read_in():
    lines = sys.stdin.readlines()
    #Since our input would only be having one line, parse our JSON data from that
    return json.loads(lines[0])

def main():
    try:
        dirname = os.path.dirname(__file__)
        
        test_data = pd.read_csv(os.path.join(dirname, 'pg/test_fake_users.csv'),
        usecols=['user_id', 'gender','age','wheelchair_type'])
        if(test_data.size < 1):
            exit()
        

        #test_data = test_data.replace(0, np.NaN)
        # drop rows with missing values
        #test_data.dropna(inplace=True)
        print("Loaded data: ")
        print(test_data.shape)
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

        test_standardized_data['age'] = test_data.age.values
        test_standardized_data['gender'] = test_data.gender.values
        test_standardized_data['wheelchair_type'] = test_data.wheelchair_type.values
        test_standardized_data['user_id'] = test_data.user_id.values
        test_standardized_data['cluster_id'] = test_prediction

        standardized_data = joblib.load(os.path.join(dirname, 'standardized_data.pkl'))
        plt.subplots(1,1)
        sns.scatterplot(x='cluster_id', y='age', style='gender', hue='wheelchair_type', data=standardized_data, palette=sns.color_palette("Set2", 3))
        sns.scatterplot(x='cluster_id', y='age', style='gender', hue='wheelchair_type', data=test_standardized_data, palette=sns.color_palette("Set1", 2), s=70)
        plt.legend(loc='center left', bbox_to_anchor=(1.05, 0.5), borderaxespad=0)
        plt.tight_layout()

        plt.show()
        
        # test_group = standardized_data.query('cluster_id == ' + str(test_prediction))
        # cluster_userids = test_group["user_id"].values.tolist()
        # cluster_userids = cluster_userids + test_data['user_id'].values.tolist()
        
        # print(','.join([str(x) for x in cluster_userids]))
        print(test_standardized_data)

    except (Exception) as error :
        print ("Error ", error)

#start process
if __name__ == '__main__':
    main()