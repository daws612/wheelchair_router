import csv
import re
import os
import statistics
import pandas as pd
import numpy as np
import psycopg2, sklearn, joblib
from pandas import DataFrame
from psycopg2 import pool
import seaborn as sns
from matplotlib import pyplot as plt

def append_to_file(row, fileName):
    with open(fileName, "a") as wekafile:
        writer = csv.writer(wekafile, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
        writer.writerow(row)

def getRatingPerClusterForRoute(fileName, testRoute):
    standardized_data = joblib.load(os.path.join(dirname, 'standardized_data.pkl'))
    cluster_ids = np.unique(standardized_data.cluster_id)
    print("Clusters found: " + str(cluster_ids))
    try:
        
    
        postgreSQL_pool = psycopg2.pool.SimpleConnectionPool(1, 50, user="wheelchair_routing",
                                                            password="em6Wgu<S;^J*xP?g%.",
                                                            host="api.jaywjay.com",
                                                            port="5432",
                                                            database="wheelchair_routing")
        if(not postgreSQL_pool):
            print("Connection pool NOT created successfully")
        # Use getconn() to Get Connection from connection pool
        ps_connection = postgreSQL_pool.getconn()

        for clusterId in cluster_ids:
            clusterUsers = standardized_data.query('cluster_id == ' + str(clusterId))
            clusterUserIds = ','.join([str(x) for x in clusterUsers['user_id'].values.tolist()])
            print(str(clusterId) + " cluster has users: " + clusterUserIds)

            
            if(ps_connection):
                #print("successfully received connection from connection pool ")
                ps_cursor = ps_connection.cursor()


                sql = '''SELECT distinct(r.route_name), coalesce(round(avg(rating),2),0) as rating
                    FROM izmit.route_ratings rr
                    LEFT JOIN izmit.routes r on r.route_id = rr.route_id
                    where route_name like '%bus-%' and rr.user_id in ({clusterUserIds})
                    group by r.route_name
                    order by r.route_name'''.format(clusterUserIds = clusterUserIds)

                sql = ''' select (select route_name from izmit.routes where route_id=busname::bigint), * from			
                        (SELECT split_part(route_sections, ',', 1) as busname, coalesce(round(avg(rating),2),0) as rating, 
                        concat(rr.orig_lat, ',', rr.orig_lon) as origin,
                        concat(rr.dest_lat, ',', rr.dest_lon) as destination,
                        
                        ST_DistanceSphere(st_point({origlon},{origlat}), st_point(rr.orig_lon, rr.orig_lat)) as orig_dist_m,
                        ST_DistanceSphere(st_point({destlon},{destlat}), st_point(rr.dest_lon, rr.dest_lat)) as dest_dist_m,
                        max(coalesce(round(avg(rating),2),0)) over (partition by split_part(route_sections, ',', 1)) as max_rating
                        FROM izmit.route_ratings rr 
                        where 
                        ST_DistanceSphere(st_point({origlon},{origlat}), st_point(rr.orig_lon, rr.orig_lat)) < 100 and
                        ST_DistanceSphere(st_point({destlon},{destlat}), st_point(rr.dest_lon, rr.dest_lat)) < 100
                        and rr.user_id in ({clusterUserIds})
                        GROUP BY  rr.orig_lon, rr.orig_lat, rr.dest_lon, rr.dest_lat, busname
                        order by busname, rating desc) busratings 
                        WHERE rating = max_rating '''.format(clusterUserIds = clusterUserIds, 
                        origlon=testRoute[2], origlat=testRoute[1],
                        destlon=testRoute[4], destlat=testRoute[3])
                ps_cursor.execute(sql)
                raw_data = DataFrame(ps_cursor.fetchall())
                ps_cursor.close()
                if(raw_data.size < 1):
                    print("No data found")
                    continue
                raw_data.columns = [x.name for x in ps_cursor.description]
                for idx, row in raw_data.iterrows():
                    #print(row)
                    append_to_file([clusterId, clusterUserIds, row.route_name, testRoute[0], row.rating], fileName)


        # Use this method to release the connection object and send back to connection pool
        postgreSQL_pool.putconn(ps_connection)
        print("Put away a PostgreSQL connection")

    except (Exception, psycopg2.DatabaseError) as error:
        print("Error while connecting to PostgreSQL", error)

    finally:
        # closing database connection.
        # use closeall method to close all the active connection if you want to turn of the application
        if (postgreSQL_pool):
            postgreSQL_pool.closeall
        print("PostgreSQL connection pool is closed")

def calculate_ratings(fileName, routesFileName):
    testRoutesData = pd.read_csv(routesFileName)
    if(testRoutesData.size < 1):
        print("No test route data found")
        exit()
    
    append_to_file(['cluster_id', 'user_ids', 'route_name', 'route_desc', 'rating'], fileName)
    for idx, row in testRoutesData.iterrows():
        print("Getting rating for ")
        print(row)
        getRatingPerClusterForRoute(fileName, row)


if __name__ == "__main__" :
    dirname = os.path.dirname(__file__)
    fileName = os.path.join(dirname, 'pg/route_rating_per_cluster.csv')
    routesFileName = os.path.join(dirname, 'pg/test_routes.csv')
    if(os.path.exists(fileName)):
        os.remove(fileName)
    else:
        print("File not found. Skip delete")
    
    calculate_ratings(fileName,routesFileName)

    ratingData = pd.read_csv(fileName,
    usecols=['cluster_id', 'route_name', 'route_desc', 'rating'])
    if(ratingData.size < 1):
        exit()
    ratingData = ratingData.query("rating >= 3.0")  

    bar_width = 0.7
    # plt.subplots(1,1)
    #ratingGraph = sns.scatterplot(x='route_name', y='rating', hue='cluster_id', data=ratingData, palette='bright')
    # sns.barplot(x='route_name', y='rating', hue='cluster_id', data=ratingData, palette='bright')

    dfs = dict(tuple(ratingData.groupby('route_desc')))

    for df in dfs:

        ratingData = dfs[df]
        # ratingData.groupby(['route_name','cluster_id']).size().unstack().plot(kind='bar',stacked=True, width=bar_width)
        # plt.ylabel('cluster_count')
        # plt.legend(loc='center left', bbox_to_anchor=(1.05, 0.5), borderaxespad=0, title='cluster_id')

        pivot_df = ratingData.pivot(index='route_name', columns='cluster_id', values='rating')
        ax = pivot_df.plot.bar(stacked=True, width=bar_width, cmap='Paired', title='Route: '+df)
        ## Write rating values in the bar
        # .patches is everything inside of the chart
        for rect in ax.patches:
            # Find where everything is located
            height = rect.get_height()
            width = rect.get_width()
            x = rect.get_x()
            y = rect.get_y()

            # The height of the bar is the data value and can be used as the label
            label_text = f'{height: .2f}'  # f'{height:.2f}' to format decimal values

            # ax.text(x, y, text)
            label_x = x + width - 0.3   # adjust 0.2 to center the label
            label_y = y + height / 2
            if height > 0.0:
                ax.text(label_x, label_y, label_text, ha='center', va='center', color='white', fontsize=8, fontweight='bold')
        plt.ylabel('rating')
        plt.legend(loc='center left', bbox_to_anchor=(1.05, 0.5), borderaxespad=0, title='cluster_id')

        plt.tight_layout()
        ax.figure.savefig(os.path.join(dirname, 'route_rating_{name}.png'.format(name=df)))
    plt.close()