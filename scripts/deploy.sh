#!/bin/bash

# Build and start containers
docker-compose up --build -d

# Wait for services to be ready
sleep 30

# Test the services
curl http://localhost/health
curl http://localhost/market-data/AAPL