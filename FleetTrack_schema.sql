-- FleetTrack: Logistics Shipment and Delivery Performance Analytics

CREATE DATABASE IF NOT EXISTS fleettrack_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE fleettrack_db;

-- Drop child tables before parent tables if rerunning this script.
DROP TABLE IF EXISTS Deliveries;
DROP TABLE IF EXISTS Shipments;
DROP TABLE IF EXISTS Routes;
DROP TABLE IF EXISTS Drivers;
DROP TABLE IF EXISTS Vehicles;
DROP TABLE IF EXISTS Customers;
DROP TABLE IF EXISTS Hubs;

-- 1. HUBS
CREATE TABLE Hubs (
    HubID INT NOT NULL,
    HubName VARCHAR(100) NOT NULL,
    City VARCHAR(60) NOT NULL,
    State VARCHAR(60) NOT NULL,
    HubType VARCHAR(40) NOT NULL,
    CapacityPerDay INT NOT NULL,
    CONSTRAINT pk_hubs PRIMARY KEY (HubID),
    CONSTRAINT chk_hubs_capacity CHECK (CapacityPerDay > 0)
) ENGINE=InnoDB;

-- 2. CUSTOMERS
CREATE TABLE Customers (
    CustomerID INT NOT NULL,
    CustomerName VARCHAR(100) NOT NULL,
    Email VARCHAR(120) NOT NULL,
    Phone VARCHAR(15) NOT NULL,
    Address VARCHAR(255) NOT NULL,
    City VARCHAR(60) NOT NULL,
    State VARCHAR(60) NOT NULL,
    Pincode VARCHAR(10) NOT NULL,
    CONSTRAINT pk_customers PRIMARY KEY (CustomerID),
    CONSTRAINT uq_customers_email UNIQUE (Email)
) ENGINE=InnoDB;

-- 3. DRIVERS
CREATE TABLE Drivers (
    DriverID INT NOT NULL,
    DriverName VARCHAR(100) NOT NULL,
    Phone VARCHAR(15) NOT NULL,
    LicenseNumber VARCHAR(30) NOT NULL,
    EmploymentStatus VARCHAR(20) NOT NULL,
    CONSTRAINT pk_drivers PRIMARY KEY (DriverID),
    CONSTRAINT uq_drivers_license UNIQUE (LicenseNumber)
) ENGINE=InnoDB;

-- 4. VEHICLES
CREATE TABLE Vehicles (
    VehicleID INT NOT NULL,
    VehicleNumber VARCHAR(20) NOT NULL,
    VehicleType VARCHAR(40) NOT NULL,
    CapacityKg DECIMAL(8,2) NOT NULL,
    VehicleStatus VARCHAR(20) NOT NULL,
    CONSTRAINT pk_vehicles PRIMARY KEY (VehicleID),
    CONSTRAINT uq_vehicles_number UNIQUE (VehicleNumber),
    CONSTRAINT chk_vehicles_capacity CHECK (CapacityKg > 0)
) ENGINE=InnoDB;

-- 5. ROUTES
-- SourceHubID and DestinationHubID both reference Hubs.
CREATE TABLE Routes (
    RouteID INT NOT NULL,
    SourceHubID INT NOT NULL,
    DestinationHubID INT NOT NULL,
    DistanceKm DECIMAL(8,2) NOT NULL,
    EstimatedTransitHours DECIMAL(6,2) NOT NULL,
    CONSTRAINT pk_routes PRIMARY KEY (RouteID),
    CONSTRAINT fk_routes_source_hub
        FOREIGN KEY (SourceHubID) REFERENCES Hubs(HubID),
    CONSTRAINT fk_routes_destination_hub
        FOREIGN KEY (DestinationHubID) REFERENCES Hubs(HubID),
    CONSTRAINT chk_routes_different_hubs CHECK (SourceHubID <> DestinationHubID),
    CONSTRAINT chk_routes_distance CHECK (DistanceKm > 0),
    CONSTRAINT chk_routes_transit CHECK (EstimatedTransitHours > 0)
) ENGINE=InnoDB;

