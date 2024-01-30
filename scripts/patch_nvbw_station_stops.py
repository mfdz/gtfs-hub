# This script patches stations referenced as stops by 
# adding a new stop with `:na:na` appended to the id and
# replacing the original station's ID in stop_times.txt
# by this new stop ID.
# Note: This script is a quick and dirty hack and no
# general purpose patch script. I.e. GTFS feeds with transfers
# might need additional changes.

# Background: this fix is necssary


import csv
import os
from os.path import join
import sys

gtfs_dir = sys.argv[1] if len(sys.argv) >= 2 else ''

original_stops_file_path = join(gtfs_dir, 'stops.txt')
new_stops_file_path = join(gtfs_dir, 'new_stops.txt')
original_stop_times_file_path = join(gtfs_dir, 'stop_times.txt')
new_stop_times_file_path= join(gtfs_dir, 'new_stop_times.txt')

with open(original_stops_file_path) as csvfile:

	reader = csv.DictReader(csvfile)
	stations = {}
	for row in reader:
		if row['location_type'] == '1':
			stations[row['stop_id']] = row

renamed_stop_ids = {}
# check if they are references by stop_times
with open(original_stop_times_file_path) as csvfile:
	with open(new_stop_times_file_path, 'w') as new_stops_file:

		reader = csv.DictReader(csvfile)
		writer = csv.DictWriter(new_stops_file, reader.fieldnames)
		writer.writeheader()
		for row in reader:
			if row['stop_id'] in stations:
				print(row['stop_id'],row['trip_id'],row['departure_time'])
				new_stop_id = row['stop_id']+':na:na'
				renamed_stop_ids[row['stop_id']] = new_stop_id
				row['stop_id']= new_stop_id

			writer.writerow(row)

with open(original_stops_file_path) as csvfile:
	with open(new_stops_file_path, 'w') as new_stops_file:
		reader = csv.DictReader(csvfile)
		writer = csv.DictWriter(new_stops_file, reader.fieldnames)
		writer.writeheader()

		for row in reader:
			writer.writerow(row)
			if row['stop_id'] in renamed_stop_ids:
				row['stop_id'] = renamed_stop_ids[row['stop_id'] ]
				row['location_type'] = '0'
				writer.writerow(row)

os.remove(original_stops_file_path)
os.rename(new_stops_file_path, original_stops_file_path)

os.remove(original_stop_times_file_path)
os.rename(new_stop_times_file_path, original_stop_times_file_path)
