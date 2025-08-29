const express = require('express');
const redis = require('redis');
const { Pool } = require('pg');

const app = express();
const port = 3001;

// Redis setup
const redisClient = redis.createClient({ url: process.env.REDIS_URL });
(async () => {
  await redisClient.connect();
})();

// Postgres setup
const pool = new Pool({ connectionString: process.env.POSTGRES_URL });

app.get('/health', (req, res) => {
  res.send('OK');
});

app.get('/market-data/:symbol', async (req, res) => {
  const { symbol } = req.params;

  // Check cache first
  const cached = await redisClient.get(symbol);
  if (cached) {
    return res.json(JSON.parse(cached));
  }

  // If not in cache, query database
  const result = await pool.query('SELECT * FROM market_data WHERE symbol = $1', [symbol]);
  if (result.rows.length === 0) {
    return res.status(404).send('Not found');
  }

  // Store in cache for 5 minutes
  await redisClient.setEx(symbol, 300, JSON.stringify(result.rows[0]));

  res.json(result.rows[0]);
});

app.listen(port, () => {
  console.log(`Market data service listening on port ${port}`);
});