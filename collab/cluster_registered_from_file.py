import joblib
import os
import numpy as np
import pandas as pd
import psycopg2, sklearn
from pandas import DataFrame
from psycopg2 import pool
from sklearn.cluster import KMeans
from sklearn.preprocessing import LabelEncoder, OneHotEncoder, StandardScaler
from sklearn_pandas import DataFrameMapper
from matplotlib import pyplot as plt
from sklearn.metrics import silhouette_score
import seaborn as sns
from mpl_toolkits import mplot3d

def elbow(standardized_data):
    #ELBOW METHOD
    # calculate distortion for a range of number of cluster
    maxK = 20
    if(len(standardized_data.index) < maxK):
        maxK = len(standardized_data.index)
    sse = []
    k = range(1, maxK-1)
    for i in k:
        km = KMeans(
            n_clusters=i, init='k-means++',
            n_init=10, max_iter=300
        )
        km.fit(standardized_data)
        sse.append(km.inertia_)

    # plot
    elbowPlot = plt.figure(1)
    plt.plot(k, sse, marker='o')
    plt.xlabel('Number of clusters, K')
    plt.ylabel('SSE')

    #plt.show()
    dirname = os.path.dirname(__file__)
    elbowPlot.savefig(os.path.join(dirname, 'elbow.png'))
    plt.close(elbowPlot)

    # get the list of tuples from two lists.  
    # and merge them by using zip().  
    list_of_tuples = list(zip(k, sse))
    # Converting lists of tuples into  
    # pandas Dataframe.  
    df = pd.DataFrame(list_of_tuples, columns = ['K', 'SSE'])  
        
    # Print data. 
    print("Elbow values") 
    print(df)  

def getOptimalKSilhoutteCoeff(standardized_data):
    maxScore = -1
    optimalK = 1
    maxK = 20
    if(len(standardized_data.index) < maxK):
        maxK = len(standardized_data.index)
    
    k = range(2, maxK-1)
    for i in k:
        km = KMeans(
            n_clusters=i, init='k-means++',
            n_init=10, max_iter=300
        )
        labels = km.fit_predict(standardized_data)
        silhouette_avg = silhouette_score(standardized_data, labels)
        print("For n_clusters =", i,
            "The average silhouette_score is :", silhouette_avg)
        if(silhouette_avg > maxScore):
            maxScore = silhouette_avg
            optimalK = i
    return optimalK

def visualize_clusters():
    dirname = os.path.dirname(__file__)
    standardized_data = joblib.load(os.path.join(dirname, 'TrainData_file.pkl'))

    clusterPlot = plt.figure(2, figsize=(6, 6))
    plt.scatter(standardized_data.iloc[:, 3], standardized_data.iloc[:, 0], c=cluster, s=10, cmap='viridis')

    loaded_model = joblib.load(os.path.join(dirname, 'KmeansModel_file.pkl'))
    centers = loaded_model.cluster_centers_
    plt.scatter(centers[:, 3], centers[:, 0], c='grey', s=200, alpha=0.1)

    plt.xlabel(standardized_data.columns[3])
    plt.ylabel(standardized_data.columns[0])
    #plt.show()
    
    clusterPlot.savefig(os.path.join(dirname, 'cluster.png'))
    plt.close(clusterPlot)

