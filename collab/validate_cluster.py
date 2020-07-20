import joblib, os
from sklearn.metrics import silhouette_score, silhouette_samples
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
import matplotlib.cm as cm
import numpy as np


def silhouttePlot(X_std):
    for k in range(2, len(X_std.index)-1) :
        fig, (ax1, ax2) = plt.subplots(1, 2)
        #fig.set_size_inches(18, 7)
        
        # Run the Kmeans algorithm
        km = KMeans(n_clusters=k)
        labels = km.fit_predict(X_std)
        centroids = km.cluster_centers_

        # Get silhouette samples
        silhouette_vals = silhouette_samples(X_std, labels)

        # Silhouette plot
        y_ticks = []
        y_lower, y_upper = 0, 0
        for i, cluster in enumerate(np.unique(labels)):
            cluster_silhouette_vals = silhouette_vals[labels == cluster]
            cluster_silhouette_vals.sort()
            y_upper += len(cluster_silhouette_vals)
            ax1.barh(range(y_lower, y_upper), cluster_silhouette_vals, edgecolor='none', height=1)
            ax1.text(-0.03, (y_lower + y_upper) / 2, str(i + 1))
            y_lower += len(cluster_silhouette_vals)

        # Get the average silhouette score and plot it
        avg_score = np.mean(silhouette_vals)
        ax1.axvline(avg_score, linestyle='--', linewidth=2, color='green')
        ax1.set_yticks([])
        # ax1.set_xlim([-0.1, 1])
        ax1.set_xlabel('Silhouette coefficient values ')
        ax1.set_ylabel(f'Cluster labels k = {k}')
        ax1.set_title(f'Silhouette plot for k = {k}', y=1.02);
        
        # Scatter plot of data colored with labels
        ax2.scatter(X_std.iloc[:, 3], X_std.iloc[:, 6], c=labels)
        ax2.scatter(centroids[:, 3], centroids[:, 6], marker='*', c='r', s=50)
        # ax2.set_xlim([-2, 2])
        # ax2.set_xlim([-2, 2])
        ax2.set_xlabel('Wh-Electric')
        ax2.set_ylabel('Age')
        ax2.set_title('Visualization of clustered data', y=1.02)
        ax2.set_aspect('equal')
        plt.tight_layout()
        plt.suptitle(f'Silhouette analysis using k = {k}',
                    fontsize=16, fontweight='semibold', y=1.05);


def main():
    dirname = os.path.dirname(__file__)
    clusterData = joblib.load(os.path.join(dirname, 'standardized_data.pkl'))
    print(clusterData)
    loaded_model = joblib.load(os.path.join(dirname, 'KmeansModel.pkl'))
    standardized_data = joblib.load(os.path.join(dirname, 'TrainData.pkl'))
    print(standardized_data)

    score = silhouette_score(standardized_data, loaded_model.labels_, metric='euclidean')
    print(score)
    silhouttePlot(standardized_data)
    plt.show()

    # maxK = 10
    # if(len(standardized_data.index) < maxK):
    #     maxK = len(standardized_data.index)

    # range_n_clusters = range(2, maxK+1)
    # X = standardized_data
    # for n_clusters in range_n_clusters:
    #     # Create a subplot with 1 row and 2 columns
    #     fig, (ax1, ax2) = plt.subplots(1, 2)
    #     fig.set_size_inches(18, 7)

    #     # The 1st subplot is the silhouette plot
    #     # The silhouette coefficient can range from -1, 1 but in this example all
    #     # lie within [-0.1, 1]
    #     ax1.set_xlim([-0.1, 1])
    #     # The (n_clusters+1)*10 is for inserting blank space between silhouette
    #     # plots of individual clusters, to demarcate them clearly.
    #     ax1.set_ylim([0, len(X) + (n_clusters + 1) * 10])

    #     # Initialize the clusterer with n_clusters value and a random generator
    #     # seed of 10 for reproducibility.
    #     clusterer = KMeans(n_clusters=n_clusters, random_state=10)
    #     cluster_labels = clusterer.fit_predict(X)

    #     # The silhouette_score gives the average value for all the samples.
    #     # This gives a perspective into the density and separation of the formed
    #     # clusters
    #     silhouette_avg = silhouette_score(X, cluster_labels)
    #     print("For n_clusters =", n_clusters,
    #         "The average silhouette_score is :", silhouette_avg)

    #     # Compute the silhouette scores for each sample
    #     sample_silhouette_values = silhouette_samples(X, cluster_labels)

    #     y_lower = 10
    #     for i in range(n_clusters):
    #         # Aggregate the silhouette scores for samples belonging to
    #         # cluster i, and sort them
    #         ith_cluster_silhouette_values = \
    #             sample_silhouette_values[cluster_labels == i]

    #         ith_cluster_silhouette_values.sort()

    #         size_cluster_i = ith_cluster_silhouette_values.shape[0]
    #         y_upper = y_lower + size_cluster_i

    #         color = cm.nipy_spectral(float(i) / n_clusters)
    #         ax1.fill_betweenx(np.arange(y_lower, y_upper),
    #                         0, ith_cluster_silhouette_values,
    #                         facecolor=color, edgecolor=color, alpha=0.7)

    #         # Label the silhouette plots with their cluster numbers at the middle
    #         ax1.text(-0.05, y_lower + 0.5 * size_cluster_i, str(i))

    #         # Compute the new y_lower for next plot
    #         y_lower = y_upper + 10  # 10 for the 0 samples

    #     ax1.set_title("The silhouette plot for the various clusters.")
    #     ax1.set_xlabel("The silhouette coefficient values")
    #     ax1.set_ylabel("Cluster label")

    #     # The vertical line for average silhouette score of all the values
    #     ax1.axvline(x=silhouette_avg, color="red", linestyle="--")

    #     ax1.set_yticks([])  # Clear the yaxis labels / ticks
    #     ax1.set_xticks([-0.1, 0, 0.2, 0.4, 0.6, 0.8, 1])

    #     # 2nd Plot showing the actual clusters formed
    #     colors = cm.nipy_spectral(cluster_labels.astype(float) / n_clusters)
    #     ax2.scatter(X.iloc[:, 3], X.iloc[:, 0], marker='.', s=30, lw=0, alpha=0.7,
    #                 c=colors, edgecolor='k')

    #     # Labeling the clusters
    #     centers = clusterer.cluster_centers_
    #     # Draw white circles at cluster centers
    #     ax2.scatter(centers[:, 3], centers[:, 0], marker='o',
    #                 c="white", alpha=1, s=200, edgecolor='k')

    #     for i, c in enumerate(centers):
    #         ax2.scatter(c[0], c[1], marker='$%d$' % i, alpha=1,
    #                     s=50, edgecolor='k')

    #     ax2.set_title("The visualization of the clustered data.")
    #     ax2.set_xlabel("Feature space for the 1st feature")
    #     ax2.set_ylabel("Feature space for the 2nd feature")

    #     plt.suptitle(("Silhouette analysis for KMeans clustering on sample data "
    #                 "with n_clusters = %d" % n_clusters),
    #                 fontsize=14, fontweight='bold')

    # plt.show()

#start process
if __name__ == '__main__':
    main()