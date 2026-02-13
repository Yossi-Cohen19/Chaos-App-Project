import { NextResponse } from 'next/server';
import { Pool } from 'pg';

// Create PostgreSQL connection pool
// DATABASE_URL is injected via External Secrets
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

export async function GET() {
    let client;
    try {
        client = await pool.connect();

        // Query active connections
        const activeQuery = await client.query(
            'SELECT COUNT(*) as active_connections FROM pg_stat_activity WHERE state = $1',
            ['active']
        );

        // Query total connections
        const totalQuery = await client.query(
            'SELECT COUNT(*) as total_connections FROM pg_stat_activity'
        );

        // Query database name
        const dbQuery = await client.query('SELECT current_database()');

        const activeConnections = parseInt(activeQuery.rows[0].active_connections);
        const totalConnections = parseInt(totalQuery.rows[0].total_connections);
        const databaseName = dbQuery.rows[0].current_database;

        return NextResponse.json({
            active: activeConnections,
            total: totalConnections,
            maxConnections: pool.options.max || 20,
            database: databaseName,
            timestamp: Date.now(),
        });
    } catch (error: any) {
        console.error('Database connection error:', error);

        // Return fallback data if database is unavailable
        return NextResponse.json(
            {
                error: 'Database unavailable',
                message: error.message,
                fallback: true,
                active: 0,
                total: 0,
                maxConnections: 20,
            },
            { status: 503 }
        );
    } finally {
        if (client) {
            client.release();
        }
    }
}
