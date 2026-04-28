USE SalesDB;
GO

CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) UNIQUE NOT NULL,
    RegistrationDate DATETIME DEFAULT GETDATE() NOT NULL
);

CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderTotal FLOAT NOT NULL CHECK (OrderTotal > 0),
    OrderDate DATETIME NOT NULL DEFAULT GETDATE(),
    [Status] NVARCHAR(20) NOT NULL DEFAULT 'Новый',
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
GO

USE LogisticsDB;
GO

CREATE TABLE Warehouses (
    WarehouseID INT IDENTITY(1,1) PRIMARY KEY,
    [Location] NVARCHAR(100) UNIQUE NOT NULL,
    Capacity FLOAT NOT NULL,
    ManagerContact NVARCHAR(50) NOT NULL DEFAULT 'не назначен',
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE Shipments (
    ShipmentID INT IDENTITY(1,1) PRIMARY KEY,
    WarehouseID INT NOT NULL,
    OrderID INT NOT NULL,
    TrackingCode NVARCHAR(50) UNIQUE NOT NULL,
    [Weight] FLOAT NOT NULL,
    DispatchDate DATETIME NULL,
    [Status] NVARCHAR(20) NOT NULL DEFAULT 'Ожидает отправки',
    CONSTRAINT FK_Shipments_Warehouse FOREIGN KEY (WarehouseID) REFERENCES Warehouses(WarehouseID)
);

USE LogisticsDB;
GO
CREATE OR ALTER TRIGGER CheckOrderID
ON Shipments
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE NOT EXISTS (SELECT 1 FROM SalesDB.dbo.Orders o WHERE o.OrderID = i.OrderID)
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, 'Ошибка: OrderID не найден', 1;
    END
END
GO

USE SalesDB;
GO
CREATE OR ALTER TRIGGER SalesDB_Orders
ON Orders
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO LogisticsDB.dbo.Shipments (WarehouseID, OrderID, TrackingCode, [Weight], DispatchDate, [Status])
    SELECT 
        1, 
        i.OrderID, 
        CAST(NEWID() AS NVARCHAR(50)), 
        1.0, 
        NULL, 
        'Ожидает отправки'
    FROM inserted i
    WHERE i.[Status] = 'Подтвержден'
    AND NOT EXISTS (SELECT 1 FROM LogisticsDB.dbo.Shipments s WHERE s.OrderID = i.OrderID);
END
GO

USE SalesDB;
GO
CREATE OR ALTER FUNCTION fn_GetCustomers() RETURNS TABLE AS RETURN (SELECT CustomerID, FullName, Email, RegistrationDate FROM Customers);
GO
CREATE OR ALTER FUNCTION fn_GetOrders() RETURNS TABLE AS RETURN (SELECT OrderID, CustomerID, OrderTotal, OrderDate, [Status] FROM Orders);
GO
CREATE OR ALTER FUNCTION fn_GetOrdersByStatus(@status NVARCHAR(20)) RETURNS TABLE AS RETURN (SELECT OrderID, CustomerID, OrderTotal, OrderDate, [Status] FROM Orders WHERE [Status] = @status);
GO

USE LogisticsDB;
GO
CREATE OR ALTER FUNCTION fn_GetShipments() RETURNS TABLE AS RETURN (SELECT ShipmentID, WarehouseID, OrderID, TrackingCode, [Weight], DispatchDate, [Status] FROM Shipments);
GO
CREATE OR ALTER FUNCTION fn_GetShipmentsByWarehouse(@wid INT) RETURNS TABLE AS RETURN (SELECT ShipmentID, WarehouseID, OrderID, TrackingCode, [Weight], DispatchDate, [Status] FROM Shipments WHERE WarehouseID = @wid);
GO
CREATE OR ALTER FUNCTION fn_GetWarehouses() RETURNS TABLE AS RETURN (SELECT WarehouseID, [Location], Capacity, ManagerContact, CreatedDate FROM Warehouses);
GO

USE SalesDB;
GO
CREATE OR ALTER PROCEDURE CustomerProblemUpdate
AS
BEGIN
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            UPDATE Customers 
            SET Email = CONCAT(LEFT(Email, CHARINDEX('@', Email)-1), '_updated@test.com')
            WHERE CustomerID = (SELECT MIN(CustomerID) FROM Customers);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50002, 'Ошибка транзакции', 1;
    END CATCH
END
GO

USE LogisticsDB;
INSERT INTO Warehouses ([Location], Capacity) VALUES ('г. Минск', 500.0);

USE SalesDB;
INSERT INTO Customers (FullName, Email) VALUES ('Иван Иванов', 'ivan@test.com');
INSERT INTO Orders (CustomerID, OrderTotal) VALUES (1, 100.0);
UPDATE Orders SET [Status] = 'Подтвержден' WHERE CustomerID = 1;

SELECT * FROM SalesDB.dbo.fn_GetCustomers();
SELECT * FROM LogisticsDB.dbo.fn_GetShipments();
