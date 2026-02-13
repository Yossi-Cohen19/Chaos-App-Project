"use client"

import { useState, useEffect } from "react"
import { Activity, Cpu, AlertTriangle } from "lucide-react"

function SparklineChart({
  data,
  color,
  fillColor,
  label,
  value,
  unit,
  icon: Icon,
  isAlert = false
}: {
  data: number[]
  color: string
  fillColor: string
  label: string
  value: string
  unit: string
  icon: typeof Activity
  isAlert?: boolean
}) {
  const max = Math.max(...data)
  const min = Math.min(...data)
  const range = max - min || 1

  const points = data
    .map((val, i) => {
      const x = (i / (data.length - 1)) * 100
      const y = 100 - ((val - min) / range) * 70 - 15
      return `${x},${y}`
    })
    .join(" ")

  const areaPoints = `0,100 ${points} 100,100`

  return (
    <div className="flex-1 p-4 rounded-lg bg-card/80 border border-border/30 holo-panel">
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center gap-2">
          <Icon className={`h-4 w-4 ${color}`} />
          <span className="text-xs text-muted-foreground uppercase tracking-widest font-sans">{label}</span>
        </div>
        <div className={`font-mono text-sm tracking-wider ${isAlert ? "text-destructive animate-pulse neon-text" : `${color} neon-text`}`}>
          {value}
          <span className="text-muted-foreground text-xs ml-1 font-mono">{unit}</span>
        </div>
      </div>
      <svg viewBox="0 0 100 100" className="w-full h-16" preserveAspectRatio="none">
        <defs>
          <filter id={`glow-${label}`} x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="3" result="blur" />
            <feMerge>
              <feMergeNode in="blur" />
              <feMergeNode in="blur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
          <linearGradient id={`gradient-${label}`} x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={fillColor} stopOpacity="0.4" />
            <stop offset="100%" stopColor={fillColor} stopOpacity="0" />
          </linearGradient>
        </defs>
        <line x1="0" y1="25" x2="100" y2="25" stroke="currentColor" strokeOpacity="0.08" strokeWidth="0.5" />
        <line x1="0" y1="50" x2="100" y2="50" stroke="currentColor" strokeOpacity="0.08" strokeWidth="0.5" />
        <line x1="0" y1="75" x2="100" y2="75" stroke="currentColor" strokeOpacity="0.08" strokeWidth="0.5" />
        <polygon
          points={areaPoints}
          fill={`url(#gradient-${label})`}
        />
        <polyline
          points={points}
          fill="none"
          stroke="currentColor"
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
          className={color}
          filter={`url(#glow-${label})`}
        />
        <polyline
          points={points}
          fill="none"
          stroke="currentColor"
          strokeWidth="1"
          strokeLinecap="round"
          strokeLinejoin="round"
          className={color}
          style={{ opacity: 0.8 }}
        />
      </svg>
    </div>
  )
}

export function MetricsFooter() {
  const [memoryData, setMemoryData] = useState<number[]>(() => Array(20).fill(0))
  const [cpuData, setCpuData] = useState<number[]>(() => Array(20).fill(0))
  const [errorData, setErrorData] = useState<number[]>(() => Array(20).fill(0))
  const [useMockData, setUseMockData] = useState(true)

  // Fetch real metrics periodically
  useEffect(() => {
    const fetchMetrics = async () => {
      try {
        const response = await fetch('/api/metrics')
        if (response.ok) {
          const data = await response.json()
          if (!data.fallback) {
            setCpuData(prev => [...prev.slice(1), data.cpu || 0])
            setMemoryData(prev => [...prev.slice(1), data.memoryPercent || 0])
            setErrorData(prev => [...prev.slice(1), data.errorRate || 0])
            setUseMockData(false)
            return
          }
        }
      } catch (error) {
        console.error('Failed to fetch metrics:', error)
      }

      // Fallback to mock data
      setUseMockData(true)
      setMemoryData(prev => [...prev.slice(1), 65 + (Math.random() - 0.5) * 20])
      setCpuData(prev => [...prev.slice(1), 45 + (Math.random() - 0.5) * 30])
      setErrorData(prev => {
        const spike = Math.random() > 0.9 ? 5 : 0
        return [...prev.slice(1), Math.max(0, 0.5 + (Math.random() - 0.5) * 0.6 + spike)]
      })
    }

    const interval = setInterval(fetchMetrics, 3000)
    fetchMetrics()
    return () => clearInterval(interval)
  }, [])

  const currentMemory = memoryData[memoryData.length - 1]
  const currentCpu = cpuData[cpuData.length - 1]
  const currentError = errorData[errorData.length - 1]
  const isErrorSpike = currentError > 2

  return (
    <footer className="border-t border-primary/20 bg-card/90 backdrop-blur-sm px-6 py-4 shadow-[0_-5px_30px_rgba(34,211,238,0.1)]">
      <div className="flex items-center gap-2 mb-3">
        <Activity className="h-4 w-4 text-primary neon-text" />
        <span className="text-xs text-muted-foreground uppercase tracking-widest font-sans">Real-time Observability</span>
        <span className="text-xs text-primary/60 font-mono tracking-wider">
          {useMockData ? 'Mock Mode' : 'Prometheus/Grafana'}
        </span>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <SparklineChart
          data={memoryData}
          color="text-primary"
          fillColor="#22d3ee"
          label="Memory Usage"
          value={currentMemory.toFixed(1)}
          unit="%"
          icon={Activity}
        />
        <SparklineChart
          data={cpuData}
          color="text-amber-500"
          fillColor="#f59e0b"
          label="CPU Load"
          value={currentCpu.toFixed(1)}
          unit="%"
          icon={Cpu}
        />
        <SparklineChart
          data={errorData}
          color={isErrorSpike ? "text-destructive" : "text-accent"}
          fillColor={isErrorSpike ? "#f43f5e" : "#10b981"}
          label="Error Rate"
          value={currentError.toFixed(2)}
          unit="/hr"
          icon={AlertTriangle}
          isAlert={isErrorSpike}
        />
      </div>
    </footer>
  )
}
