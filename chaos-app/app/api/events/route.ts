import { NextResponse } from 'next/server';
import * as k8s from '@kubernetes/client-node';

const kc = new k8s.KubeConfig();

if (process.env.KUBERNETES_SERVICE_HOST) {
    kc.loadFromCluster();
} else {
    kc.loadFromDefault();
}

const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
const namespace = process.env.NAMESPACE || 'dev';

export async function GET() {
    try {
        const response = await k8sApi.listNamespacedEvent(namespace);
        const items: k8s.CoreV1Event[] = response.body.items || [];
        const events = items
            .sort((a: k8s.CoreV1Event, b: k8s.CoreV1Event) => {
                const getTime = (d: Date | undefined | null) => {
                    if (!d) return 0;
                    return d instanceof Date ? d.getTime() : new Date(d).getTime();
                };
                const ta = getTime(a.lastTimestamp);
                const tb = getTime(b.lastTimestamp);
                return tb - ta;
            })
            .slice(0, 30)
            .map((event: k8s.CoreV1Event) => ({
                type: event.type || 'Normal',
                reason: event.reason || 'Unknown',
                message: event.message || '',
                source: event.source?.component || '',
                object: event.involvedObject?.name || '',
                timestamp: event.lastTimestamp || event.eventTime || null,
                count: event.count || 1,
            }));

        return NextResponse.json({ events });
    } catch (error: any) {
        console.error('K8s Events API error:', error);
        return NextResponse.json(
            { error: 'Failed to list events', message: error.message, events: [] },
            { status: 500 }
        );
    }
}
