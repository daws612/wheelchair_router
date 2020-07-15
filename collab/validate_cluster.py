import joblib, os
from sklearn.metrics import silhouette_score

def main():
    dirname = os.path.dirname(__file__)
    loaded_model = joblib.load(os.path.join(dirname, 'KmeansModel.pkl'))
    standardized_data = joblib.load(os.path.join(dirname, 'TrainData.pkl'))

    score = silhouette_score(standardized_data, loaded_model.labels_, metric='euclidean')
    print(score)

#start process
if __name__ == '__main__':
    main()