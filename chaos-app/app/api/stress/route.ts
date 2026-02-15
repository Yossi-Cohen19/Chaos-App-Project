import { NextResponse } from 'next/server';
import { Worker } from 'worker_threads';
import os from 'os';

export async function POST(request: Request) {
    try {
        const body = await request.json();
        // SAFETY CRITICAL: Hardcode max duration to 120 seconds
        const requestedDuration = body.duration || 5;
        const durationSeconds = Math.min(requestedDuration, 120);

        // FULL LOAD: Use all cores to ensure we hit limits
        const totalCpus = os.cpus().length;
        const threadCount = Math.max(1, totalCpus);

        console.log(`Starting SAFE CPU stress for ${durationSeconds} seconds on ${threadCount} threads (Total CPUs: ${totalCpus})...`);

        const workerScript = `
            const { parentPort, workerData } = require('worker_threads');
            const endTime = Date.now() + workerData.duration * 1000;
            while (Date.now() < endTime) {
                // Heavy calculation
                Math.sqrt(Math.random() * Math.random());
            }
            if (parentPort) parentPort.postMessage('done');
        `;

        const workers = [];
        for (let i = 0; i < threadCount; i++) {
            workers.push(new Promise((resolve, reject) => {
                const worker = new Worker(workerScript, {
                    eval: true,
                    workerData: { duration: durationSeconds }
                });
                worker.on('message', resolve);
                worker.on('error', reject);
                worker.on('exit', (code) => {
                    if (code !== 0) reject(new Error(`Worker stopped with exit code ${code}`));
                    else resolve(code);
                });
            }));
        }

        await Promise.all(workers);

        console.log('CPU stress completed.');
        return NextResponse.json({
            status: 'completed',
            duration: durationSeconds,
            threads: threadCount,
            message: 'Stress test completed successfully (Full Load)'
        });
    } catch (error) {
        console.error('Stress test error:', error);
        return NextResponse.json({ error: 'Stress test failed' }, { status: 500 });
    }
}
