"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Zap, Activity } from "lucide-react"

export function StressButton() {
    const [isLoading, setIsLoading] = useState(false)
    const [result, setResult] = useState<any>(null)

    const handleStressTest = async () => {
        setIsLoading(true)
        setResult(null)

        try {
            const response = await fetch('/api/stress', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ duration: 60 }), // Request 60s for full effect
            })

            const data = await response.json()
            console.log('Stress Test Result:', data)
            setResult(data)
        } catch (error) {
            console.error('Stress Test Failed:', error)
            setResult({ error: 'Failed to run stress test' })
        } finally {
            setIsLoading(false)
        }
    }

    return (
        <div className="flex flex-col gap-2 items-center">
            <Button
                onClick={handleStressTest}
                disabled={isLoading}
                variant="outline"
                className="gap-2 border-primary/20 hover:bg-primary/10 transition-all font-mono"
            >
                {isLoading ? (
                    <>
                        <Activity className="h-4 w-4 animate-spin" />
                        STRESSING...
                    </>
                ) : (
                    <>
                        <Zap className="h-4 w-4 text-yellow-500" />
                        Test CPU Load (Safe Mode)
                    </>
                )}
            </Button>

            {result && (
                <div className="text-xs font-mono text-muted-foreground animate-in fade-in slide-in-from-top-1">
                    {result.error ? (
                        <span className="text-destructive">Error: {result.error}</span>
                    ) : (
                        <span className="text-green-500">
                            Done: {result.threads} threads / {result.duration}s
                        </span>
                    )}
                </div>
            )}
        </div>
    )
}
