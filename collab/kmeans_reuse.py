import pandas as pd
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.cluster import KMeans
import numpy as np
from sklearn_pandas import DataFrameMapper
import pickle
from sklearn.preprocessing import OneHotEncoder
from matplotlib import pyplot as plt
import joblib

# We need to know how many clusters to make.
N_CLUSTERS = 2

# We need to know which features are categorical.
CATEGORICAL_FEATURES = ['gender', 'wheelchair_type']

#create a dataframe with all columns to use later for standardizing the data
column_names_all = ['gender_Female', 'gender_Male', 'wheelchair_type_Electric',  'wheelchair_type_Manual']
df = pd.DataFrame(columns = column_names_all)  

raw_data = pd.read_csv('~/Documents/Thesis/wheelchair_router/collab/pg/users.csv',
usecols=['user_id', 'gender','age','wheelchair_type'])

# mark zero values as missing or NaN
raw_data = raw_data.replace(0, np.NaN)
# drop rows with missing values
raw_data.dropna(inplace=True)

# summarize the number of rows and columns in the dataset
print(raw_data.shape)
print(raw_data)

#OnehotEncoder will transform categorical features into binary/numerical? 
onehot = OneHotEncoder(dtype=np.int, sparse=True, handle_unknown='ignore', categories='auto')
transformed = onehot.fit_transform(raw_data[['gender', 'wheelchair_type']])
column_names = onehot.get_feature_names(['gender', 'wheelchair_type'])

#Create dataframe using categorical columns of the train data
train_frame = pd.DataFrame(
    transformed.toarray(),
    columns=column_names)

#Append this data to an empty dataframe with all the columns of all categories
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
standardized_data[cols_to_standardize] = data_to_standardize #standardized_columns

# It's helpful to double check that the final data looks good.
# print('Sample of data to use:')
# print(standardized_data)
# print('')
# print(standardized_data.shape)

#Save for later
# pickle.dump(mapper_fit, open('fitted_mapper.pkl', 'wb'))
#print(train_processed)


#model = KMeans(n_clusters=N_CLUSTERS).fit(standardized_data)
model = KMeans(
        n_clusters=2, init='random',
        n_init=10, max_iter=300,
        tol=1e-04, random_state=0
    ).fit(standardized_data)
cluster = model.predict(standardized_data)
print(model.labels_)
standardized_data['user_id'] = raw_data.user_id.values
standardized_data['cluster_id'] = model.labels_

print("Results:")
print(standardized_data)

joblib.dump(model, "KmeansModel.pkl");

test_data = pd.read_csv('~/Documents/Thesis/wheelchair_router/collab/pg/user_test.csv',
usecols=['user_id', 'gender','age','wheelchair_type'])
# mark zero values as missing or NaN
test_data = test_data.replace(0, np.NaN)
# drop rows with missing values
test_data.dropna(inplace=True)
# summarize the number of rows and columns in the dataset
print(test_data.shape)
print(test_data)

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

# Standardize the data
test_standardized_data = test_processed.copy()
test_standardized_columns = scaler.transform(test_data_to_standardize)
test_standardized_data[test_cols_to_standardize] = test_data_to_standardize #test_standardized_columns

# It's helpful to double check that the final data looks good.
# print('Sample of data to use:')
# print(test_standardized_data)
# print('')
# print(test_standardized_data.shape)

# print(test_processed)
loaded_model = joblib.load("KmeansModel.pkl")
test_prediction = loaded_model.predict(test_standardized_data)
print(loaded_model.cluster_centers_)

test_standardized_data['user_id'] = test_data.user_id.values
test_standardized_data['cluster_id'] = test_prediction

print(test_standardized_data)

test_group = standardized_data.query('cluster_id == ' + str(test_prediction))
print(test_group)

#get rating data of all users in our cluster
ratings_data = pd.read_csv('~/Documents/Thesis/wheelchair_router/collab/pg/route_ratings.csv')
#Average of routes for each user
Mean = ratings_data.groupby(by=["user_id", "route_id"],as_index=False)['rating'].mean()
df_inner = pd.merge(test_group, Mean, on='user_id', how='inner')
print(df_inner)
#average of routes regardless of user
Route_Mean = df_inner.groupby(by=["route_id"],as_index=False)['rating'].mean()
print(Route_Mean)

clusterPlot = plt.figure(1, figsize=(6, 6))
plt.scatter(standardized_data.iloc[:, 4], standardized_data.iloc[:, 2], c=cluster, s=10, cmap='viridis')
plt.scatter(test_standardized_data.iloc[:, 4], test_standardized_data.iloc[:, 2], c='green', s=100)

centers = loaded_model.cluster_centers_
plt.scatter(centers[:, 4], centers[:, 2], c='grey', s=200, alpha=0.1);

plt.xlabel(standardized_data.columns[4])
plt.ylabel(standardized_data.columns[2])
#plt.show()

#ELBOW METHOD
# calculate distortion for a range of number of cluster
elbowPlot = plt.figure(2);
distortions = []
for i in range(1, 6):
    km = KMeans(
        n_clusters=i, init='random',
        n_init=10, max_iter=300,
        tol=1e-04, random_state=0
    )
    km.fit(standardized_data)
    distortions.append(km.inertia_)

# plot
plt.plot(range(1, 6), distortions, marker='o')
plt.xlabel('Number of clusters')
plt.ylabel('Distortion')

plt.show()