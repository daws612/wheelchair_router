import csv
import re
import os
from decimal import Decimal
import statistics
import random

def append_to_file(row, fileName):
    with open(fileName, "a") as wekafile:
        writer = csv.writer(wekafile, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
        writer.writerow(row)


def create_fake_row(rowNum, genderChoices, whTypeChoices, fileName):
    for i in range (1, rowNum+1):
        #Create fake elderly
        age = random.randint(10, 80)
        whtype = random.choice(whTypeChoices)
        gender = random.choice(genderChoices)
        append_to_file([i, age, gender, whtype], fileName)
    print("Create " + str(rowNum))


def generate_fake_data(fileName, rows):
    append_to_file(['user_id', 'age', 'gender', 'wheelchair_type'], fileName)
    genderChoices = ['Female', 'Male']
    whTypeChoices = ['Electric', 'Manual']
    create_fake_row(rows, genderChoices, whTypeChoices, fileName)


if __name__ == "__main__" :
    dirname = os.path.dirname(__file__)
    fileName = os.path.join(dirname, 'pg/fake_users.csv')
    testFileName = os.path.join(dirname, 'pg/test_fake_users.csv')
    if(os.path.exists(fileName)):
        os.remove(fileName)
    else:
        print("File not found. Skip delete")
    rows = random.randint(400, 500)
    generate_fake_data(fileName, rows)

    if(os.path.exists(testFileName)):
        os.remove(testFileName)
    else:
        print("File not found. Skip test file delete")
    generate_fake_data(testFileName, 5)