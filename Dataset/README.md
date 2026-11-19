# FleetTrack Synthetic Dataset

## Overview
This package contains a synthetic Indian logistics dataset for the FleetTrack academic DBMS project.
All records are computer-generated for educational use and do not represent real customers, couriers,
drivers, vehicles, companies, routes, or operational performance. Delivery timestamps are validated to occur
after dispatch, and delivery status is held only in deliveries.csv.

## Period
2025-11-01 through 2026-10-31 (12 months).

## Relational CSV files
- customers.csv: 500 customer records
- hubs.csv: 15 logistics hub records
- vehicles.csv: 100 vehicle records
- drivers.csv: 150 driver records
- routes.csv: 50 directed hub-to-hub route records
- shipments.csv: 1,000 shipment records
- deliveries.csv: 1,000 delivery/assignment records

## MongoDB file
- tracking_scans.jsonl: one JSON document per shipment, with an array of tracking events.
  Import using: mongoimport --db fleettrack --collection tracking_scans --file tracking_scans.jsonl

## Main relationships
- shipments.CustomerID -> customers.CustomerID
- shipments.RouteID -> routes.RouteID
- routes.SourceHubID -> hubs.HubID
- routes.DestinationHubID -> hubs.HubID
- deliveries.ShipmentID -> shipments.ShipmentID
- deliveries.DriverID -> drivers.DriverID
- deliveries.VehicleID -> vehicles.VehicleID

## Important interpretation
- DeliveryStatus in deliveries.csv is one of Delivered, Delayed, In Transit, Out for Delivery, or Cancelled.
- For Delivered and Delayed records, ActualDeliveryDate is populated in deliveries.csv.
- For in-progress and cancelled records, ActualDeliveryDate is blank in deliveries.csv.
- Delayed means the actual delivery timestamp in deliveries.csv is later than ExpectedDeliveryDate in shipments.csv.
- Distance, route duration, costs, addresses, names, and event times are simulated.
- The dataset is designed for database practice and demonstration, not operational decision-making.

## Suggested analytics
On-time delivery rate, average transit time, delayed shipments by route, shipment volume by hub,
driver delivery counts, cost by route, monthly shipment trends, and tracking-event analysis.
