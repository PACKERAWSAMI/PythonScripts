import json
import csv


#Read a json file 
with open('employee.json', 'r') as f:
    datastore = json.load(f)
    print (datastore)

empployee_data = datastore['employee_details'] 
#open a file for writing csv
write_file = open('parm.csv','w')

# create the csv write object
csvconverter = csv.write(write_file)

count = 0
for emp in empployee_data:
    if count == 0:
        header = emp.keys()
        csvwriter.writerow(header)
        count += 1
    csvconverter.writerow(emp.values())

empployee_data.close()
