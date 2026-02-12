"use client"

import React from "react"
import { useState, useEffect, useRef } from "react"
import { Cpu, DollarSign, TrendingUp, Zap, Server } from "lucide-react"
import { Button } from "@/components/ui/button"

const MAX_REPLICAS = 10
const COST_PER_REPLICA = 0.02

export function ScalingPanel() {
  const [isHighLoad, setIsHighLoad] = useState(false)
  const [replicas, setReplicas] = useState(1)
  const [cpuLoad, setCpuLoad] = useState(0)
  const [isScaling, setIsScaling] = useState(false)
  const [animatingReplicas, setAnimatingReplicas] = useState<number[]>([0])
  const [useMockData, setUseMockData] = useState(false)

  const hourlyCost = replicas * COST_PER_REPLICA

  // Fetch real metrics from Prometheus
  useEffect(() => {
    const fetchMetrics = async () => {
      try {
        const response = await fetch('/api/metrics')
        if (response.ok) {
          const data = await response.json()
          if (!data.fallback) {
            setCpuLoad(Math.round(data.cpu))
            setReplicas(data.replicas)
            setAnimatingReplicas(Array.from({ length: data.replicas }, (_, i) => i))
            setUseMockData(false)
            return
          }
        }
      } catch (error) {
        console.error('Failed to fetch metrics:', error)
      }
      // Fallback to mock data if API fails
      setUseMockData(true)
    }

    // Initial fetch
    fetchMetrics()

    // Poll every 5 seconds
    const interval = setInterval(fetchMetrics, 5000)
    return () => clearInterval(interval)
  }, [])

  return (
    <div
      className="rounded-lg border border-amber-500/30 bg-card/80 backdrop-blur-sm p-6 h-full flex flex-col holo-panel"
      style={{ "--tw-shadow-color": "rgba(245, 158, 11, 0.15)" } as React.CSSProperties}
    >
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <div className="p-2 rounded-lg bg-amber-500/10 border border-amber-500/30 shadow-[0_0_15px_rgba(245,158,11,0.2)]">
          <TrendingUp className="h-5 w-5 text-amber-500 neon-text" />
        </div>
        <div>
          <h2 className="text-lg font-semibold text-foreground font-sans">HPA & Cost Analysis</h2>
          <p className="text-xs text-amber-500/70 font-mono tracking-wider">
            {useMockData ? 'Mock Mode' : 'Live Prometheus Data'}
          </p>
        </div>
      </div>

      {/* CPU Load Gauge */}
      <div className="mb-6">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <Cpu className="h-4 w-4 text-amber-500" />
            <span className="text-sm text-muted-foreground font-sans">CPU Load</span>
          </div>
          <span
            className={`font-mono text-sm tracking-wider transition-colors duration-300 ${cpuLoad > 80 ? "text-destructive neon-text" : cpuLoad > 50 ? "text-amber-500 neon-text" : "text-accent"}`}
          >
            {cpuLoad}%
          </span>
        </div>
        <div className="h-4 rounded-full bg-secondary/80 overflow-hidden border border-border/50 shadow-[inset_0_2px_4px_rgba(0,0,0,0.3)]">
          <div
            className={`h-full rounded-full transition-all duration-500 ease-linear ${cpuLoad > 80
              ? "bg-gradient-to-r from-destructive/80 to-destructive shadow-[0_0_15px_rgba(244,63,94,0.6)]"
              : cpuLoad > 50
                ? "bg-gradient-to-r from-amber-600 to-amber-500 shadow-[0_0_15px_rgba(245,158,11,0.6)]"
                : "bg-gradient-to-r from-accent/80 to-accent shadow-[0_0_15px_rgba(16,185,129,0.5)]"
              }`}
            style={{ width: `${Math.min(cpuLoad, 100)}%` }}
          />
        </div>
      </div>

      {/* Replica Visualization */}
      <div className="flex-1">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <Server className="h-4 w-4 text-primary" />
            <span className="text-sm text-muted-foreground font-sans">Active Replicas</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="font-mono text-2xl text-primary neon-text">{replicas}</span>
            <span className="text-muted-foreground">/</span>
            <span className="font-mono text-sm text-muted-foreground">{MAX_REPLICAS}</span>
            {isScaling && <Zap className="h-4 w-4 text-amber-500 animate-pulse neon-text" />}
          </div>
        </div>

        {/* Replica Bar Chart - Server Rack Style */}
        <div className="grid grid-cols-10 gap-2 mb-6">
          {Array.from({ length: MAX_REPLICAS }).map((_, i) => {
            const isActive = animatingReplicas.includes(i)

            return (
              <div
                key={i}
                className={`h-24 rounded relative transition-all duration-300 ${isActive
                  ? `server-unit border border-primary/60`
                  : "bg-secondary/30 border border-border/20"
                  }`}
              >
                {isActive && (
                  <>
                    {/* LED indicator */}
                    <div className="absolute top-2 left-1/2 -translate-x-1/2 w-1.5 h-1.5 rounded-full bg-accent shadow-[0_0_6px_rgba(16,185,129,0.8)]" />
                    {/* Rack lines */}
                    <div className="absolute bottom-2 left-1/2 -translate-x-1/2 w-4 h-px bg-primary/40" />
                    <div className="absolute bottom-4 left-1/2 -translate-x-1/2 w-4 h-px bg-primary/40" />
                    <div className="absolute bottom-6 left-1/2 -translate-x-1/2 w-4 h-px bg-primary/40" />
                  </>
                )}
              </div>
            )
          })}
        </div>
      </div>

      {/* Cost Section with Animated Value */}
      <div className="p-4 rounded-lg bg-secondary/80 border border-amber-500/20 mb-6 shadow-[inset_0_0_20px_rgba(245,158,11,0.05)]">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <DollarSign className="h-5 w-5 text-accent" />
            <span className="text-sm text-muted-foreground font-sans">Current Hourly Cost</span>
          </div>
          <div
            className={`font-mono text-2xl tracking-wider transition-all duration-300 ${hourlyCost > 0.15
              ? "text-destructive neon-text"
              : hourlyCost > 0.06
                ? "text-amber-500 neon-text"
                : "text-accent cost-glow"
              }`}
          >
            ${hourlyCost.toFixed(2)}
            <span className="text-sm text-muted-foreground font-mono">/hr</span>
          </div>
        </div>
        {hourlyCost > 0.15 && (
          <p className="text-xs text-destructive mt-2 font-mono animate-pulse neon-text">
            HIGH COST ALERT: Consider scaling policies
          </p>
        )}
      </div>

      {/* Load Simulation Button - Heat Style */}
      <Button
        onClick={() => {
          const newState = !isHighLoad;
          setIsHighLoad(newState);
          if (newState) {
            // trigger stress for 30 seconds
            fetch('/api/stress', {
              method: 'POST',
              body: JSON.stringify({ duration: 30 }),
              headers: { 'Content-Type': 'application/json' }
            }).catch(err => console.error("Stress request failed", err));
          }
        }}
        className={`w-full h-14 font-mono font-bold text-base tracking-wider transition-all duration-300 ${isHighLoad
          ? "bg-amber-500/30 hover:bg-amber-500/40 border-2 border-amber-500/60 text-amber-500 heat-btn"
          : "bg-amber-500/10 hover:bg-amber-500/20 border-2 border-amber-500/30 text-amber-500"
          }`}
      >
        <Zap className="h-5 w-5 mr-2" />
        {isHighLoad ? "STOP LOAD SIMULATION" : "SIMULATE HIGH CPU LOAD"}
      </Button>

      {/* Info Footer */}
      <p className="text-xs text-muted-foreground text-center mt-4 font-sans">
        {useMockData ? 'Using mock data (Prometheus unavailable)' : 'Real-time metrics from Prometheus'}
      </p>
    </div>
  )
}
