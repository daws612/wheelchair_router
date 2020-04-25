import pandas as pd
from surprise import Dataset, Reader, accuracy
from surprise import get_dataset_dir, dump
from surprise.model_selection import train_test_split
from surprise import KNNBasic, KNNWithMeans, KNNBaseline, KNNWithZScore

user = pd.read_csv('~/Documents/Thesis/wheelchair_router/collab/pg/users.csv',
                   usecols=['user_id', 'gender', 'age', 'wheelchair_type'],
                   sep=',', error_bad_lines=False, encoding="latin-1")
user.columns = ['user_id', 'gender', 'age', 'wheelchair_type']
rating = pd.read_csv('~/Documents/Thesis/wheelchair_router/collab/pg/route_ratings.csv',
                     usecols=['route_id', 'user_id', 'rating'],
                     sep=',', error_bad_lines=False, encoding="latin-1")
rating.columns = ['route_id', 'user_id', 'rating']
df = pd.merge(user, rating, on='user_id', how='inner')
#df.drop(['user_id', 'Age'], axis=1, inplace=True)
df.head()

reader = Reader(rating_scale=(0, 5))
data = Dataset.load_from_df(df[['user_id', 'route_id', 'rating']], reader)

train, test = train_test_split(data, test_size=.2)

sim_options = {'name': 'msd',
               'min_support': 5,
               'user_based': True}
base1 = KNNBaseline(k=30,sim_options=sim_options)

base1.fit(train)
base1_preds = base1.test(test)
accuracy.rmse(base1_preds)

sim_options1 = {'name': 'cosine',
               'min_support': 5,
               'user_based': True}
base13 = KNNBaseline(k=2,sim_options=sim_options1)


base13.fit(train)
base13_preds = base13.test(test)
acc = accuracy.rmse(base13_preds)


dump.dump('KNNFinal_Model',algo=base13,predictions=base13_preds)