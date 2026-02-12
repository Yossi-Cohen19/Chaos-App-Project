import { NextResponse } from 'next/server';

const PROMETHEUS_URL = process.env.PROMETHEUS_URL || 'http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090';
const NAMESPACE = process.env.NAMESPACE || 'dev';

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

function extractValue(data: PrometheusResponse | null): number | null {
    const raw = data?.data?.result?.[0]?.value?.[1];
    return raw != null ? parseFloat(raw) : null;
}

export async function GET() {
    try {
        const ns = NAMESPACE;

        // CPU usage % (rate over 5m, normalised to cores then to %)
        const cpuQuery = `sum(rate(container_cpu_usage_seconds_total{namespace="${ns}",pod=~"chaos-app.*",container!=""}[5m])) * 100`;

        // Memory working-set as % of limit
        const memPercentQuery = `sum(container_memory_working_set_bytes{namespace="${ns}",pod=~"chaos-app.*",container!=""}) / sum(kube_pod_container_resource_limits{namespace="${ns}",pod=~"chaos-app.*",resource="memory"}) * 100`;

        // Raw memory in MB (fallback display)
        const memMbQuery = `sum(container_memory_working_set_bytes{namespace="${ns}",pod=~"chaos-app.*",container!=""}) / 1024 / 1024`;

        // Replica count
        const replicaQuery = `kube_deployment_status_replicas{namespace="${ns}",deployment=~"chaos-app.*"}`;

        // Error rate — pod restart rate over last 15m
        const errorRateQuery = `sum(rate(kube_pod_container_status_restarts_total{namespace="${ns}",pod=~"chaos-app.*"}[15m])) * 3600`;

        // HPA desired replicas (max across HPAs)
        const hpaMaxQuery = `kube_horizontalpodautoscaler_spec_max_replicas{namespace="${ns}",horizontalpodautoscaler=~"chaos-app.*"}`;

        const [cpuData, memPctData, memMbData, replicaData, errorData, hpaData] = await Promise.all([
            queryPrometheus(cpuQuery),
            queryPrometheus(memPercentQuery),
            queryPrometheus(memMbQuery),
            queryPrometheus(replicaQuery),
            queryPrometheus(errorRateQuery),
            queryPrometheus(hpaMaxQuery),
        ]);

        const cpuPercent = extractValue(cpuData) ?? 0;
        const memoryPercent = extractValue(memPctData) ?? 0;
        const memoryMB = extractValue(memMbData) ?? 0;
        const replicas = extractValue(replicaData) ?? 1;
        const errorRate = extractValue(errorData) ?? 0;
        const maxReplicas = extractValue(hpaData) ?? 10;

        return NextResponse.json({
            cpu: Math.round(cpuPercent * 10) / 10,
            memory: Math.round(memoryMB),
            memoryPercent: Math.round(memoryPercent * 10) / 10,
            replicas: Math.round(replicas),
            maxReplicas: Math.round(maxReplicas),
            errorRate: Math.round(errorRate * 100) / 100,
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
