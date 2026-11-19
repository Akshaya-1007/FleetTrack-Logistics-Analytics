USE fleettrack_db;

-- PART A: VIEW
CREATE OR REPLACE VIEW vw_shipment_delivery_details AS
SELECT
    s.ShipmentID,
    c.CustomerName,
    c.City AS CustomerCity,
    h1.City AS SourceCity,
    h2.City AS DestinationCity,
    r.DistanceKm,
    s.BookingDate,
    s.ExpectedDeliveryDate,
    s.WeightKg,
    s.ShippingCostINR,
    s.Priority,
    d.DeliveryID,
    d.DispatchDate,
    d.ActualDeliveryDate,
    d.DeliveryStatus,
    d.DelayReason,
    dr.DriverName,
    v.VehicleNumber,
    v.VehicleType,
    CASE
        WHEN d.ShipmentID IS NULL THEN 'No Delivery Record'
        WHEN d.DeliveryStatus = 'Delivered'
             AND d.ActualDeliveryDate <= s.ExpectedDeliveryDate
            THEN 'On Time'
        WHEN d.DeliveryStatus IN ('Delivered', 'Delayed')
            THEN 'Late'
        ELSE d.DeliveryStatus
    END AS DeliveryPerformance
FROM Shipments AS s
INNER JOIN Customers AS c
    ON s.CustomerID = c.CustomerID
INNER JOIN Routes AS r
    ON s.RouteID = r.RouteID
INNER JOIN Hubs AS h1
    ON r.SourceHubID = h1.HubID
INNER JOIN Hubs AS h2
    ON r.DestinationHubID = h2.HubID
LEFT JOIN Deliveries AS d
    ON s.ShipmentID = d.ShipmentID
LEFT JOIN Drivers AS dr
    ON d.DriverID = dr.DriverID
LEFT JOIN Vehicles AS v
    ON d.VehicleID = v.VehicleID;

-- Verify and preview the view.
SHOW FULL TABLES WHERE Table_type = 'VIEW';

SELECT *
FROM vw_shipment_delivery_details
ORDER BY ShipmentID
LIMIT 10;

-- PART B: TRIGGERS
-- If an actual delivery date is provided for a Delivered or
-- Delayed record, compare it with the shipment's expected date.
-- Later than expected = Delayed; on/before expected = Delivered.
-- NULL actual dates and other statuses are left unchanged.

DROP TRIGGER IF EXISTS trg_check_delivery_status_insert;
DROP TRIGGER IF EXISTS trg_check_delivery_status_update;

DELIMITER $$
CREATE TRIGGER trg_check_delivery_status_update
BEFORE UPDATE ON Deliveries
FOR EACH ROW
BEGIN
    DECLARE v_expected_date DATETIME;

    SELECT ExpectedDeliveryDate
    INTO v_expected_date
    FROM Shipments
    WHERE ShipmentID = NEW.ShipmentID;

    IF NEW.ActualDeliveryDate IS NOT NULL
       AND NEW.DeliveryStatus IN ('Delivered', 'Delayed') THEN
        IF NEW.ActualDeliveryDate > v_expected_date THEN
            SET NEW.DeliveryStatus = 'Delayed';
        ELSE
            SET NEW.DeliveryStatus = 'Delivered';
        END IF;
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_check_delivery_status_insert
BEFORE INSERT ON Deliveries
FOR EACH ROW
BEGIN
    DECLARE v_expected_date DATETIME;

    SELECT ExpectedDeliveryDate
    INTO v_expected_date
    FROM Shipments
    WHERE ShipmentID = NEW.ShipmentID;

    IF NEW.ActualDeliveryDate IS NOT NULL
       AND NEW.DeliveryStatus IN ('Delivered', 'Delayed') THEN

        IF NEW.ActualDeliveryDate > v_expected_date THEN
            SET NEW.DeliveryStatus = 'Delayed';
        ELSE
            SET NEW.DeliveryStatus = 'Delivered';
        END IF;

    END IF;
END$$
DELIMITER ;

-- Verify triggers.
SHOW TRIGGERS FROM fleettrack_db;

-- PART C: ANALYTICAL SQL QUERIES

-- Query 1: Record count in each relational table.
SELECT 'Customers' AS TableName, COUNT(*) AS TotalRecords FROM Customers
UNION ALL
SELECT 'Hubs', COUNT(*) FROM Hubs
UNION ALL
SELECT 'Drivers', COUNT(*) FROM Drivers
UNION ALL
SELECT 'Vehicles', COUNT(*) FROM Vehicles
UNION ALL
SELECT 'Routes', COUNT(*) FROM Routes
UNION ALL
SELECT 'Shipments', COUNT(*) FROM Shipments
UNION ALL
SELECT 'Deliveries', COUNT(*) FROM Deliveries;

-- Query 2: Shipment count by delivery status.
SELECT DeliveryStatus, COUNT(*) AS TotalShipments
FROM Deliveries
GROUP BY DeliveryStatus
ORDER BY TotalShipments DESC;

