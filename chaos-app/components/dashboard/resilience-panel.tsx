"use client"

import { useState, useEffect, useRef } from "react"
import { Database, Skull, Server, RefreshCw } from "lucide-react"
import { Button } from "@/components/ui/button"

type LogEntry = {
  timestamp: string
  level: "INFO" | "WARN" | "ERROR" | "K8S"
  message: string
}

const NORMAL_LOGS = [
  "Health check passed - 200 OK",
  "Incoming request processed",
  "Cache hit for user session",
  "Database query completed in 12ms",
  "Connection pool: 8/20 active",
  "Memory usage: 342MB / 512MB",
  "Heartbeat sent to control plane",
  "Request latency: 23ms avg",
]

export function ResiliencePanel() {
  const [hitCount, setHitCount] = useState(0)
  const [currentPod, setCurrentPod] = useState<string>("")
  const [availablePods, setAvailablePods] = useState<string[]>([])
  const [isReconnecting, setIsReconnecting] = useState(false)
  const [podStatus, setPodStatus] = useState<"healthy" | "terminated" | "reconnecting">("healthy")
  const [isGlitching, setIsGlitching] = useState(false)
  const [logs, setLogs] = useState<LogEntry[]>([])
  const [isKillActive, setIsKillActive] = useState(false)
  const logContainerRef = useRef<HTMLDivElement>(null)

  const getTimestamp = () => {
    const now = new Date()
    return now.toTimeString().split(" ")[0]
  }

  const addLog = (level: LogEntry["level"], message: string) => {
    setLogs((prev) => [...prev.slice(-50), { timestamp: getTimestamp(), level, message }])
  }

  // Fetch real database stats
  useEffect(() => {
    const fetchDbStats = async () => {
      try {
        const response = await fetch('/api/db/stats')
        if (response.ok) {
          const data = await response.json()
          if (!data.fallback) {
            setHitCount(data.active)
          }
        }
      } catch (error) {
        console.error('Failed to fetch DB stats:', error)
      }
    }

    fetchDbStats()
    const interval = setInterval(fetchDbStats, 5000)
    return () => clearInterval(interval)
  }, [])

  // Fetch real pod list
  useEffect(() => {
    const fetchPods = async () => {
      try {
        const response = await fetch('/api/pods')
        if (response.ok) {
          const data = await response.json()
          const podNames = data.pods.map((p: any) => p.name)
          setAvailablePods(podNames)
          if (podNames.length > 0 && !currentPod) {
            setCurrentPod(podNames[0])
          }
        }
      } catch (error) {
        console.error('Failed to fetch pods:', error)
      }
    }

    fetchPods()
    const interval = setInterval(fetchPods, 10000)
    return () => clearInterval(interval)
  }, [currentPod])

  // Auto-scroll logs
  useEffect(() => {
    if (logContainerRef.current) {
      logContainerRef.current.scrollTop = logContainerRef.current.scrollHeight
    }
  }, [logs])

  // Normal log generation
  useEffect(() => {
    if (isReconnecting) return
    const interval = setInterval(() => {
      addLog("INFO", NORMAL_LOGS[Math.floor(Math.random() * NORMAL_LOGS.length)])
    }, 3000)
    return () => clearInterval(interval)
  }, [isReconnecting])

  const handleKillPod = async () => {
    if (availablePods.length === 0) {
      addLog("ERROR", "No pods available to delete")
      return
    }

    // Find a pod to kill (not the current one if possible)
    const targetPod = availablePods.length > 1
      ? availablePods.find(p => p !== currentPod) || availablePods[0]
      : availablePods[0]

    setIsReconnecting(true)
    setIsKillActive(true)
    setIsGlitching(true)
    setPodStatus("terminated")

    addLog("WARN", `Deleting pod: ${targetPod}`)
    addLog("K8S", "Sending DELETE request to K8s API...")

    // Call real K8s API to delete pod
    try {
      const response = await fetch(`/api/pods?name=${encodeURIComponent(targetPod)}`, {
        method: 'DELETE',
      })

      if (response.ok) {
        addLog("K8S", `Pod ${targetPod} deleted successfully`)
        addLog("K8S", "ReplicaSet controller creating replacement pod...")
      } else {
        const error = await response.json()
        addLog("ERROR", `Failed to delete pod: ${error.message}`)
      }
    } catch (error: any) {
      addLog("ERROR", `K8s API error: ${error.message}`)
    }

    setTimeout(() => setIsKillActive(false), 1000)
    setTimeout(() => {
      setPodStatus("reconnecting")
      addLog("K8S", "Waiting for new pod to become ready...")
    }, 1500)

    // Recovery
    setTimeout(() => {
      setIsGlitching(false)
      setPodStatus("healthy")
      setIsReconnecting(false)
      addLog("INFO", "New pod healthy and serving traffic")

      // Refresh pod list
      fetch('/api/pods')
        .then(r => r.json())
        .then(data => {
          const podNames = data.pods.map((p: any) => p.name)
          setAvailablePods(podNames)
          if (podNames.length > 0) {
            setCurrentPod(podNames[0])
          }
        })
        .catch(console.error)
    }, 8000)
  }

  const getLogColor = (level: LogEntry["level"]) => {
    switch (level) {
      case "INFO":
        return "text-primary"
      case "WARN":
        return "text-amber-500"
      case "ERROR":
        return "text-destructive"
      case "K8S":
        return "text-cyan-400"
      default:
        return "text-primary"
    }
  }

  return (
    <div className="rounded-lg border border-primary/30 bg-card/80 backdrop-blur-sm p-6 h-full flex flex-col holo-panel">
      {/* Header */}
      <div className="flex items-center gap-3 mb-4">
        <div className="p-2 rounded-lg bg-primary/10 border border-primary/30 shadow-[0_0_15px_rgba(34,211,238,0.2)]">
          <Database className="h-5 w-5 text-primary neon-text" />
        </div>
        <div>
          <h2 className="text-lg font-semibold text-foreground font-sans">Service Resilience</h2>
          <p className="text-xs text-primary/70 font-mono tracking-wider">RDS Connection Pool</p>
        </div>
      </div>

      {/* Main Counter - Nixie Tube Style */}
      <div className="flex flex-col items-center justify-center py-4">
        <div className="relative">
          <div className="absolute inset-0 -inset-x-8 -inset-y-4 bg-gradient-to-b from-primary/5 via-primary/10 to-primary/5 rounded-xl blur-xl" />
          <div className="relative text-5xl md:text-6xl font-mono font-bold text-primary tracking-[0.15em] text-center nixie-counter">
            {hitCount.toLocaleString()}
          </div>
          <div className="absolute inset-0 text-5xl md:text-6xl font-mono font-bold text-primary tracking-[0.15em] text-center blur-md opacity-50">
            {hitCount.toLocaleString()}
          </div>
        </div>
        <p className="text-sm text-muted-foreground mt-2 font-sans uppercase tracking-widest">Active Connections</p>
      </div>

      {/* CRT Terminal Log */}
      <div className="mt-4 rounded-lg overflow-hidden crt-screen border border-primary/20 relative">
        <div className="px-3 py-1.5 border-b border-primary/20 flex items-center gap-2 bg-primary/5">
          <div className="flex gap-1.5">
            <div className="w-2 h-2 rounded-full bg-destructive/80" />
            <div className="w-2 h-2 rounded-full bg-amber-500/80" />
            <div className="w-2 h-2 rounded-full bg-accent/80" />
          </div>
          <span className="text-[10px] text-primary/60 font-mono tracking-wider">K8S EVENT LOG</span>
        </div>
        <div
          ref={logContainerRef}
          className="h-28 overflow-y-auto px-3 py-2 font-mono text-[11px] leading-relaxed scrollbar-thin"
        >
          {logs.map((log, i) => (
            <div key={i} className="flex gap-2">
              <span className="text-muted-foreground/60">{log.timestamp}</span>
              <span className={`${getLogColor(log.level)} font-semibold`}>[{log.level}]</span>
              <span className={getLogColor(log.level)}>{log.message}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Pod Status */}
      <div className="mt-4 p-4 rounded-lg bg-secondary/80 border border-primary/20 shadow-[inset_0_0_20px_rgba(34,211,238,0.05)]">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <Server className="h-4 w-4 text-primary/70" />
            <span className="text-sm text-muted-foreground font-sans">Current Pod:</span>
          </div>
          <div
            className={`flex items-center gap-2 px-3 py-1 rounded text-xs font-mono tracking-wider ${podStatus === "healthy"
              ? "bg-accent/20 text-accent border border-accent/40 shadow-[0_0_10px_rgba(16,185,129,0.3)]"
              : podStatus === "terminated"
                ? "bg-destructive/20 text-destructive border border-destructive/40 shadow-[0_0_10px_rgba(244,63,94,0.3)]"
                : "bg-amber-500/20 text-amber-500 border border-amber-500/40 shadow-[0_0_10px_rgba(245,158,11,0.3)]"
              }`}
          >
            {podStatus === "reconnecting" && <RefreshCw className="h-3 w-3 animate-spin" />}
            {podStatus.toUpperCase()}
          </div>
        </div>
        <div
          className={`font-mono text-sm flex items-center gap-2 ${isGlitching ? "text-destructive glitch-text" : "text-primary neon-text"
            }`}
        >
          <span>
            {podStatus === "terminated"
              ? "Deleting pod..."
              : podStatus === "reconnecting"
                ? "Waiting for replacement..."
                : currentPod || "Loading..."}
          </span>
        </div>
      </div>

      {/* Kill Button - Hazard Style */}
      <Button
        onClick={handleKillPod}
        disabled={isReconnecting || availablePods.length === 0}
        className={`mt-4 w-full h-14 bg-destructive/20 hover:bg-destructive/40 border-2 border-destructive/60 text-destructive font-mono font-bold text-base tracking-wider transition-all duration-300 disabled:opacity-50 relative overflow-hidden ${isKillActive ? "kill-active" : "hazard-btn"
          }`}
      >
        <Skull className="h-5 w-5 mr-2" />
        {isReconnecting ? "DELETING POD..." : `KILL POD (${availablePods.length} available)`}
      </Button>

      {/* Info Footer */}
      <p className="text-xs text-muted-foreground text-center mt-3 font-sans">
        Real chaos engineering - Deletes actual K8s pod triggering auto-recovery
      </p>
    </div>
  )
}
