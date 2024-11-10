import csv
import sys
from argparse import ArgumentParser
from pathlib import Path

emissions_per_route_type = {
    3: {"avg_co2_per_vehicle_per_km": 85, "avg_passenger_count": 1}, # Bus
    0: {"avg_co2_per_vehicle_per_km": 37.7, "avg_passenger_count": 1}, # Interpretiere Tram, Streetcar, Light rail wie S-Bahn
    109: {"avg_co2_per_vehicle_per_km": 37.7, "avg_passenger_count": 1}, # S-Bahn
    2: {"avg_co2_per_vehicle_per_km": 54, "avg_passenger_count": 1}, # Intepretiere Rails (Long Distance) wie Regionalbahn
    106: {"avg_co2_per_vehicle_per_km": 54, "avg_passenger_count": 1}, # Regionalbahn
    1: {"avg_co2_per_vehicle_per_km": 2.6, "avg_passenger_count": 1}, # interpretiere Subway, Metro wie Stadtbahn
    403: {"avg_co2_per_vehicle_per_km": 2.6, "avg_passenger_count": 1}, # Stadtbahn
    4: {"avg_co2_per_vehicle_per_km": 2600, "avg_passenger_count": 1.4}, # Ferries
    7: {"avg_co2_per_vehicle_per_km": 2.6, "avg_passenger_count": 1}, # Funicular, Übernahme Wert Stadtbahn
}

# Estimating CO2 emissions for funiculars:
# VVS does not provide numbers neither for Seilbahn ("Außerhalb Tarifgebiet") 
# nor Zahnradbahn ("1.2km Fußweg (while it's 2.4km [1] or 1.6 fly distance)")
# We assume it is approximately the Stadtbahn. 
# [1] https://herrenberg.stadtnavi.de/reiseplan/Marienplatz%2C%20Stuttgart%3A%3A48.7642519%2C9.1681266/Degerloch%2C%20Stuttgart%3A%3A48.7485636%2C9.1682656/walk?time=1731217647

# Estimating CO2 emissions for ferries:
# CO2 emissions for ferries are barely available. We deduced them from a single datapoint
# we found: 2.8l per car for the Horgener Zürichsee-Ferry [1]. As the distance between Horgen
# and Meilen is, according to OSM exactly 2.8km, we assume it's 1l/km. As 1l Diesel
# corresponds to 2.6kg CO2 [3], that corresponds to 1l/PKWkm*2600g => 2600g/km. 
# Per car we assume a medium occupancy of 1.4
# [1] https://www.tagesanzeiger.ch/die-faehre-verbraucht-einen-liter-fuer-2-8-kilometer-pro-auto-737265054748
# [2] https://www.openstreetmap.org/directions?engine=graphhopper_foot&route=47.25919%2C8.60453%3B47.26770%2C8.63839
# [3] https://www.econologie.de/Emissions-co2-Liter-Kraftstoff-Benzin-oder-Diesel-gpl/



def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def map_to_standard_route_type(extended_route_type: int) -> int:
    if extended_route_type < 15:
        return extended_route_type
    if extended_route_type >= 400 and extended_route_type < 500:
        return 1
    if extended_route_type >= 100 and extended_route_type < 200:
        return 2
    if extended_route_type >= 700 and extended_route_type < 800:
        return 3
    if extended_route_type >= 1400 and extended_route_type < 1500:
        return 7
    eprint(f"WARN: no mapping to standard route_type for {extended_route_type}")
    return extended_route_type    

def print_mappings(used_route_types: set[int]):
    eprint("The following co2 emissions per route type where used:")
    eprint(f'route_type|avg_co2_per_vehicle_per_km|avg_passenger_count')
    eprint(f'----------|--------------------------|-------------------')
    
    for route_type in used_route_types:
        mapped_route_type = map_to_standard_route_type(route_type)
        emissions = emissions_per_route_type[mapped_route_type]
        avg_co2_per_vehicle_per_km = emissions['avg_co2_per_vehicle_per_km']
        avg_passenger_count = emissions['avg_passenger_count']
        eprint(f'{route_type: 10}|{avg_co2_per_vehicle_per_km: 26}|{avg_passenger_count: 19}')

def generate_emissions_file(routes_file_path: str, emissions_file_path: str) -> None:
    used_route_types = set()
    with open(routes_file_path) as f:
        reader = csv.DictReader(f)

        emissions = []
        for route in reader:
            route_type = int(route["route_type"])
            used_route_types.add(route_type)
            standard_route_type = map_to_standard_route_type(route_type)
            route_id = route["route_id"]
            route_type_emissions = emissions_per_route_type.get(route_type, emissions_per_route_type.get(standard_route_type))
            if not route_type_emissions:
                eprint(f"Error: no emissions defined for route_type {route_type} or route {route_id}")
            else:
                route_emission= {}
                route_emission["route_id"] = route_id
                route_emission["avg_co2_per_vehicle_per_km"] = route_type_emissions['avg_co2_per_vehicle_per_km']
                route_emission["avg_passenger_count"] = route_type_emissions['avg_passenger_count']
                emissions.append(route_emission)

    with open(emissions_file_path, 'w') as f:
        fieldnames = ['route_id', 'avg_co2_per_vehicle_per_km', 'avg_passenger_count' ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        
        writer.writeheader()
        for route_emisions in emissions:
            writer.writerow(route_emisions)

    print_mappings(used_route_types)

if __name__ == "__main__":
    parser = ArgumentParser(prog='generate_emissions_file')
    parser.add_argument('gtfs_dir', help='Path to GTFS directory')
    args = parser.parse_args()
    generate_emissions_file(Path(args.gtfs_dir, 'routes.txt'), Path(args.gtfs_dir, 'emissions.txt'))

    