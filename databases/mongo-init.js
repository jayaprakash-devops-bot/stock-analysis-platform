db = db.getSiblingDB('ai_agent');

db.analyses.insertMany([
    {
        symbol: 'AAPL',
        analysis: {
            score: 85,
            summary: 'Strong buy'
        }
    },
    {
        symbol: 'GOOGL',
        analysis: {
            score: 90,
            summary: 'Very strong buy'
        }
    }
]);