-- 6. SHIPMENTS
-- DeliveryStatus is stored only in Deliveries to avoid duplication.
CREATE TABLE Shipments (
    ShipmentID VARCHAR(12) NOT NULL,
    CustomerID INT NOT NULL,
    RouteID INT NOT NULL,
    BookingDate DATETIME NOT NULL,
    ExpectedDeliveryDate DATETIME NOT NULL,
    WeightKg DECIMAL(6,2) NOT NULL,
    ShippingCostINR DECIMAL(10,2) NOT NULL,
    Priority VARCHAR(20) NOT NULL,
    CONSTRAINT pk_shipments PRIMARY KEY (ShipmentID),
    CONSTRAINT fk_shipments_customer
        FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    CONSTRAINT fk_shipments_route
        FOREIGN KEY (RouteID) REFERENCES Routes(RouteID),
    CONSTRAINT chk_shipments_weight CHECK (WeightKg > 0),
    CONSTRAINT chk_shipments_cost CHECK (ShippingCostINR >= 0),
    CONSTRAINT chk_shipments_expected_date CHECK (ExpectedDeliveryDate >= BookingDate)
) ENGINE=InnoDB;

-- 7. DELIVERIES
-- UNIQUE(ShipmentID) enforces at most one delivery record per shipment.
-- This represents 1 : 0..1 at schema level.
CREATE TABLE Deliveries (
    DeliveryID INT NOT NULL,
    ShipmentID VARCHAR(12) NOT NULL,
    DriverID INT NOT NULL,
    VehicleID INT NOT NULL,
    DispatchDate DATETIME NOT NULL,
    ActualDeliveryDate DATETIME NULL,
    DeliveryStatus VARCHAR(30) NOT NULL,
    DelayReason VARCHAR(100) NULL,
    CONSTRAINT pk_deliveries PRIMARY KEY (DeliveryID),
    CONSTRAINT uq_deliveries_shipment UNIQUE (ShipmentID),
    CONSTRAINT fk_deliveries_shipment
        FOREIGN KEY (ShipmentID) REFERENCES Shipments(ShipmentID),
    CONSTRAINT fk_deliveries_driver
        FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID),
    CONSTRAINT fk_deliveries_vehicle
        FOREIGN KEY (VehicleID) REFERENCES Vehicles(VehicleID),
    CONSTRAINT chk_deliveries_status CHECK (
        DeliveryStatus IN ('Delivered', 'Delayed', 'In Transit',
                           'Out for Delivery', 'Cancelled')
    ),
    CONSTRAINT chk_deliveries_actual_date CHECK (
        ActualDeliveryDate IS NULL OR ActualDeliveryDate >= DispatchDate
    )
) ENGINE=InnoDB;

-- Helpful indexes for common joins and analysis.
CREATE INDEX idx_shipments_booking_date ON Shipments(BookingDate);
CREATE INDEX idx_shipments_expected_date ON Shipments(ExpectedDeliveryDate);
CREATE INDEX idx_deliveries_status ON Deliveries(DeliveryStatus);
CREATE INDEX idx_deliveries_driver ON Deliveries(DriverID);
CREATE INDEX idx_routes_source_hub ON Routes(SourceHubID);
CREATE INDEX idx_routes_destination_hub ON Routes(DestinationHubID);

-- Verify that all seven tables were created.
SHOW TABLES;


SELECT COUNT(*) FROM Hubs;
SELECT COUNT(*) FROM Customers;
SELECT COUNT(*) FROM Drivers;
SELECT COUNT(*) FROM Vehicles;
SELECT COUNT(*) FROM Routes;
SELECT COUNT(*) FROM Shipments;
SELECT COUNT(*) FROM Deliveries;