try:
    print("Python on duty!")

    print('The scikit-learn version is {}.'.format(sklearn.__version__))

    dirname = os.path.dirname(__file__)

    raw_data = pd.read_csv(os.path.join(dirname, 'pg/fake_users.csv'),
    usecols=['user_id', 'gender','age','wheelchair_type'])
    if(raw_data.size < 1):
        exit()

    # mark zero values as missing or NaN
    #raw_data = raw_data.replace(0, np.NaN)
    # drop rows with missing values
    #raw_data.dropna(inplace=True)
    # summarize the number of rows and columns in the dataset
    print("Loaded data: ")
    print(raw_data.shape)
    if(raw_data.size < 1):
        exit()

    # We need to know which features are categorical.
    CATEGORICAL_FEATURES = ['gender', 'wheelchair_type']

    # create a dataframe with all columns to use later for standardizing the data
    column_names_all = ['gender_Female', 'gender_Male', 'gender_Unspecified',
                        'wheelchair_type_Electric',  'wheelchair_type_Manual', 'wheelchair_type_Unspecified']
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
    joblib.dump(scaler, os.path.join(dirname, 'Scaler_file.pkl'))

    
    # We need to know how many clusters to make.
    N_CLUSTERS = getOptimalKSilhoutteCoeff(standardized_data)
    elbow(standardized_data)
    print("Cluster with k=" + str(N_CLUSTERS))

    model = KMeans(
        n_clusters=N_CLUSTERS, init='k-means++',
        n_init=10, max_iter=300
    ).fit(standardized_data)

    cluster = model.predict(standardized_data)
    joblib.dump(standardized_data, os.path.join(dirname, 'TrainData_file.pkl'))

    standardized_data['raw_age'] = raw_data.age.values
    standardized_data['gender'] = raw_data.gender.values
    standardized_data['wheelchair_type'] = raw_data.wheelchair_type.values
    standardized_data['user_id'] = raw_data.user_id.values
    standardized_data['cluster_id'] = model.labels_

    print("Results:")
    print(standardized_data)

    joblib.dump(model, os.path.join(dirname, 'KmeansModel_file.pkl'))
    joblib.dump(standardized_data, os.path.join(dirname, 'standardized_data_file.pkl'))

    visualize_clusters()
    #raw_data.groupby('gender')['gender'].nunique().plot(kind='bar', x='gender', y='age')
    # bar = plt.subplots(1,1)
    # ax1 = raw_data.groupby(['gender','wheelchair_type']).size().unstack().plot(kind='bar',stacked=False)
    # ax1.set_xlabel("Gender")
    # ax1.set_ylabel("Frequency")
    # bar2, ax2  = plt.subplots(1,1)
    # ax2.set_xlim([0, 90])
    # ax2.set_xlabel("Age")
    # ax2.set_ylabel("Frequency")
    # bar2 = raw_data.groupby('gender').age.plot(kind='kde')
    # plt.subplots(1,1)
    # sns.set_style('whitegrid')
    # sns.countplot(x='wheelchair_type', hue='gender', data=raw_data, palette='husl')
    # #plt.subplots(1,1)
    # sns.catplot(x='wheelchair_type', y='age', data=raw_data, palette='husl')
    # sns.catplot(x='gender', y='age', data=raw_data, palette='husl')
    # sns.catplot(x='gender', y='age', hue='cluster_id', data=standardized_data, palette='husl')
    # sns.catplot(x='wheelchair_type', y='age', hue='cluster_id', data=standardized_data, palette='husl')
    # #plt.subplots(1,1)
    # sns.scatterplot(x='wheelchair_type', y='age', style='gender', hue='cluster_id', data=standardized_data, palette='Set2', legend=False)

    # Data for three-dimensional scattered points
    # plt.subplots(1,1)
    # ax = plt.axes(projection='3d')
    # zdata = raw_data('gender')
    # xdata = raw_data('wheelchair_type')
    # ydata = raw_data('age')
    # ax.scatter3D(xdata, ydata, zdata, c=zdata, cmap='viridis');
    #ax.scatter(centers[:, 3], centers[:, 0], c='grey', s=200, alpha=0.1);

    # plt.legend(loc='upper left')

    sns.set_style('whitegrid')
    sns.countplot(x='wheelchair_type', hue='gender', data=raw_data, palette='husl')
    sns.catplot(x='wheelchair_type', y='age', data=raw_data, palette='husl')
    sns.catplot(x='gender', y='age', data=raw_data, palette='husl')
    sns.catplot(x='gender', y='age', hue='cluster_id', data=standardized_data, palette='husl')
    sns.catplot(x='wheelchair_type', y='age', hue='cluster_id', data=standardized_data, palette='husl')

    plt.subplots(1,1)
    sns.countplot(x='cluster_id', hue='gender', data=standardized_data, palette='husl')
    plt.subplots(1,1)
    sns.countplot(x='cluster_id', hue='wheelchair_type', data=standardized_data, palette='husl')
    
    plt.subplots(1,1)
    g = sns.scatterplot(x='cluster_id', y='age', style='gender', hue='wheelchair_type', data=standardized_data, palette='Set2')
    
    centers = model.cluster_centers_
    cluster_ids = np.unique(model.labels_)
    plt.scatter( cluster_ids, centers[:, 6], c='grey', s=200, alpha=0.2)

    plt.legend(loc='center left', bbox_to_anchor=(1.05, 0.5), borderaxespad=0)
    plt.tight_layout()

    plt.subplots(1,1)
    sns.scatterplot(x='cluster_id', y='raw_age', style='gender', hue='wheelchair_type', data=standardized_data, palette='Set2')
    plt.legend(loc='center left', bbox_to_anchor=(1.05, 0.5), borderaxespad=0)
    plt.tight_layout()

    plt.show()

except (Exception) as error:
    print("Error ", error)
