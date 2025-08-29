CREATE TABLE IF NOT EXISTS market_data (
    symbol VARCHAR(10) PRIMARY KEY,
    price DECIMAL(10, 2),
    volume BIGINT,
    timestamp TIMESTAMP
);

INSERT INTO market_data (symbol, price, volume, timestamp) VALUES
('AAPL', 150.00, 1000000, NOW()),
('GOOGL', 2800.00, 2000000, NOW());