-- Query 3: Delivery performance summary.
SELECT DeliveryPerformance, COUNT(*) AS TotalShipments
FROM vw_shipment_delivery_details
GROUP BY DeliveryPerformance
ORDER BY TotalShipments DESC;

-- Query 4: Average shipping cost by priority.
SELECT
    Priority,
    COUNT(*) AS TotalShipments,
    ROUND(AVG(ShippingCostINR), 2) AS AverageShippingCostINR
FROM Shipments
GROUP BY Priority
ORDER BY AverageShippingCostINR DESC;

-- Query 5: Shipment volume and weight by route.
SELECT
    r.RouteID,
    h1.City AS SourceCity,
    h2.City AS DestinationCity,
    COUNT(s.ShipmentID) AS TotalShipments,
    ROUND(SUM(s.WeightKg), 2) AS TotalWeightKg,
    ROUND(AVG(s.WeightKg), 2) AS AverageWeightKg
FROM Routes AS r
INNER JOIN Hubs AS h1 ON r.SourceHubID = h1.HubID
INNER JOIN Hubs AS h2 ON r.DestinationHubID = h2.HubID
LEFT JOIN Shipments AS s ON r.RouteID = s.RouteID
GROUP BY r.RouteID, h1.City, h2.City
ORDER BY TotalShipments DESC;

-- Query 6: Top 10 customers by shipment count.
SELECT
    c.CustomerID,
    c.CustomerName,
    c.City,
    COUNT(s.ShipmentID) AS TotalShipments,
    ROUND(SUM(s.ShippingCostINR), 2) AS TotalShippingCostINR
FROM Customers AS c
INNER JOIN Shipments AS s ON c.CustomerID = s.CustomerID
GROUP BY c.CustomerID, c.CustomerName, c.City
ORDER BY TotalShipments DESC
LIMIT 10;

-- Query 7: Driver delivery performance.
SELECT
    dr.DriverID,
    dr.DriverName,
    COUNT(d.DeliveryID) AS TotalDeliveries,
    SUM(d.DeliveryStatus = 'Delivered') AS DeliveredCount,
    SUM(d.DeliveryStatus = 'Delayed') AS DelayedCount,
    ROUND(
        100.0 * SUM(d.DeliveryStatus = 'Delivered')
        / NULLIF(COUNT(d.DeliveryID), 0),
        2
    ) AS DeliveredPercentage
FROM Drivers AS dr
LEFT JOIN Deliveries AS d ON dr.DriverID = d.DriverID
GROUP BY dr.DriverID, dr.DriverName
ORDER BY DeliveredPercentage DESC, TotalDeliveries DESC
LIMIT 10;

-- Query 8: Vehicle utilisation by assigned delivery count.
SELECT
    v.VehicleID,
    v.VehicleNumber,
    v.VehicleType,
    v.VehicleStatus,
    COUNT(d.DeliveryID) AS TotalAssignedDeliveries
FROM Vehicles AS v
LEFT JOIN Deliveries AS d ON v.VehicleID = d.VehicleID
GROUP BY v.VehicleID, v.VehicleNumber, v.VehicleType, v.VehicleStatus
ORDER BY TotalAssignedDeliveries DESC
LIMIT 10;

-- Query 9: Monthly shipment volume and shipping revenue.
SELECT
    DATE_FORMAT(BookingDate, '%Y-%m') AS BookingMonth,
    COUNT(*) AS TotalShipments,
    ROUND(SUM(ShippingCostINR), 2) AS TotalShippingRevenueINR,
    ROUND(AVG(ShippingCostINR), 2) AS AverageShippingCostINR
FROM Shipments
GROUP BY DATE_FORMAT(BookingDate, '%Y-%m')
ORDER BY BookingMonth;

-- Query 10: Delayed shipments and their details.
SELECT
    ShipmentID,
    CustomerName,
    SourceCity,
    DestinationCity,
    ExpectedDeliveryDate,
    ActualDeliveryDate,
    DelayReason,
    DriverName,
    VehicleNumber
FROM vw_shipment_delivery_details
WHERE DeliveryStatus = 'Delayed'
ORDER BY ActualDeliveryDate DESC
LIMIT 20;

-- Query 11: Shipments without a delivery record, if any.
SELECT
    s.ShipmentID,
    s.BookingDate,
    s.ExpectedDeliveryDate,
    s.Priority
FROM Shipments AS s
LEFT JOIN Deliveries AS d ON s.ShipmentID = d.ShipmentID
WHERE d.ShipmentID IS NULL;

-- PART D: FINAL VERIFICATION

SELECT
    COUNT(*) AS TotalDeliveries,
    COUNT(DISTINCT ShipmentID) AS UniqueShipmentIDs,
    SUM(ActualDeliveryDate IS NULL) AS NullActualDeliveryDates
FROM Deliveries;

SHOW FULL TABLES WHERE Table_type = 'VIEW';
SHOW TRIGGERS FROM fleettrack_db;

-- End of FleetTrack Phase 3 SQL script.
