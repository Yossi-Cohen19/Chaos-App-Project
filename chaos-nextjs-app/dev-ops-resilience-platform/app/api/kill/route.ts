import { NextResponse } from 'next/server';

export async function POST() {
    // We return a response first so the client knows the request was received,
    // then we kill the process. Ideally, the connection might drop before the response 
    // allows the client to process it, but this is a "hard crash" simulation.

    // Using a slight delay to allow the response to flush, optionally. 
    // But user asked for "immediately crash".
    // Let's print a log and then exit.

    console.log('Kill signal received. Terminating process...');

    // We intentionally don't await this or expect it to succeed fully if we exit immediately
    setTimeout(() => {
        process.exit(1);
    }, 100);

    return NextResponse.json({ status: 'terminating' }, { status: 200 });
}
