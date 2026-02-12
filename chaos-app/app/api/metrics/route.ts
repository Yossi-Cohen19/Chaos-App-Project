import { NextResponse } from 'next/server';

const PROMETHEUS_URL = process.env.PROMETHEUS_URL || 'http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090';

interface PrometheusResponse {
    status: string;
    data: {
        resultType: string;
        result: Array<{
            metric: Record<string, string>;
            value: [number, string];
        }>;
    };
}

async function queryPrometheus(query: string): Promise<PrometheusResponse | null> {
    try {
        const url = `${PROMETHEUS_URL}/api/v1/query?query=${encodeURIComponent(query)}`;
        const response = await fetch(url, {
            headers: { 'Content-Type': 'application/json' },
        });

        if (!response.ok) {
            console.error('Prometheus query failed:', response.statusText);
            return null;
        }

        return await response.json();
    } catch (error) {
        console.error('Error querying Prometheus:', error);
        return null;
    }
}

export async function GET() {
    try {
        // Query CPU usage (rate over last 5 minutes)
        const cpuQuery = 'sum(rate(container_cpu_usage_seconds_total{namespace="dev",pod=~"chaos-app.*"}[5m])) * 100';
        const cpuData = await queryPrometheus(cpuQuery);

        // Query memory usage (in MB)
        const memoryQuery = 'sum(container_memory_working_set_bytes{namespace="dev",pod=~"chaos-app.*"}) / 1024 / 1024';
        const memoryData = await queryPrometheus(memoryQuery);

        // Query replica count
        const replicaQuery = 'kube_deployment_status_replicas{namespace="dev",deployment=~"chaos-app.*"}';
        const replicaData = await queryPrometheus(replicaQuery);

        // Extract values
        const cpuPercent = cpuData?.data?.result?.[0]?.value?.[1]
            ? parseFloat(cpuData.data.result[0].value[1])
            : 0;

        const memoryMB = memoryData?.data?.result?.[0]?.value?.[1]
            ? parseFloat(memoryData.data.result[0].value[1])
            : 0;

        const replicas = replicaData?.data?.result?.[0]?.value?.[1]
            ? parseInt(replicaData.data.result[0].value[1])
            : 1;

        return NextResponse.json({
            cpu: Math.round(cpuPercent * 10) / 10, // Round to 1 decimal
            memory: Math.round(memoryMB),
            replicas: replicas,
            timestamp: Date.now(),
        });
    } catch (error) {
        console.error('Metrics API error:', error);
        return NextResponse.json(
            { error: 'Failed to fetch metrics', fallback: true },
            { status: 500 }
        );
    }
}
