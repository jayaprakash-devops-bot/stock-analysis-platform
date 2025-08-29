import React, { useState, useEffect } from 'react';
import { Canvas } from '@react-three/fiber';
import { OrbitControls, Text } from '@react-three/drei';
import './App.css';

function StockVisualization({ data }) {
  return (
    <mesh>
      <boxGeometry args={[1, 1, 1]} />
      <meshStandardMaterial color="orange" />
    </mesh>
  );
}

function App() {
  const [stockData, setStockData] = useState(null);

  useEffect(() => {
    // Fetch data from API gateway
    fetch('/api/market-data/AAPL')
      .then(response => response.json())
      .then(data => setStockData(data));
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <h1>3D Stock Analysis Platform</h1>
      </header>
      
      <div style={{ width: '100vw', height: '80vh' }}>
        <Canvas>
          <ambientLight />
          <pointLight position={[10, 10, 10]} />
          <StockVisualization data={stockData} />
          <OrbitControls />
          <Text
            position={[0, 2, 0]}
            color="black"
            anchorX="center"
            anchorY="middle"
          >
            Stock Analysis Platform
          </Text>
        </Canvas>
      </div>
      
      <div className="data-panel">
        {stockData && (
          <div>
            <h2>AAPL Data</h2>
            <p>Price: ${stockData.price}</p>
            <p>Change: {stockData.change}%</p>
          </div>
        )}
      </div>
    </div>
  );
}

export default App;